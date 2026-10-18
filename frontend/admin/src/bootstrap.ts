import { initI18n } from '@/core/i18n';
import { usePreferencesStore } from '@/core/preferences';
import { RequestClient } from '@/core/transport/rest';
import i18n from 'i18next';
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
    // 后端无管理端 refresh 端点：返回空串让 401 拦截器直接走重新认证
    refreshToken: async () => '',
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

  const { accessToken, userInfo } = useAuthStore.getState();
  if (accessToken) {
    if (userInfo && !useUserStore.getState().userInfo) {
      useUserStore.getState().setUserInfo(userInfo);
      useUserStore.getState().setUserRoles(userInfo.roles ?? []);
    }
    startRefreshTimer();
    // 会话恢复后重建站内信 SSE 实时通道（整页刷新会断开旧连接）
    connectSSEServer();
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
    error && typeof error === 'object' ? (error as Record<string, any>) : undefined;
  const resData = (source?.response?.data ?? source) as
    | { reason?: string }
    | undefined;

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
