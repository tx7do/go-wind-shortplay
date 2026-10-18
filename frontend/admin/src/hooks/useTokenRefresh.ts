/**
 * 会话保活（定时续期 access token）+ SSE 连接管理
 * 结构对齐 go-wind-cms useTokenRefresh（基座机制，2026-10-18 接通管理端
 * refresh 端点 POST /admin/v1/refresh-token）：
 *
 * - 主动定时续期：在 access token 到期前（剩余时间的 80%，减安全垫）静默
 *   调 refresh 端点换新（凭证为 HttpOnly refresh cookie，浏览器自动携带），
 *   避免请求时才被动刷新导致延迟；
 * - refresh_exp cookie（非 HttpOnly，仅含过期时间戳，登录/刷新时由后端种下）
 *   缺失或临期 → forceLogout，让界面回到登录页；
 * - 刷新成功后用新 token 重连 SSE（internal-message 域实时通知，
 *   server.sse → :7601 /events）；登出 / token 失效时断开。
 */
import { globalSSEClient } from '@/core/transport/sse';
import { useAuthStore } from '@/stores/auth';

// ==============================
// 常量（对齐基座）
// ==============================

/** Access Token 刷新间隔上限（1.5 小时） */
const ACCESS_TOKEN_REFRESH_INTERVAL = 90 * 60 * 1000;

/** 在 access token / refresh cookie 到期前多久开始刷新 */
const SAFETY_BUFFER_MS = 5 * 60 * 1000;
/** 最小刷新间隔（避免立即重试风暴） */
const MIN_INTERVAL_MS = 3 * 1000;

// ==============================
// 模块级状态（单例）
// ==============================

let refreshTimer: ReturnType<typeof setTimeout> | null = null;

// ==============================
// Cookie 读取辅助
// ==============================

/**
 * 从 refresh_exp cookie 读取 refresh token 的过期时间戳（Unix 秒）。
 * refresh_exp 为非 HttpOnly cookie，仅含过期时间戳，无敏感信息；
 * 由后端在登录/刷新时 Set-Cookie 写入，登出时清除。
 * 返回毫秒级时间戳或 null（cookie 不存在/不可解析）。
 */
function getRefreshExpireAt(): number | null {
  const match = document.cookie
    .split('; ')
    .find((row) => row.startsWith('refresh_exp='));
  if (!match) return null;
  const parts = match.split('=');
  if (parts.length < 2) return null;
  const val = parseInt(parts[1], 10);
  if (!Number.isFinite(val) || val <= 0) return null;
  return val * 1000;
}

// ==============================
// 核心：计算下次刷新间隔
// ==============================

function computeNextInterval(): number {
  const { accessTokenExpireAt } = useAuthStore.getState();
  const now = Date.now();

  // refresh cookie 临期 → 快速重试（使其在过期前尽快刷新/登出）
  const refreshExpireAt = getRefreshExpireAt();
  const refreshRemaining = (refreshExpireAt ?? 0) - now;
  if (refreshExpireAt && refreshRemaining <= SAFETY_BUFFER_MS) {
    return MIN_INTERVAL_MS;
  }

  // access token 已过期或没有 → 快速重试
  const accessRemaining = (accessTokenExpireAt ?? 0) - now;
  if (!accessTokenExpireAt || accessRemaining <= 0) {
    return MIN_INTERVAL_MS;
  }

  // access token 快过期 → 快速重试
  if (accessRemaining <= SAFETY_BUFFER_MS) {
    return MIN_INTERVAL_MS;
  }

  // 正常情况：在过期前提前刷新（80% 剩余时间，不超过默认间隔）
  return Math.floor(
    Math.max(
      MIN_INTERVAL_MS,
      Math.min(ACCESS_TOKEN_REFRESH_INTERVAL, (accessRemaining - SAFETY_BUFFER_MS) * 0.8),
    ),
  );
}

// ==============================
// 核心：定时刷新调度
// ==============================

function scheduleRefresh(): void {
  stopRefreshTimer();

  const tick = async () => {
    try {
      const now = Date.now();

      // refresh cookie 缺失（登出被清/从未种下）→ 强制登出
      const refreshExpireAt = getRefreshExpireAt();
      if (!refreshExpireAt) {
        useAuthStore.getState().forceLogout();
        return;
      }

      // refresh cookie 临期（续期链路已无法维持会话）→ 强制登出
      if (refreshExpireAt - now <= SAFETY_BUFFER_MS) {
        useAuthStore.getState().forceLogout();
        return;
      }

      // 执行续期（store.refreshToken 内部失败会 forceLogout）
      const newToken = await useAuthStore.getState().refreshToken();

      // 续期成功后，SSE 若在连着则用新 token 重连（旧凭证已轮换）
      if (newToken) {
        reconnectSSEServer();
      }
    } catch (error) {
      console.error('[TokenRefresh] scheduled refresh failed:', error);
    } finally {
      // 无论成功失败，只要定时器还在（未被 forceLogout 停掉），就安排下一次
      if (refreshTimer !== null) {
        refreshTimer = globalThis.setTimeout(tick, computeNextInterval());
      }
    }
  };

  refreshTimer = globalThis.setTimeout(tick, computeNextInterval());
}

// ==============================
// 公开 API
// ==============================

/**
 * 启动定时续期（登录成功 / 会话恢复后调用）
 */
export function startRefreshTimer(): void {
  scheduleRefresh();
}

/**
 * 停止定时续期（登出、token 失效时调用）
 */
export function stopRefreshTimer(): void {
  if (refreshTimer !== null) {
    globalThis.clearTimeout(refreshTimer);
    refreshTimer = null;
  }
}

/**
 * 用最新 token 重连 SSE 服务器（token 续期成功后调用）
 *
 * 后端约定：`?stream=` 必须与令牌一致（HandleAuthorize 校验
 * streamID != token 即 403），鉴权另走 Authorization 头。缺一不可。
 * 仅在当前已有连接时重连，避免无连接时意外建连。
 */
export function reconnectSSEServer(): void {
  const { accessToken } = useAuthStore.getState();
  if (!accessToken) {
    console.warn('[TokenRefresh] No access token, skip SSE reconnect');
    return;
  }
  if (globalSSEClient.getStatus() === 'disconnected') {
    return;
  }
  const sseUrl = `${import.meta.env.VITE_SSE_URL || '/events'}?stream=${encodeURIComponent(accessToken)}`;
  globalSSEClient.setHeaders({ Authorization: `Bearer ${accessToken}` });
  globalSSEClient.reconnect(sseUrl);
}

/**
 * 连接 SSE 服务器（基座契约）
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
