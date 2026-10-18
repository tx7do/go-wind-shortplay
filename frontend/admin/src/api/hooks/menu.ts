/**
 * 菜单管理 hooks —— 从 go-wind-cms api/hooks/menu.ts 拷贝适配：
 * cms 的 apiClient.menuService.* 改为本仓 adminHttp（REST 路径 /admin/v1/menus）。
 */
import {
  useMutation,
  useQuery,
  type UseMutationOptions,
  type UseQueryOptions,
} from '@tanstack/react-query';
import {
  type permissionservicev1_CreateMenuRequest,
  type permissionservicev1_DeleteMenuRequest,
  type permissionservicev1_GetMenuRequest,
  type permissionservicev1_ListMenuResponse,
  type permissionservicev1_Menu,
} from '@/api/generated/admin/service/v1';
import { makeUpdateMask, type PaginationQuery } from '@/core';
import { adminHttp } from '@/api/client';
import { queryClient, rbacRawParams } from './rbac';

// ==============================
// 菜单管理
// ==============================

export function useListMenus(
  query: PaginationQuery,
  options?: UseQueryOptions<permissionservicev1_ListMenuResponse, Error>,
) {
  return useQuery({
    queryKey: ['listMenus', query],
    queryFn: () => adminHttp.get<permissionservicev1_ListMenuResponse>('menus', rbacRawParams(query)),
    ...options,
  });
}

export async function fetchListMenus(params: PaginationQuery) {
  return queryClient.fetchQuery({
    queryKey: ['listMenus', params],
    queryFn: () =>
      adminHttp.get<permissionservicev1_ListMenuResponse>('menus', rbacRawParams(params)),
    retry: 0,
  });
}

export function useGetMenu(
  req: permissionservicev1_GetMenuRequest,
  options?: UseQueryOptions<permissionservicev1_Menu, Error>,
) {
  return useQuery({
    queryKey: ['getMenu', req],
    queryFn: () => adminHttp.get<permissionservicev1_Menu>(`menus/${req.id ?? ''}`),
    ...options,
  });
}

export function useCreateMenu(
  options?: UseMutationOptions<unknown, Error, permissionservicev1_CreateMenuRequest>,
) {
  return useMutation({
    mutationFn: (data) => adminHttp.post<unknown>('menus', data),
    ...options,
  });
}

export function useUpdateMenu(
  options?: UseMutationOptions<unknown, Error, { id: number; values: Record<string, unknown> }>,
) {
  return useMutation({
    mutationFn: ({ id, values }: { id: number; values: Record<string, unknown> }) =>
      adminHttp.put<unknown>(`menus/${id}`, {
        id,
        data: { ...values },
        // children 是树的只读虚拟边：表里没有该列，进 updateMask 会让后端生成非法 SQL
        updateMask: makeUpdateMask(Object.keys(values ?? {}).filter((k) => k !== 'children')),
      }),
    ...options,
  });
}

export function useDeleteMenu(
  options?: UseMutationOptions<unknown, Error, permissionservicev1_DeleteMenuRequest>,
) {
  return useMutation({
    mutationFn: (req) => adminHttp.delete<unknown>(`menus/${req.id}`),
    ...options,
  });
}
