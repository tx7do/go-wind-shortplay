/**
 * 站内信 API hooks（react-query）——基座 internal-message 域（管理端收件箱）
 *
 * - GET /admin/v1/internal-message/inbox（服务端强制按调用者 user_id 过滤，
 *   前端无需也不应传 recipient_user_id）；
 * - POST /admin/v1/internal-message/read（recipientIds 为空 = 该用户全部未读，
 *   对齐基座契约；非空 = 仅指定的收件行）；
 * - POST /admin/v1/internal-message/inbox/delete（recipientIds 必填）；
 * - GET /admin/v1/internal-message/messages/{id}（详情抽屉按 messageId 补拉
 *   发送人名，sender_id=0 的系统消息 senderName 为空）。
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
import type { Int64 } from '@/api/types';
import { PaginationQuery, queryClient } from '@/core';

// ==============================
// 类型（internal_message.service.v1 的 protojson 形状）
// ==============================

/**
 * 收件箱行：internal_message.service.v1.InternalMessageRecipient。
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
  /** 不分页全量拉（导出聚合用） */
  noPaging?: boolean;
}

/** 站内信消息（详情抽屉只需要发送人名；sender_id=0 的系统消息为空） */
export interface InternalMessageSummary {
  id?: number;
  senderName?: string;
}

// ==============================
// 收件箱查询
// ==============================

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

/**
 * 收件箱列表（PaginationQuery 直通形态）：收件箱页 ProTable request 与
 * TableExportButton 聚合导出走这里，搜索条件由调用方合进 formValues。
 */
export async function fetchListInboxQuery(query: PaginationQuery): Promise<InboxListResponse> {
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

// ==============================
// 收件箱操作
// ==============================

/**
 * 标记已读（POST /admin/v1/internal-message/read）。
 * recipientIds 为空 = 该用户全部未读置已读（基座契约）；非空 = 仅指定收件行。
 */
export function useMarkNotificationAsRead(
  options?: UseMutationOptions<unknown, Error, { recipientIds: number[] }>,
) {
  const { onSuccess: callerOnSuccess, onError: callerOnError, ...rest } = options ?? {};
  return useMutation<unknown, Error, { recipientIds: number[] }>({
    mutationFn: ({ recipientIds }) =>
      adminHttp.post('internal-message/read', { recipientIds }),
    ...rest,
    onSuccess: (...args) => {
      invalidateInboxQueries();
      callerOnSuccess?.(...args);
    },
    onError: callerOnError,
  });
}

/** 从收件箱删除（POST /admin/v1/internal-message/inbox/delete，recipientIds 必填） */
export function useDeleteNotificationFromInbox(
  options?: UseMutationOptions<unknown, Error, { recipientIds: number[] }>,
) {
  const { onSuccess: callerOnSuccess, onError: callerOnError, ...rest } = options ?? {};
  return useMutation<unknown, Error, { recipientIds: number[] }>({
    mutationFn: ({ recipientIds }) =>
      adminHttp.post('internal-message/inbox/delete', { recipientIds }),
    ...rest,
    onSuccess: (...args) => {
      invalidateInboxQueries();
      callerOnSuccess?.(...args);
    },
    onError: callerOnError,
  });
}

/**
 * 按 messageId 补拉消息（GET /admin/v1/internal-message/messages/{id}）：
 * 收件行不带发送人名，详情抽屉打开时取一次；失败不影响抽屉其余部分。
 */
export function useGetInternalMessage(
  id: number | undefined,
  options?: Omit<UseQueryOptions<InternalMessageSummary, Error>, 'queryKey' | 'queryFn'>,
) {
  return useQuery<InternalMessageSummary, Error>({
    queryKey: ['getInternalMessage', id],
    queryFn: () => adminHttp.get<InternalMessageSummary>(`internal-message/messages/${id}`),
    ...options,
    enabled: (options?.enabled ?? true) && !!id,
  });
}
