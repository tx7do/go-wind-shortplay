/**
 * 视频管理接口（Admin 端 /admin/v1/videos）
 */
import { del, get, put } from './request';
import type { PageResult, Video, VideoStatus } from '../types';
import { normalizePage } from './page';

export interface ListVideosParams {
  page?: number;
  pageSize?: number;
  /** 关键字（标题模糊搜索） */
  query?: string;
  /** 状态筛选：1 草稿 / 2 审核中 / 3 已发布 / 4 驳回 / 5 下架 */
  status?: VideoStatus;
}

/** 视频列表（分页 + query 关键字 + 状态筛选） */
export async function listVideos(params: ListVideosParams): Promise<PageResult<Video>> {
  const data = await get<PageResult<Video>>('/videos', {
    params: {
      page: params.page,
      pageSize: params.pageSize,
      query: params.query || undefined,
      filter: params.status ? String(params.status) : undefined,
    },
  });
  return normalizePage(data);
}

/** 视频详情 */
export function getVideo(id: number): Promise<Video> {
  return get<Video>(`/videos/${id}`);
}

/**
 * 变更视频状态：2 重审 / 3 审核通过 / 4 驳回 / 5 下架
 * （驳回、下架必填 reason）
 */
export function changeVideoStatus(id: number, status: number, reason?: string): Promise<Video> {
  return put<Video>(`/videos/${id}/status`, {
    status,
    reason: reason ? reason.trim() : undefined,
  });
}

/** 删除视频 */
export function deleteVideo(id: number): Promise<void> {
  return del<void>(`/videos/${id}`);
}
