import { create } from 'zustand';
import { persist } from 'zustand/middleware';
import i18next from 'i18next';

import { adminHttp } from '@/api/client';
import type { LoginResponse } from '@/api/types';
import { useUserStore } from './user';
import { useTabsStore } from './tabs';
import { queryClient } from '@/core/query-client';

/**
 * 认证 Store（GoWind shortplay Admin BFF 契约）
 *
 * POST /admin/v1/login {username,password} →
 *   {authenticator:{accessToken,refreshToken,expiresIn,tokenType}, user:{id,username,nickname,avatarUrl}}
 *
 * 与底座差异（裁剪说明）：
 * - 后端无 MFA / 验证码 / SSE / 管理端 refresh 端点，相关链路全部移除；
 * - 登录响应自带 user，无需再调 GetMe；为支撑刷新页面后恢复身份，
 *   userInfo 随 accessToken 一并持久化（不含任何凭证信息）；
 * - 401 由 transport 拦截器直接 forceLogout（无静默续期）。
 */
export interface AuthState {
  // Token 状态
  accessToken: string | null;
  accessTokenExpireAt: number | null;

  // 用户状态（登录响应中的 user；持久化以便刷新页面恢复身份）
  userInfo: UserInfo | null;

  // UI 状态
  loginLoading: boolean;
  error: string | null;

  // 动作
  login: (
    params: { username: string; password: string },
    onSuccess?: () => void,
  ) => Promise<void>;
  logout: (redirect?: boolean) => Promise<void>;
  reauthenticate: () => void;
  /** 强制登出：纯前端清除认证状态，不调后端接口（用于 401 场景） */
  forceLogout: () => void;
  setUserInfo: (info: UserInfo) => void;
  clearError: () => void;
  $reset: () => void;
}

/** 登录响应 user → 底座 BasicUserInfo（avatar 字段对齐 + 静态管理员角色） */
function toUserInfo(user: LoginResponse['user']): UserInfo {
  return {
    id: user?.id ?? 0,
    username: user?.username ?? '',
    nickname: user?.nickname ?? user?.username ?? '',
    realname: user?.nickname ?? '',
    avatar: user?.avatarUrl ?? '',
    avatarUrl: user?.avatarUrl ?? '',
    description: '',
    homePath: '/dashboard',
    token: '',
    roles: ['super_admin'],
    tenantId: 0,
  };
}

// ========== Store 实现 ==========
export const useAuthStore = create<AuthState>()(
  persist(
    (set) => ({
      accessToken: null,
      accessTokenExpireAt: null,
      userInfo: null,
      loginLoading: false,
      error: null,

      // 登录
      login: async (params, onSuccess) => {
        set({ loginLoading: true, error: null });

        try {
          const response = await adminHttp.post<LoginResponse>('login', {
            username: params.username,
            password: params.password,
          });

          const token = response.authenticator?.accessToken || '';
          if (!token) {
            throw new Error(i18next.t('auth:loginFailed'));
          }

          const expiresIn = response.authenticator?.expiresIn || 7200;
          set({
            accessToken: token,
            accessTokenExpireAt: Date.now() + expiresIn * 1000,
            userInfo: toUserInfo(response.user),
          });

          // 同步角色到 userStore（getAccessStatic 从这里读权限）
          const userInfo = toUserInfo(response.user);
          useUserStore.getState().setUserInfo(userInfo);
          useUserStore.getState().setUserRoles(userInfo.roles ?? []);
          useUserStore.getState().setAccessCodes([]);

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

      // 重认证（兜底）
      reauthenticate: () => {
        console.warn('Token invalid, please re-login');
        set({ error: i18next.t('auth:sessionExpired') });
      },

      // 强制登出：纯前端操作，不调后端接口（token 已失效 401 场景）
      forceLogout: () => {
        console.warn('Force logout: clearing auth state');
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
      // 持久化 access token 与用户信息：后端无管理端 refresh 端点，
      // 刷新页面后凭持久化的 accessToken + userInfo 直接恢复会话（免二次登录）。
      // token 过期后首个 API 401 会经拦截器 forceLogout 清空本存储。
      partialize: (s) => ({
        accessToken: s.accessToken,
        accessTokenExpireAt: s.accessTokenExpireAt,
        userInfo: s.userInfo,
      }),
    },
  ),
);
