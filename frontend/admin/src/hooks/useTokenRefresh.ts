/**
 * 会话保活（GoWind shortplay 裁剪版）
 *
 * 后端无管理端 refresh 端点，也不存在 SSE：这里仅保留一个轻量定时器，
 * 在本地记录的 access token 过期后执行 forceLogout，让界面回到登录页。
 */
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
      // 已过期：本地清理（首个 API 请求也会被 401 拦截器兜底）
      useAuthStore.getState().forceLogout();
      return;
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
