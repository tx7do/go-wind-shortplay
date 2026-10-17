import type { AppRouteObject } from '@/core/router/types';
import { createLazyRoute } from '@/core/router';

export const commentRoutes: AppRouteObject[] = [
  {
    name: 'comments',
    path: 'comments',
    element: createLazyRoute(() => import('@/pages/app/comment')),
    meta: {
      title: 'routes:comments',
      icon: 'CommentOutlined',
      order: 3,
    },
  },
];

export default commentRoutes;
