/**
 * 认证相关 Hook（GoWind shortplay 裁剪版）
 *
 * 后端无权限/角色服务：登录响应即完整身份，角色固定 super_admin
 * （login 时已写入 userStore）。这里只组合 store 状态与登出动作。
 */
import { useAuthStore } from '@/stores/auth';
import { useUserStore } from '@/stores/user';

/**
 * 获取用户权限码（角色码 + 权限码）——非 hook 的纯函数版本。
 * 无权限服务：全部来自登录时写入的 userStore，仅做一次空值兜底。
 *
 * 独立导出以便在 effect / 普通异步流程（如路由初始化）中调用：
 * useAuth() 名义上是 React hook，按 rules-of-hooks 约定不能在
 * 组件渲染流之外的普通函数里调用；本函数内部只读 store 快照，
 * 不触发 React 调度，无此限制。
 */
export async function getUserPermissionCodes(): Promise<{ roles: string[]; codes: string[] }> {
  const { userInfo, userRoles, accessCodes } = useUserStore.getState();
  if (userInfo === null) {
    throw new Error('userInfo missing: not authenticated');
  }
  return { roles: userRoles.length ? userRoles : (userInfo.roles ?? []), codes: accessCodes };
}

export function useAuth() {
  const authStore = useAuthStore;

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
