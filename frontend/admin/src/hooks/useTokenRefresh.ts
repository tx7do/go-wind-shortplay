/**
 * 会话保活 + SSE 连接管理（GoWind shortplay 裁剪版，结构对齐 go-wind-cms useTokenRefresh）
 *
 * - 后端无管理端 refresh 端点：保留轻量定时器，在本地记录的 access token
 *   过期后执行 forceLogout，让界面回到登录页；
 * - 后端有管理端 SSE（server.sse → :7601 /events，internal-message 域实时通知）：
 *   登录成功 / 页面恢复后 connectSSEServer() 建连，登出 / token 失效时断开。
 */
import { globalSSEClient } from '@/core/transport/sse';
import { useAuthStore } from '@/stores/auth';

/** 检查间隔（1 分钟） */
const CHECK_INTERVAL_MS = 60 * 1000;

let sessionTimer: ReturnType<typeof setTimeout> | null = null;

function scheduleNext(): void {
  stopRefreshTimer();
  sessionTimer = globalThis.setTimeout(tick, CHECK_INTERVAL_MS);
}

async function tick(): Promise<void> {
  try {
    const { accessTokenExpireAt, accessToken } = useAuthStore.getState();
    if (accessToken && accessTokenExpireAt && Date.now() > accessTokenExpireAt) {
      // 已过期：本地清理（首个 API 请求也会被 401 拦截器兜底）；
      // 同步断开 SSE——过期令牌的重连必 401，避免重连风暴
      disconnectSSEServer();
      useAuthStore.getState().forceLogout();
    }
  } finally {
    if (sessionTimer !== null) {
      scheduleNext();
    }
  }
}

/**
 * 启动会话检查（登录成功 / 页面恢复后调用）
 */
export function startRefreshTimer(): void {
  scheduleNext();
}

/**
 * 停止会话检查（登出、token 失效时调用）
 */
export function stopRefreshTimer(): void {
  if (sessionTimer !== null) {
    globalThis.clearTimeout(sessionTimer);
    sessionTimer = null;
  }
}

/**
 * 连接 SSE 服务器（基座契约）
 *
 * 后端约定：`?stream=` 必须与令牌一致（HandleAuthorize 校验
 * streamID != token 即 403），鉴权另走 Authorization 头。缺一不可。
 */
export function connectSSEServer(): void {
  const { accessToken } = useAuthStore.getState();
  if (!accessToken) {
    console.warn('[TokenRefresh] No access token, skip SSE connection');
    return;
  }

  const sseUrl = `${import.meta.env.VITE_SSE_URL || '/events'}?stream=${encodeURIComponent(accessToken)}`;
  globalSSEClient.setHeaders({ Authorization: `Bearer ${accessToken}` });
  globalSSEClient.connect(sseUrl);
}

/**
 * 关闭 SSE 连接（登出 / token 失效时调用）
 */
export function disconnectSSEServer(): void {
  globalSSEClient.close();
}
