import { Navigate } from 'react-router-dom';

import { type AppRouteObject, createLazyRoute } from '@/core/router';
import { AuthGuard } from '@/router/guards';
import MainLayout from '@/layouts/MainLayout';

/**
 * 静态基础路由配置
 */
export const staticRoutes: AppRouteObject[] = [
  // 主布局容器（所有需要登录的页面都在这里）
  // 直接使用 '/' 作为路径，业务路由会作为其子路由。
  // meta.replaceByBackendLayout：后端菜单模式下本容器由 navigation 下发的
  // BasicLayout 取代（见 core/router/factory separateRoutes）
  {
    path: '/',
    element: (
      <AuthGuard>
        <MainLayout />
      </AuthGuard>
    ),
    meta: {
      hideInMenu: true,
      hideInTab: true,
      replaceByBackendLayout: true,
    },
    children: [
      // 根路径重定向到 dashboard
      {
        path: '/',
        index: true,
        element: <Navigate to="/dashboard" replace />,
        meta: { title: 'routes:home', hideInMenu: true, hideInTab: true },
      },
      // 个人中心：不进菜单（顶栏用户下拉进入），静态/后端两种模式都需挂载
      {
        name: 'profile',
        path: 'profile',
        element: createLazyRoute(() => import('@/pages/app/profile')),
        meta: { title: 'routes:profile', hideInMenu: true },
      },
    ],
  },
];
