import type { AppRouteObject } from '@/core/router/types';
import { createLazyRoute } from '@/core/router';

export const sysconfRoutes: AppRouteObject[] = [
  {
    name: 'sysconf',
    path: 'sysconf',
    element: createLazyRoute(() => import('@/pages/app/sysconf')),
    meta: {
      title: 'routes:sysconf',
      icon: 'SettingOutlined',
      order: 6,
    },
  },
];

export default sysconfRoutes;
