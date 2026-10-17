/**
 * 数据看板接口（Admin 端 /admin/v1/dashboard）
 */
import { get } from './request';
import type { Overview, PageResult, TopMetric, Video } from '../types';
import { normalizePage } from './page';

/** 运营总览统计 */
export function getOverview(): Promise<Overview> {
  return get<Overview>('/dashboard/overview');
}

/** 视频 TOP 排行（metric：VIEW/LIKE/COLLECT/COMMENT，limit 缺省 10） */
export async function listTopVideos(metric: TopMetric, limit = 10): Promise<PageResult<Video>> {
  const data = await get<PageResult<Video>>('/dashboard/top-videos', {
    params: { metric, limit },
  });
  return normalizePage(data);
}
