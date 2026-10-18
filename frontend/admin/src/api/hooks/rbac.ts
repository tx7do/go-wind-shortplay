/**
 * RBAC 公共与用户角色分配 hooks（react-query）
 *
 * 角色 / 菜单 / API / 部门（org-units）/ 权限点 / 权限组的 CRUD hooks 在
 * 各自文件（role.ts / menu.ts / api.ts / org-unit.ts / permission.ts /
 * permission-group.ts，从 go-wind-cms 同名文件拷贝适配），本文件保留：
 * - RBAC 列表请求参数助手（PaginationQuery → REST query，含 orderBy 归一）；
 * - 用户角色分配（/users/{id}/role-ids、/users/{id}/roles，短剧 BFF 契约）；
 * - 动态菜单 navigation（router 后端模式数据源）。
 */
import {
  useMutation,
  type UseMutationOptions,
} from '@tanstack/react-query';

import { adminHttp } from '@/api/client';
import type { ListResponse, NavigationNode } from '@/api/types';
import { type PaginationQuery, queryClient } from '@/core';

/**
 * PaginationQuery → adminHttp 查询参数。
 *
 * 与 cms 的 apiClient 一致直接透传 toRawParams()；唯一归一化：orderBy 里的
 * `created_at`（snake）改写为 `createdAt`（camel）——实测基座各 RBAC 列表
 * 接口 camel 均可用，而 /roles 对 snake 的 `created_at` 返回 500
 * （"invalid character 'c' in numeric literal"，roles 服务自定义解析所致）。
 */
export function rbacRawParams(query: PaginationQuery): Record<string, unknown> {
  const raw = query.toRawParams() as Record<string, unknown>;
  if (typeof raw.orderBy === 'string' && raw.orderBy.includes('created_at')) {
    raw.orderBy = raw.orderBy.replaceAll('created_at', 'createdAt');
  }
  return raw;
}

// ==============================
// 用户角色分配（/admin/v1/users/{id}/role-ids | roles）
// ==============================

/** 用户已分配角色 ID 列表（响应形态宽容解析：roleIds / ids / items） */
export async function fetchGetUserRoleIds(id: number): Promise<number[]> {
  const res = await adminHttp.get<Record<string, unknown>>(`users/${id}/role-ids`);
  return extractIdArray(res);
}

/** 分配角色（全量覆盖） */
export function useAssignUserRoles(
  options?: UseMutationOptions<void, Error, { id: number; roleIds: number[] }>,
) {
  return useMutation<void, Error, { id: number; roleIds: number[] }>({
    mutationFn: ({ id, roleIds }) => adminHttp.put<void>(`users/${id}/roles`, { roleIds }),
    ...options,
  });
}

/** 提取 {roleIds:[]}/{ids:[]}/{items:[]} 形态响应中的数字 ID 数组 */
function extractIdArray(res: Record<string, unknown> | undefined): number[] {
  const raw =
    (res?.roleIds as unknown[]) ??
    (res?.menuIds as unknown[]) ??
    (res?.apiIds as unknown[]) ??
    (res?.ids as unknown[]) ??
    (res?.items as unknown[]) ??
    (Array.isArray(res) ? (res as unknown[]) : []);
  return (raw ?? [])
    .map((v) => (typeof v === 'string' ? Number(v) : (v as number)))
    .filter((v) => typeof v === 'number' && !Number.isNaN(v));
}

// ==============================
// 动态菜单（navigation）
// ==============================

/**
 * 拉取当前用户菜单树（按角色过滤；super_admin 全量；BUTTON 类型不下发）。
 * 仅供 router 后端模式使用：失败/为空时由调用方回退静态路由。
 * 响应形态宽容：{items:[...]} 或裸数组均可。
 */
export async function fetchNavigation(): Promise<NavigationNode[]> {
  const res = await adminHttp.get<ListResponse<NavigationNode> | NavigationNode[]>('navigation');
  if (Array.isArray(res)) return res;
  return res.items ?? [];
}

/** RBAC 列表全量拉取兜底 pageSize（树形接口一次取全） */
export const RBAC_PAGE_SIZE_MAX = 1000;

// queryClient 保留导出：各域 hook 文件统一从这里取，避免散装 import 路径漂移。
export { queryClient };
