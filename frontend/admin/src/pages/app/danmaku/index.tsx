/**
 * 弹幕列表页（管理端全量）
 * 模式对齐评论管理：ProTable 列表 + 隐藏/恢复 + Popconfirm 删除。
 * Admin BFF 为扁平全量列表（videoId/status/content 过滤经 query JSON 下发）。
 */
import { useRef } from 'react';
import type { ProColumns, ActionType } from '@ant-design/pro-components';
import ListTable from '@/components/common/ListTable';
import { Avatar, Popconfirm, App, Tag } from 'antd';
import { DeleteOutlined, EyeInvisibleOutlined, EyeOutlined } from '@ant-design/icons';
import { useQueryClient } from '@tanstack/react-query';
import { useTranslation } from 'react-i18next';
import dayjs from 'dayjs';

import { TABLE } from '@/config/constants';
import { useProTableScrollY } from '@/hooks/useProTableScrollY';
import {
  fetchListDanmaku,
  useDeleteDanmaku,
  useSetDanmakuStatus,
} from '@/api/hooks';
import type { Danmaku } from '@/api/types';

const PAGE_SIZE_MAX = 50; // 后端 pageSize 上限

const DANMAKU_STATUS = {
  VISIBLE: 'DANMAKU_STATUS_VISIBLE',
  HIDDEN: 'DANMAKU_STATUS_HIDDEN',
} as const;

/** 毫秒偏移 → mm:ss 播放位置展示 */
const formatOffset = (ms?: number | string) => {
  const v = Number(ms ?? 0);
  if (!Number.isFinite(v) || v < 0) return '-';
  const total = Math.floor(v / 1000);
  return `${Math.floor(total / 60)}:${String(total % 60).padStart(2, '0')}`;
};

const DanmakuList = () => {
  const { t } = useTranslation('danmaku');
  const actionRef = useRef<ActionType>(null);
  const containerRef = useRef<HTMLDivElement>(null);
  const tableScrollY = useProTableScrollY(containerRef);
  const queryClient = useQueryClient();
  const { message } = App.useApp();

  const invalidate = () => {
    queryClient.invalidateQueries({ queryKey: ['listDanmaku'] });
  };

  const deleteMutation = useDeleteDanmaku({
    onSuccess: () => {
      message.success(t('deleteSuccess'));
      actionRef.current?.reload();
      invalidate();
    },
    onError: (error: Error) => {
      message.error(error.message || t('deleteFailed'));
    },
  });

  const statusMutation = useSetDanmakuStatus({
    onSuccess: () => {
      message.success(t('statusChanged'));
      actionRef.current?.reload();
      invalidate();
    },
    onError: (error: Error) => {
      message.error(error.message || t('statusChangeFailed'));
    },
  });

  const columns: ProColumns<Danmaku>[] = [
    {
      title: 'ID',
      dataIndex: 'id',
      width: 70,
      search: false,
    },
    {
      title: t('user'),
      dataIndex: 'user',
      width: 150,
      search: false,
      render: (_, record) => (
        <span style={{ display: 'inline-flex', alignItems: 'center', gap: 8 }}>
          <Avatar src={record.user?.avatarUrl} size="small">
            {(record.user?.nickname ?? '?').slice(0, 1)}
          </Avatar>
          {record.user?.nickname || record.userId || '-'}
        </span>
      ),
    },
    {
      title: t('content'),
      dataIndex: 'content',
      ellipsis: true,
    },
    {
      title: t('videoId'),
      dataIndex: 'videoId',
      width: 90,
      render: (_, record) => record.videoId || '-',
    },
    {
      title: t('timeOffset'),
      dataIndex: 'timeOffsetMs',
      width: 90,
      search: false,
      render: (_, record) => formatOffset(record.timeOffsetMs),
    },
    {
      title: t('status'),
      dataIndex: 'status',
      width: 100,
      valueType: 'select',
      fieldProps: {
        options: [
          { label: t('statusVisible'), value: DANMAKU_STATUS.VISIBLE },
          { label: t('statusHidden'), value: DANMAKU_STATUS.HIDDEN },
        ],
      },
      render: (_, record) =>
        record.status === DANMAKU_STATUS.HIDDEN ? (
          <Tag color="default">{t('statusHidden')}</Tag>
        ) : (
          <Tag color="processing">{t('statusVisible')}</Tag>
        ),
    },
    {
      title: t('createdAt'),
      dataIndex: 'createdAt',
      search: false,
      width: 160,
      render: (_, record) =>
        record.createdAt ? dayjs(record.createdAt).format('YYYY-MM-DD HH:mm') : '',
    },
    {
      title: t('action'),
      valueType: 'option',
      width: 130,
      fixed: 'right',
      render: (_, record) => {
        if (!record.id) return [];
        const hidden = record.status === DANMAKU_STATUS.HIDDEN;
        return [
          <a
            key="toggle"
            onClick={() =>
              statusMutation.mutate({
                id: record.id!,
                status: hidden ? DANMAKU_STATUS.VISIBLE : DANMAKU_STATUS.HIDDEN,
              })
            }
          >
            {hidden ? <EyeOutlined /> : <EyeInvisibleOutlined />}
            {hidden ? t('restore') : t('hide')}
          </a>,
          <Popconfirm
            key="delete"
            title={t('deleteConfirmTitle')}
            description={t('deleteConfirmDesc', { moduleName: t('moduleName') })}
            onConfirm={() => deleteMutation.mutate(record.id!)}
            okText={t('common:button.ok')}
            cancelText={t('common:button.cancel')}
          >
            <a style={{ color: 'var(--ant-color-error)' }}>
              <DeleteOutlined />
            </a>
          </Popconfirm>,
        ];
      },
    },
  ];

  return (
    <div
      ref={containerRef}
      className="page-container-content"
      style={{ padding: '0 8px', height: '100%' }}
    >
      <ListTable<Danmaku>
        actionRef={actionRef}
        columns={columns}
        headerTitle={t('danmakuList')}
        request={async (params) => {
          const response = await fetchListDanmaku({
            // 后端 pageSize 上限 50，超出会被截断导致分页错乱
            page: params.current || 1,
            pageSize: Math.min(params.pageSize || TABLE.DEFAULT_PAGE_SIZE, PAGE_SIZE_MAX),
            // 状态筛选经 BFF 翻译为 query JSON（video_id/status/content___icontains）
            ...(params.status ? { status: params.status } : {}),
            ...(params.videoId ? { video_id: params.videoId } : {}),
          });
          return {
            data: response.items || [],
            total: Number(response.total ?? 0),
            success: true,
          };
        }}
        rowKey="id"
        pagination={{
          defaultPageSize: TABLE.DEFAULT_PAGE_SIZE,
          showSizeChanger: true,
          showQuickJumper: true,
          pageSizeOptions: ['10', '20', '50'],
        }}
        options={{
          density: false,
          fullScreen: false,
          setting: false,
          reload: true,
        }}
        size="small"
        bordered
        cardBordered={false}
        scroll={{ x: 940, y: tableScrollY }}
      />
    </div>
  );
};

export default DanmakuList;
