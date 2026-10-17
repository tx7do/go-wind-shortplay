import type { AppRouteObject } from '@/core/router/types';
import { createLazyRoute } from '@/core/router';

export const dashboardRoutes: AppRouteObject[] = [
  {
    name: 'dashboard',
    path: 'dashboard', // 相对路径，会自动拼接到父路由 '/'
    element: createLazyRoute(() => import('@/pages/app/dashboard')),
    meta: {
      title: 'routes:dashboard',
      icon: 'DashboardOutlined', // Ant Design 图标（iconResolver 向后兼容格式）
      order: 1,
      hideInMenu: false,
    },
  },
];

export default dashboardRoutes;
