import { useState, useEffect, type ComponentType } from 'react';
import { Navigate, RouterProvider } from 'react-router-dom';

import { createAccessibleRouter } from '@/core/router/factory';
import { AccessibleRoutesContext } from '@/core/router';
import { useAuthStore } from '@/stores';
import { getUserPermissionCodes } from '@/hooks/useAuth';
import { getAccessStatic } from '@/core/access';
import { usePreferencesStore } from '@/core/preferences/store';
import { useI18n } from '@/core/i18n';

import { Forbidden } from '@/pages/core/error';
import type {
  AppRouteObject,
  BackendRoute,
  ComponentRecordType,
} from '@/core/router';
import type { NavigationNode } from '@/api/types';
import { fetchNavigation } from '@/api/hooks/rbac';
import MainLayout from '@/layouts/MainLayout';
import { AuthGuard } from '@/router/guards';

import { errorRoutes } from './config/error-routes';
import Loading from '@/components/common/Loading';
import { authRoutes } from './config/auth';
import { staticRoutes } from './config/static';

// ====================================================================
// 后端菜单模式（动态菜单）：
// 从 cms 原版拷回 layoutMap / pageMap / fetchMenuListAsync 链路并适配：
// - navigation（GET /admin/v1/navigation）返回当前用户菜单树（按角色过滤）；
// - component 字段映射 pageMap 中的本地页面组件（六业务页 + 四权限页）；
// - navigation 拉取失败 / 为空时整树回退静态路由（前端模式），登录不闪断。
// ====================================================================

// 布局组件映射（后端 component 字段 → React 组件）
// 后端模式：BasicLayout 需要包裹 AuthGuard（前端模式已在 staticRoutes 中包裹）
const AuthenticatedLayout = () => (
  <AuthGuard>
    <MainLayout />
  </AuthGuard>
);

const layoutMap: ComponentRecordType = {
  BasicLayout: AuthenticatedLayout,
};

// 页面组件映射：Vite glob 导入所有业务页面（后端模式用）
// 关键：pageMap 的键必须与 generate-routes-backend 的 normalizeViewPath 产物一致。
// 后端 component 如 "dashboard" / "permission/roles" → 标准化为 "/dashboard" 等，
// 这里按同规则注册 4 种键形态，兼容任意写法。
const rawPageModules = import.meta.glob('../pages/app/**/*.tsx', { eager: true });

const pageMap: ComponentRecordType = {};
for (const [globPath, module] of Object.entries(rawPageModules)) {
  const mod = module as { default?: unknown };
  const Candidate = mod?.default || mod;
  if (typeof Candidate === 'function') {
    // globPath: "../pages/app/dashboard/index.tsx" → 相对 app/ 的页面路径
    const appMatch = globPath.match(/(?:pages|views)\/app\/(.+)/);
    if (!appMatch) continue;

    const relativePath = appMatch[1] // "dashboard/index.tsx"
      .replace(/\.tsx$/, '') // "dashboard/index"
      .replace(/\/index$/, ''); // "dashboard"

    const normalizedKey = `/${relativePath}`; // "/dashboard"
    // 页面 props 由后端路由数据动态注入，无静态形态可约束，收窄为索引签名
    const Component = Candidate as ComponentType<Record<string, unknown>>;
    pageMap[normalizedKey] = Component;
    pageMap[`${normalizedKey}/index`] = Component; // "/dashboard/index"
    pageMap[`${normalizedKey}.tsx`] = Component; // "/dashboard.tsx"
    pageMap[`${normalizedKey}/index.tsx`] = Component; // "/dashboard/index.tsx"
  }
}

// 后端菜单种子以「与路径一致的复数」作为 component 标识（/videos → "videos" 等），
// 而本仓页面目录为单数（pages/app/video、comment、report、user）。这里补注册别名键，
// 使单数目录名与后端复数标识都能解析；后端若改回单数也依然命中，属纯增量兼容。
const COMPONENT_ALIAS_KEYS: Record<string, string> = {
  '/videos': '/video',
  '/comments': '/comment',
  '/reports': '/report',
  '/users': '/user',
};
for (const [aliasKey, targetKey] of Object.entries(COMPONENT_ALIAS_KEYS)) {
  const Target = pageMap[targetKey];
  if (Target) {
    pageMap[aliasKey] = Target;
    pageMap[`${aliasKey}/index`] = Target;
    pageMap[`${aliasKey}.tsx`] = Target;
    pageMap[`${aliasKey}/index.tsx`] = Target;
  }
}

/**
 * navigation 节点 → BackendRoute：
 * - 路由唯一标识取 path（后端 name 可能是 i18n key，二者都可作标题）；
 * - meta.title 直接用节点 name：SiderMenu/面包屑对 'menu.xxx' / 'routes:xxx'
 *   形态自动翻译，普通文本原样展示，两种种子写法均兼容；
 * - 路径只在根层级补前导 '/'，子层级保持后端下发的相对路径
 *   （React Router 要求绝对子路径必须以父路径为前缀，全量绝对化会在
 *   createBrowserRouter 处炸掉嵌套树——这正是"侧栏被打平"的次生根因之一）；
 * - 目录节点的 BasicLayout 组件在此剥离：布局由 ensureLayoutRoot 合成的
 *   '/' 根统一承载，嵌套 BasicLayout 会挂出双层侧栏；
 * - 目录节点合成 redirect 指向第一个子节点的完整路径，
 *   由 generate-routes-backend 转成 index <Navigate>（React Router v6 无 redirect 属性）。
 */
function toBackendRoutes(nodes: NavigationNode[], parentPath: string = ''): BackendRoute[] {
  return (nodes || [])
    .filter((node) => node?.path)
    .map((node) => {
      const rawPath = node.path ?? '';
      // 根层级统一为绝对路径（redirect 合成与菜单 key 计算都依赖稳定形态）；
      // 子层级保持相对路径，交给 React Router 按父路径拼接
      const isRoot = parentPath === '';
      const path = isRoot && !rawPath.startsWith('/') ? `/${rawPath}` : rawPath;
      const children = node.children?.length
        ? toBackendRoutes(node.children, path)
        : undefined;
      const route: BackendRoute = {
        name: path,
        path,
        meta: {
          title: node.name || path,
          icon: node.icon || undefined,
          order: node.sort,
          hideInMenu: node.visible === false,
        },
      };
      if (node.component && node.component !== 'BasicLayout') {
        route.component = node.component;
      } else if (children?.length) {
        // 目录节点（无页面组件）：注入带 name 的 index 重定向子路由。
        // redirect 取第一个子节点的完整路径（相对子路径按当前目录路径补全）；
        // 子节点与目录同路径时（如 Dashboard 目录/页共用 /dashboard）不注入，
        // 避免 index <Navigate> 自我重定向死循环。
        const firstChild = children[0];
        const firstChildAbs = firstChild.path?.startsWith('/')
          ? firstChild.path
          : `${path}/${firstChild.path}`;
        if (firstChildAbs !== path) {
          children.unshift({
            name: `${path}-redirect`,
            index: true,
            redirect: firstChildAbs,
          });
        }
        route.children = children;
      }
      return route;
    });
}

// 个人中心伪节点：不在后端菜单种子约定内（docs/API.md 只列了 10 个菜单路径），
// 但顶栏「个人中心」入口始终需要路由。后端模式追加为隐藏节点。
const PROFILE_BACKEND_ROUTE: BackendRoute = {
  name: '/profile',
  path: '/profile',
  component: 'profile',
  meta: { title: 'routes:profile', hideInMenu: true },
};

/**
 * 旧扁平路径兼容重定向：初版静态树把业务页挂在 '/' 顶层（/users、/videos 等），
 * 对齐后端菜单种子后统一嵌套为 /opm/users、/shortplay/*。这里保留旧路径 →
 * 新路径的重定向，前端回退树（allRoutes 合并）与后端树（ensureLayoutRoot）
 * 共用，历史书签 / 旧标签页两种模式下都能落地。
 */
const LEGACY_REDIRECT_PAIRS: ReadonlyArray<{ from: string; to: string; title: string }> = [
  { from: 'users', to: '/opm/users', title: 'routes:users' },
  { from: 'videos', to: '/shortplay/videos', title: 'menu.shortPlay.video' },
  { from: 'comments', to: '/shortplay/comments', title: 'menu.shortPlay.comment' },
  { from: 'reports', to: '/shortplay/reports', title: 'menu.shortPlay.report' },
  { from: 'sysconf', to: '/shortplay/sysconf', title: 'menu.shortPlay.sysconf' },
];

/** 静态树形态（element 直挂 Navigate，随 allRoutes 并入 '/' 容器） */
const LEGACY_REDIRECT_ROUTES: AppRouteObject[] = LEGACY_REDIRECT_PAIRS.map(({ from, to, title }) => ({
  name: `${from}-legacy`,
  path: from,
  element: <Navigate to={to} replace />,
  meta: { title, hideInMenu: true, hideInTab: true },
}));

/** 后端树形态（redirect 经 generateRoutesByBackend 转 index Navigate） */
const LEGACY_REDIRECT_BACKEND_ROUTES: BackendRoute[] = LEGACY_REDIRECT_PAIRS.map(({ from, to, title }) => ({
  name: `${from}-legacy`,
  path: from,
  redirect: to,
  meta: { title, hideInMenu: true, hideInTab: true },
}));

/**
 * 统一合成 '/' 主布局根节点：
 * - navigation 下发的多棵目录子树（Dashboard/组织人事/权限/短剧管理等）全部
 *   挂到同一 BasicLayout 根下，侧栏（useMenuData 取 '/' 容器的 children）才能
 *   呈现完整层级树；目录的 BasicLayout 已在 toBackendRoutes 剥离，不会双层布局；
 * - 个人中心伪节点并入根 children（顶栏「个人中心」入口始终有路由）。
 */
function ensureLayoutRoot(routes: BackendRoute[]): BackendRoute[] {
  return [
    {
      name: 'root',
      path: '/',
      component: 'BasicLayout',
      meta: { title: 'routes:home', hideInMenu: true, hideInTab: true },
      children: [...routes, PROFILE_BACKEND_ROUTE, ...LEGACY_REDIRECT_BACKEND_ROUTES],
    },
  ];
}

// 业务模块路由在 ./business-routes.ts 中统一提取（allRoutes 组装与菜单同步共用）
import { businessRoutes } from './business-routes';
export { businessRoutes };

// 合并路由：将业务模块路由合并到主布局容器的 children 中
export const allRoutes: AppRouteObject[] = [
  ...staticRoutes.map((route) => {
    // 找到主布局容器路由（path 为 '/' 且包含 children）
    if (route.path === '/' && route.children) {
      return {
        ...route,
        children: [...route.children, ...businessRoutes, ...LEGACY_REDIRECT_ROUTES],
      };
    }
    return route;
  }),
  ...authRoutes, // 认证路由（独立，不受 AuthGuard 保护）
  ...errorRoutes, // 错误路由放在最后
];

// 路由器实例类型随 createAccessibleRouter 的返回签名走，避免手写 any
type RouterBundle = {
  router: Awaited<ReturnType<typeof createAccessibleRouter>>['router'];
  routes: AppRouteObject[];
};

export const AppRouter = () => {
  const [routerBundle, setRouterBundle] = useState<RouterBundle | null>(null);
  const [loading, setLoading] = useState(true);

  const { accessToken } = useAuthStore();
  const accessMode = usePreferencesStore((s) => s.preferences.app.accessMode);
  const { t } = useI18n('common');

  const isAuthenticated = !!accessToken;

  useEffect(() => {
    let stale = false;

    const initRouter = async () => {
      setLoading(true);

      try {
        // ========== 已认证时的初始化流程 ==========
        if (isAuthenticated) {
          try {
            // 校验本地身份完整（角色码来自登录响应，无权限服务可调）；
            // 身份缺失=脏存储，forceLogout 后走未认证分支。
            // 用非 hook 版本 getUserPermissionCodes：useAuth() 名义上是 hook，
            // 不能在 effect 内的普通异步函数里调用（rules-of-hooks）。
            await getUserPermissionCodes();
          } catch (authErr) {
            console.warn('Auth initialization failed, will redirect to login:', authErr);
            useAuthStore.getState().forceLogout();
            // 立即终止本轮初始化：isAuthenticated 翻转会重触发本 effect 并按
            // 未登录分支重建路由。若继续往下跑，会用 effect 闭包里过期的
            // isAuthenticated=true 去拉 navigation（此时 token 已清）→ 必 401
            // → 静默回退前端静态树，把深链打进 404 通配符。
            return;
          }
        }

        // ========== 后端菜单模式探测 ==========
        // 先拉 navigation：成功才走 backend 模式；失败/为空回退 frontend
        // 模式（静态路由全量仍在，登录不闪断）。
        // ⚠ 重试一次再回退：后端重启/网络抖动的瞬时失败若直接回退静态树，
        // 深链（/opm/users 等）会在静态树里落 404 通配符——静态树虽已按
        // 种子路径嵌套对齐，但权限页等后端独有路径仍只有后端树才有。
        let backendMenuRoutes: BackendRoute[] | null = null;
        if (accessMode === 'backend' && isAuthenticated) {
          const fetchNavWithRetry = async (): Promise<BackendRoute[] | null> => {
            try {
              const mapped = toBackendRoutes(await fetchNavigation());
              // 空 navigation 视同失败：回退静态树（保持既有行为，
              // 避免后端模式 + 空路由树把静态页全部打丢）
              return mapped.length ? ensureLayoutRoot(mapped) : null;
            } catch (navErr) {
              // 首次失败按瞬时故障处理：短暂退避后重试一次
              console.warn('[Router] navigation 拉取失败，300ms 后重试一次:', navErr);
              await new Promise((resolve) => setTimeout(resolve, 300));
              try {
                const mapped = toBackendRoutes(await fetchNavigation());
                return mapped.length ? ensureLayoutRoot(mapped) : null;
              } catch (retryErr) {
                console.warn('[Router] navigation 重试仍失败，回退静态路由:', retryErr);
                return null;
              }
            }
          };
          backendMenuRoutes = await fetchNavWithRetry();
        }

        // await 之后，通过 useAccess 获取最新合并权限（角色码 + 权限码）
        const freshPermissions = getAccessStatic().getAllPermissions();

        // 无论认证是否成功，都生成路由（未认证时 permissions 为空，AuthGuard 会拦截）
        const { router: appRouter, routes: generatedRoutes } = await createAccessibleRouter(
          backendMenuRoutes ? 'backend' : 'frontend',
          {
            routes: allRoutes,
            permissions: freshPermissions,
            forbiddenElement: <Forbidden />,
            fetchMenuListAsync: async () => backendMenuRoutes ?? [],
            layoutMap,
            pageMap,
            autoInjectRedirect: true,
            autoSort: true,
          },
        );

        if (!stale) {
          setRouterBundle({ router: appRouter, routes: generatedRoutes });
        }
      } catch (err) {
        console.error('Router init failed:', err);
      } finally {
        if (!stale) {
          setLoading(false);
        }
      }
    };

    initRouter();

    // cleanup：当 effect 重新触发时（isAuthenticated 变化），取消上一次 initRouter
    return () => {
      stale = true;
    };
  }, [isAuthenticated, accessMode]);

  if (loading || !routerBundle)
    return <Loading fullScreen text={t('loading.initializing')} subText={t('loading.loadingRouter')} />;

  // 挂载路由树经 Context 下发：侧栏镜像实际挂载路由（后端模式=后端下发，
  // 前端模式=权限过滤后），避免后端模式侧栏回退静态全量表造成越权观感
  return (
    <AccessibleRoutesContext.Provider value={routerBundle.routes}>
      <RouterProvider router={routerBundle.router} />
    </AccessibleRoutesContext.Provider>
  );
};
