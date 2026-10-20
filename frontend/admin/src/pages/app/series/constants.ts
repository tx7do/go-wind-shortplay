import { VIDEO_STATUS } from '@/api/types';

/** 剧内选集状态映射（剧集本体无状态机，可见性跟随视频，复用视频状态展示） */
export interface EpisodeStatusConfig {
  color: string;
  labelKey: string;
}

export function getEpisodeStatusConfig(status: unknown): EpisodeStatusConfig {
  switch (status) {
    case VIDEO_STATUS.PUBLISHED:
      return { color: 'success', labelKey: 'episodeStatusPublished' };
    case VIDEO_STATUS.REVIEWING:
      return { color: 'processing', labelKey: 'episodeStatusReviewing' };
    case VIDEO_STATUS.REJECTED:
      return { color: 'error', labelKey: 'episodeStatusRejected' };
    case VIDEO_STATUS.OFFLINE:
      return { color: 'warning', labelKey: 'episodeStatusOffline' };
    default:
      return { color: 'default', labelKey: 'episodeStatusDraft' };
  }
}

/** int64（protojson 字符串）→ number */
export function toNum(v: number | string | undefined): number {
  return Number(v ?? 0);
}

/** 秒 → mm:ss / h:mm:ss */
export function formatDuration(seconds?: number): string {
  if (!seconds || seconds <= 0) return '-';
  const h = Math.floor(seconds / 3600);
  const m = Math.floor((seconds % 3600) / 60);
  const s = seconds % 60;
  if (h > 0) {
    return `${h}:${String(m).padStart(2, '0')}:${String(s).padStart(2, '0')}`;
  }
  return `${m}:${String(s).padStart(2, '0')}`;
}
