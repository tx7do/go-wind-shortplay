import type { AppRouteObject } from '@/core/router/types';
import { createLazyRoute } from '@/core/router';

export const videoRoutes: AppRouteObject[] = [
  {
    name: 'videos',
    path: 'videos',
    element: createLazyRoute(() => import('@/pages/app/video')),
    meta: {
      title: 'routes:videos',
      icon: 'PlaySquareOutlined',
      order: 2,
    },
  },
];

export default videoRoutes;
