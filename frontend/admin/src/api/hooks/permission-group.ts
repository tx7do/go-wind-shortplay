/**
 * 权限组管理 hooks —— 从 go-wind-cms api/hooks/permission-group.ts 拷贝适配：
 * cms 的 apiClient.permissionGroupService.* 改为本仓 adminHttp
 * （/admin/v1/permission-groups）。短剧无独立权限组管理页，
 * 本文件供角色授权树（RoleDrawer）取数。
 */
import {
  useMutation,
  useQuery,
  type UseMutationOptions,
  type UseQueryOptions,
} from '@tanstack/react-query';
import {
  type permissionservicev1_CreatePermissionGroupRequest,
  type permissionservicev1_DeletePermissionGroupRequest,
  type permissionservicev1_GetPermissionGroupRequest,
  type permissionservicev1_ListPermissionGroupResponse,
  type permissionservicev1_PermissionGroup,
} from '@/api/generated/admin/service/v1';
import { makeUpdateMask, type PaginationQuery } from '@/core';
import { adminHttp } from '@/api/client';
import { queryClient, rbacRawParams } from './rbac';

// ==============================
// 权限组管理
// ==============================

export function useListPermissionGroups(
  query: PaginationQuery,
  options?: UseQueryOptions<permissionservicev1_ListPermissionGroupResponse, Error>,
) {
  return useQuery({
    queryKey: ['listPermissionGroups', query],
    queryFn: () =>
      adminHttp.get<permissionservicev1_ListPermissionGroupResponse>(
        'permission-groups',
        rbacRawParams(query),
      ),
    ...options,
  });
}

export async function fetchListPermissionGroups(params: PaginationQuery) {
  return queryClient.fetchQuery({
    queryKey: ['listPermissionGroups', params],
    queryFn: () =>
      adminHttp.get<permissionservicev1_ListPermissionGroupResponse>(
        'permission-groups',
        rbacRawParams(params),
      ),
    retry: 0,
  });
}

export function useGetPermissionGroup(
  req: permissionservicev1_GetPermissionGroupRequest,
  options?: UseQueryOptions<permissionservicev1_PermissionGroup, Error>,
) {
  return useQuery({
    queryKey: ['getPermissionGroup', req],
    queryFn: () =>
      adminHttp.get<permissionservicev1_PermissionGroup>(`permission-groups/${req.id ?? ''}`),
    ...options,
  });
}

export function useCreatePermissionGroup(
  options?: UseMutationOptions<unknown, Error, permissionservicev1_CreatePermissionGroupRequest>,
) {
  return useMutation({
    mutationFn: (data) => adminHttp.post<unknown>('permission-groups', data),
    ...options,
  });
}

export function useUpdatePermissionGroup(
  options?: UseMutationOptions<unknown, Error, { id: number; values: Record<string, unknown> }>,
) {
  return useMutation({
    mutationFn: ({ id, values }: { id: number; values: Record<string, unknown> }) =>
      adminHttp.put<unknown>(`permission-groups/${id}`, {
        id,
        data: { ...values, children: [] },
        updateMask: makeUpdateMask(Object.keys(values ?? {})),
      }),
    ...options,
  });
}

export function useDeletePermissionGroup(
  options?: UseMutationOptions<unknown, Error, permissionservicev1_DeletePermissionGroupRequest>,
) {
  return useMutation({
    mutationFn: (req) => adminHttp.delete<unknown>(`permission-groups/${req.id}`),
    ...options,
  });
}
