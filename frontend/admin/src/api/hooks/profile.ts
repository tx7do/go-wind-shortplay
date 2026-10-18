/**
 * 个人中心 / 站内通知 API hooks（react-query）
 *
 * 个人中心走基座链路（i_user_profile）：
 * - GET /admin/v1/me、PUT /admin/v1/me（{data,updateMask} 信封；可改字段
 *   nickname/avatar/realname/mobile/email/remark/gender，基座白名单过滤）；
 * - POST /admin/v1/me/password（旧密码错误 400 BAD_REQUEST，页面内友好提示）；
 * 站内通知走基座 internal-message 域（管理端收件箱）：
 * - GET /admin/v1/internal-message/inbox（服务端强制按调用者 user_id 过滤）；
 * - POST /admin/v1/internal-message/read（recipientIds 必填非空，空数组 400）；
 * 实时推送走管理端 SSE（server.sse :7601 /events，事件 notification），
 * 失联时由 useGetUnreadCount 的兜底轮询补拉。
 */
import {
  useMutation,
  useQuery,
  type UseMutationOptions,
  type UseQueryOptions,
} from '@tanstack/react-query';

import { adminHttp } from '@/api/client';
import type {
  AdminUser,
  ChangePasswordRequest,
  Int64,
  UpdateProfileRequest,
} from '@/api/types';
import { PaginationQuery, queryClient } from '@/core';

// ==============================
// 个人中心（基座 /admin/v1/me）
// ==============================

export function useGetProfile(options?: UseQueryOptions<AdminUser, Error>) {
  return useQuery<AdminUser, Error>({
    queryKey: ['adminProfile'],
    queryFn: () => adminHttp.get<AdminUser>('me'),
    ...options,
  });
}

export function useUpdateProfile(
  options?: UseMutationOptions<unknown, Error, UpdateProfileRequest>,
) {
  const { onSuccess: callerOnSuccess, ...rest } = options ?? {};
  return useMutation<unknown, Error, UpdateProfileRequest>({
    mutationFn: (data) => {
      const values: Record<string, string> = {};
      for (const [k, v] of Object.entries(data)) {
        if (v !== undefined && v !== null && v !== '') values[k] = String(v);
      }
      return adminHttp.put<unknown>('me', {
        data: values,
        // 基座 UpdateUserRequest：updateMask 逗号分隔（提交字段 + id）
        updateMask: [...Object.keys(values), 'id'].join(','),
      });
    },
    ...rest,
    onSuccess: (...args) => {
      // 资料变更后失效缓存（个人中心页与顶栏头像昵称一致）
      queryClient.invalidateQueries({ queryKey: ['adminProfile'] });
      callerOnSuccess?.(...args);
    },
  });
}

/**
 * 修改密码（基座 POST /admin/v1/me/password）。旧密码错误时后端返回
 * 400 BAD_REQUEST（message: invalid old password），页面给出友好提示。
 */
export function useChangePassword(
  options?: UseMutationOptions<void, Error, ChangePasswordRequest>,
) {
  return useMutation<void, Error, ChangePasswordRequest>({
    mutationFn: (data) => adminHttp.post<void>('me/password', data),
    ...options,
  });
}

// ==============================
// 站内通知（基座 internal-message 收件箱 + SSE 实时推送）
// ==============================

/**
 * 收件箱行：internal_message.service.v1.InternalMessageRecipient 的 protojson 形状。
 * status 枚举为名字符串；uint64 total 为 JSON 字符串（protojson 约定）。
 */
export interface InboxItem {
  id?: number;
  messageId?: number;
  recipientUserId?: number;
  status?: 'SENT' | 'RECEIVED' | 'READ' | 'REVOKED' | 'DELETED';
  title?: string;
  content?: string;
  receivedAt?: string;
  readAt?: string;
  createdAt?: string;
  updatedAt?: string;
}

export interface InboxListResponse {
  items?: InboxItem[];
  total?: Int64;
}

export interface ListInboxParams {
  page?: number;
  pageSize?: number;
  /** 只看未读（服务端按 status=SENT 过滤；本后端未读即 SENT，已读置 READ） */
  unreadOnly?: boolean;
  /** 不分页全量拉（标记全部已读前收集 id 用） */
  noPaging?: boolean;
}

/**
 * 收件箱列表（GET /admin/v1/internal-message/inbox）。
 * 服务端强制按调用者 user_id 过滤（repo 内 viewerUserIDFromContext），
 * 前端无需（也不应）传 recipient_user_id。
 */
export async function fetchListInbox(params: ListInboxParams): Promise<InboxListResponse> {
  const query = new PaginationQuery({
    paging: params.noPaging ? undefined : { page: params.page || 1, pageSize: params.pageSize || 10 },
    orderBy: ['-created_at'],
    formValues: params.unreadOnly ? { status: 'SENT' } : undefined,
  });
  return adminHttp.get<InboxListResponse>('internal-message/inbox', query.toRawParams());
}

/** 未读判定：SENT（待拉取）与 RECEIVED（已拉取未读）都算未读；READ/REVOKED/DELETED 不算 */
export function isInboxItemUnread(item: InboxItem): boolean {
  return item.status === 'SENT' || item.status === 'RECEIVED';
}

/**
 * 未读数角标：未读 total（服务端 COUNT）。
 * 实时性由 SSE notification 事件 invalidate 驱动；这里保留 5 分钟兜底轮询，
 * 仅在 SSE 失联时补拉（与基座 HeaderContent 的节奏一致）。
 * retry:false：SSE 正常时无需重试放大请求；失败角标短暂滞后可接受。
 */
export function useGetUnreadCount(options?: UseQueryOptions<InboxListResponse, Error>) {
  return useQuery<InboxListResponse, Error>({
    queryKey: ['inbox', 'unread'],
    queryFn: () => fetchListInbox({ page: 1, pageSize: 1, unreadOnly: true }),
    refetchInterval: 300_000,
    refetchIntervalInBackground: false,
    retry: false,
    ...options,
  });
}

/** 失效全部收件箱查询（SSE 推送 / 已读操作后调用） */
export function invalidateInboxQueries() {
  queryClient.invalidateQueries({ queryKey: ['inbox'] });
}

/**
 * 标记已读（POST /admin/v1/internal-message/read）。
 * ⚠ 与基座差异：本后端 recipientIds 必须非空（空数组 400 BadRequest），
 * 「全部已读」由 markAllInboxRead 先拉未读 id 列表再提交。
 */
export function useMarkInboxRead(
  options?: UseMutationOptions<unknown, Error, { ids: number[] }>,
) {
  const { onSuccess: callerOnSuccess, ...rest } = options ?? {};
  return useMutation<unknown, Error, { ids: number[] }>({
    mutationFn: ({ ids }) => adminHttp.post('internal-message/read', { recipientIds: ids }),
    ...rest,
    onSuccess: (...args) => {
      invalidateInboxQueries();
      callerOnSuccess?.(...args);
    },
  });
}

/** 全部已读：拉全量未读 id（noPaging）后一次性提交；无未读时不发请求 */
export function useMarkAllInboxRead(
  options?: UseMutationOptions<unknown, Error, void>,
) {
  const { onSuccess: callerOnSuccess, ...rest } = options ?? {};
  return useMutation<unknown, Error, void>({
    mutationFn: async () => {
      const res = await fetchListInbox({ noPaging: true, unreadOnly: true });
      const ids = (res.items ?? [])
        .map((item) => item.id)
        .filter((id): id is number => id !== null && id !== undefined);
      if (ids.length === 0) return;
      await adminHttp.post('internal-message/read', { recipientIds: ids });
    },
    ...rest,
    onSuccess: (...args) => {
      invalidateInboxQueries();
      callerOnSuccess?.(...args);
    },
  });
}
