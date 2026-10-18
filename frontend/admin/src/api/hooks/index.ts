/**
 * 短剧业务 API hooks（react-query）
 *
 * 与底座约定一致：列表用 fetchXxx（queryClient.fetchQuery，供 ProTable request
 * 与导出复用），变更用 useXxxMutation；queryKey 与后端资源一一对应。
 */
import {
  useMutation,
  useQuery,
  type UseMutationOptions,
  type UseQueryOptions,
} from '@tanstack/react-query';

import { adminHttp } from '@/api/client';
import type {
  AppUser,
  ChangeVideoStatusRequest,
  Comment,
  CreateUserRequest,
  DashboardOverview,
  DashboardTrendsResponse,
  HandleReportRequest,
  ListResponse,
  Report,
  SysConf,
  TopMetric,
  UpdateSysConfRequest,
  UpdateUserRequest,
  UpdateVideoRequest,
  Video,
} from '@/api/types';
import { queryClient, type PaginationQuery } from '@/core';

/** 列表查询参数（Admin BFF 统一 ?page=&pageSize=&query=&filter=） */
export interface ListParams {
  page?: number;
  pageSize?: number;
  /** 标题/昵称模糊搜索 */
  query?: string;
  /** 状态过滤（数字字符串，如 "1"~"5"） */
  filter?: string;
  /** 作者过滤（GET /videos?authorId=，用户管理「查看作品」用） */
  authorId?: number;
}

/** 剔除 undefined/null/空串，避免 axios 序列化出脏参数 */
export function cleanParams(params?: ListParams): Record<string, string | number> | undefined {
  if (!params) return undefined;
  const out: Record<string, string | number> = {};
  for (const [k, v] of Object.entries(params)) {
    if (v !== undefined && v !== null && v !== '') out[k] = v as string | number;
  }
  return out;
}

// ==============================
// 数据看板
// ==============================

export function useGetDashboardOverview(
  options?: UseQueryOptions<DashboardOverview, Error>,
) {
  return useQuery<DashboardOverview, Error>({
    queryKey: ['dashboardOverview'],
    queryFn: () => adminHttp.get<DashboardOverview>('dashboard/overview'),
    ...options,
  });
}

export function useListTopVideos(
  metric: TopMetric,
  limit = 10,
  options?: UseQueryOptions<ListResponse<Video>, Error>,
) {
  return useQuery<ListResponse<Video>, Error>({
    queryKey: ['topVideos', metric, limit],
    queryFn: () =>
      adminHttp.get<ListResponse<Video>>('dashboard/top-videos', { metric, limit }),
    ...options,
  });
}

/**
 * 近 N 日趋势（1-30，看板默认 7）。
 * 后端增量端点（契约 docs/API.md「Admin 端增补」）：失败/为空时由调用方渲染空态，
 * 不阻断看板其余区块。
 */
export function useGetDashboardTrends(
  days = 7,
  options?: UseQueryOptions<DashboardTrendsResponse, Error>,
) {
  return useQuery<DashboardTrendsResponse, Error>({
    queryKey: ['dashboardTrends', days],
    queryFn: () => adminHttp.get<DashboardTrendsResponse>('dashboard/trends', { days }),
    ...options,
  });
}

// ==============================
// 视频管理
// ==============================

export async function fetchListVideos(params: ListParams) {
  return queryClient.fetchQuery({
    queryKey: ['listVideos', params],
    queryFn: () => adminHttp.get<ListResponse<Video>>('videos', cleanParams(params)),
    retry: 0,
  });
}

export function useGetVideo(id: number | undefined, options?: UseQueryOptions<Video, Error>) {
  return useQuery<Video, Error>({
    queryKey: ['getVideo', id],
    queryFn: () => adminHttp.get<Video>(`videos/${id}`),
    enabled: id != null,
    ...options,
  });
}

export function useChangeVideoStatus(
  options?: UseMutationOptions<Video, Error, { id: number } & ChangeVideoStatusRequest>,
) {
  return useMutation<Video, Error, { id: number } & ChangeVideoStatusRequest>({
    mutationFn: ({ id, ...body }) =>
      adminHttp.put<Video>(`videos/${id}/status`, body),
    ...options,
  });
}

export function useUpdateVideo(
  options?: UseMutationOptions<Video, Error, { id: number } & UpdateVideoRequest>,
) {
  return useMutation<Video, Error, { id: number } & UpdateVideoRequest>({
    mutationFn: ({ id, ...body }) => adminHttp.put<Video>(`videos/${id}`, body),
    ...options,
  });
}

export function useDeleteVideo(
  options?: UseMutationOptions<void, Error, number>,
) {
  return useMutation<void, Error, number>({
    mutationFn: (id) => adminHttp.delete<void>(`videos/${id}`),
    ...options,
  });
}

// ==============================
// 评论管理
// ==============================

export async function fetchListComments(params: ListParams) {
  return queryClient.fetchQuery({
    queryKey: ['listComments', params],
    queryFn: () => adminHttp.get<ListResponse<Comment>>('comments', cleanParams(params)),
    retry: 0,
  });
}

export function useDeleteComment(options?: UseMutationOptions<void, Error, number>) {
  return useMutation<void, Error, number>({
    mutationFn: (id) => adminHttp.delete<void>(`comments/${id}`),
    ...options,
  });
}

// ==============================
// 举报管理
// ==============================

export async function fetchListReports(params: ListParams) {
  return queryClient.fetchQuery({
    queryKey: ['listReports', params],
    queryFn: () => adminHttp.get<ListResponse<Report>>('reports', cleanParams(params)),
    retry: 0,
  });
}

export function useGetReport(id: number | undefined, options?: UseQueryOptions<Report, Error>) {
  return useQuery<Report, Error>({
    queryKey: ['getReport', id],
    queryFn: () => adminHttp.get<Report>(`reports/${id}`),
    enabled: id != null,
    ...options,
  });
}

export function useHandleReport(
  options?: UseMutationOptions<Report, Error, { id: number } & HandleReportRequest>,
) {
  return useMutation<Report, Error, { id: number } & HandleReportRequest>({
    mutationFn: ({ id, ...body }) => adminHttp.put<Report>(`reports/${id}/handle`, body),
    ...options,
  });
}

// ==============================
// 用户管理（/admin/v1/users：短剧 App 用户域，proto 形状 AppUser）
// ==============================

/**
 * 用户列表 —— fetcher 契约与基座一致（PaginationQuery → ?page&pageSize&query）：
 * formValues 由 PaginationQuery 序列化为 go-crud JSON 过滤
 * （username/nickname 等字符串值自动转 __contains 模糊匹配）。
 */
export async function fetchListUsers(params: PaginationQuery) {
  return queryClient.fetchQuery({
    queryKey: ['listUsers', params],
    queryFn: () =>
      adminHttp.get<ListResponse<AppUser>>(
        'users',
        params.toRawParams() as Record<string, unknown>,
      ),
    retry: 0,
  });
}

export function useCreateUser(
  options?: UseMutationOptions<AppUser, Error, CreateUserRequest>,
) {
  return useMutation<AppUser, Error, CreateUserRequest>({
    mutationFn: (data) => adminHttp.post<AppUser>('users', data),
    ...options,
  });
}

export function useUpdateUser(
  options?: UseMutationOptions<AppUser, Error, { id: number } & UpdateUserRequest>,
) {
  return useMutation<AppUser, Error, { id: number } & UpdateUserRequest>({
    mutationFn: ({ id, ...body }) => adminHttp.put<AppUser>(`users/${id}`, body),
    ...options,
  });
}

export function useDeleteUser(options?: UseMutationOptions<void, Error, number>) {
  return useMutation<void, Error, number>({
    mutationFn: (id) => adminHttp.delete<void>(`users/${id}`),
    ...options,
  });
}

export function useUpdateUserStatus(
  options?: UseMutationOptions<AppUser, Error, { id: number; status: string }>,
) {
  return useMutation<AppUser, Error, { id: number; status: string }>({
    mutationFn: ({ id, status }) => adminHttp.put<AppUser>(`users/${id}/status`, { status }),
    ...options,
  });
}

// ==============================
// 系统配置
// ==============================

export function useGetSysConf(options?: UseQueryOptions<SysConf, Error>) {
  return useQuery<SysConf, Error>({
    queryKey: ['sysconf'],
    queryFn: () => adminHttp.get<SysConf>('sysconf'),
    ...options,
  });
}

export function useUpdateSysConf(
  options?: UseMutationOptions<SysConf, Error, UpdateSysConfRequest>,
) {
  return useMutation<SysConf, Error, UpdateSysConfRequest>({
    mutationFn: (data) => adminHttp.put<SysConf>('sysconf', data),
    ...options,
  });
}
