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
    mutationFn: ({ id, values }: { id: number; values: Record<string, unknown> }) => {
      // ⚠ 后端缺陷规避（实测 2026-10-18）：更新载荷携带 permissions + updateMask
      // 含 permissions 时，核心库 FilterByFieldMask 会在 ReplacePermissions 之前
      // 就地剥掉 data.permissions（permissions 已被后端移出 mask），ReplacePermissions
      // 拿到空列表 → 角色既有授权被整体清空（cms 基座同源同病）。
      // 故更新路径一律剔除 permissions（后端维持既有授权不变）；权限分配仅在
      // 创建路径提交（Create 的 ReplacePermissions 不经 mask 过滤，实测可用）。
      const metaValues: Record<string, unknown> = { ...values };
      delete metaValues.permissions;
      return adminHttp.put<unknown>(`roles/${id}`, {
        id,
        data: metaValues,
        updateMask: makeUpdateMask(Object.keys(metaValues)),
      });
    },
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
