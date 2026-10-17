import { useEffect } from 'react';
import { Form, Input, Modal } from 'antd';
import { useTranslation } from 'react-i18next';

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
      <Form form={form} layout="vertical" style={{ marginTop: 12 }}>
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
