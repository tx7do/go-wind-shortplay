import type { AppRouteObject } from '@/core/router/types';
import { createLazyRoute } from '@/core/router';

export const userRoutes: AppRouteObject[] = [
  {
    name: 'users',
    path: 'users',
    element: createLazyRoute(() => import('@/pages/app/user')),
    meta: {
      title: 'routes:users',
      icon: 'TeamOutlined',
      order: 5,
    },
  },
];

export default userRoutes;
