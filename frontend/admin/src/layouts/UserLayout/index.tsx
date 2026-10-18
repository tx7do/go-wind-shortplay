import React from 'react';
import { Outlet, Navigate } from 'react-router-dom';
import { ConfigProvider, Button, Tooltip } from 'antd';
import {
  AuditOutlined,
  GlobalOutlined,
  MoonOutlined,
  PlaySquareOutlined,
  SafetyOutlined,
  SunOutlined,
} from '@ant-design/icons';
import { useTranslation } from 'react-i18next';

import { useAuthStore } from '@/stores';
import { usePreferencesStore } from '@/core/preferences/store';
import { useThemeConfig } from '@/core/preferences/hooks/useThemeConfig';
import { useLocale } from '@/core/preferences/hooks/useLocale';
import { startThemeViewTransition } from '@/core/preferences/theme-transition';

import SloganIcon from '@/components/bussiness/AuthLayout/icons/SloganIcon';

import './UserLayout.style.less';

/** 左侧品牌区特性点（沉浸式视频流 / 完整审核工作流 / RBAC 权限管控） */
const BRAND_FEATURES = [
  { icon: <PlaySquareOutlined />, nameKey: 'brandFeatureImmersive', descKey: 'brandFeatureImmersiveDesc' },
  { icon: <AuditOutlined />, nameKey: 'brandFeatureReview', descKey: 'brandFeatureReviewDesc' },
  { icon: <SafetyOutlined />, nameKey: 'brandFeatureRbac', descKey: 'brandFeatureRbacDesc' },
] as const;

interface UserLayoutProps {
  requireAuth?: boolean; // 是否需要登录（用于保护路由）
}

export const UserLayout = ({ requireAuth = false }: UserLayoutProps) => {
  const { accessToken } = useAuthStore();
  const preferences = usePreferencesStore((state) => state.preferences);
  const themeConfig = useThemeConfig();
  const { locale, toggleLocale } = useLocale();
  const { t } = useTranslation('auth');

  // 根据主题模式判断当前是否为亮色模式
  const isLightMode = React.useMemo(() => {
    if (preferences.theme.mode === 'auto') {
      return window.matchMedia('(prefers-color-scheme: light)').matches;
    }
    return preferences.theme.mode === 'light';
  }, [preferences.theme.mode]);

  // 监听系统主题变化
  React.useEffect(() => {
    const mediaQuery = window.matchMedia('(prefers-color-scheme: dark)');
    const handleChange = () => {
      if (preferences.theme.mode === 'auto') {
        // 触发重新渲染以更新 isLightMode
        usePreferencesStore.getState().setPreferences({ theme: { mode: 'auto' } });
      }
    };
    mediaQuery.addEventListener('change', handleChange);
    return () => mediaQuery.removeEventListener('change', handleChange);
  }, [preferences.theme.mode]);

  // 未登录保护
  if (requireAuth && !accessToken) {
    const redirect = encodeURIComponent(window.location.pathname + window.location.search);
    return <Navigate to={`/login?redirect=${redirect}`} replace />;
  }

  // 已登录跳转（用于登录页）
  if (!requireAuth && accessToken) {
    return <Navigate to="/" replace />;
  }

  return (
    <ConfigProvider {...themeConfig}>
      <div
        className={`user-layout-wrapper${isLightMode ? ' light-mode' : ''}`}
        style={{
          display: 'flex',
          minHeight: '100vh',
          width: '100%',
          height: '100%'
        }}
      >
        {/* 右上角工具栏 */}
        <div className="user-toolbar">
          <Tooltip title={t('switchLanguage')}>
            <Button
              type="text"
              icon={<GlobalOutlined />}
              onClick={toggleLocale}
              className={isLightMode ? 'user-toolbar-btn-light' : 'user-toolbar-btn-dark'}
            >
              {locale === 'zh-CN' ? '中文' : 'English'}
            </Button>
          </Tooltip>
          <Tooltip
            title={preferences.theme.mode === 'light' ? t('switchToDarkMode') : t('switchToLightMode')}
          >
            <Button
              type="text"
              icon={preferences.theme.mode === 'light' ? <MoonOutlined /> : <SunOutlined />}
              onClick={(event) => {
                const nextMode = preferences.theme.mode === 'light' ? 'dark' : 'light';
                startThemeViewTransition({
                  origin: { x: event.clientX, y: event.clientY },
                  update: () => {
                    usePreferencesStore.getState().setPreferences({
                      theme: {
                        mode: nextMode,
                      },
                    });
                  },
                });
              }}
              className={isLightMode ? 'user-toolbar-btn-light' : 'user-toolbar-btn-dark'}
            />
          </Tooltip>
        </div>

        {/* 左侧品牌展示区 */}
        <div className="user-brand-section">
          {/* 背景装饰 - 多层渐变 */}
          <div className="user-brand-overlay" />

          {/* 装饰圆形 */}
          <div className="user-brand-circle circle-1" />
          <div className="user-brand-circle circle-2" />

          {/* 品牌图标 */}
          <div className="user-brand-icon">
            <SloganIcon />
          </div>

          <h2 className="user-brand-title">{t('systemTitle')}</h2>
          <p className="user-brand-description">{t('systemDescription')}</p>

          {/* 特性点：图标 + 名称 + 一句话说明（文案见 auth 命名空间 brandFeature*） */}
          <div className="user-brand-features">
            {BRAND_FEATURES.map((feature) => (
              <div key={feature.nameKey} className="user-brand-feature">
                <span className="user-brand-feature-icon">{feature.icon}</span>
                <span className="user-brand-feature-text">
                  <span className="user-brand-feature-name">{t(feature.nameKey)}</span>
                  <span className="user-brand-feature-desc">{t(feature.descKey)}</span>
                </span>
              </div>
            ))}
          </div>
        </div>

        {/* 右侧表单区 */}
        <div className="user-form-section">
          <div className="user-form-content">
            {/* 路由出口 */}
            <Outlet />
          </div>

          {/* 底部版权信息 */}
          {preferences.copyright.enable && (
            <div className="user-copyright text-[color:var(--gowind-secondary-text)]">
              Copyright © {preferences.copyright.date} {preferences.copyright.companyName}
            </div>
          )}
        </div>
      </div>
    </ConfigProvider>
  );
};

export default UserLayout;
