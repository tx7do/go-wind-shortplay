/**
 * 展示辅助：枚举映射（标签文案 / 颜色）、数字与时间格式化。
 */
import dayjs from 'dayjs';
import type { TopMetric } from '../types';

/** 视频状态映射：1 草稿 / 2 审核中 / 3 已发布 / 4 驳回 / 5 下架 */
export const VIDEO_STATUS_MAP: Record<number, { label: string; color: string }> = {
  1: { label: '草稿', color: 'default' },
  2: { label: '审核中', color: 'processing' },
  3: { label: '已发布', color: 'success' },
  4: { label: '驳回', color: 'error' },
  5: { label: '下架', color: 'warning' },
};

/** 用户状态映射：1 禁用 / 2 正常 */
export const USER_STATUS_MAP: Record<number, { label: string; color: string }> = {
  1: { label: '禁用', color: 'error' },
  2: { label: '正常', color: 'success' },
};

/** 举报工单状态映射：1 待处理 / 2 已通过 / 3 已驳回 */
export const REPORT_STATUS_MAP: Record<number, { label: string; color: string }> = {
  1: { label: '待处理', color: 'warning' },
  2: { label: '已通过', color: 'success' },
  3: { label: '已驳回', color: 'default' },
};

/** 举报目标类型映射：1 视频 / 2 评论 / 3 用户 */
export const TARGET_TYPE_MAP: Record<number, string> = {
  1: '视频',
  2: '评论',
  3: '用户',
};

/** 看板排行指标选项 */
export const METRIC_OPTIONS: { label: string; value: TopMetric }[] = [
  { label: '按播放', value: 'VIEW' },
  { label: '按点赞', value: 'LIKE' },
  { label: '按收藏', value: 'COLLECT' },
  { label: '按评论', value: 'COMMENT' },
];

/** 数字格式化（千分位；空值显示 0） */
export function formatNumber(value?: number | null): string {
  if (value === undefined || value === null) return '0';
  return Number(value).toLocaleString('zh-CN');
}

/** 时间格式化（RFC3339 → YYYY-MM-DD HH:mm:ss；空值显示 —） */
export function formatDateTime(value?: string | null): string {
  if (!value) return '—';
  const d = dayjs(value);
  return d.isValid() ? d.format('YYYY-MM-DD HH:mm:ss') : value;
}

/** 时长格式化（秒 → mm:ss 或 hh:mm:ss） */
export function formatDuration(seconds?: number | null): string {
  if (!seconds || seconds <= 0) return '—';
  const h = Math.floor(seconds / 3600);
  const m = Math.floor((seconds % 3600) / 60);
  const s = Math.floor(seconds % 60);
  const mm = String(m).padStart(2, '0');
  const ss = String(s).padStart(2, '0');
  return h > 0 ? `${h}:${mm}:${ss}` : `${mm}:${ss}`;
}
