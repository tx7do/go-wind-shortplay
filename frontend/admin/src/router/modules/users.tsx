import { Navigate } from 'react-router-dom';

import type { AppRouteObject } from '@/core/router/types';
import { createLazyRoute } from '@/core/router';

/**
 * 用户模块路由（静态前端模式）
 *
 * 路径必须与后端菜单种子（GET /admin/v1/navigation）保持同形：
 * 后端下发目录 /opm → 子 users（component "users"）。此前的静态声明是
 * 扁平的 /users，一旦路由初始化时 navigation 拉取失败回退静态树，
 * 深链 /opm/users 就会落进 404 通配符——这正是「SPA 内导航正常、整页
 * 刷新 404」的根因（/permission/* 深链正常，恰因该模块早已按种子嵌套）。
 * 详见 docs/API.md「约定」节的菜单路径契约。
 *
 * 旧扁平路径 /users 的重定向统一收口在 router/index.tsx 的
 * LEGACY_REDIRECT_ROUTES（前端回退树与后端树共用），本模块不再重复声明。
 */
export const userRoutes: AppRouteObject[] = [
  {
    name: 'opm',
    path: 'opm',
    meta: {
      title: 'menu.opm.moduleName',
      icon: 'lucide:users',
      order: 5,
    },
    children: [
      // /opm → 第一个子页面（与后端目录节点 redirect 行为一致）
      {
        index: true,
        element: <Navigate to="/opm/users" replace />,
        meta: { title: 'menu.opm.moduleName', hideInMenu: true, hideInTab: true },
      },
      {
        name: 'users',
        path: 'users',
        element: createLazyRoute(() => import('@/pages/app/user')),
        meta: {
          title: 'routes:users',
          icon: 'TeamOutlined',
          order: 3,
        },
      },
    ],
  },
];

export default userRoutes;
