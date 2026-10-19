import { useState } from 'react';
import { Form, Input, Button, App } from 'antd';
import { useTranslation } from 'react-i18next';

import { useChangePassword } from '@/api/hooks/profile';
import { useAuthStore } from '@/stores';

/** 从错误对象提取后端 reason（{code,reason,message} 错误体） */
function extractReason(error: unknown): string | undefined {
  if (!error || typeof error !== 'object') return undefined;
  const source = error as { response?: { data?: { reason?: string } }; reason?: string };
  return source?.response?.data?.reason ?? source?.reason;
}

const EditPassword = () => {
  const { t } = useTranslation('profile');
  const { message } = App.useApp();
  const [form] = Form.useForm();
  const [changingPwd, setChangingPwd] = useState(false);

  // 改密成功后强制重新登录（对齐底座行为，避免旧会话悬置）：
  // 后端吊销本人会话令牌，这里同步 forceLogout，由路由守卫重定向到登录页。
  const changePwdMutation = useChangePassword({
    onSuccess: () => {
      message.success(t('changePasswordSuccess'));
      form.resetFields();
      useAuthStore.getState().forceLogout();
    },
    onError: (error: Error) => {
      // 旧密码错误：基座返回 400 BAD_REQUEST（message: invalid old password）
      const reason = extractReason(error);
      const msgText = error.message || '';
      if (reason === 'WRONG_PASSWORD' || msgText.includes('invalid old password')) {
        message.error(t('wrongOldPassword'));
      } else {
        message.error(error.message || t('changePasswordFailed'));
      }
    },
  });

  const handleChangePassword = async () => {
    try {
      const values = await form.validateFields();
      if (values.newPassword !== values.confirmPassword) {
        message.error(t('passwordMismatch'));
        return;
      }
      setChangingPwd(true);
      await changePwdMutation.mutateAsync({
        oldPassword: values.oldPassword,
        newPassword: values.newPassword,
      });
    } catch {
      // 表单校验失败，Antd 已就地标红字段
    } finally {
      setChangingPwd(false);
    }
  };

  return (
    <div style={{ maxWidth: 460 }}>
      <Form form={form} layout="vertical">
        <Form.Item
          name="oldPassword"
          label={t('oldPassword')}
          rules={[{ required: true, message: t('requiredOldPassword') }]}
        >
          <Input.Password placeholder={t('oldPasswordPlaceholder')} autoComplete="current-password" />
        </Form.Item>
        <Form.Item
          name="newPassword"
          label={t('newPassword')}
          rules={[
            { required: true, message: t('requiredNewPassword') },
            { min: 6, message: t('passwordMinLength') },
          ]}
        >
          <Input.Password placeholder={t('newPasswordPlaceholder')} autoComplete="new-password" />
        </Form.Item>
        <Form.Item
          name="confirmPassword"
          label={t('confirmPassword')}
          dependencies={['newPassword']}
          rules={[{ required: true, message: t('requiredConfirmPassword') }]}
        >
          <Input.Password placeholder={t('confirmPasswordPlaceholder')} autoComplete="new-password" />
        </Form.Item>
        <Form.Item>
          <Button type="primary" loading={changingPwd} onClick={handleChangePassword}>
            {t('changePassword')}
          </Button>
        </Form.Item>
      </Form>
    </div>
  );
};

export default EditPassword;
