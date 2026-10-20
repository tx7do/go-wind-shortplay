import { useEffect } from 'react';
import { Form, Input, Modal, Space, Tag } from 'antd';
import { useTranslation } from 'react-i18next';

/** 驳回理由快捷模板（i18n 键，video ns tpl1~tpl5） */
const REASON_TEMPLATE_KEYS = ['tpl1', 'tpl2', 'tpl3', 'tpl4', 'tpl5'] as const;

interface ReasonModalProps {
  open: boolean;
  title: string;
  placeholder?: string;
  /** 提交中 */
  confirmLoading?: boolean;
  onOk: (reason: string) => void;
  onCancel: () => void;
}

/**
 * 必填原因弹窗：驳回 / 下架共用（后端约定 reason 为必填）。
 */
const ReasonModal = ({
  open,
  title,
  placeholder,
  confirmLoading,
  onOk,
  onCancel,
}: ReasonModalProps) => {
  const { t } = useTranslation('video');
  const [form] = Form.useForm<{ reason: string }>();

  // 每次打开重置输入
  useEffect(() => {
    if (open) {
      form.resetFields();
    }
  }, [open, form]);

  return (
    <Modal
      title={title}
      open={open}
      confirmLoading={confirmLoading}
      okText={t('common:button.ok')}
      cancelText={t('common:button.cancel')}
      onOk={async () => {
        const values = await form.validateFields();
        onOk(values.reason.trim());
      }}
      onCancel={onCancel}
      destroyOnHidden
    >
      {/* 快捷理由模板：点击填入（可再编辑） */}
      <Space wrap size={4} style={{ marginBottom: 8, marginTop: 12 }}>
        {REASON_TEMPLATE_KEYS.map((key) => (
          <Tag.CheckableTag
            key={key}
            checked={false}
            onChange={() => form.setFieldsValue({ reason: t(key) })}
            style={{
              border: '1px solid var(--ant-color-border)',
              borderRadius: 4,
              padding: '1px 8px',
              cursor: 'pointer',
            }}
          >
            {t(key)}
          </Tag.CheckableTag>
        ))}
      </Space>
      <Form form={form} layout="vertical" style={{ marginTop: 0 }}>
        <Form.Item
          name="reason"
          rules={[
            { required: true, whitespace: true, message: t('reasonRequired') },
          ]}
        >
          <Input.TextArea
            rows={4}
            placeholder={placeholder ?? t('rejectReasonPlaceholder')}
            maxLength={200}
            showCount
          />
        </Form.Item>
      </Form>
    </Modal>
  );
};

export default ReasonModal;
