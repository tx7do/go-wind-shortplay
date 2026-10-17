/**
 * 评论管理接口（Admin 端 /admin/v1/comments）
 */
import { del, get } from './request';
import type { Comment, PageParams, PageResult } from '../types';
import { normalizePage } from './page';

/** 评论列表（分页） */
export async function listComments(params: PageParams): Promise<PageResult<Comment>> {
  const data = await get<PageResult<Comment>>('/comments', {
    params: { page: params.page, pageSize: params.pageSize },
  });
  return normalizePage(data);
}

/** 删除违规评论 */
export function deleteComment(id: number): Promise<void> {
  return del<void>(`/comments/${id}`);
}
