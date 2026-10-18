/**
 * 角色管理 hooks —— 从 go-wind-cms api/hooks/role.ts 拷贝适配：
 * cms 的 apiClient.roleService.* 改为本仓 adminHttp（REST 路径 /admin/v1/roles），
 * 请求/响应形状与基座契约一致（列表 query 走 PaginationQuery.toRawParams()，
 * Update 用 {data, updateMask} 信封）。
 */
import {
  useMutation,
  useQuery,
  type UseMutationOptions,
  type UseQueryOptions,
} from '@tanstack/react-query';
import {
  type permissionservicev1_CreateRoleRequest,
  type permissionservicev1_DeleteRoleRequest,
  type permissionservicev1_GetRoleRequest,
  type permissionservicev1_ListRoleResponse,
  type permissionservicev1_Role,
} from '@/api/generated/admin/service/v1';
import { makeUpdateMask, type PaginationQuery } from '@/core';
import { adminHttp } from '@/api/client';
import { queryClient, rbacRawParams } from './rbac';

// ==============================
// 角色管理
// ==============================

export function useListRoles(
  query: PaginationQuery,
  options?: UseQueryOptions<permissionservicev1_ListRoleResponse, Error>,
) {
  return useQuery({
    queryKey: ['listRoles', query],
    queryFn: () => adminHttp.get<permissionservicev1_ListRoleResponse>('roles', rbacRawParams(query)),
    ...options,
  });
}

export async function fetchListRoles(params: PaginationQuery) {
  return queryClient.fetchQuery({
    queryKey: ['listRoles', params],
    queryFn: () =>
      adminHttp.get<permissionservicev1_ListRoleResponse>('roles', rbacRawParams(params)),
    retry: 0,
  });
}

export function useGetRole(
  req: permissionservicev1_GetRoleRequest,
  options?: UseQueryOptions<permissionservicev1_Role, Error>,
) {
  return useQuery({
    queryKey: ['getRole', req],
    queryFn: () => adminHttp.get<permissionservicev1_Role>(`roles/${req.id ?? ''}`),
    ...options,
  });
}

export function useCreateRole(
  options?: UseMutationOptions<unknown, Error, permissionservicev1_CreateRoleRequest>,
) {
  return useMutation({
    mutationFn: (data) => adminHttp.post<unknown>('roles', data),
    ...options,
  });
}

export function useUpdateRole(
  options?: UseMutationOptions<unknown, Error, { id: number; values: Record<string, unknown> }>,
) {
  return useMutation({
    // 对齐基座原生行为：Update 载荷整体透传（含 permissions）+ 全量字段 updateMask。
    // 后端 role_repo.Update 已修复「mask 剥离 permissions 致 ReplacePermissions
    // 拿空列表清空授权」缺陷（字段掩码过滤前快照权限集合，后置替换），编辑提交
    // 权限即生效，无需再规避剔除。
    mutationFn: ({ id, values }: { id: number; values: Record<string, unknown> }) =>
      adminHttp.put<unknown>(`roles/${id}`, {
        id,
        data: values,
        updateMask: makeUpdateMask(Object.keys(values)),
      }),
    ...options,
  });
}

export function useDeleteRole(
  options?: UseMutationOptions<unknown, Error, permissionservicev1_DeleteRoleRequest>,
) {
  return useMutation({
    mutationFn: (req) => adminHttp.delete<unknown>(`roles/${req.id}`),
    ...options,
  });
}
