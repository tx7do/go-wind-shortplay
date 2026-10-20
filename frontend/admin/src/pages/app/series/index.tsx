import { useRef, useState } from 'react';
import type { ActionType, ProColumns } from '@ant-design/pro-components';
import ListTable from '@/components/common/ListTable';
import { App, Image, Popconfirm, Space, Tag } from 'antd';
import { DeleteOutlined, EditOutlined, EyeOutlined } from '@ant-design/icons';
import { useQueryClient } from '@tanstack/react-query';
import { useTranslation } from 'react-i18next';
import dayjs from 'dayjs';

import { TABLE } from '@/config/constants';
import { useProTableScrollY } from '@/hooks/useProTableScrollY';
import { fetchListSeries, useDeleteSeries } from '@/api/hooks';
import type { Series } from '@/api/types';
import { toNum } from './constants';
import SeriesDetailDrawer from './SeriesDetailDrawer';
import SeriesEditDrawer from './SeriesEditDrawer';

/**
 * 剧集管理列表页：标题搜索 + 详情（含剧内选集）/ 编辑 / 删除。
 * 剧集为 UGC（App 端创作者创建），管理端不提供新建。
 */
const SeriesList = () => {
  const { t } = useTranslation('series');
  const actionRef = useRef<ActionType>(null);
  const containerRef = useRef<HTMLDivElement>(null);
  const tableScrollY = useProTableScrollY(containerRef);
  const queryClient = useQueryClient();
  const { message } = App.useApp();

  // 详情抽屉（按 seriesId 拉全集）
  const [detailId, setDetailId] = useState<number | undefined>(undefined);
  const [detailOpen, setDetailOpen] = useState(false);

  // 编辑抽屉
  const [editOpen, setEditOpen] = useState(false);
  const [editRow, setEditRow] = useState<Series | null>(null);

  const refresh = () => {
    actionRef.current?.reload();
    queryClient.invalidateQueries({ queryKey: ['listSeries'] });
  };

  const deleteMutation = useDeleteSeries({
    onSuccess: () => {
      message.success(t('deleteSuccess'));
      refresh();
    },
    onError: (error: Error) => {
      message.error(error.message || t('deleteFailed'));
    },
  });

  const columns: ProColumns<Series>[] = [
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
      // 搜索键名对齐后端：剧名模糊搜索走 ?query=
      search: {
        transform: (value: string) => ({ query: value }),
      },
    },
    {
      title: t('cover'),
      dataIndex: 'coverUrl',
      search: false,
      width: 100,
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
      title: t('episodeCounts'),
      dataIndex: 'publishedCount',
      search: false,
      width: 130,
      render: (_, record) => (
        <Space size={4}>
          <Tag color="success">{`${t('publishedCount')} ${toNum(record.publishedCount)}`}</Tag>
          <Tag>{`${t('totalCount')} ${toNum(record.episodeCount)}`}</Tag>
        </Space>
      ),
    },
    {
      title: t('authorId'),
      dataIndex: 'authorId',
      search: false,
      width: 90,
    },
    {
      title: t('description'),
      dataIndex: 'description',
      search: false,
      ellipsis: true,
      width: 200,
      render: (_, record) => record.description || '-',
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
      width: 180,
      fixed: 'right',
      render: (_, record) => [
        <a
          key="detail"
          onClick={() => {
            setDetailId(record.id);
            setDetailOpen(true);
          }}
        >
          <EyeOutlined /> {t('detail')}
        </a>,
        <a
          key="edit"
          onClick={() => {
            setEditRow(record);
            setEditOpen(true);
          }}
        >
          <EditOutlined /> {t('edit')}
        </a>,
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
      ],
    },
  ];

  return (
    <>
      <div
        ref={containerRef}
        className="page-container-content"
        style={{ padding: '0 8px', height: '100%' }}
      >
        <ListTable<Series>
          actionRef={actionRef}
          columns={columns}
          headerTitle={t('seriesList')}
          request={async (params) => {
            const response = await fetchListSeries({
              page: params.current || 1,
              pageSize: params.pageSize || TABLE.DEFAULT_PAGE_SIZE,
              query: typeof params.query === 'string' ? params.query : undefined,
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
          scroll={{ x: 1200, y: tableScrollY }}
        />
      </div>

      {/* 详情抽屉：剧信息 + 选集列表 */}
      <SeriesDetailDrawer
        open={detailOpen}
        seriesId={detailId}
        onClose={() => {
          setDetailOpen(false);
          setDetailId(undefined);
        }}
      />

      {/* 编辑抽屉：标题/简介/封面，成功后刷新列表 */}
      <SeriesEditDrawer
        open={editOpen}
        data={editRow}
        onClose={() => {
          setEditOpen(false);
          setEditRow(null);
        }}
        onSuccess={refresh}
      />
    </>
  );
};

export default SeriesList;
