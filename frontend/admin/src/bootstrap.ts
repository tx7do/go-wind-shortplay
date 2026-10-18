import { initI18n } from '@/core/i18n';
import { usePreferencesStore } from '@/core/preferences';
import { RequestClient } from '@/core/transport/rest';
import i18n from 'i18next';
import { adminPath } from '@/api/client';
import { useAuthStore, useUserStore } from '@/stores';
import { connectSSEServer, startRefreshTimer } from '@/hooks/useTokenRefresh';

/**
 * 应用启动初始化
 */
export async function bootstrap() {
  await _initI18n();

  // 全局错误观测：未处理的 promise 拒绝/运行时异常若无人接管会静默丢失，
  // 统一加 [GlobalError] 前缀落 console，保证浏览器端排查有迹可循。
  window.addEventListener('unhandledrejection', (event) => {
    console.error('[GlobalError] unhandled rejection:', event.reason);
  });
  window.addEventListener('error', (event) => {
    console.error('[GlobalError] uncaught error:', event.error ?? event.message);
  });

  console.log('✅ 应用启动初始化完成');
}

async function _initI18n() {
  // 从 preferences 获取初始语言
  const initialLocale = usePreferencesStore.getState().preferences.app.locale;

  // 初始化 i18n（传入初始语言）
  await initI18n(initialLocale);

  // 注入 RequestClient 回调（业务层 → 基础设施层）
  RequestClient.init(import.meta.env.VITE_API_URL, {
    getToken: () => useAuthStore.getState().accessToken,
    getLocale: () => i18n.language,
    // 401 时凭 HttpOnly refresh cookie 静默续期（基座机制）；续期失败
    // （cookie 失效）返回空串，由拦截器走 forceLogout。
    refreshToken: async () => useAuthStore.getState().refreshToken(),
    onReAuthenticate: async () => {
      useAuthStore.getState().forceLogout();
    },
    onError: (msg) => console.error('[RequestClient]', msg),
    getErrorMsg: getErrorMsg,
  });

  // 页面刷新后的会话恢复：zustand persist 的水化是异步微任务，若等自然水化，
  // initRouter 首跑可能读到未水化的 store 而误判未登录（实测复现）。这里在
  // 渲染前显式 rehydrate 两个 store，并从 auth-storage 的 userInfo 回填 userStore。
  try {
    await Promise.all([
      useAuthStore.persist.rehydrate(),
      useUserStore.persist.rehydrate(),
    ]);
  } catch (e) {
    console.error('[Bootstrap] persist rehydrate failed:', e);
  }

  const { accessToken, accessTokenExpireAt, userInfo } = useAuthStore.getState();
  if (accessToken) {
    if (userInfo && !useUserStore.getState().userInfo) {
      useUserStore.getState().setUserInfo(userInfo);
      useUserStore.getState().setUserRoles(userInfo.roles ?? []);
    }
    // 持久化的 access token 已过期（页面搁置后回来）：凭 HttpOnly refresh
    // cookie 静默续期，避免白屏后首个请求 401 → forceLogout 弹回登录页。
    // 过期 token 的 payload 仍可解出 uid/jti 作刷新绑定键。
    if (accessTokenExpireAt && accessTokenExpireAt <= Date.now()) {
      const newToken = await useAuthStore
        .getState()
        .refreshToken()
        .catch((e) => {
          // 带出真实错误：固定话术会把 refresh 端点 5xx/网络错等真因掩盖成“cookie 失效”
          console.error('[Bootstrap] silent session renew failed:', e);
          return '';
        });
      if (newToken) {
        console.log('[Bootstrap] session silently renewed via refresh cookie');
      }
    }
    // 续期失败时 forceLogout 已清空 token，跳过 SSE 建连（SSE 携带的是旧凭证）
    if (useAuthStore.getState().accessToken) {
      // 半残会话守卫：路由守卫只查 token，放行有 token 无 userInfo 的会话会让
      // 依赖 userInfo.id 的页面把字面量 "undefined" 当用户 ID 发出去（后端解析
      // 500）。userInfo 缺失时重拉身份（3 次重试消化后端重启窗口期），仍失败
      // 则强制登出收敛到干净的重登录。
      if (!useAuthStore.getState().userInfo) {
        const restored = await restoreIdentityWithRetry();
        if (!restored) {
          useAuthStore.getState().forceLogout();
          // 半残会话到此为止：不再起定时器、不再连 SSE
          return;
        }
      }
      // 会话恢复后重建站内信 SSE 实时通道（整页刷新会断开旧连接）
      connectSSEServer();
    }
    startRefreshTimer();
  } else if (getRefreshExpireAt() && (getRefreshExpireAt() ?? 0) > Date.now()) {
    // 无持久化 token（localStorage 被清/首次访问）但 refresh cookie 仍有效：
    // 静默恢复会话——凭 cookie 换新 token 后重拉 /me + /perm-codes 重建身份。
    try {
      const newToken = await useAuthStore.getState().refreshToken();
      if (newToken) {
        // profile 拉取失败不能只留痕继续跑（同上半残会话守卫）：短暂重试消化
        // 后端重启窗口期，仍失败则强制登出收敛到干净的重登录。
        const restored = await restoreIdentityWithRetry(newToken);
        if (restored) {
          connectSSEServer();
          startRefreshTimer();
          console.log('[Bootstrap] session silently restored via refresh cookie');
        } else {
          useAuthStore.getState().forceLogout();
        }
      }
    } catch (e) {
      console.error('[Bootstrap] silent restore failed (refresh cookie 可能无效或过期):', e);
    }
  }
}

/**
 * 拉取身份（/me + /perm-codes）带 3 次重试：短暂重试消化后端重启窗口期；
 * 全部失败返回 false，由调用方 forceLogout 收敛到干净的重登录。
 */
async function restoreIdentityWithRetry(token?: string): Promise<boolean> {
  let lastError: unknown = null;
  for (let attempt = 1; attempt <= 3; attempt += 1) {
    try {
      await restoreIdentity(token ?? useAuthStore.getState().accessToken ?? '');
      return true;
    } catch (e) {
      lastError = e;
      console.error(
        `[Bootstrap] identity restore failed (attempt ${attempt}/3):`,
        e,
      );
      if (attempt < 3) {
        await new Promise((resolve) => setTimeout(resolve, 400));
      }
    }
  }
  console.error(
    '[Bootstrap] identity unavailable after retries, forcing logout:',
    lastError,
  );
  return false;
}

/**
 * 从 refresh_exp cookie 读取 refresh token 的过期时间戳（Unix 秒 → 毫秒）。
 * 与 useTokenRefresh 内部逻辑同源（cookie 由后端登录/刷新时种下，Path=/）。
 */
function getRefreshExpireAt(): number | null {
  const match = document.cookie
    .split('; ')
    .find((row) => row.startsWith('refresh_exp='));
  if (!match) return null;
  const val = parseInt(match.split('=')[1], 10);
  return Number.isFinite(val) && val > 0 ? val * 1000 : null;
}

/**
 * 用显式 Authorization 头拉取 /me + /perm-codes 重建身份（静默恢复会话用，
 * 与 auth store 登录链路同源：原生 fetch 避免 axios 拦截器空 token 覆盖显式头）。
 */
async function restoreIdentity(token: string): Promise<void> {
  const fetchWithToken = async (path: string) => {
    const resp = await fetch(`/${adminPath(path)}`, {
      headers: {
        Authorization: `Bearer ${token}`,
        'Accept-Language': navigator.language || 'zh-CN',
      },
    });
    if (!resp.ok) {
      throw new Error(`${path} -> HTTP ${resp.status}`);
    }
    return resp.json();
  };
  try {
    const me = (await fetchWithToken('me')) as Record<string, unknown>;
    // toUserInfo 未导出：这里就地做最小映射（与 store 内字段一致），角色缺省平台管理员
    const roles = Array.isArray(me.roles) && me.roles.length > 0 ? (me.roles as string[]) : ['platform:admin'];
    const userInfo: UserInfo = {
      id: Number(me.id ?? 0),
      username: String(me.username ?? ''),
      nickname: String(me.nickname ?? me.realname ?? me.username ?? ''),
      realname: String(me.realname ?? me.nickname ?? ''),
      avatar: String(me.avatar ?? ''),
      avatarUrl: String(me.avatar ?? ''),
      description: '',
      homePath: '/dashboard',
      token: '',
      roles,
      tenantId: Number(me.tenantId ?? 0),
    };
    useAuthStore.getState().setUserInfo(userInfo);
    useUserStore.getState().setUserInfo(userInfo);
    useUserStore.getState().setUserRoles(userInfo.roles ?? []);
    try {
      const res = (await fetchWithToken('perm-codes')) as { codes?: string[] };
      useUserStore.getState().setAccessCodes(res?.codes ?? []);
    } catch (error) {
      console.error('[Bootstrap] restore /perm-codes failed:', error);
    }
  } catch (error) {
    // /me 失败必须向上抛：静默吞掉会放行"有 token 无 userInfo"的半残会话，
    // 重试与强制登出的收敛由 restoreIdentityWithRetry 的调用方负责
    console.error('[Bootstrap] restore /me failed:', error);
    throw error;
  }
}

/**
 * 获取错误提示文本。
 *
 * 后端错误响应形态：{"code":404,"reason":"VIDEO_NOT_FOUND","message":"...","metadata":{}}
 * 错误提示统一基于 reason 字段经 i18n 翻译，未命中映射时回退通用文案。
 */
export function getErrorMsg(error: unknown) {
  const i18nPrefix = 'request.';

  // 网络错误
  const errStr = String(error ?? '');
  if (errStr.includes('Network Error')) {
    return i18n.t(i18nPrefix + 'error.networkError', { ns: 'common' });
  }

  // 超时
  if (
    error &&
    typeof error === 'object' &&
    'message' in error &&
    String(error.message).includes('timeout')
  ) {
    return i18n.t(i18nPrefix + 'error.timeout', { ns: 'common' });
  }

  // 获取后端返回数据：兼容 AxiosError（响应体在 response.data）
  // 与已被 request() 解包的响应体（{code, reason, message}）两类形态
  const source =
    error && typeof error === 'object' ? (error as Record<string, unknown>) : undefined;
  const sourceResponse = source?.response as { data?: unknown } | undefined;
  const resData = (sourceResponse?.data ?? source) as { reason?: string } | undefined;

  // 仅基于 reason 查询 i18n；不再回退到后端 message
  if (resData) {
    const { reason } = resData;
    if (reason) {
      const key = i18nPrefix + `reason.${reason}`;
      // 使用 i18n.exists() 时需要指定命名空间
      if (i18n.exists(key, { ns: 'common' })) {
        return i18n.t(key, { ns: 'common' });
      }
    }
  }

  // 兜底
  return i18n.t(i18nPrefix + 'error.unknownError', { ns: 'common' });
}
