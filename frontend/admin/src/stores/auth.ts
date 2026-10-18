import { create } from 'zustand';
import { persist } from 'zustand/middleware';
import i18next from 'i18next';

import { adminHttp, adminPath } from '@/api/client';
import type { LoginResponse } from '@/api/types';
import { RequestClient } from '@/core/transport/rest';
import { connectSSEServer, disconnectSSEServer, startRefreshTimer, stopRefreshTimer } from '@/hooks/useTokenRefresh';
import { encryptPassword } from '@/utils';
import { useUserStore } from './user';
import { useTabsStore } from './tabs';
import { queryClient } from '@/core/query-client';

/**
 * 认证 Store（基座链路：cms authentication 移植面）
 *
 * 登录流程（与 cms 原版一致）：
 * 1. GET /admin/v1/captcha 取图形验证码（登录页负责展示/刷新）；
 * 2. POST /admin/v1/login，验证码经 X-Captcha-Id / X-Captcha-Value 请求头
 *    一次性携带，密码经 AES-128-CBC 加密（utils/crypto，VITE_AES_KEY）后传输；
 * 3. 成功响应 {access_token, expires_in,...}（snake_case，与 cms 基座一致），
 *    随后 GET /admin/v1/me 恢复身份与角色、GET /admin/v1/perm-codes 恢复权限码。
 *
 * 会话续期（基座机制，2026-10-18 接通；curl 契约实测见下）：
 * - 登录/刷新响应体只含 {token_type, access_token, expires_in, refresh_expires_in}，
 *   refresh token 经 Set-Cookie 下发：HttpOnly `refresh_token`
 *   （Path=/admin/v1/refresh-token，JS 不可读）+ 可读 `refresh_exp`（Path=/，
 *   Unix 秒过期时间戳，供定时器判失效）。登出由后端 clearRefreshCookies 清除；
 * - 续期 = POST /admin/v1/refresh-token（鉴权白名单端点），body 携带绑定键
 *   {grant_type:'refresh_token', user_id, jti}（从 access token payload 解出，
 *   非机密；真凭证是浏览器自动携带的 HttpOnly cookie），响应同登录形状并轮换
 *   refresh cookie；到期前由 useTokenRefresh 定时续期，401 时由 transport
 *   拦截器凭 cookie 静默重试一次，cookie 失效才 forceLogout。
 *
 * 与底座差异（裁剪说明）：
 * - 后端无 MFA，相关链路移除；
 * - SSE 保留：后端 internal-message 域有管理端 SSE（server.sse → :7601 /events），
 *   登录成功 / 会话恢复后建连，登出 / token 失效时断开（useTokenRefresh）；
 * - 登录响应不含 user，身份经 /me 获取；为支撑刷新页面后恢复身份，
 *   userInfo 随 accessToken 一并持久化（不含任何凭证信息）。
 */
export interface AuthState {
  // Token 状态
  accessToken: string | null;
  accessTokenExpireAt: number | null;

  // 用户状态（/me 拉取；持久化以便刷新页面恢复身份）
  userInfo: UserInfo | null;

  // UI 状态
  loginLoading: boolean;
  error: string | null;

  // 动作
  login: (
    params: { username: string; password: string },
    onSuccess?: () => void,
    captcha?: { id: string; value: string },
  ) => Promise<void>;
  logout: (redirect?: boolean) => Promise<void>;
  /**
   * 刷新 Token（基座机制）：凭 HttpOnly refresh cookie 换新 access token，
   * 绑定键 (uid/jti) 从当前 access token payload 解出随 body 回传。
   * 成功返回新 token，失败 forceLogout 并返回空串。
   */
  refreshToken: () => Promise<string>;
  reauthenticate: () => void;
  /** 强制登出：纯前端清除认证状态，不调后端接口（用于 401 场景） */
  forceLogout: () => void;
  setUserInfo: (info: UserInfo) => void;
  clearError: () => void;
  $reset: () => void;
}

/** /me（基座 i_user）→ 底座 BasicUserInfo（avatar 字段对齐 + 角色码透传） */
function toUserInfo(me: Partial<UserInfo> & Record<string, any>): UserInfo {
  return {
    id: me.id ?? 0,
    username: me.username ?? '',
    nickname: me.nickname ?? me.realname ?? me.username ?? '',
    realname: me.realname ?? me.nickname ?? '',
    avatar: me.avatar ?? '',
    avatarUrl: me.avatar ?? '',
    description: '',
    homePath: '/dashboard',
    token: '',
    roles: Array.isArray(me.roles) && me.roles.length > 0 ? me.roles : ['platform:admin'],
    tenantId: me.tenantId ?? 0,
  };
}

// ========== Store 实现 ==========
export const useAuthStore = create<AuthState>()(
  persist(
    (set, get) => ({
      accessToken: null,
      accessTokenExpireAt: null,
      userInfo: null,
      loginLoading: false,
      error: null,

      // 登录（基座链路：验证码头 + AES 加密密码 + /me + /perm-codes）
      login: async (params, onSuccess, captcha) => {
        set({ loginLoading: true, error: null });

        try {
          // 1. 调用登录接口：验证码经一次性 Header 携带（基座约定），
          //    密文传输（后端 NeedDecrypt 解密）。
          const headers: Record<string, string> = {};
          if (captcha) {
            headers['X-Captcha-Id'] = captcha.id;
            headers['X-Captcha-Value'] = captcha.value;
          }
          // ⚠ 登录响应是全站唯一的 snake_case 端点（curl 实测：access_token /
          // expires_in / refresh_expires_in / token_type，与 cms 基座一致），
          // camelCase 仅作防御性兼容位。
          const response = await RequestClient.getInstance().post<LoginResponse>(
            adminPath('login'),
            {
              username: params.username,
              password: encryptPassword(params.password || ''),
              grantType: 'password',
            } as never,
            { headers },
          );

          const token = response?.access_token || response?.accessToken || '';
          if (!token) {
            throw new Error(i18next.t('auth:loginFailed'));
          }

          const expiresIn =
            Number(response?.expires_in ?? response?.expiresIn ?? 0) || 7200;

          // 2. 恢复身份与权限码（/me + /perm-codes，基座登录后聚合链路）。
          //    ⚠ 必须在 accessToken 落 store 之前完成：AppRouter 订阅
          //    isAuthenticated，token 一落地就会跑 initRouter →
          //    getUserPermissionCodes()（userInfo 缺失即抛错 → forceLogout）。
          //    若先 set(token) 再异步拉 /me，校验必然与登录竞态，把会话拦腰
          //    打断（实测复现：登录 toast 成功但立即被弹回登录页）。
          //    这里用原生 fetch 携带显式 Authorization：axios 拦截器会把
          //    getToken()（此刻为 null）的空值写回 headers，覆盖掉显式头。
          //    失败不阻断登录但留痕排查。
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
          let me: Record<string, any> = {};
          try {
            me = (await fetchWithToken('me')) as Record<string, any>;
          } catch (error) {
            console.error('fetch /me failed after login:', error);
          }
          const userInfo = toUserInfo(me);
          let permCodes: string[] = [];
          try {
            const res = (await fetchWithToken('perm-codes')) as { codes?: string[] };
            permCodes = res?.codes ?? [];
          } catch (error) {
            console.error('fetch /perm-codes failed after login:', error);
          }

          // 3. 原子落地：token 与身份/角色/权限码同时就绪，AppRouter 校验必过。
          set({
            accessToken: token,
            accessTokenExpireAt: Date.now() + expiresIn * 1000,
            userInfo,
          });

          // 同步角色/权限码到 userStore（getAccessStatic 从这里读权限）
          useUserStore.getState().setUserInfo(userInfo);
          useUserStore.getState().setUserRoles(userInfo.roles ?? []);
          useUserStore.getState().setAccessCodes(permCodes);

          // 建立站内信 SSE 实时通道（internal-message 域通知推送）
          connectSSEServer();
          startRefreshTimer();

          if (onSuccess) {
            onSuccess();
          }
        } catch (err: any) {
          const errorMsg = err?.message || i18next.t('auth:loginFailed');
          set({
            error: errorMsg,
            accessToken: null,
            accessTokenExpireAt: null,
          });
          throw err;
        } finally {
          set({ loginLoading: false });
        }
      },

      // 登出（主动，调后端接口）
      // 清除状态后由 React 组件响应状态变化自然重定向
      logout: async (_redirect = true) => {
        try {
          // 服务端登出失败不影响本地清理
          await adminHttp.post('logout', {}).catch((error) => {
            console.error('服务端登出请求失败（已继续本地清理）:', error);
          });
        } finally {
          disconnectSSEServer();
          stopRefreshTimer();
          queryClient.clear();

          // 清除 localStorage 中的持久化数据
          localStorage.removeItem('auth-storage');
          localStorage.removeItem('user-storage');

          // 清除内存中的用户态（身份/角色/权限码）
          useUserStore.getState().$reset();
          // 布局态标签页一并清（对齐底座 D14 约定）
          useTabsStore.setState({ tabs: [] });
          localStorage.removeItem('app-tabs');

          set({
            accessToken: null,
            accessTokenExpireAt: null,
            userInfo: null,
            error: null,
            loginLoading: false,
          });
        }
      },

      // 刷新 Token（基座机制）：真凭证是 HttpOnly refresh cookie（浏览器同源
      // 自动携带，withCredentials 已开），绑定键 (uid/jti) 从持久化的 access
      // token payload 解出随 body 回传（过期 token 的未验签 payload 也可解，
      // 后端容忍）。响应同登录形状，含轮换后的新 access token 与新 refresh
      // cookie；响应体不含 refresh token（后端剥进 cookie）。
      refreshToken: async () => {
        try {
          let binding: { user_id?: number; jti?: string } = {};
          const at = get().accessToken;
          if (at) {
            try {
              const payload = JSON.parse(
                atob(at.split('.')[1].replace(/-/g, '+').replace(/_/g, '/')),
              ) as { uid?: number; jti?: string };
              binding = { user_id: payload.uid, jti: payload.jti };
            } catch {
              // 解码失败则空绑定键，交由服务端判定（不吞错：留痕后继续）
              console.error('[Auth] decode access token payload for refresh binding failed');
            }
          }
          // ⚠ 与登录同为 snake_case 契约（curl 实测：grant_type/user_id/jti）；
          // 走 RequestClient 单例（401 拦截器对 /refresh-token 特判：cookie
          // 失效直接重认证，不会死锁刷新队列）。
          const response = await RequestClient.getInstance().post<LoginResponse>(
            adminPath('refresh-token'),
            { grant_type: 'refresh_token', ...binding } as never,
          );

          const token = response?.access_token || response?.accessToken || '';
          if (!token) {
            throw new Error('refresh response missing access_token');
          }
          const expiresIn = Number(response?.expires_in ?? response?.expiresIn ?? 0) || 7200;

          set({
            accessToken: token,
            accessTokenExpireAt: Date.now() + expiresIn * 1000,
          });
          return token;
        } catch (err) {
          console.error('Refresh token failed:', err);
          get().forceLogout();
          return '';
        }
      },

      // 重认证（兜底）
      reauthenticate: () => {
        console.warn('Token invalid, please re-login');
        set({ error: i18next.t('auth:sessionExpired') });
      },

      // 强制登出：纯前端操作，不调后端接口（token 已失效 401 场景）
      forceLogout: () => {
        console.warn('Force logout: clearing auth state');
        disconnectSSEServer();
        stopRefreshTimer();
        queryClient.clear();
        localStorage.removeItem('auth-storage');
        localStorage.removeItem('user-storage');
        useUserStore.getState().$reset();
        useTabsStore.setState({ tabs: [] });
        localStorage.removeItem('app-tabs');
        set({
          accessToken: null,
          accessTokenExpireAt: null,
          userInfo: null,
          error: null,
          loginLoading: false,
        });
      },

      // 设置用户信息
      setUserInfo: (info) => set({ userInfo: info }),

      // 清除错误
      clearError: () => set({ error: null }),

      // 重置（用于测试/登出）
      $reset: () =>
        set({
          accessToken: null,
          accessTokenExpireAt: null,
          userInfo: null,
          loginLoading: false,
          error: null,
        }),
    }),
    {
      name: 'auth-storage', // localStorage key
      // 持久化 access token 与用户信息：刷新页面后凭持久化 token 恢复会话；
      // token 已过期时 bootstrap 凭 HttpOnly refresh cookie 静默续期（过期
      // token 的 payload 仍可解出 uid/jti 作刷新绑定键）。续期失效则由
      // 401 拦截器 / useTokenRefresh 的 forceLogout 清空本存储。
      partialize: (s) => ({
        accessToken: s.accessToken,
        accessTokenExpireAt: s.accessTokenExpireAt,
        userInfo: s.userInfo,
      }),
    },
  ),
);
