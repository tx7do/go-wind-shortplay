/**
 * 组织架构（部门）管理 hooks —— 从 go-wind-cms api/hooks/org-unit.ts 拷贝适配：
 * cms 的 apiClient.orgUnitService.* 改为本仓 adminHttp（REST 路径
 * /admin/v1/org-units；短剧后端无 /departments 路由，实测 404）。
 */
import {
  useMutation,
  useQuery,
  type UseMutationOptions,
  type UseQueryOptions,
} from '@tanstack/react-query';
import {
  type identityservicev1_CreateOrgUnitRequest,
  type identityservicev1_DeleteOrgUnitRequest,
  type identityservicev1_GetOrgUnitRequest,
  type identityservicev1_ListOrgUnitResponse,
  type identityservicev1_OrgUnit,
} from '@/api/generated/admin/service/v1';
import { makeUpdateMask, type PaginationQuery } from '@/core';
import { adminHttp } from '@/api/client';
import { queryClient, rbacRawParams } from './rbac';

// ==============================
// 组织架构管理
// ==============================

export function useListOrgUnits(
  query: PaginationQuery,
  options?: UseQueryOptions<identityservicev1_ListOrgUnitResponse, Error>,
) {
  return useQuery({
    queryKey: ['listOrgUnits', query],
    queryFn: () =>
      adminHttp.get<identityservicev1_ListOrgUnitResponse>('org-units', rbacRawParams(query)),
    ...options,
  });
}

export async function fetchListOrgUnits(params: PaginationQuery) {
  return queryClient.fetchQuery({
    queryKey: ['listOrgUnits', params],
    queryFn: () =>
      adminHttp.get<identityservicev1_ListOrgUnitResponse>('org-units', rbacRawParams(params)),
    retry: 0,
  });
}

export function useGetOrgUnit(
  req: identityservicev1_GetOrgUnitRequest,
  options?: UseQueryOptions<identityservicev1_OrgUnit, Error>,
) {
  return useQuery({
    queryKey: ['getOrgUnit', req],
    queryFn: () => adminHttp.get<identityservicev1_OrgUnit>(`org-units/${req.id ?? ''}`),
    ...options,
  });
}

export function useCreateOrgUnit(
  options?: UseMutationOptions<unknown, Error, identityservicev1_CreateOrgUnitRequest>,
) {
  return useMutation({
    mutationFn: (data) => adminHttp.post<unknown>('org-units', data),
    ...options,
  });
}

export function useUpdateOrgUnit(
  options?: UseMutationOptions<unknown, Error, { id: number; values: Record<string, unknown> }>,
) {
  return useMutation({
    mutationFn: ({ id, values }: { id: number; values: Record<string, unknown> }) =>
      adminHttp.put<unknown>(`org-units/${id}`, {
        id,
        data: { ...values },
        updateMask: makeUpdateMask(Object.keys(values ?? {})),
      }),
    ...options,
  });
}

export function useDeleteOrgUnit(
  options?: UseMutationOptions<unknown, Error, identityservicev1_DeleteOrgUnitRequest>,
) {
  return useMutation({
    mutationFn: (req) => adminHttp.delete<unknown>(`org-units/${req.id}`),
    ...options,
  });
}
