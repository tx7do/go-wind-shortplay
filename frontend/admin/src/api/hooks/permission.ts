/**
 * 权限点管理 hooks —— 从 go-wind-cms api/hooks/permission.ts 拷贝适配：
 * cms 的 apiClient.permissionService.* 改为本仓 adminHttp（/admin/v1/permissions）。
 * 短剧无独立权限点管理页，本文件供角色授权树（RoleDrawer）取数。
 */
import {
  useMutation,
  useQuery,
  type UseMutationOptions,
  type UseQueryOptions,
} from '@tanstack/react-query';
import {
  type permissionservicev1_CreatePermissionRequest,
  type permissionservicev1_DeletePermissionRequest,
  type permissionservicev1_GetPermissionRequest,
  type permissionservicev1_ListPermissionResponse,
  type permissionservicev1_Permission,
} from '@/api/generated/admin/service/v1';
import { makeUpdateMask, type PaginationQuery } from '@/core';
import { adminHttp } from '@/api/client';
import { queryClient, rbacRawParams } from './rbac';

// ==============================
// 权限点管理
// ==============================

export function useListPermissions(
  query: PaginationQuery,
  options?: UseQueryOptions<permissionservicev1_ListPermissionResponse, Error>,
) {
  return useQuery({
    queryKey: ['listPermissions', query],
    queryFn: () =>
      adminHttp.get<permissionservicev1_ListPermissionResponse>('permissions', rbacRawParams(query)),
    ...options,
  });
}

export async function fetchListPermissions(params: PaginationQuery) {
  return queryClient.fetchQuery({
    queryKey: ['listPermissions', params],
    queryFn: () =>
      adminHttp.get<permissionservicev1_ListPermissionResponse>('permissions', rbacRawParams(params)),
    retry: 0,
  });
}

export function useGetPermission(
  req: permissionservicev1_GetPermissionRequest,
  options?: UseQueryOptions<permissionservicev1_Permission, Error>,
) {
  return useQuery({
    queryKey: ['getPermission', req],
    queryFn: () => adminHttp.get<permissionservicev1_Permission>(`permissions/${req.id ?? ''}`),
    ...options,
  });
}

export function useCreatePermission(
  options?: UseMutationOptions<unknown, Error, permissionservicev1_CreatePermissionRequest>,
) {
  return useMutation({
    mutationFn: (data) => adminHttp.post<unknown>('permissions', data),
    ...options,
  });
}

export function useUpdatePermission(
  options?: UseMutationOptions<unknown, Error, { id: number; values: Record<string, unknown> }>,
) {
  return useMutation({
    mutationFn: ({ id, values }: { id: number; values: Record<string, unknown> }) =>
      adminHttp.put<unknown>(`permissions/${id}`, {
        id,
        data: { ...values },
        updateMask: makeUpdateMask(Object.keys(values ?? {})),
      }),
    ...options,
  });
}

export function useDeletePermission(
  options?: UseMutationOptions<unknown, Error, permissionservicev1_DeletePermissionRequest>,
) {
  return useMutation({
    mutationFn: (req) => adminHttp.delete<unknown>(`permissions/${req.id}`),
    ...options,
  });
}
