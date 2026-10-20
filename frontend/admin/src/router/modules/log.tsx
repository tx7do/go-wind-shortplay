import { Navigate } from 'react-router-dom';

import type { AppRouteObject } from '@/core/router/types';
import { createLazyRoute } from '@/core/router';

/**
 * 日志审计模块路由（静态前端模式，路径与基座菜单种子 50-55 同形）。
 * navigation 拉取失败回退静态树时深链不落 404。
 */
export const logRoutes: AppRouteObject[] = [
  {
    name: 'log',
    path: 'log',
    meta: {
      title: 'menu.log.moduleName',
      icon: 'lucide:logs',
      order: 9,
    },
    children: [
      {
        index: true,
        element: <Navigate to="/log/login-audit-logs" replace />,
        meta: { title: 'menu.log.moduleName', hideInMenu: true, hideInTab: true },
      },
      {
        name: 'login-audit-logs',
        path: 'login-audit-logs',
        element: createLazyRoute(() => import('@/pages/app/audit/login')),
        meta: { title: 'menu.log.loginAuditLog', icon: 'lucide:user-lock', order: 1 },
      },
      {
        name: 'api-audit-logs',
        path: 'api-audit-logs',
        element: createLazyRoute(() => import('@/pages/app/audit/api')),
        meta: { title: 'menu.log.apiAuditLog', icon: 'lucide:plug', order: 2 },
      },
      {
        name: 'operation-audit-logs',
        path: 'operation-audit-logs',
        element: createLazyRoute(() => import('@/pages/app/audit/operation')),
        meta: { title: 'menu.log.operationAuditLog', icon: 'lucide:shield-ellipsis', order: 3 },
      },
      {
        name: 'data-access-audit-logs',
        path: 'data-access-audit-logs',
        element: createLazyRoute(() => import('@/pages/app/audit/data-access')),
        meta: { title: 'menu.log.dataAccessAuditLog', icon: 'lucide:database', order: 4 },
      },
      {
        name: 'permission-audit-logs',
        path: 'permission-audit-logs',
        element: createLazyRoute(() => import('@/pages/app/audit/permission')),
        meta: { title: 'menu.log.permissionAuditLog', icon: 'lucide:key-round', order: 5 },
      },
    ],
  },
];
