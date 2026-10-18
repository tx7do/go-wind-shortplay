import { useEffect, useRef, useState } from 'react';
import type { ProFormInstance } from '@ant-design/pro-components';
import {
  DrawerForm,
  ProForm,
  ProFormSelect,
  ProFormText,
  ProFormTextArea,
} from '@ant-design/pro-components';
import { App, Input } from 'antd';
import { useTranslation } from 'react-i18next';

import {
  useCreateUser,
  useUpdateUser,
} from '@/api/hooks';
import {
  fetchGetUserRoleIds,
  useAssignUserRoles,
} from '@/api/hooks/rbac';
import { fetchListRoles } from '@/api/hooks/role';
import { PaginationQuery } from '@/core';
import { RBAC_PAGE_SIZE_MAX } from '@/api/hooks/rbac';
import UploadImage from '@/components/common/UploadImage';
import type { AppUser } from '@/api/types';

interface UserDrawerProps {
  open: boolean;
  mode: 'create' | 'edit';
  data: AppUser | null;
  onClose: () => void;
  onSuccess: () => void;
}

/**
 * 头像字段：手填 URL 输入框 + 上传按钮并排（上传成功经 value/onChange 协议回填
 * 输入框，手填能力保留），与个人中心头像字段同一交互。
 */
const AvatarUrlField: React.FC<{
  value?: string;
  onChange?: (url?: string) => void;
  uploadText?: string;
}> = ({ value, onChange, uploadText }) => (
  <div style={{ display: 'flex', alignItems: 'center', gap: 8, flexWrap: 'wrap' }}>
    <Input
      value={value}
      onChange={(event) => onChange?.(event.target.value || undefined)}
      placeholder="https://..."
      allowClear
      style={{ flex: 1, minWidth: 180 }}
    />
    <UploadImage value={value} onChange={onChange} text={uploadText} />
  </div>
);

/** 角色选项（GET /roles） */
async function fetchRoleOptions() {
  try {
    const response = await fetchListRoles(
      new PaginationQuery({ paging: { page: 1, pageSize: RBAC_PAGE_SIZE_MAX } }),
    );
    return (response.items || [])
      .filter((role) => role.id != null)
      .map((role) => ({ label: role.name || role.code || String(role.id), value: role.id as number }));
  } catch {
    return [];
  }
}

/**
 * 用户新建/编辑抽屉（模式对齐底座 opm/user 的 UserDrawer——DrawerForm + ProFormX）：
 * - create：username + 初始密码必填；
 * - edit：昵称/头像/简介可改，密码留空不修改（管理端重置）。
 * RBAC：角色分配（GET /users/{id}/role-ids 回填 + PUT /users/{id}/roles 全量覆盖）。
 * 表单字段与 AppUser proto 逐字对齐（id/username/nickname/avatarUrl/bio/status），
 * 不臆造 departmentId 等后端不存在的字段。
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
        // 已分配角色（失败静默为空，不打断表单）
        if (data.id != null) {
          fetchGetUserRoleIds(data.id)
            .then((ids) => {
              formRef.current?.setFieldValue('roleIds', ids);
            })
            .catch(() => {
              formRef.current?.setFieldValue('roleIds', []);
            });
        }
      } else {
        formRef.current?.resetFields();
      }
    }
  }, [open, mode, data]);

  const createMutation = useCreateUser({
    onSuccess: () => {
      message.success(t('createSuccess'));
    },
    onError: (error: Error) => {
      message.error(error.message || t('createFailed'));
    },
  });

  const updateMutation = useUpdateUser({
    onSuccess: () => {
      message.success(t('updateSuccess'));
    },
    onError: (error: Error) => {
      message.error(error.message || t('updateFailed'));
    },
  });

  const assignRolesMutation = useAssignUserRoles({
    onError: (error: Error) => {
      message.error(error.message || t('assignRolesFailed'));
    },
  });

  // 提交表单（values 字段集与表单控件一一对应，这里按 AppUser 契约窄化）
  const handleSubmit = async (values: Record<string, unknown>) => {
    try {
      setConfirmLoading(true);
      const roleIds: number[] = Array.isArray(values.roleIds)
        ? (values.roleIds as number[])
        : [];

      if (mode === 'edit' && data?.id != null) {
        // 更新：密码留空 = 不修改
        const updateValues = { ...values } as Record<string, unknown>;
        if (!updateValues.password) {
          delete updateValues.password;
        }
        delete updateValues.username; // 用户名不可改
        delete updateValues.roleIds;
        await updateMutation.mutateAsync({
          id: data.id,
          nickname: values.nickname as string | undefined,
          avatarUrl: (values.avatarUrl as string | undefined) || undefined,
          bio: (values.bio as string | undefined) || undefined,
          password: updateValues.password as string | undefined,
        });
        // 角色分配：全量覆盖（与资料保存串行，任一失败都已各自提示）
        await assignRolesMutation.mutateAsync({ id: data.id, roleIds });
        onSuccess();
        onClose();
      } else {
        const created = await createMutation.mutateAsync({
          username: String(values.username ?? '').trim(),
          password: String(values.password ?? ''),
          nickname: String(values.nickname ?? '').trim(),
          avatarUrl: (values.avatarUrl as string | undefined) || undefined,
          bio: (values.bio as string | undefined) || undefined,
        });
        // 新建后可立即绑定角色（后端返回创建的用户）
        if (created?.id != null && roleIds.length > 0) {
          await assignRolesMutation.mutateAsync({ id: created.id, roleIds });
        }
        onSuccess();
        onClose();
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
      width={520}
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
      {/* 头像：URL 手填 + 上传并存（UploadImage 走 POST /uploads/image 原始字节契约） */}
      <ProForm.Item
        name="avatarUrl"
        label={t('avatarUrl')}
        extra={t('avatarUploadTip')}
      >
        <AvatarUrlField uploadText={t('uploadAvatar')} />
      </ProForm.Item>
      <ProFormTextArea name="bio" label={t('bio')} fieldProps={{ maxLength: 200, showCount: true }} />

      {/* RBAC：角色分配（多选，全量覆盖提交；后端 SetUserRoles/GetUserRoleIds） */}
      <ProFormSelect
        name="roleIds"
        label={t('roles')}
        placeholder={t('rolesPlaceholder')}
        mode="multiple"
        request={fetchRoleOptions}
        fieldProps={{ allowClear: true }}
      />

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
