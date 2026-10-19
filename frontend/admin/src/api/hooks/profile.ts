/**
 * 个人中心 API hooks（react-query），走基座链路（i_user_profile）：
 * - GET /admin/v1/me、PUT /admin/v1/me（{data,updateMask} 信封；可改字段
 *   nickname/avatar/realname/mobile/email/remark/gender，基座白名单过滤）；
 * - POST /admin/v1/me/password（旧密码错误 400 BAD_REQUEST，页面内友好提示）。
 * 站内信收件箱相关 hooks 在 @/api/hooks/internal-message。
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
