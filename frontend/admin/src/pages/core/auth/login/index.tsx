import React from 'react';
import { useTranslation } from 'react-i18next';
import { Form, Input, Button, App } from 'antd';
import { UserOutlined, LockOutlined } from '@ant-design/icons';
import { useAuthStore } from '@/stores';
import { useNavigate, useSearchParams } from 'react-router-dom';

const Login: React.FC = () => {
  const { t } = useTranslation('auth');
  const { login, loginLoading } = useAuthStore();
  const navigate = useNavigate();
  const [searchParams] = useSearchParams();
  const { message } = App.useApp();

  const handleSubmit = async (values: { username: string; password: string }) => {
    // 跳转目标：redirect 参数 → 首页。
    // 校验必须为同源相对路径，防止开放重定向（如 ?redirect=https://evil.com 或 //evil.com）
    const rawRedirect = searchParams.get('redirect') || '/';
    const redirect =
      rawRedirect.startsWith('/') && !rawRedirect.startsWith('//') ? rawRedirect : '/';
    try {
      // onSuccess：store 检测到回调即跳过默认跳转，改由这里经 react-router 跳转。
      // 必须赶在 AppRouter 重建 router（createBrowserRouter 以 window.location
      // 为初始地址）之前完成，避免整页跳转与 SPA 导航赛跑。
      await login({ username: values.username, password: values.password }, () =>
        navigate(redirect),
      );

      message.success(t('loginSuccess'));
    } catch (error: any) {
      // 弹出错误提示（与 CRUD 页面统一模式：优先用后端 message，兜底走 i18n）
      message.error(error?.message || t('loginFailed'));
    }
  };

  return (
    <div className="w-full max-w-[420px]">
      {/* 标题 */}
      <div className="mb-11">
        <h2 className="text-[34px] font-extrabold tracking-[-0.5px] mb-2.5 text-[color:var(--ant-color-text)]">
          {t('welcomeBack')}
        </h2>
        <p className="text-[15px] leading-relaxed text-[color:var(--gowind-secondary-text)]">
          {t('loginDescription')}
        </p>
      </div>

      {/* 登录表单卡片 —— 实底表面色 + 24px 大圆角 + 主色柔影（对齐 vben 认证面板） */}
      <div className="rounded-3xl border border-[color:var(--ant-color-border-secondary)] bg-[color:var(--ant-color-bg-container)] p-8 shadow-[0_12px_40px_-8px_rgba(0,107,230,0.18)]">
        <Form
          name="login"
          onFinish={handleSubmit}
          size="large"
          initialValues={{ remember: true }}
          className="login-form"
        >
          <Form.Item
            name="username"
            className="login-form-item"
            rules={[
              {
                required: true,
                message: t('usernameRequired'),
              },
            ]}
          >
            <Input
              prefix={<UserOutlined />}
              placeholder={t('usernamePlaceholder')}
              autoComplete="username"
            />
          </Form.Item>

          <Form.Item
            name="password"
            className="login-form-item"
            rules={[
              {
                required: true,
                message: t('passwordRequired'),
              },
            ]}
          >
            <Input.Password
              prefix={<LockOutlined />}
              placeholder={t('passwordPlaceholder')}
              autoComplete="current-password"
            />
          </Form.Item>

          <Form.Item className="login-form-item">
            <Button
              type="primary"
              htmlType="submit"
              loading={loginLoading}
              block
              className="login-submit-btn"
            >
              {loginLoading ? t('loggingIn') : t('loginButton')}
            </Button>
          </Form.Item>
        </Form>
      </div>

      {/* 底部提示 */}
      <div className="mt-6 text-center text-[13px]">
        <span className="text-[color:var(--ant-color-text-secondary)]">
          {t('loginHint')}
        </span>
      </div>
    </div>
  );
};

export default Login;
