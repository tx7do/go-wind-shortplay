/**
 * 视频状态常量与展示映射
 *
 * protojson 铁律：后端枚举字段是字符串全名（"VIDEO_STATUS_PUBLISHED"）；
 * 列表接口的 filter 参数用数字字符串（"1"~"5"）。
 */
import type { VideoStatus } from '@/api/types';
import { VIDEO_STATUS } from '@/api/types';

export interface VideoStatusConfig {
  /** 状态 Tab / filter 参数（数字字符串） */
  filter: string;
  /** 枚举全名 */
  value: VideoStatus;
  /** 展示文案 i18n key（video ns） */
  labelKey: string;
  /** Tag 颜色 */
  color: string;
}

/** 状态顺序与 Tab 顺序一致：全部/草稿/审核中/已发布/驳回/下架 */
export const VIDEO_STATUS_LIST: VideoStatusConfig[] = [
  { filter: '1', value: VIDEO_STATUS.DRAFT, labelKey: 'statusDraft', color: 'default' },
  { filter: '2', value: VIDEO_STATUS.REVIEWING, labelKey: 'statusReviewing', color: 'processing' },
  { filter: '3', value: VIDEO_STATUS.PUBLISHED, labelKey: 'statusPublished', color: 'success' },
  { filter: '4', value: VIDEO_STATUS.REJECTED, labelKey: 'statusRejected', color: 'error' },
  { filter: '5', value: VIDEO_STATUS.OFFLINE, labelKey: 'statusOffline', color: 'warning' },
];

export function getVideoStatusConfig(status: unknown): VideoStatusConfig {
  return (
    VIDEO_STATUS_LIST.find((item) => item.value === status) ?? {
      filter: '',
      value: String(status) as VideoStatus,
      labelKey: 'statusDraft',
      color: 'default',
    }
  );
}

/** 时长（秒）→ mm:ss */
export function formatDuration(seconds: number | undefined): string {
  if (!seconds || seconds <= 0) return '-';
  const m = Math.floor(seconds / 60);
  const s = Math.floor(seconds % 60);
  return `${String(m).padStart(2, '0')}:${String(s).padStart(2, '0')}`;
}

/** protojson int64/uint64 → number（统计列展示用） */
export function toNum(v: number | string | undefined): number {
  return Number(v ?? 0);
}
