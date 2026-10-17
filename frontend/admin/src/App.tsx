/**
 * 应用路由：/login 登录页；其余路由经 RequireAuth 守卫后进入主布局。
 * 使用 HashRouter，静态部署无需服务端回退配置。
 */
import { HashRouter, Navigate, Route, Routes } from 'react-router-dom';
import type { ReactElement } from 'react';
import MainLayout from './layouts/MainLayout';
import LoginPage from './pages/login';
import DashboardPage from './pages/dashboard';
import VideosPage from './pages/videos';
import CommentsPage from './pages/comments';
import ReportsPage from './pages/reports';
import UsersPage from './pages/users';
import SysConfPage from './pages/sysconf';
import { useAuth } from './utils/auth';

/** 路由守卫：未登录重定向到登录页 */
function RequireAuth({ children }: { children: ReactElement }) {
  const { token } = useAuth();
  if (!token) {
    return <Navigate to="/login" replace />;
  }
  return children;
}

export default function App() {
  return (
    <HashRouter>
      <Routes>
        <Route path="/login" element={<LoginPage />} />
        <Route
          path="/"
          element={
            <RequireAuth>
              <MainLayout />
            </RequireAuth>
          }
        >
          <Route index element={<Navigate to="/dashboard" replace />} />
          <Route path="dashboard" element={<DashboardPage />} />
          <Route path="videos" element={<VideosPage />} />
          <Route path="comments" element={<CommentsPage />} />
          <Route path="reports" element={<ReportsPage />} />
          <Route path="users" element={<UsersPage />} />
          <Route path="sysconf" element={<SysConfPage />} />
        </Route>
        <Route path="*" element={<Navigate to="/dashboard" replace />} />
      </Routes>
    </HashRouter>
  );
}
