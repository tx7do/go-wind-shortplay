/**
 * 个人中心页（基座契约：GET/PUT /admin/v1/me，形状 i_user）
 * 从 cms opm/user/profile 适配：资料展示（角色/组织/岗位只读）+ 编辑昵称/头像
 * （PUT /me {data,updateMask}）+ 修改密码（POST /me/password）。旧密码错误后端
 * 返回 400 BAD_REQUEST，按 reason 给友好提示。改密成功后强制重新登录。
 */
import { useEffect, useState } from 'react';
import {
  App,
  Avatar,
  Button,
  Card,
  Descriptions,
  Form,
  Input,
  Spin,
  Tabs,
  Tag,
} from 'antd';
import { useTranslation } from 'react-i18next';
import dayjs from 'dayjs';

import {
  useChangePassword,
  useGetProfile,
  useUpdateProfile,
} from '@/api/hooks/profile';
import UploadImage from '@/components/common/UploadImage';
import { getCharColor } from '@/utils/color';
import { useAuthStore, useUserStore } from '@/stores';

/** 从错误对象提取后端 reason（{code,reason,message} 错误体） */
function extractReason(error: unknown): string | undefined {
  if (!error || typeof error !== 'object') return undefined;
  const source = error as { response?: { data?: { reason?: string } }; reason?: string };
  return source?.response?.data?.reason ?? source?.reason;
}

/**
 * 头像字段：手填 URL 输入框 + 上传按钮并排（上传成功经 value/onChange 协议回填
 * 输入框，手填能力保留）；缩略图随 value 实时预览。
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
      style={{ flex: 1, minWidth: 200 }}
    />
    <UploadImage value={value} onChange={onChange} text={uploadText} />
  </div>
);

const UserProfile = () => {
  const { t } = useTranslation('profile');
  const { message } = App.useApp();

  const { data: user, isLoading } = useGetProfile();

  // 资料编辑表单
  const [form] = Form.useForm();
  const [saving, setSaving] = useState(false);

  // 修改密码表单
  const [pwdForm] = Form.useForm();
  const [changingPwd, setChangingPwd] = useState(false);

  // 打开后按服务端资料回填
  useEffect(() => {
    if (user) {
      form.setFieldsValue({
        nickname: user.nickname || '',
        avatarUrl: user.avatar || '',
        realname: user.realname || '',
      });
    }
  }, [user, form]);

  // 资料更新：同步 auth/user 两个 store，顶栏头像昵称即时生效
  const updateMutation = useUpdateProfile({
    onSuccess: (_data, variables) => {
      message.success(t('saveSuccess'));
      const currentUser = useAuthStore.getState().userInfo;
      if (currentUser) {
        const next: UserInfo = {
          ...currentUser,
          nickname: variables.nickname ?? currentUser.nickname,
          realname: variables.nickname ?? currentUser.realname,
          avatar: variables.avatar ?? currentUser.avatar,
          avatarUrl: variables.avatar ?? currentUser.avatarUrl,
        };
        useAuthStore.getState().setUserInfo(next);
        useUserStore.getState().setUserInfo(next);
      }
    },
    onError: (error: Error) => {
      message.error(error.message || t('saveFailed'));
    },
  });

  // 修改密码：成功后强制重新登录（对齐底座行为，避免旧会话悬置）
  const changePwdMutation = useChangePassword({
    onSuccess: () => {
      message.success(t('passwordChangedReLogin'));
      pwdForm.resetFields();
      useAuthStore.getState().forceLogout();
    },
    onError: (error: Error) => {
      // 旧密码错误：基座返回 400 BAD_REQUEST（message: invalid old password）
      const reason = extractReason(error);
      const msgText = (error as any)?.message || '';
      if (reason === 'WRONG_PASSWORD' || msgText.includes('invalid old password')) {
        message.error(t('wrongOldPassword'));
      } else {
        message.error(error.message || t('changePasswordFailed'));
      }
    },
  });

  const handleSave = async () => {
    try {
      const values = await form.validateFields();
      setSaving(true);
      await updateMutation.mutateAsync({
        nickname: String(values.nickname ?? '').trim(),
        avatar: values.avatarUrl || undefined,
        realname: values.realname || undefined,
      });
    } catch {
      // 表单校验失败
    } finally {
      setSaving(false);
    }
  };

  const handleChangePassword = async () => {
    try {
      const values = await pwdForm.validateFields();
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
      // 表单校验失败
    } finally {
      setChangingPwd(false);
    }
  };

  const firstChar = (user?.username || '?').slice(0, 1).toUpperCase();
  const avatarColor = getCharColor(firstChar);

  if (isLoading) {
    return (
      <div className="page-container-content" style={{ height: '100%', padding: 24 }}>
        <Spin size="large" style={{ display: 'block', margin: '120px auto' }} />
      </div>
    );
  }

  return (
    <div
      className="page-container-content"
      style={{ height: '100%', overflow: 'auto', padding: 24 }}
    >
      <Card>
        <Tabs
          defaultActiveKey="basicInfo"
          items={[
            {
              key: 'basicInfo',
              label: t('tab.basicInfo'),
              children: (
                <div style={{ display: 'flex', gap: 32, flexWrap: 'wrap' }}>
                  {/* 头像区域 */}
                  <div
                    style={{
                      display: 'flex',
                      flexDirection: 'column',
                      alignItems: 'center',
                      gap: 12,
                      minWidth: 140,
                    }}
                  >
                    <Avatar
                      src={user?.avatar || undefined}
                      size={120}
                      style={!user?.avatar ? { backgroundColor: avatarColor, fontSize: 48 } : {}}
                    >
                      {firstChar}
                    </Avatar>
                    <span style={{ fontWeight: 500 }}>{user?.username}</span>
                    {user?.roleNames?.length ? (
                      <span>
                        {user.roleNames.map((name, idx) => (
                          <Tag key={name || idx} color="blue">
                            {name}
                          </Tag>
                        ))}
                      </span>
                    ) : null}
                  </div>

                  {/* 编辑表单 */}
                  <div style={{ flex: 1, minWidth: 360, maxWidth: 520 }}>
                    <Form form={form} layout="vertical">
                      <Form.Item label={t('username')}>
                        <span style={{ fontWeight: 500 }}>{user?.username}</span>
                      </Form.Item>
                      <Form.Item
                        name="nickname"
                        label={t('nickname')}
                        rules={[{ required: true, whitespace: true, message: t('nicknameRequired') }]}
                      >
                        <Input placeholder={t('nicknamePlaceholder')} allowClear />
                      </Form.Item>
                      <Form.Item name="avatarUrl" label={t('avatarUrl')}>
                        <AvatarUrlField uploadText={t('uploadAvatar')} />
                      </Form.Item>
                      <Form.Item name="realname" label={t('realname')}>
                        <Input placeholder={t('realnamePlaceholder')} allowClear maxLength={50} />
                      </Form.Item>

                      {/* 只读信息 */}
                      <Descriptions column={1} size="small" style={{ marginBottom: 16 }}>
                        <Descriptions.Item label={t('orgUnits')}>
                          {user?.orgUnitNames?.length ? user.orgUnitNames.join('、') : '-'}
                        </Descriptions.Item>
                        <Descriptions.Item label={t('positions')}>
                          {user?.positionNames?.length ? user.positionNames.join('、') : '-'}
                        </Descriptions.Item>
                        <Descriptions.Item label={t('email')}>
                          {user?.email || '-'}
                        </Descriptions.Item>
                        <Descriptions.Item label={t('mobile')}>
                          {user?.mobile || '-'}
                        </Descriptions.Item>
                        <Descriptions.Item label={t('createdAt')}>
                          {user?.createdAt ? dayjs(user.createdAt).format('YYYY-MM-DD HH:mm:ss') : '-'}
                        </Descriptions.Item>
                      </Descriptions>

                      <Form.Item>
                        <Button type="primary" loading={saving} onClick={handleSave}>
                          {t('save')}
                        </Button>
                      </Form.Item>
                    </Form>
                  </div>
                </div>
              ),
            },
            {
              key: 'security',
              label: t('tab.security'),
              children: (
                <div style={{ maxWidth: 420 }}>
                  <h3 style={{ marginBottom: 24 }}>{t('changePassword')}</h3>
                  <Form form={pwdForm} layout="vertical">
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
                      rules={[
                        { required: true, message: t('requiredConfirmPassword') },
                        ({ getFieldValue }) => ({
                          validator(_, value) {
                            if (!value || getFieldValue('newPassword') === value) {
                              return Promise.resolve();
                            }
                            return Promise.reject(new Error(t('passwordMismatch')));
                          },
                        }),
                      ]}
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
              ),
            },
          ]}
        />
      </Card>
    </div>
  );
};

export default UserProfile;
