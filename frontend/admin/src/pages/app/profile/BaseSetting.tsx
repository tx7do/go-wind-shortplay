import { useEffect, useState } from 'react';
import { Form, Input, Select, Button, Avatar, Row, Col, Descriptions, Tag, App, Spin } from 'antd';
import { useTranslation } from 'react-i18next';

import { useGetProfile, useUpdateProfile } from '@/api/hooks/profile';
import UploadImage from '@/components/common/UploadImage';
import { getCharColor, getRandomColor } from '@/utils/color';
import { formatDateTime } from '@/utils/date';
import { useAuthStore, useUserStore } from '@/stores';

/**
 * 基本设置（基座 BaseSetting 两栏形态：左表单 + 右头像/账号归属只读信息）。
 * 与基座差异：头像走本后端 /uploads/image → URL（UploadImage），无 base64
 * 头像直传与删除接口；可编辑字段限基座 /me 白名单（昵称/姓名/邮箱/手机号/性别）。
 */
const BaseSetting = () => {
  const { t } = useTranslation(['profile', 'common']);
  const { message } = App.useApp();
  const [form] = Form.useForm();
  const [saving, setSaving] = useState(false);

  const { data: user, isLoading } = useGetProfile();
  const [avatarUrl, setAvatarUrl] = useState<string | undefined>(undefined);

  // 资料拉取后回填表单与头像
  useEffect(() => {
    if (!user) return;
    form.setFieldsValue({
      nickname: user.nickname || '',
      realname: user.realname || '',
      email: user.email || '',
      mobile: user.mobile || '',
      gender: user.gender || undefined,
    });
    setAvatarUrl(user.avatar || undefined);
  }, [user, form]);

  // 资料更新：同步 auth/user 两个 store，顶栏头像昵称即时生效
  const updateMutation = useUpdateProfile({
    onSuccess: (_data, variables) => {
      message.success(t('profile:saveSuccess'));
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
      message.error(error.message || t('profile:saveFailed'));
    },
  });

  const handleSave = async () => {
    try {
      const values = await form.validateFields();
      setSaving(true);
      await updateMutation.mutateAsync({
        nickname: String(values.nickname ?? '').trim(),
        realname: values.realname || undefined,
        email: values.email || undefined,
        mobile: values.mobile || undefined,
        gender: values.gender || undefined,
        avatar: avatarUrl || undefined,
      });
    } catch {
      // 表单校验失败，Antd 已就地标红字段
    } finally {
      setSaving(false);
    }
  };

  if (isLoading) {
    return <Spin style={{ display: 'block', margin: '48px auto' }} />;
  }

  const firstChar = (user?.username || '?').slice(0, 1).toUpperCase();
  const avatarColor = getCharColor(firstChar);

  return (
    <div style={{ overflowX: 'hidden' }}>
      <Row gutter={24}>
        <Col span={14}>
          <Form form={form} layout="vertical">
            <Form.Item name="nickname" label={t('profile:field.nickname')}>
              <Input placeholder={t('common:placeholder.input')} />
            </Form.Item>
            <Form.Item name="realname" label={t('profile:field.realname')}>
              <Input placeholder={t('common:placeholder.input')} maxLength={50} />
            </Form.Item>
            <Form.Item name="email" label={t('profile:field.email')}>
              <Input placeholder={t('common:placeholder.input')} />
            </Form.Item>
            <Form.Item name="mobile" label={t('profile:field.mobile')}>
              <Input placeholder={t('common:placeholder.input')} />
            </Form.Item>
            <Form.Item name="gender" label={t('profile:field.gender')}>
              <Select
                placeholder={t('common:placeholder.select')}
                allowClear
                options={[
                  { value: 'MALE', label: t('profile:genderMap.MALE') },
                  { value: 'FEMALE', label: t('profile:genderMap.FEMALE') },
                  { value: 'SECRET', label: t('profile:genderMap.SECRET') },
                ]}
              />
            </Form.Item>
            <Form.Item>
              <Button type="primary" loading={saving} onClick={handleSave}>
                {t('profile:save')}
              </Button>
            </Form.Item>
          </Form>
        </Col>

        <Col span={10}>
          <div style={{ paddingTop: 20 }}>
            <div style={{ fontSize: 14, fontWeight: 500, marginBottom: 16 }}>{t('profile:field.avatar')}</div>
            <Avatar
              src={avatarUrl || undefined}
              size={96}
              style={!avatarUrl ? { backgroundColor: avatarColor, fontSize: 40, fontWeight: 700 } : {}}
            >
              {firstChar}
            </Avatar>
            <div style={{ display: 'flex', gap: 8, marginTop: 12 }}>
              <UploadImage
                value={avatarUrl}
                onChange={(url) => setAvatarUrl(url)}
                showPreview={false}
                text={t('profile:button.uploadAvatar')}
              />
            </div>
          </div>

          {/* 账号归属信息（只读） */}
          <Descriptions column={1} size="small" style={{ marginTop: 24 }}>
            <Descriptions.Item label={t('profile:info.username')}>{user?.username || '-'}</Descriptions.Item>
            <Descriptions.Item label={t('profile:info.roleNames')}>
              {user?.roleNames?.length ? (
                user.roleNames.map((role, idx) => (
                  <Tag key={role || idx} color={getRandomColor(role)} style={{ marginRight: 4 }}>
                    {role}
                  </Tag>
                ))
              ) : (
                '-'
              )}
            </Descriptions.Item>
            <Descriptions.Item label={t('profile:info.orgUnitNames')}>
              {user?.orgUnitNames?.length ? user.orgUnitNames.join('、') : '-'}
            </Descriptions.Item>
            <Descriptions.Item label={t('profile:info.positionNames')}>
              {user?.positionNames?.length ? user.positionNames.join('、') : '-'}
            </Descriptions.Item>
            <Descriptions.Item label={t('profile:info.createdAt')}>
              {formatDateTime(user?.createdAt) || '-'}
            </Descriptions.Item>
          </Descriptions>
        </Col>
      </Row>
    </div>
  );
};

export default BaseSetting;
