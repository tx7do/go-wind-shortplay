import { useRef, useState } from 'react';
import type { ProColumns, ActionType } from '@ant-design/pro-components';
import ListTable from '@/components/common/ListTable';
import { Button, Image, Popconfirm, Space, Tabs, Tag, App } from 'antd';
import {
  CheckOutlined,
  CloseOutlined,
  DeleteOutlined,
  DownCircleOutlined,
  EyeOutlined,
  PlayCircleOutlined,
} from '@ant-design/icons';
import { useQueryClient } from '@tanstack/react-query';
import { useTranslation } from 'react-i18next';
import dayjs from 'dayjs';

import { TABLE } from '@/config/constants';
import { useProTableScrollY } from '@/hooks/useProTableScrollY';
import {
  fetchListVideos,
  useChangeVideoStatus,
  useDeleteVideo,
} from '@/api/hooks';
import { VIDEO_STATUS } from '@/api/types';
import type { Video } from '@/api/types';
import { formatDuration, getVideoStatusConfig, VIDEO_STATUS_LIST } from './constants';
import VideoDetailDrawer from './VideoDetailDrawer';
import ReasonModal from './ReasonModal';

type PendingAction = 'reject' | 'offline';

/**
 * 视频管理列表页
 * 状态 Tab（filter 传数字字符串）+ 标题搜索 + 详情 Drawer + 审核/下架/删除
 */
const VideoList = () => {
  const { t } = useTranslation('video');
  const actionRef = useRef<ActionType>(null);
  const containerRef = useRef<HTMLDivElement>(null);
  const tableScrollY = useProTableScrollY(containerRef);
  const queryClient = useQueryClient();
  const { message } = App.useApp();

  // 状态 Tab：'' = 全部
  const [activeFilter, setActiveFilter] = useState<string>('');

  // 详情抽屉
  const [detailOpen, setDetailOpen] = useState(false);
  const [detailRow, setDetailRow] = useState<Video | null>(null);

  // 必填原因弹窗（驳回/下架）
  const [reasonAction, setReasonAction] = useState<PendingAction | null>(null);
  const [pendingRow, setPendingRow] = useState<Video | null>(null);

  const refresh = () => {
    actionRef.current?.reload();
    queryClient.invalidateQueries({ queryKey: ['listVideos'] });
    queryClient.invalidateQueries({ queryKey: ['dashboardOverview'] });
  };

  const changeStatusMutation = useChangeVideoStatus({
    onSuccess: (_data, variables) => {
      if (variables.status === VIDEO_STATUS.PUBLISHED) {
        message.success(t('publishSuccess'));
      } else if (variables.status === VIDEO_STATUS.REJECTED) {
        message.success(t('rejectSuccess'));
      } else {
        message.success(t('offlineSuccess'));
      }
      setReasonAction(null);
      setPendingRow(null);
      refresh();
    },
    onError: (error: Error) => {
      message.error(error.message || t('operationFailed'));
    },
  });

  const deleteMutation = useDeleteVideo({
    onSuccess: () => {
      message.success(t('deleteSuccess'));
      refresh();
    },
    onError: (error: Error) => {
      message.error(error.message || t('deleteFailed'));
    },
  });

  // ===== 动作 =====
  const openDetail = (row: Video) => {
    setDetailRow(row);
    setDetailOpen(true);
  };

  const handleApprove = (row: Video) => {
    changeStatusMutation.mutate({ id: row.id!, status: VIDEO_STATUS.PUBLISHED });
  };

  const openReasonModal = (action: PendingAction, row: Video) => {
    setPendingRow(row);
    setReasonAction(action);
  };

  const submitReason = (reason: string) => {
    if (!pendingRow) return;
    changeStatusMutation.mutate({
      id: pendingRow.id!,
      status: reasonAction === 'reject' ? VIDEO_STATUS.REJECTED : VIDEO_STATUS.OFFLINE,
      reason,
    });
  };

  const handleRepublish = (row: Video) => {
    changeStatusMutation.mutate({ id: row.id!, status: VIDEO_STATUS.PUBLISHED });
  };

  // ===== 列配置 =====
  const columns: ProColumns<Video>[] = [
    {
      title: 'ID',
      dataIndex: 'id',
      width: 70,
      search: false,
    },
    {
      title: t('title'),
      dataIndex: 'title',
      ellipsis: true,
      width: 220,
      fieldProps: {
        placeholder: t('queryPlaceholder'),
        allowClear: true,
      },
      // 搜索键名对齐后端：标题模糊搜索走 ?query=（展示仍读 record.title）
      search: {
        transform: (value: string) => ({ query: value }),
      },
    },
    {
      title: t('cover'),
      dataIndex: 'coverUrl',
      search: false,
      width: 100,
      // 有封面：44px 高缩略图，点击 antd Image 预览大图；空仍显示 —
      render: (_, record) =>
        record.coverUrl ? (
          <Image
            src={record.coverUrl}
            alt={record.title}
            width={78}
            height={44}
            style={{ objectFit: 'cover', borderRadius: 4 }}
          />
        ) : (
          '-'
        ),
    },
    {
      title: t('status'),
      dataIndex: 'filter',
      width: 100,
      valueType: 'select',
      fieldProps: {
        options: VIDEO_STATUS_LIST.map((item) => ({
          label: t(item.labelKey),
          value: item.filter,
        })),
      },
      render: (_, record) => {
        const config = getVideoStatusConfig(record.status);
        return <Tag color={config.color}>{t(config.labelKey)}</Tag>;
      },
    },
    {
      title: t('duration'),
      dataIndex: 'duration',
      search: false,
      width: 80,
      render: (_, record) => formatDuration(record.duration),
    },
    {
      title: t('authorId'),
      dataIndex: 'authorId',
      search: false,
      width: 90,
    },
    {
      title: t('tags'),
      dataIndex: 'tags',
      search: false,
      width: 160,
      ellipsis: true,
      render: (_, record) => (
        <Space wrap size={4}>
          {(record.tags ?? []).slice(0, 3).map((tag) => (
            <Tag key={tag} color="blue" style={{ marginBottom: 2 }}>
              {tag}
            </Tag>
          ))}
        </Space>
      ),
    },
    {
      title: t('viewCount'),
      dataIndex: 'viewCount',
      search: false,
      width: 90,
      render: (_, record) => String(record.viewCount ?? '0'),
    },
    {
      title: t('likeCount'),
      dataIndex: 'likeCount',
      search: false,
      width: 90,
      render: (_, record) => String(record.likeCount ?? '0'),
    },
    {
      title: t('commentCount'),
      dataIndex: 'commentCount',
      search: false,
      width: 90,
      render: (_, record) => String(record.commentCount ?? '0'),
    },
    {
      title: t('createdAt'),
      dataIndex: 'createdAt',
      search: false,
      width: 150,
      render: (_, record) =>
        record.createdAt ? dayjs(record.createdAt).format('YYYY-MM-DD HH:mm') : '',
    },
    {
      title: t('action'),
      valueType: 'option',
      width: 200,
      fixed: 'right',
      render: (_, record) => {
        const status = record.status;
        const actions = [
          <a key="detail" onClick={() => openDetail(record)}>
            <EyeOutlined /> {t('detail')}
          </a>,
        ];
        // 审核中 → 通过 / 驳回
        if (status === VIDEO_STATUS.REVIEWING) {
          actions.push(
            <Popconfirm
              key="approve"
              title={t('approveConfirmTitle')}
              description={t('approveConfirmDesc')}
              onConfirm={() => handleApprove(record)}
              okText={t('common:button.ok')}
              cancelText={t('common:button.cancel')}
            >
              <a style={{ color: 'var(--ant-color-success)' }}>
                <CheckOutlined /> {t('approve')}
              </a>
            </Popconfirm>,
            <a
              key="reject"
              style={{ color: 'var(--ant-color-warning)' }}
              onClick={() => openReasonModal('reject', record)}
            >
              <CloseOutlined /> {t('reject')}
            </a>,
          );
        }
        // 已发布 → 下架
        if (status === VIDEO_STATUS.PUBLISHED) {
          actions.push(
            <a
              key="offline"
              style={{ color: 'var(--ant-color-warning)' }}
              onClick={() => openReasonModal('offline', record)}
            >
              <DownCircleOutlined /> {t('offline')}
            </a>,
          );
        }
        // 已下架 / 已驳回 → 恢复发布
        if (status === VIDEO_STATUS.OFFLINE || status === VIDEO_STATUS.REJECTED) {
          actions.push(
            <Popconfirm
              key="republish"
              title={t('approveConfirmTitle')}
              description={t('approveConfirmDesc')}
              onConfirm={() => handleRepublish(record)}
              okText={t('common:button.ok')}
              cancelText={t('common:button.cancel')}
            >
              <a style={{ color: 'var(--ant-color-success)' }}>
                <PlayCircleOutlined /> {t('republish')}
              </a>
            </Popconfirm>,
          );
        }
        actions.push(
          <Popconfirm
            key="delete"
            title={t('deleteConfirmTitle')}
            description={t('deleteConfirmDesc', { moduleName: t('moduleName') })}
            onConfirm={() => record.id && deleteMutation.mutate(record.id)}
            okText={t('common:button.ok')}
            cancelText={t('common:button.cancel')}
          >
            <a style={{ color: 'var(--ant-color-error)' }}>
              <DeleteOutlined />
            </a>
          </Popconfirm>,
        );
        return actions;
      },
    },
  ];

  // 状态 Tab 定义（全部 + 五个状态）
  const tabItems = [
    { key: '', label: t('tabAll') },
    ...VIDEO_STATUS_LIST.map((item) => ({
      key: item.filter,
      label: (
        <span>
          <Tag color={item.color} style={{ marginInlineEnd: 4 }}>
            {t(item.labelKey)}
          </Tag>
        </span>
      ),
    })),
  ];

  return (
    <>
      <div
        ref={containerRef}
        className="page-container-content"
        style={{ padding: '0 8px', height: '100%' }}
      >
        <Tabs
          activeKey={activeFilter}
          onChange={(key) => setActiveFilter(key)}
          items={tabItems}
          size="small"
          style={{ marginBottom: 0 }}
        />
        <ListTable<Video>
          actionRef={actionRef}
          columns={columns}
          headerTitle={t('videoList')}
          params={{ filter: activeFilter }}
          request={async (params) => {
            const response = await fetchListVideos({
              page: params.current || 1,
              pageSize: params.pageSize || TABLE.DEFAULT_PAGE_SIZE,
              query: typeof params.query === 'string' ? params.query : undefined,
              filter: activeFilter || undefined,
            });
            return {
              data: response.items || [],
              total: Number(response.total ?? 0),
              success: true,
            };
          }}
          rowKey="id"
          search={{
            labelWidth: 'auto',
            defaultCollapsed: false,
            span: 8,
          }}
          pagination={{
            defaultPageSize: TABLE.DEFAULT_PAGE_SIZE,
            showSizeChanger: true,
            showQuickJumper: true,
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
          scroll={{ x: 1400, y: tableScrollY }}
        />
      </div>

      {/* 详情抽屉：底部动作区与状态联动 */}
      <VideoDetailDrawer
        open={detailOpen}
        data={detailRow}
        onClose={() => {
          setDetailOpen(false);
          setDetailRow(null);
        }}
        extra={
          detailRow && (
            <>
              {detailRow.status === VIDEO_STATUS.REVIEWING && (
                <>
                  <Popconfirm
                    title={t('approveConfirmTitle')}
                    description={t('approveConfirmDesc')}
                    onConfirm={() => handleApprove(detailRow)}
                    okText={t('common:button.ok')}
                    cancelText={t('common:button.cancel')}
                  >
                    <Button
                      type="primary"
                      icon={<CheckOutlined />}
                      loading={changeStatusMutation.isPending}
                    >
                      {t('approve')}
                    </Button>
                  </Popconfirm>
                  <Button
                    danger
                    icon={<CloseOutlined />}
                    onClick={() => openReasonModal('reject', detailRow)}
                  >
                    {t('reject')}
                  </Button>
                </>
              )}
              {detailRow.status === VIDEO_STATUS.PUBLISHED && (
                <Button
                  danger
                  icon={<DownCircleOutlined />}
                  onClick={() => openReasonModal('offline', detailRow)}
                >
                  {t('offline')}
                </Button>
              )}
              {(detailRow.status === VIDEO_STATUS.OFFLINE ||
                detailRow.status === VIDEO_STATUS.REJECTED) && (
                <Popconfirm
                  title={t('approveConfirmTitle')}
                  description={t('approveConfirmDesc')}
                  onConfirm={() => handleRepublish(detailRow)}
                  okText={t('common:button.ok')}
                  cancelText={t('common:button.cancel')}
                >
                  <Button
                    type="primary"
                    icon={<PlayCircleOutlined />}
                    loading={changeStatusMutation.isPending}
                  >
                    {t('republish')}
                  </Button>
                </Popconfirm>
              )}
            </>
          )
        }
      />

      {/* 驳回 / 下架：必填原因 */}
      <ReasonModal
        open={reasonAction !== null}
        title={reasonAction === 'reject' ? t('rejectTitle') : t('offlineTitle')}
        placeholder={
          reasonAction === 'reject' ? t('rejectReasonPlaceholder') : t('offlineReasonPlaceholder')
        }
        confirmLoading={changeStatusMutation.isPending}
        onOk={submitReason}
        onCancel={() => {
          setReasonAction(null);
          setPendingRow(null);
        }}
      />
    </>
  );
};

export default VideoList;
