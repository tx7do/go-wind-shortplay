/**
 * 主布局：左侧导航菜单 + 顶栏（当前用户名 / 退出登录）+ 内容区。
 */
import { useState } from 'react';
import { Avatar, Button, Layout, Menu, message, Space } from 'antd';
import type { MenuProps } from 'antd';
import {
  CommentOutlined,
  DashboardOutlined,
  FlagOutlined,
  LogoutOutlined,
  SettingOutlined,
  TeamOutlined,
  UserOutlined,
  VideoCameraOutlined,
} from '@ant-design/icons';
import { Outlet, useLocation, useNavigate } from 'react-router-dom';
import { logout } from '../api/auth';
import { useAuth } from '../utils/auth';

const { Header, Sider, Content } = Layout;

/** 左侧菜单项 */
const MENU_ITEMS: MenuProps['items'] = [
  { key: '/dashboard', icon: <DashboardOutlined />, label: '数据看板' },
  { key: '/videos', icon: <VideoCameraOutlined />, label: '视频管理' },
  { key: '/comments', icon: <CommentOutlined />, label: '评论管理' },
  { key: '/reports', icon: <FlagOutlined />, label: '举报管理' },
  { key: '/users', icon: <TeamOutlined />, label: '用户管理' },
  { key: '/sysconf', icon: <SettingOutlined />, label: '系统配置' },
];

export default function MainLayout() {
  const navigate = useNavigate();
  const location = useLocation();
  const { user, signOut } = useAuth();
  const [collapsed, setCollapsed] = useState(false);

  // 按路径第一段高亮菜单
  const selectedKey = `/${location.pathname.split('/')[1] || 'dashboard'}`;

  const handleLogout = async () => {
    try {
      await logout();
    } catch {
      // 登出接口失败不阻断本地清理
    }
    signOut();
    message.success('已退出登录');
    navigate('/login', { replace: true });
  };

  const onMenuClick: MenuProps['onClick'] = ({ key }) => {
    navigate(key);
  };

  return (
    <Layout style={{ minHeight: '100vh' }}>
      <Sider collapsible collapsed={collapsed} onCollapse={setCollapsed}>
        <div className="admin-logo">{collapsed ? 'GW' : 'GoWind 管理后台'}</div>
        <Menu theme="dark" mode="inline" selectedKeys={[selectedKey]} items={MENU_ITEMS} onClick={onMenuClick} />
      </Sider>
      <Layout>
        <Header
          style={{
            background: '#fff',
            padding: '0 24px',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'space-between',
            borderBottom: '1px solid #f0f0f0',
          }}
        >
          <span style={{ fontSize: 16, fontWeight: 600 }}>GoWind 短视频社区 · 管理后台</span>
          <Space size={12}>
            <Avatar size="small" icon={<UserOutlined />} />
            <span>{user?.nickname || user?.username || '管理员'}</span>
            <Button type="link" size="small" icon={<LogoutOutlined />} onClick={handleLogout}>
              退出登录
            </Button>
          </Space>
        </Header>
        <Content style={{ margin: 16 }}>
          <Outlet />
        </Content>
      </Layout>
    </Layout>
  );
}
