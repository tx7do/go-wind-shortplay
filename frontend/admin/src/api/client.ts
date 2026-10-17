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

/** Admin BFF 统一前缀（与 .env 的 VITE_PROXY 转发规则对齐：/admin → 127.0.0.1:6600，无 rewrite） */
export const ADMIN_API_PREFIX = 'admin/v1';

/** 组合完整请求路径：`videos` → `admin/v1/videos` */
export const adminPath = (p: string) => `${ADMIN_API_PREFIX}/${p.replace(/^\//, '')}`;

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
