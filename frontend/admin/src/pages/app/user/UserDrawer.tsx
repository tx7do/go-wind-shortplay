import { useRef, useEffect, useState } from 'react';
import type { ProFormInstance } from '@ant-design/pro-components';
import { DrawerForm, ProFormText, ProFormTextArea } from '@ant-design/pro-components';
import { App } from 'antd';
import { useTranslation } from 'react-i18next';

import { useCreateUser, useUpdateUser } from '@/api/hooks';
import type { AppUser } from '@/api/types';

interface UserDrawerProps {
  open: boolean;
  mode: 'create' | 'edit';
  data: AppUser | null;
  onClose: () => void;
  onSuccess: () => void;
}

/**
 * 用户新建/编辑抽屉（模式对齐底座 opm/user 的 UserDrawer——DrawerForm + ProFormX，
 * 去角色/部门/租户）：
 * - create：username + 初始密码必填；
 * - edit：昵称/头像/简介可改，密码留空不修改（管理端重置）。
 */
const UserDrawer = ({ open, mode, data, onClose, onSuccess }: UserDrawerProps) => {
  const { t } = useTranslation('user');
  const formRef = useRef<ProFormInstance>(null);
  const { message } = App.useApp();
  const [confirmLoading, setConfirmLoading] = useState(false);

  // 打开时回填编辑数据（DrawerForm 挂载晚于本 effect，按底座惯例 setTimeout 延迟回填）
  useEffect(() => {
    if (open) {
      if (mode === 'edit' && data) {
        setTimeout(() => {
          formRef.current?.setFieldsValue({
            username: data.username,
            nickname: data.nickname,
            avatarUrl: data.avatarUrl,
            bio: data.bio,
          });
        }, 0);
      } else {
        formRef.current?.resetFields();
      }
    }
  }, [open, mode, data]);

  const createMutation = useCreateUser({
    onSuccess: () => {
      message.success(t('createSuccess'));
      onSuccess();
      onClose();
    },
    onError: (error: Error) => {
      message.error(error.message || t('createFailed'));
    },
  });

  const updateMutation = useUpdateUser({
    onSuccess: () => {
      message.success(t('updateSuccess'));
      onSuccess();
      onClose();
    },
    onError: (error: Error) => {
      message.error(error.message || t('updateFailed'));
    },
  });

  // 提交表单
  const handleSubmit = async (values: Record<string, any>) => {
    try {
      setConfirmLoading(true);
      if (mode === 'edit' && data?.id != null) {
        // 更新：密码留空 = 不修改
        const updateValues = { ...values };
        if (!updateValues.password) {
          delete updateValues.password;
        }
        delete updateValues.username; // 用户名不可改
        await updateMutation.mutateAsync({ id: data.id, ...updateValues });
      } else {
        await createMutation.mutateAsync({
          username: String(values.username ?? '').trim(),
          password: String(values.password ?? ''),
          nickname: String(values.nickname ?? '').trim(),
          avatarUrl: values.avatarUrl || undefined,
          bio: values.bio || undefined,
        });
      }
      return true;
    } catch {
      return false;
    } finally {
      setConfirmLoading(false);
    }
  };

  return (
    <DrawerForm
      formRef={formRef}
      title={mode === 'create' ? t('create') : t('edit')}
      open={open}
      onOpenChange={(visible) => {
        if (!visible) {
          formRef.current?.resetFields();
          onClose();
        }
      }}
      onFinish={handleSubmit}
      submitter={{
        searchConfig: {
          submitText: t('common:button.submit'),
          resetText: t('common:button.cancel'),
        },
        submitButtonProps: { loading: confirmLoading },
      }}
      width={480}
      drawerProps={{ destroyOnHidden: true }}
    >
      <ProFormText
        name="username"
        label={t('username')}
        rules={[{ required: true, message: t('usernameRequired') }]}
        disabled={mode === 'edit'}
        fieldProps={{ autoComplete: 'off' }}
      />
      <ProFormText
        name="nickname"
        label={t('nickname')}
        rules={[{ required: true, whitespace: true, message: t('nicknameRequired') }]}
        fieldProps={{ autoComplete: 'off' }}
      />
      <ProFormText
        name="avatarUrl"
        label={t('avatarUrl')}
        placeholder="https://..."
        fieldProps={{ autoComplete: 'off' }}
      />
      <ProFormTextArea name="bio" label={t('bio')} fieldProps={{ maxLength: 200, showCount: true }} />
      <ProFormText.Password
        name="password"
        label={mode === 'create' ? t('resetPassword') : t('newPassword')}
        rules={mode === 'create' ? [{ required: true, message: t('passwordRequired') }] : undefined}
        extra={mode === 'edit' ? t('newPasswordPlaceholder') : undefined}
        fieldProps={{ autoComplete: 'new-password' }}
      />
    </DrawerForm>
  );
};

export default UserDrawer;
