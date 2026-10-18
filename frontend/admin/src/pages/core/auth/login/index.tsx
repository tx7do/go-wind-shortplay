import React, { useCallback, useEffect, useState } from 'react';
import { useTranslation } from 'react-i18next';
import { Form, Input, Button, App } from 'antd';
import { UserOutlined, LockOutlined, SafetyOutlined } from '@ant-design/icons';
import { useAuthStore } from '@/stores';
import { useNavigate, useSearchParams } from 'react-router-dom';
import { fetchGenerateCaptcha } from '@/api/hooks/auth';

/**
 * 验证码控件（从 cms 登录页拷回适配）：输入框与图片盒同排，组成单一受控组件
 * 挂进 Form.Item。value/onChange 由 Form.Item 注入后透传给 Input；校验错误渲染
 * 在整行下方，验证码图不会被错误行挤偏。
 */
const CaptchaField: React.FC<{
  value?: string;
  onChange?: (...event: unknown[]) => void;
  placeholder?: string;
  imageEl?: React.ReactNode;
}> = ({ value, onChange, placeholder, imageEl }) => (
  <div className="flex items-center gap-2">
    <Input
      prefix={<SafetyOutlined />}
      placeholder={placeholder}
      autoComplete="off"
      value={value}
      onChange={onChange}
    />
    {imageEl}
  </div>
);

const Login: React.FC = () => {
  const { t } = useTranslation('auth');
  const { login, loginLoading } = useAuthStore();
  const navigate = useNavigate();
  const [searchParams] = useSearchParams();
  const { message } = App.useApp();

  // 验证码状态（基座链路：GET /captcha → 登录时经 X-Captcha-* 头一次性校验）
  const [captchaId, setCaptchaId] = useState<string>('');
  const [captchaImage, setCaptchaImage] = useState<string>('');
  const [captchaLoading, setCaptchaLoading] = useState(false);

  // 获取验证码（StrictMode effect 双跑防护：丢弃被取消的首次请求结果，
  // 确保登录时携带的 captchaId 始终对应最后一次请求——验证码一次性消费）
  useEffect(() => {
    let cancelled = false;
    const run = async () => {
      setCaptchaLoading(true);
      try {
        const resp = await fetchGenerateCaptcha();
        if (cancelled) return;
        setCaptchaId(resp.captchaId ?? '');
        setCaptchaImage(resp.imageBase64 ?? '');
      } catch {
        // 验证码获取失败不阻断页面，登录时会再次校验
      } finally {
        if (!cancelled) setCaptchaLoading(false);
      }
    };
    run();
    return () => {
      cancelled = true;
    };
  }, []);

  const refreshCaptcha = useCallback(async () => {
    setCaptchaLoading(true);
    try {
      const resp = await fetchGenerateCaptcha();
      setCaptchaId(resp.captchaId ?? '');
      setCaptchaImage(resp.imageBase64 ?? '');
    } catch {
      // 验证码获取失败不阻断页面，登录时会再次校验
    } finally {
      setCaptchaLoading(false);
    }
  }, []);

  const handleSubmit = async (values: { username: string; password: string; captcha?: string }) => {
    // 跳转目标：redirect 参数 → 首页。
    // 校验必须为同源相对路径，防止开放重定向（如 ?redirect=https://evil.com 或 //evil.com）
    const rawRedirect = searchParams.get('redirect') || '/';
    const redirect =
      rawRedirect.startsWith('/') && !rawRedirect.startsWith('//') ? rawRedirect : '/';
    try {
      // onSuccess：store 检测到回调即跳过默认跳转，改由这里经 react-router 跳转。
      // 必须赶在 AppRouter 重建 router（createBrowserRouter 以 window.location
      // 为初始地址）之前完成，避免整页跳转与 SPA 导航赛跑。
      // 密码加密与验证码头由 store 内部完成（基座链路）。
      await login(
        { username: values.username, password: values.password },
        () => navigate(redirect),
        { id: captchaId, value: values.captcha ?? '' },
      );

      message.success(t('loginSuccess'));
    } catch (error) {
      // 登录失败后刷新验证码（后端一次性消费，旧图必然失效）
      refreshCaptcha();
      // 弹出错误提示（与 CRUD 页面统一模式：优先用后端 message，兜底走 i18n）
      const msg = error instanceof Error ? error.message : '';
      message.error(msg || t('loginFailed'));
    }
  };

  /**
   * 验证码图片盒（cms 同款）：与输入框等高（h-11=44px），宽 132px 与后端
   * 240×80（3:1）等比，img object-cover 满高填充无留白。点击刷新验证码。
   */
  const captchaImageEl = (
    <div
      className="flex items-center justify-center overflow-hidden w-[132px] h-11 shrink-0 rounded-lg cursor-pointer border border-solid bg-white light:border-black/10 light:bg-black/[0.03]"
      title={t('captchaRefresh')}
      onClick={() => !captchaLoading && refreshCaptcha()}
    >
      {captchaImage ? (
        <img
          src={captchaImage}
          alt="captcha"
          className="h-full w-full object-cover"
        />
      ) : (
        // 占位文案走实底暗墨而非次要文字档：外层盒子两态都是浅底
        <span className="text-[color:var(--gowind-solid-ink)] text-xs">
          {captchaLoading ? '...' : t('captchaRefresh')}
        </span>
      )}
    </div>
  );

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

          {/* 验证码 —— 输入框与图片盒组成单一受控组件（CaptchaField），
              校验错误渲染在整行下方，图片盒与输入框始终保持等高对齐 */}
          <Form.Item
            name="captcha"
            rules={[
              {
                required: true,
                message: t('captchaRequired'),
              },
            ]}
            className="login-form-item"
          >
            <CaptchaField
              placeholder={t('captchaPlaceholder')}
              imageEl={captchaImageEl}
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
