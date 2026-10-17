/**
 * 认证相关 Hook（GoWind shortplay 裁剪版）
 *
 * 后端无权限/角色服务：登录响应即完整身份，角色固定 super_admin
 * （login 时已写入 userStore）。这里只组合 store 状态与登出动作。
 */
import { useAuthStore } from '@/stores/auth';
import { useUserStore } from '@/stores/user';

export function useAuth() {
  const authStore = useAuthStore;

  /**
   * 获取用户权限码（角色码 + 权限码）。
   * 无权限服务：全部来自登录时写入的 userStore，仅做一次空值兜底。
   */
  async function getUserPermissionCodes(): Promise<{ roles: string[]; codes: string[] }> {
    const { userInfo, userRoles, accessCodes } = useUserStore.getState();
    if (userInfo === null) {
      throw new Error('userInfo missing: not authenticated');
    }
    return { roles: userRoles.length ? userRoles : (userInfo.roles ?? []), codes: accessCodes };
  }

  return {
    /** 登录加载状态 */
    get loginLoading() {
      return authStore.getState().loginLoading;
    },
    /** 登录 */
    login: (params: { username: string; password: string }, onSuccess?: () => void) =>
      authStore.getState().login(params, onSuccess),
    /** 登出（主动，调后端接口） */
    logout: (redirect?: boolean) => authStore.getState().logout(redirect),
    /** 强制登出（被动，不调后端接口，用于 token 失效场景） */
    forceLogout: () => authStore.getState().forceLogout(),
    /** 获取用户信息 */
    fetchUserInfo: async () => useUserStore.getState().userInfo,
    /** 获取角色码和权限码（无权限服务，本地读取） */
    getUserPermissionCodes,
  };
}
