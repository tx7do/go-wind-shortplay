/**
 * SSE 传输通道（从 go-wind-cms 底座移植）
 *
 * 后端管理端 SSE：`server.sse`（configs/server.yaml）监听 :7601，
 * 路径 /events，事件源见 ./event。连接契约（HandleAuthorize）：
 * - `?stream=<accessToken>` 必须与令牌一致，否则 403；
 * - 鉴权走 Authorization: Bearer 头（框架亦接受 X-Token）。
 * 登录成功后 connectSSEServer()（hooks/useTokenRefresh）建立连接，
 * 业务组件经 globalSSEClient.on(SSE_EVENT.Notification, ...) 订阅实时推送。
 */
import { SSEClient } from './sse_client';

export * from './sse_client';
export * from './event';
export * from './types';

export const globalSSEClient = new SSEClient({
  url: import.meta.env.VITE_SSE_URL || '/events',
  withCredentials: false,
  reconnectDelay: 5000,
  autoParseJson: true,
});
