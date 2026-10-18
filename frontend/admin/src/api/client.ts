/**
 * Admin BFF REST 客户端
 *
 * GoWind shortplay 管理端为纯 REST 契约（docs/API.md「Admin 端」一节）：
 * 统一前缀 /admin/v1，JSON 请求体，Bearer 鉴权。这里复用底座 RequestClient
 * 单例（token 注入 / 401 处理 / 错误消息本地化全部沿用），仅做一层薄封装。
 *
 * protojson 序列化约定（铁律）：
 * - 枚举字段是字符串全名（如 "VIDEO_STATUS_PUBLISHED"、"USER_STATUS_DISABLED"）；
 * - int64/uint64 字段是 JSON 字符串（"likeCount":"1"、"total":"2"）；
 * - uint32/int32 是数字（id、authorId 等）。请求方向同理：提交枚举必须传全名。
 */
import { RequestClient } from '@/core/transport/rest';
import { useAuthStore } from '@/stores';

/** Admin BFF 统一前缀（与 .env 的 VITE_PROXY 转发规则对齐：/admin → 127.0.0.1:7600，无 rewrite） */
export const ADMIN_API_PREFIX = 'admin/v1';

/** 组合完整请求路径：`videos` → `admin/v1/videos` */
export const adminPath = (p: string) => `${ADMIN_API_PREFIX}/${p.replace(/^\//, '')}`;

/**
 * 通用图片上传（docs/API.md「Admin 端增补」：POST /uploads/image）。
 *
 * 契约要点：body = 图片原始字节（非 multipart），Content-Type = 图片 MIME，
 * ≤2MB，成功返回 {url}。因需要上传进度回调，这里用 XHR 实现（fetch 无法观测
 * 上传字节）；鉴权与 RequestClient 的 token 拦截器同源（auth store）。
 *
 * 错误形态与全仓一致：HTTP 状态码 + {code,reason,message}，reason 供上层做 i18n。
 */
export function adminUploadImage(
  file: File,
  onProgress?: (percent: number) => void,
): Promise<{ url: string }> {
  return new Promise((resolve, reject) => {
    const xhr = new XMLHttpRequest();
    // baseURL 在 dev 为 "/"：补前导斜杠拼出绝对路径，避免在 /auth/login 等
    // 子路径页面被相对解析成 /auth/admin/v1/...（与 RequestClient 行为对齐）
    xhr.open('POST', `/${adminPath('uploads/image')}`);
    xhr.responseType = 'json';
    xhr.setRequestHeader('Authorization', `Bearer ${useAuthStore.getState().accessToken ?? ''}`);
    xhr.setRequestHeader('X-Requested-With', 'XMLHttpRequest');
    // 契约：Content-Type 即图片 MIME（后端按它校验类型）；缺省兜底 octet-stream
    xhr.setRequestHeader('Content-Type', file.type || 'application/octet-stream');

    xhr.upload.onprogress = (event) => {
      if (event.lengthComputable && onProgress) {
        onProgress(Math.round((event.loaded / event.total) * 100));
      }
    };

    xhr.onload = () => {
      const body = (xhr.response ?? null) as { url?: string; reason?: string; message?: string } | null;
      if (xhr.status >= 200 && xhr.status < 300 && body?.url) {
        resolve({ url: body.url });
        return;
      }
      const error = new Error(body?.message || `HTTP ${xhr.status}`) as Error & {
        reason?: string;
      };
      error.reason = body?.reason;
      reject(error);
    };
    xhr.onerror = () => reject(new Error('Network Error'));
    xhr.onabort = () => reject(new Error('Upload aborted'));

    // 原始字节直传（关键：不是 FormData）
    xhr.send(file);
  });
}

/**
 * REST 请求封装：所有方法经 RequestClient 单例发出（bootstrap 时已 init）。
 * GET 用 params 传查询串，其余用 JSON body。
 */
export const adminHttp = {
  get<T>(path: string, params?: Record<string, unknown>): Promise<T> {
    return RequestClient.getInstance().get<T>(adminPath(path), { params } as never);
  },
  post<T>(path: string, data?: unknown): Promise<T> {
    return RequestClient.getInstance().post<T>(adminPath(path), data as never);
  },
  put<T>(path: string, data?: unknown): Promise<T> {
    return RequestClient.getInstance().put<T>(adminPath(path), data as never);
  },
  delete<T>(path: string): Promise<T> {
    return RequestClient.getInstance().delete<T>(adminPath(path));
  },
};
