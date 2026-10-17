/**
 * 系统配置页：GET/PUT /sysconf 回显 + 保存表单。
 * allowedVideoTypes 后端为 string[]，界面用逗号分隔输入。
 * 表单形态对齐底座 DrawerForm/ProFormX 用法（ProForm + formRef）。
 */
import { useEffect, useRef } from 'react';
import type { ProFormInstance } from '@ant-design/pro-components';
import {
  ProCard,
  ProForm,
  ProFormText,
  ProFormSwitch,
  ProFormTextArea,
} from '@ant-design/pro-components';
import { App, Spin } from 'antd';
import { useTranslation } from 'react-i18next';
import dayjs from 'dayjs';

import ContentContainer from '@/layouts/components/PageContainer/ContentContainer';
import { useGetSysConf, useUpdateSysConf } from '@/api/hooks';

const SysConfPage = () => {
  const { t } = useTranslation('sysconf');
  const { message } = App.useApp();
  const { data, isLoading, refetch } = useGetSysConf();
  const formRef = useRef<ProFormInstance>(null);

  // 回显：接口返回后填充表单
  useEffect(() => {
    if (data) {
      formRef.current?.setFieldsValue({
        maxUploadSizeMb: String(data.maxUploadSizeMb ?? ''),
        maxDurationSeconds: String(data.maxDurationSeconds ?? ''),
        manualReviewEnabled: !!data.manualReviewEnabled,
        registerEnabled: !!data.registerEnabled,
        allowedVideoTypesText: (data.allowedVideoTypes ?? []).join(', '),
      });
    }
  }, [data]);

  const updateMutation = useUpdateSysConf({
    onSuccess: () => {
      message.success(t('saveSuccess'));
      refetch();
    },
    onError: (error: Error) => {
      message.error(error.message || t('saveFailed'));
    },
  });

  const handleSubmit = async (values: Record<string, any>) => {
    // 逗号分隔输入 → string[]。后端用文件名扩展名（".mp4"）与配置做 EqualFold
    // 等值比较，因此统一补齐前导点（"."），而非剥除。
    const types = String(values.allowedVideoTypesText ?? '')
      .split(/[,，\s]+/)
      .map((s) => s.trim())
      .filter(Boolean)
      .map((s) => (s.startsWith('.') ? s : `.${s}`));
    try {
      await updateMutation.mutateAsync({
        maxUploadSizeMb: Number(values.maxUploadSizeMb),
        maxDurationSeconds: Number(values.maxDurationSeconds),
        manualReviewEnabled: !!values.manualReviewEnabled,
        registerEnabled: !!values.registerEnabled,
        allowedVideoTypes: types,
      });
      return true;
    } catch {
      return false;
    }
  };

  if (isLoading) {
    return (
      <ContentContainer heightMode="auto" scrollable padding="16px">
        <Spin style={{ display: 'block', margin: '80px auto' }} />
      </ContentContainer>
    );
  }

  return (
    <ContentContainer heightMode="auto" scrollable padding="16px">
      <ProCard
        title={t('title')}
        subTitle={t('subtitle')}
        headerBordered
        bordered
        style={{ maxWidth: 720, margin: '0 auto' }}
      >
        <ProForm
          formRef={formRef}
          onFinish={handleSubmit}
          submitter={{
            searchConfig: { submitText: t('save'), resetText: t('common:button.cancel') },
            submitButtonProps: { loading: updateMutation.isPending },
            resetButtonProps: { style: { display: 'none' } },
          }}
        >
          <ProFormText
            name="maxUploadSizeMb"
            label={t('maxUploadSizeMb')}
            rules={[
              { required: true, message: t('maxUploadSizeMbRequired') },
              { pattern: /^\d+$/, message: t('maxUploadSizeMbRequired') },
            ]}
            fieldProps={{ addonAfter: 'MB' }}
          />
          <ProFormText
            name="maxDurationSeconds"
            label={t('maxDurationSeconds')}
            rules={[
              { required: true, message: t('maxDurationSecondsRequired') },
              { pattern: /^\d+$/, message: t('maxDurationSecondsRequired') },
            ]}
            fieldProps={{ addonAfter: 's' }}
          />
          <ProFormTextArea
            name="allowedVideoTypesText"
            label={t('allowedVideoTypes')}
            extra={t('allowedVideoTypesHint')}
            rules={[{ required: true, message: t('allowedVideoTypesRequired') }]}
            fieldProps={{ rows: 2, placeholder: 'mp4, mov, webm' }}
          />
          <ProFormSwitch
            name="manualReviewEnabled"
            label={t('manualReviewEnabled')}
            extra={t('manualReviewEnabledHint')}
          />
          <ProFormSwitch
            name="registerEnabled"
            label={t('registerEnabled')}
            extra={t('registerEnabledHint')}
          />
        </ProForm>

        {data?.updatedAt && (
          <div style={{ marginTop: 8, color: 'var(--ant-color-text-tertiary)', fontSize: 12 }}>
            {t('updatedAt')}: {dayjs(data.updatedAt).format('YYYY-MM-DD HH:mm:ss')}
          </div>
        )}
      </ProCard>
    </ContentContainer>
  );
};

export default SysConfPage;
