/**
 * 系统配置：GET /sysconf 回显表单，PUT /sysconf 保存。
 * - maxUploadSizeMb：单视频大小上限（MB）
 * - maxDurationSeconds：单视频时长上限（秒）
 * - manualReviewEnabled / registerEnabled：开关
 * - allowedVideoTypes：逗号分隔输入框，保存时解析为数组
 */
import { useEffect, useState } from 'react';
import { Button, Card, Form, Input, InputNumber, Spin, Switch, message } from 'antd';
import { getSysConf, updateSysConf } from '../../api/sysconf';
import { formatDateTime } from '../../utils/format';

interface SysConfFormValues {
  maxUploadSizeMb: number;
  maxDurationSeconds: number;
  manualReviewEnabled: boolean;
  registerEnabled: boolean;
  /** 逗号分隔的扩展名，如：mp4, mov, webm */
  allowedVideoTypesText: string;
}

export default function SysConfPage() {
  const [form] = Form.useForm<SysConfFormValues>();
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [updatedAt, setUpdatedAt] = useState<string | undefined>();

  // 加载配置回显
  useEffect(() => {
    let cancelled = false;
    setLoading(true);
    getSysConf()
      .then((conf) => {
        if (cancelled) return;
        form.setFieldsValue({
          maxUploadSizeMb: conf.maxUploadSizeMb ?? 500,
          maxDurationSeconds: conf.maxDurationSeconds ?? 300,
          manualReviewEnabled: !!conf.manualReviewEnabled,
          registerEnabled: conf.registerEnabled ?? true,
          allowedVideoTypesText: (conf.allowedVideoTypes ?? []).join(','),
        });
        setUpdatedAt(conf.updatedAt);
      })
      .catch(() => {
        // 错误已由拦截器统一提示
      })
      .finally(() => {
        if (!cancelled) setLoading(false);
      });
    return () => {
      cancelled = true;
    };
  }, [form]);

  /** 保存：allowedVideoTypesText 按中英文逗号 / 顿号 / 空白拆分为数组 */
  const onFinish = async (values: SysConfFormValues) => {
    setSaving(true);
    try {
      const allowedVideoTypes = values.allowedVideoTypesText
        .split(/[,，、\s]+/)
        .map((s) => s.trim().replace(/^\./, '').toLowerCase())
        .filter(Boolean);
      const conf = await updateSysConf({
        maxUploadSizeMb: values.maxUploadSizeMb,
        maxDurationSeconds: values.maxDurationSeconds,
        manualReviewEnabled: values.manualReviewEnabled,
        registerEnabled: values.registerEnabled,
        allowedVideoTypes,
      });
      message.success('配置已保存');
      setUpdatedAt(conf.updatedAt);
      // 保存后按后端返回回显一遍（含规范化后的扩展名）
      form.setFieldsValue({ allowedVideoTypesText: (conf.allowedVideoTypes ?? []).join(',') });
    } catch {
      // 错误已由拦截器统一提示
    } finally {
      setSaving(false);
    }
  };

  return (
    <Card
      title="系统配置"
      extra={updatedAt ? <span style={{ color: '#999' }}>最近更新：{formatDateTime(updatedAt)}</span> : undefined}
      style={{ maxWidth: 640 }}
    >
      <Spin spinning={loading}>
        <Form<SysConfFormValues> form={form} layout="vertical" onFinish={onFinish}>
          <Form.Item
            name="maxUploadSizeMb"
            label="单视频大小上限（MB）"
            rules={[{ required: true, message: '请输入大小上限' }]}
          >
            <InputNumber min={1} max={10240} style={{ width: 200 }} addonAfter="MB" />
          </Form.Item>
          <Form.Item
            name="maxDurationSeconds"
            label="单视频时长上限（秒）"
            rules={[{ required: true, message: '请输入时长上限' }]}
          >
            <InputNumber min={1} max={86400} style={{ width: 200 }} addonAfter="秒" />
          </Form.Item>
          <Form.Item
            name="manualReviewEnabled"
            label="人工审核"
            valuePropName="checked"
            extra="开启后发布需人工审核；关闭则发布直接可见"
          >
            <Switch checkedChildren="开" unCheckedChildren="关" />
          </Form.Item>
          <Form.Item
            name="registerEnabled"
            label="开放注册"
            valuePropName="checked"
            extra="关闭后 App 端将无法注册新用户"
          >
            <Switch checkedChildren="开" unCheckedChildren="关" />
          </Form.Item>
          <Form.Item
            name="allowedVideoTypesText"
            label="允许的视频类型"
            extra="多个扩展名用英文逗号分隔，如：mp4, mov, webm"
            rules={[{ required: true, message: '请输入允许的视频类型' }]}
          >
            <Input placeholder="mp4, mov, webm" />
          </Form.Item>
          <Form.Item>
            <Button type="primary" htmlType="submit" loading={saving}>
              保存配置
            </Button>
          </Form.Item>
        </Form>
      </Spin>
    </Card>
  );
}
