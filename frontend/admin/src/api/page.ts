/**
 * 分页响应的兜底归一化：后端字段缺省时保证 items/total 可用。
 */
import type { PageResult } from '../types';

export function normalizePage<T>(data?: PageResult<T> | null): PageResult<T> {
  return {
    items: Array.isArray(data?.items) ? data.items : [],
    total: data?.total ?? 0,
  };
}
