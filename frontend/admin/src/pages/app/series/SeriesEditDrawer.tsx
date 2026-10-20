import { useEffect, useRef, useState } from 'react';
import type { ProFormInstance } from '@ant-design/pro-components';
import { DrawerForm, ProForm, ProFormText, ProFormTextArea } from '@ant-design/pro-components';
import { App, Input } from 'antd';
import { useTranslation } from 'react-i18next';

import { useUpdateSeries } from '@/api/hooks';
import UploadImage from '@/components/common/UploadImage';
import type { Series } from '@/api/types';

interface SeriesEditDrawerProps {
  open: boolean;
  data: Series | null;
  onClose: () => void;
  onSuccess: () => void;
}

/**
 * 封面字段：手填 URL 输入框 + 上传按钮并排（与视频编辑封面同一交互）。
 */
const CoverUrlField: React.FC<{
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

/**
 * 剧集编辑抽屉：标题 / 简介 / 封面（真传图 POST /uploads/image 回填 URL），
 * 提交 PUT /admin/v1/series/{id}。
 */
const SeriesEditDrawer = ({ open, data, onClose, onSuccess }: SeriesEditDrawerProps) => {
  const { t } = useTranslation('series');
  const formRef = useRef<ProFormInstance>(null);
  const { message } = App.useApp();
  const [confirmLoading, setConfirmLoading] = useState(false);

  const updateMutation = useUpdateSeries({
    onSuccess: () => {
      message.success(t('editSuccess'));
    },
    onError: (error: Error) => {
      message.error(error.message || t('editFailed'));
    },
  });

  // 打开时回填编辑数据（DrawerForm 挂载晚于本 effect，按底座惯例 setTimeout 延迟回填）
  useEffect(() => {
    if (open && data) {
      setTimeout(() => {
        formRef.current?.setFieldsValue({
          title: data.title,
          description: data.description,
          coverUrl: data.coverUrl,
        });
      }, 0);
    }
  }, [open, data]);

  const handleSubmit = async (values: Record<string, unknown>) => {
    if (data?.id === undefined) return false;
    try {
      setConfirmLoading(true);
      await updateMutation.mutateAsync({
        id: data.id,
        title: String(values.title ?? '').trim(),
        description: (values.description as string | undefined) || undefined,
        coverUrl: (values.coverUrl as string | undefined) || undefined,
      });
      onSuccess();
      onClose();
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
      title={t('edit')}
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
        name="title"
        label={t('title')}
        rules={[{ required: true, whitespace: true, message: t('titleRequired') }]}
        fieldProps={{ maxLength: 100, showCount: true, autoComplete: 'off' }}
      />
      <ProFormTextArea
        name="description"
        label={t('description')}
        fieldProps={{ maxLength: 500, showCount: true, autoSize: { minRows: 3, maxRows: 6 } }}
      />
      {/* 封面：URL 手填 + 上传并存（UploadImage 走 POST /uploads/image 原始字节契约） */}
      <ProForm.Item name="coverUrl" label={t('cover')} extra={t('coverUploadTip')}>
        <CoverUrlField uploadText={t('uploadCover')} />
      </ProForm.Item>
    </DrawerForm>
  );
};

export default SeriesEditDrawer;
