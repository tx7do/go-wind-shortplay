/**
 * 通用图片上传组件（antd Upload + customRequest）
 *
 * - 契约：POST /admin/v1/uploads/image，body = 图片原始字节，Content-Type = 图片
 *   MIME，≤2MB，成功返回 {url}（docs/API.md「Admin 端增补」）；
 * - 上传中展示进度百分比；成功后经 onChange/onUploaded 回传 URL；
 * - value 受控（兼容 antd Form 的 value/onChange 协议），传入 URL 时显示可预览缩略图；
 * - 手填 URL 能力由调用方组合（本组件只负责「上传 → 回填 URL」这一段）。
 */
import { useState } from 'react';
import { Button, Image, Space, Upload, App } from 'antd';
import type { UploadProps } from 'antd';
import { DeleteOutlined, PictureOutlined, UploadOutlined } from '@ant-design/icons';

import { adminUploadImage } from '@/api/client';

/** customRequest 入参类型（从 antd UploadProps 推导，避免直引 @rc-component/upload） */
type CustomRequestOptions = Parameters<NonNullable<UploadProps['customRequest']>>[0];

/** 默认接受的图片类型：jpg / png / webp / gif */
const DEFAULT_ACCEPT = '.jpg,.jpeg,.png,.webp,.gif,image/jpeg,image/png,image/webp,image/gif';

/** 默认大小上限（后端契约 2MB） */
const DEFAULT_MAX_SIZE_MB = 2;

export interface UploadImageProps {
  /** 当前图片 URL（受控预览；配合 antd Form 时由 Form.Item 注入） */
  value?: string;
  /** URL 变化回调：上传成功回传新 URL；点击缩略图移除按钮回传 undefined */
  onChange?: (url?: string) => void;
  /** 上传成功回调（不受控用法等价于 onChange） */
  onUploaded?: (url: string) => void;
  /** 按钮文案，默认「上传图片」 */
  text?: string;
  /** 接受的文件类型，默认 jpg/jpeg/png/webp/gif */
  accept?: string;
  /** 大小上限（MB），默认 2 */
  maxSizeMb?: number;
  /** 是否展示已上传缩略图（可点击预览大图），默认 true */
  showPreview?: boolean;
  disabled?: boolean;
}

const UploadImage: React.FC<UploadImageProps> = ({
  value,
  onChange,
  onUploaded,
  text,
  accept = DEFAULT_ACCEPT,
  maxSizeMb = DEFAULT_MAX_SIZE_MB,
  showPreview = true,
  disabled = false,
}) => {
  const { message } = App.useApp();
  const [uploading, setUploading] = useState(false);
  const [percent, setPercent] = useState(0);

  const buttonText = text ?? '上传图片';

  // 上传前校验类型与大小（LIST_IGNORE 连 fileList 都不进，避免默认 POST）
  const beforeUpload = (file: File) => {
    const allowed = accept
      .split(',')
      .map((item) => item.trim().toLowerCase())
      .filter((item) => item.startsWith('.'));
    const ext = `.${(file.name.split('.').pop() ?? '').toLowerCase()}`;
    if (allowed.length > 0 && !allowed.includes(ext)) {
      message.error(`仅支持 ${allowed.join(' / ')} 格式的图片`);
      return Upload.LIST_IGNORE;
    }
    if (file.size > maxSizeMb * 1024 * 1024) {
      message.error(`图片大小不能超过 ${maxSizeMb}MB`);
      return Upload.LIST_IGNORE;
    }
    return true;
  };

  // customRequest：走 api 层 XHR 上传（带进度），不使用 antd 默认 action POST
  const customRequest = (options: CustomRequestOptions) => {
    const file = options.file as File;
    setUploading(true);
    setPercent(0);
    adminUploadImage(file, setPercent)
      .then(({ url }) => {
        onChange?.(url);
        onUploaded?.(url);
        message.success('上传成功');
      })
      .catch((error: Error) => {
        // 后端错误体 {code,reason,message}：优先展示后端 message（如 FILE_TOO_LARGE）
        message.error(error.message || '上传失败');
      })
      .finally(() => {
        setUploading(false);
      });
  };

  return (
    <Space wrap size={8} align="center">
      <Upload
        accept={accept}
        showUploadList={false}
        beforeUpload={beforeUpload}
        customRequest={customRequest}
        disabled={disabled || uploading}
      >
        <Button icon={<UploadOutlined />} loading={uploading} disabled={disabled}>
          {uploading ? `上传中 ${percent}%` : buttonText}
        </Button>
      </Upload>
      {showPreview && value ? (
        <Space size={4} align="center">
          <Image
            src={value}
            alt="preview"
            width={44}
            height={44}
            style={{ objectFit: 'cover', borderRadius: 6, border: '1px solid var(--ant-color-border-secondary)' }}
          />
          <Button
            type="text"
            size="small"
            icon={<DeleteOutlined />}
            title="移除图片"
            disabled={disabled}
            onClick={() => onChange?.(undefined)}
          />
        </Space>
      ) : (
        showPreview && (
          <PictureOutlined
            style={{ fontSize: 28, color: 'var(--ant-color-text-quaternary)' }}
            aria-hidden
          />
        )
      )}
    </Space>
  );
};

export default UploadImage;
