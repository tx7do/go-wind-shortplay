/**
 * 媒体地址解析
 *
 * 后端返回的 videoUrl 是对象存储的对象键（如 `sp/xxx.mp4`，见 core
 * video_service「DB video_url 存对象键，前端按 MEDIA_BASE 拼播放地址」约定），
 * 需要拼接媒体基地址（`<host>/<桶>`）才能播放；完整 http(s) 地址原样返回。
 * 与 Flutter App 的 MediaUrl.resolve（frontend/app MediaUrl）同一契约。
 */

/** 缺省媒体基地址（本地 MinIO 统一媒体桶，与后端 OSS_DOWNLOAD_HOST / OSS_BUCKET 缺省对齐） */
const DEFAULT_MEDIA_BASE = 'http://127.0.0.1:9000/shortplay';

/**
 * 解析媒体对象键为可访问 URL
 * @param keyOrUrl - 对象键（`sp/xxx.mp4`）或完整地址
 */
export function resolveMediaUrl(keyOrUrl?: string | null): string {
  const value = keyOrUrl ?? '';
  if (!value) return '';
  if (/^https?:\/\//i.test(value)) return value;

  const base = (import.meta.env.VITE_MEDIA_BASE_URL || DEFAULT_MEDIA_BASE).replace(/\/+$/, '');
  return `${base}/${value.replace(/^\/+/, '')}`;
}
