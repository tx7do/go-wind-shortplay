import { Navigate } from 'react-router-dom';

import type { AppRouteObject } from '@/core/router/types';
import { createLazyRoute } from '@/core/router';

/**
 * 短剧管理模块路由（静态前端模式）
 *
 * 路径与后端菜单种子（GET /admin/v1/navigation）保持同形：
 * 目录 /shortplay → 子 videos / comments / reports / sysconf。
 * 此前四个页面是扁平的 /videos 等，navigation 拉取失败回退静态树时，
 * 深链 /shortplay/videos 会落进 404 通配符（与 /opm/users 同根因，
 * 见 users.tsx 顶部说明）。
 *
 * 旧扁平路径（/videos 等）的重定向统一收口在 router/index.tsx 的
 * LEGACY_REDIRECT_ROUTES（前端回退树与后端树共用），本模块不再重复声明。
 */
export const shortplayRoutes: AppRouteObject[] = [
  {
    name: 'shortplay',
    path: 'shortplay',
    meta: {
      title: 'menu.shortPlay.moduleName',
      icon: 'lucide:clapperboard',
      order: 2,
    },
    children: [
      // /shortplay → 第一个子页面
      {
        index: true,
        element: <Navigate to="/shortplay/videos" replace />,
        meta: { title: 'menu.shortPlay.moduleName', hideInMenu: true, hideInTab: true },
      },
      {
        name: 'videos',
        path: 'videos',
        element: createLazyRoute(() => import('@/pages/app/video')),
        meta: {
          title: 'menu.shortPlay.video',
          icon: 'PlaySquareOutlined',
          order: 1,
        },
      },
      {
        name: 'comments',
        path: 'comments',
        element: createLazyRoute(() => import('@/pages/app/comment')),
        meta: {
          title: 'menu.shortPlay.comment',
          icon: 'CommentOutlined',
          order: 2,
        },
      },
      {
        name: 'reports',
        path: 'reports',
        element: createLazyRoute(() => import('@/pages/app/report')),
        meta: {
          title: 'menu.shortPlay.report',
          icon: 'FlagOutlined',
          order: 3,
        },
      },
      {
        name: 'sysconf',
        path: 'sysconf',
        element: createLazyRoute(() => import('@/pages/app/sysconf')),
        meta: {
          title: 'menu.shortPlay.sysconf',
          icon: 'SettingOutlined',
          order: 4,
        },
      },
    ],
  },
];
