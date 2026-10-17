/**
 * 举报工单接口（Admin 端 /admin/v1/reports）
 */
import { get, put } from './request';
import type { PageParams, PageResult, Report } from '../types';
import { normalizePage } from './page';

export interface ListReportsParams extends PageParams {
  /** 状态筛选：1 待处理 / 2 已通过 / 3 已驳回 */
  filter?: 1 | 2 | 3;
}

/** 举报工单列表（分页 + 状态筛选） */
export async function listReports(params: ListReportsParams): Promise<PageResult<Report>> {
  const data = await get<PageResult<Report>>('/reports', {
    params: {
      page: params.page,
      pageSize: params.pageSize,
      filter: params.filter,
    },
  });
  return normalizePage(data);
}

/** 举报工单详情 */
export function getReport(id: number): Promise<Report> {
  return get<Report>(`/reports/${id}`);
}

/** 处理工单：action 1 通过并处置目标 / 2 驳回；note 处理备注（可选） */
export function handleReport(id: number, action: 1 | 2, note?: string): Promise<Report> {
  return put<Report>(`/reports/${id}/handle`, { action, note: note ? note.trim() : undefined });
}
