/**
 * API 资源管理 hooks —— 从 go-wind-cms api/hooks/api.ts 拷贝适配：
 * cms 的 apiClient.apiService.* 改为本仓 adminHttp（REST 路径 /admin/v1/apis，
 * 同步锚点 POST /admin/v1/apis/sync，与 i_api.proto 的 HTTP binding 一致）。
 */
import {
  useMutation,
  useQuery,
  type UseMutationOptions,
  type UseQueryOptions,
} from '@tanstack/react-query';
import {
  type permissionservicev1_Api,
  type permissionservicev1_CreateApiRequest,
  type permissionservicev1_DeleteApiRequest,
  type permissionservicev1_GetApiRequest,
  type permissionservicev1_ListApiResponse,
} from '@/api/generated/admin/service/v1';
import { makeUpdateMask, type PaginationQuery } from '@/core';
import { adminHttp } from '@/api/client';
import { queryClient, rbacRawParams } from './rbac';

// ==============================
// API 管理
// ==============================

export function useListApis(
  query: PaginationQuery,
  options?: UseQueryOptions<permissionservicev1_ListApiResponse, Error>,
) {
  return useQuery({
    queryKey: ['listApis', query],
    queryFn: () => adminHttp.get<permissionservicev1_ListApiResponse>('apis', rbacRawParams(query)),
    ...options,
  });
}

export async function fetchListApis(params: PaginationQuery) {
  return queryClient.fetchQuery({
    queryKey: ['listApis', params],
    queryFn: () =>
      adminHttp.get<permissionservicev1_ListApiResponse>('apis', rbacRawParams(params)),
    retry: 0,
  });
}

export function useGetApi(
  req: permissionservicev1_GetApiRequest,
  options?: UseQueryOptions<permissionservicev1_Api, Error>,
) {
  return useQuery({
    queryKey: ['getApi', req],
    queryFn: () => adminHttp.get<permissionservicev1_Api>(`apis/${req.id ?? ''}`),
    ...options,
  });
}

export function useCreateApi(
  options?: UseMutationOptions<unknown, Error, permissionservicev1_CreateApiRequest>,
) {
  return useMutation({
    mutationFn: (data) => adminHttp.post<unknown>('apis', data),
    ...options,
  });
}

export function useUpdateApi(
  options?: UseMutationOptions<unknown, Error, { id: number; values: Record<string, unknown> }>,
) {
  return useMutation({
    mutationFn: ({ id, values }: { id: number; values: Record<string, unknown> }) =>
      adminHttp.put<unknown>(`apis/${id}`, {
        id,
        data: {
          ...values,
        },
        updateMask: makeUpdateMask(Object.keys(values ?? {})),
      }),
    ...options,
  });
}

export function useDeleteApi(
  options?: UseMutationOptions<unknown, Error, permissionservicev1_DeleteApiRequest>,
) {
  return useMutation({
    mutationFn: (req) => adminHttp.delete<unknown>(`apis/${req.id}`),
    ...options,
  });
}

export function useSyncApisApi(options?: UseMutationOptions<unknown, Error>) {
  return useMutation({
    mutationFn: () => adminHttp.post<unknown>('apis/sync', {}),
    ...options,
  });
}
