import { useState, useEffect } from 'react';
import { RouterProvider } from 'react-router-dom';

import { createAccessibleRouter } from '@/core/router/factory';
import { AccessibleRoutesContext } from '@/core/router';
import { useAuthStore } from '@/stores';
import { useAuth } from '@/hooks/useAuth';
import { getAccessStatic } from '@/core/access';
import { usePreferencesStore } from '@/core/preferences/store';
import { useI18n } from '@/core/i18n';

import { Forbidden } from '@/pages/core/error';
import type { AppRouteObject } from '@/core/router';

import { errorRoutes } from './config/error-routes';
import Loading from '@/components/common/Loading';
import { authRoutes } from './config/auth';
import { staticRoutes } from './config/static';

// GoWind shortplay：静态路由模式（后端无菜单/权限服务），
// 后端模式专用的 layoutMap/pageMap/fetchMenuListAsync 链路已随 cms 裁剪移除。

// 业务模块路由在 ./business-routes.ts 中统一提取（allRoutes 组装与菜单同步共用）
import { businessRoutes } from './business-routes';
export { businessRoutes };

// 合并路由：将业务模块路由合并到主布局容器的 children 中
export const allRoutes: AppRouteObject[] = [
  ...staticRoutes.map((route) => {
    // 找到主布局容器路由（path 为 '/' 且包含 children）
    if (route.path === '/' && route.children) {
      return {
        ...route,
        children: [...route.children, ...businessRoutes],
      };
    }
    return route;
  }),
  ...authRoutes, // 认证路由（独立，不受 AuthGuard 保护）
  ...errorRoutes, // 错误路由放在最后
];

export const AppRouter = () => {
  const [routerBundle, setRouterBundle] = useState<{ router: any; routes: AppRouteObject[] } | null>(null);
  const [loading, setLoading] = useState(true);

  const { accessToken } = useAuthStore();
  const accessMode = usePreferencesStore((s) => s.preferences.app.accessMode);
  const { t } = useI18n('common');

  const isAuthenticated = !!accessToken;

  useEffect(() => {
    let stale = false;

    const initRouter = async () => {
      setLoading(true);

      try {
        // ========== 已认证时的初始化流程 ==========
        if (isAuthenticated) {
          try {
            const auth = useAuth();

            // 校验本地身份完整（角色码来自登录响应，无权限服务可调）；
            // 身份缺失=脏存储，forceLogout 后走未认证分支
            await auth.getUserPermissionCodes();
          } catch (authErr) {
            console.warn('Auth initialization failed, will redirect to login:', authErr);
            useAuthStore.getState().forceLogout();

            if (stale) return; // 已过期，不继续创建路由
          }
        }

        // await 之后，通过 useAccess 获取最新合并权限（角色码 + 权限码）
        const freshPermissions = getAccessStatic().getAllPermissions();

        // 无论认证是否成功，都生成路由（未认证时 permissions 为空，AuthGuard 会拦截）
        const { router: appRouter, routes: generatedRoutes } = await createAccessibleRouter(
          accessMode,
          {
            routes: allRoutes,
            permissions: freshPermissions,
            forbiddenElement: <Forbidden />,
            autoInjectRedirect: true,
            autoSort: true,
          },
        );

        if (!stale) {
          setRouterBundle({ router: appRouter, routes: generatedRoutes });
        }
      } catch (err) {
        console.error('Router init failed:', err);
      } finally {
        if (!stale) {
          setLoading(false);
        }
      }
    };

    initRouter();

    // cleanup：当 effect 重新触发时（isAuthenticated 变化），取消上一次 initRouter
    return () => {
      stale = true;
    };
  }, [isAuthenticated, accessMode]);

  if (loading || !routerBundle)
    return <Loading fullScreen text={t('loading.initializing')} subText={t('loading.loadingRouter')} />;

  // 挂载路由树经 Context 下发：侧栏镜像实际挂载路由（后端模式=后端下发，
  // 前端模式=权限过滤后），避免后端模式侧栏回退静态全量表造成越权观感
  return (
    <AccessibleRoutesContext.Provider value={routerBundle.routes}>
      <RouterProvider router={routerBundle.router} />
    </AccessibleRoutesContext.Provider>
  );
};
