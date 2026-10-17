/**
 * 登录页：POST /admin/v1/login。
 * 角落注明演示账号 admin / admin（需后端先注册该账号）。
 */
import { useState } from 'react';
import { Button, Card, Form, Input, message } from 'antd';
import { LockOutlined, UserOutlined } from '@ant-design/icons';
import { Navigate, useNavigate } from 'react-router-dom';
import { login } from '../../api/auth';
import { useAuth } from '../../utils/auth';

interface LoginFormValues {
  username: string;
  password: string;
}

export default function LoginPage() {
  const navigate = useNavigate();
  const { token, signIn } = useAuth();
  const [loading, setLoading] = useState(false);

  // 已登录则直接进入后台
  if (token) {
    return <Navigate to="/dashboard" replace />;
  }

  const onFinish = async (values: LoginFormValues) => {
    setLoading(true);
    try {
      const { token: accessToken, user } = await login(values.username.trim(), values.password);
      signIn(accessToken, user);
      message.success('登录成功');
      navigate('/dashboard', { replace: true });
    } catch {
      // 错误提示已由 request 拦截器统一处理
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="login-page">
      <Card
        style={{ width: 400, boxShadow: '0 8px 24px rgba(0, 0, 0, 0.25)' }}
        styles={{ body: { padding: '32px 32px 20px' } }}
      >
        <div style={{ textAlign: 'center', marginBottom: 24 }}>
          <h1 style={{ fontSize: 22, margin: 0 }}>GoWind 短视频社区</h1>
          <p style={{ color: '#999', margin: '8px 0 0' }}>管理后台</p>
        </div>
        <Form<LoginFormValues> onFinish={onFinish} size="large" initialValues={{ username: '', password: '' }}>
          <Form.Item name="username" rules={[{ required: true, message: '请输入用户名' }]}>
            <Input prefix={<UserOutlined />} placeholder="用户名" autoComplete="username" />
          </Form.Item>
          <Form.Item name="password" rules={[{ required: true, message: '请输入密码' }]}>
            <Input.Password prefix={<LockOutlined />} placeholder="密码" autoComplete="current-password" />
          </Form.Item>
          <Form.Item style={{ marginBottom: 12 }}>
            <Button type="primary" htmlType="submit" block loading={loading}>
              登 录
            </Button>
          </Form.Item>
        </Form>
        <p style={{ color: '#999', fontSize: 12, textAlign: 'center', margin: 0 }}>
          演示账号：admin / admin（需后端先注册该账号）
        </p>
      </Card>
    </div>
  );
}
