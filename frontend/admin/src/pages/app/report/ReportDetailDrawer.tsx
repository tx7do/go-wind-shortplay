import { Descriptions, Drawer, Space, Tag, Typography } from 'antd';
import { useTranslation } from 'react-i18next';
import dayjs from 'dayjs';

import type { Report } from '@/api/types';
import { getReportStatusConfig, getTargetTypeLabelKey } from './constants';

interface ReportDetailDrawerProps {
  open: boolean;
  data: Report | null;
  onClose: () => void;
  /** 底部操作区（处理按钮由列表页注入） */
  extra?: React.ReactNode;
}

const formatTime = (value?: string) =>
  value && dayjs(value).isValid() ? dayjs(value).format('YYYY-MM-DD HH:mm:ss') : '-';

/**
 * 举报工单详情抽屉：举报人 / 目标类型 / 原因 / 说明 / 处理信息。
 */
const ReportDetailDrawer = ({ open, data, onClose, extra }: ReportDetailDrawerProps) => {
  const { t } = useTranslation('report');

  const statusConfig = data ? getReportStatusConfig(data.status) : null;

  return (
    <Drawer
      title={t('detail')}
      size={520}
      open={open}
      onClose={onClose}
      destroyOnHidden
      footer={extra ? <Space style={{ display: 'flex', justifyContent: 'flex-end' }}>{extra}</Space> : null}
    >
      {data && (
        <Descriptions
          column={2}
          size="small"
          bordered
          items={[
            { key: 'id', label: t('id'), children: data.id ?? '-' },
            {
              key: 'status',
              label: t('status'),
              children: statusConfig ? (
                <Tag color={statusConfig.color}>{t(statusConfig.labelKey)}</Tag>
              ) : (
                '-'
              ),
            },
            {
              key: 'reporter',
              label: t('reporter'),
              children: (
                <span>
                  {data.reporter?.avatarUrl && (
                    <img
                      src={data.reporter.avatarUrl}
                      alt=""
                      style={{ width: 20, height: 20, borderRadius: '50%', marginRight: 6, verticalAlign: 'middle' }}
                    />
                  )}
                  {data.reporter?.nickname || data.reporterId || '-'}
                </span>
              ),
            },
            {
              key: 'targetType',
              label: t('targetType'),
              children: (
                <Tag color="blue">{t(getTargetTypeLabelKey(data.targetType))}</Tag>
              ),
            },
            { key: 'targetId', label: t('targetId'), children: data.targetId ?? '-' },
            { key: 'createdAt', label: t('createdAt'), children: formatTime(data.createdAt) },
            {
              key: 'reason',
              label: t('reason'),
              span: 2,
              children: data.reason ? <Tag color="error">{data.reason}</Tag> : '-',
            },
            {
              key: 'description',
              label: t('description'),
              span: 2,
              children: (
                <Typography.Paragraph style={{ marginBottom: 0 }} ellipsis={{ rows: 4, expandable: true }}>
                  {data.description || '-'}
                </Typography.Paragraph>
              ),
            },
            {
              key: 'handledBy',
              label: t('handledBy'),
              children: data.handledBy ?? t('unhandled'),
            },
            {
              key: 'handledAt',
              label: t('handledAt'),
              children: formatTime(data.handledAt),
            },
            {
              key: 'handleNote',
              label: t('handleNote'),
              span: 2,
              children: data.handleNote || '-',
            },
          ]}
        />
      )}
    </Drawer>
  );
};

export default ReportDetailDrawer;
