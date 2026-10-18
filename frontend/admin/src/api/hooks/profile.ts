/**
 * 个人中心 / 站内通知 API hooks（react-query）
 *
 * 个人中心走基座链路（i_user_profile）：
 * - GET /admin/v1/me、PUT /admin/v1/me（{data,updateMask} 信封；可改字段
 *   nickname/avatar/realname/mobile/email/remark/gender，基座白名单过滤）；
 * - POST /admin/v1/me/password（旧密码错误 400 BAD_REQUEST，页面内友好提示）；
 * 站内通知段为 Phase 2 契约（后端暂无对应端点，保留供后续接通）。
 */
import {
  useMutation,
  useQuery,
  type UseMutationOptions,
  type UseQueryOptions,
} from '@tanstack/react-query';

import { adminHttp } from '@/api/client';
import type {
  AdminNotification,
  AdminUser,
  ChangePasswordRequest,
  Int64,
  ListNotificationsResponse,
  UpdateProfileRequest,
} from '@/api/types';
import { queryClient } from '@/core';

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
// 站内通知（轮询，不依赖 SSE）
// ==============================

export interface ListNotificationsParams {
  unreadOnly?: boolean;
  pageNum?: number;
  pageSize?: number;
}

/**
 * 通知列表（Admin 端复用 notify 域，pageNum 从 1 起）。
 * 注意：必须直接发请求，不能用 queryClient.fetchQuery——调用方 useQuery 的
 * queryKey 与此处相同，fetchQuery 会去重返回外层在途 promise 造成自等死锁。
 */
export async function fetchListNotifications(params: ListNotificationsParams) {
  return adminHttp.get<ListNotificationsResponse>('notifications', {
    unreadOnly: params.unreadOnly || undefined,
    pageNum: params.pageNum || 1,
    pageSize: params.pageSize || 10,
  });
}

/**
 * 未读数角标：顶栏通知铃以 30s 轮询拉取（原 cms 为 SSE 实时推送 + 5 分钟兜底轮询，
 * 本后端无管理端 SSE，统一改为轮询）。
 * ⚠ 后端暂无 /notifications* 管理端端点（Phase 2 契约保留待接通）：
 * retry:false 避免每次轮询 404 × 默认 3 次重试放大请求量；失败静默（角标恒 0）。
 */
export function useGetUnreadCount(
  options?: UseQueryOptions<{ count?: Int64 }, Error>,
) {
  return useQuery<{ count?: Int64 }, Error>({
    queryKey: ['adminUnreadCount'],
    queryFn: () => adminHttp.get<{ count?: Int64 }>('notifications/unread-count'),
    refetchInterval: 30_000,
    refetchIntervalInBackground: false,
    retry: false,
    ...options,
  });
}

export function useMarkNotificationsRead(
  options?: UseMutationOptions<void, Error, { ids: number[] }>,
) {
  const { onSuccess: callerOnSuccess, ...rest } = options ?? {};
  return useMutation<void, Error, { ids: number[] }>({
    mutationFn: ({ ids }) => adminHttp.put<void>('notifications/read', { ids }),
    ...rest,
    onSuccess: (...args) => {
      queryClient.invalidateQueries({ queryKey: ['adminUnreadCount'] });
      queryClient.invalidateQueries({ queryKey: ['listAdminNotifications'] });
      callerOnSuccess?.(...args);
    },
  });
}

export function useMarkAllNotificationsRead(options?: UseMutationOptions<void, Error, void>) {
  const { onSuccess: callerOnSuccess, ...rest } = options ?? {};
  return useMutation<void, Error, void>({
    mutationFn: () => adminHttp.put<void>('notifications/read-all', {}),
    ...rest,
    onSuccess: (...args) => {
      queryClient.invalidateQueries({ queryKey: ['adminUnreadCount'] });
      queryClient.invalidateQueries({ queryKey: ['listAdminNotifications'] });
      callerOnSuccess?.(...args);
    },
  });
}

/** 类型收窄辅助：判断通知类型 Tag 展示用 */
export function getNotificationTypeLabel(type: unknown): 'LIKE' | 'COMMENT' | 'FOLLOW' | 'SYSTEM' {
  const s = String(type ?? '');
  if (s.includes('COMMENT')) return 'COMMENT';
  if (s.includes('FOLLOW')) return 'FOLLOW';
  if (s.includes('SYSTEM')) return 'SYSTEM';
  return 'LIKE';
}

export type { AdminNotification };
