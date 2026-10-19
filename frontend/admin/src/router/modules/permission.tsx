import { Navigate } from 'react-router-dom';

import type { AppRouteObject } from '@/core/router/types';
import { createLazyRoute } from '@/core/router';

/**
 * 「组织与权限」模块路由（静态前端模式）
 *
 * 后端菜单模式下由 navigation 下发同名 component（permission/roles 等），
 * 这里的静态声明仅作为 navigation 失败回退时的兜底，路径与后端种子约定
 * （docs/API.md「约定」节）保持一致：/permission/roles、/permission/menus、
 * /permission/apis、/permission/departments、/permission/groups。
 */
export const permissionRoutes: AppRouteObject[] = [
  {
    name: 'permission',
    path: 'permission',
    meta: {
      title: 'routes:permission',
      icon: 'ApartmentOutlined',
      order: 7,
    },
    children: [
      // /permission → 第一个子页面
      {
        index: true,
        element: <Navigate to="/permission/roles" replace />,
        meta: { title: 'routes:permission', hideInMenu: true, hideInTab: true },
      },
      {
        name: 'permission-roles',
        path: 'roles',
        element: createLazyRoute(() => import('@/pages/app/permission/roles')),
        meta: {
          title: 'routes:permission-roles',
          icon: 'UsergroupAddOutlined',
          order: 1,
        },
      },
      {
        name: 'permission-menus',
        path: 'menus',
        element: createLazyRoute(() => import('@/pages/app/permission/menus')),
        meta: {
          title: 'routes:permission-menus',
          icon: 'MenuOutlined',
          order: 2,
        },
      },
      {
        name: 'permission-apis',
        path: 'apis',
        element: createLazyRoute(() => import('@/pages/app/permission/apis')),
        meta: {
          title: 'routes:permission-apis',
          icon: 'ApiOutlined',
          order: 3,
        },
      },
      {
        name: 'permission-departments',
        path: 'departments',
        element: createLazyRoute(() => import('@/pages/app/permission/departments')),
        meta: {
          title: 'routes:permission-departments',
          icon: 'ClusterOutlined',
          order: 4,
        },
      },
      {
        name: 'permission-groups',
        path: 'groups',
        element: createLazyRoute(() => import('@/pages/app/permission/groups')),
        meta: {
          title: 'routes:permission-groups',
          icon: 'KeyOutlined',
          order: 5,
        },
      },
    ],
  },
];

export default permissionRoutes;
