import type { AppRouteObject } from '@/core/router/types';
import { createLazyRoute } from '@/core/router';

export const reportRoutes: AppRouteObject[] = [
  {
    name: 'reports',
    path: 'reports',
    element: createLazyRoute(() => import('@/pages/app/report')),
    meta: {
      title: 'routes:reports',
      icon: 'FlagOutlined',
      order: 4,
    },
  },
];

export default reportRoutes;
