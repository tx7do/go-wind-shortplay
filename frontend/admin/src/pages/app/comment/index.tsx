/**
 * 评论列表页（管理端全量）
 * 模式对齐底座 engagement/comment：ProTable 列表 + Popconfirm 删除。
 * Admin BFF 为扁平全量列表（无树形/回复/审核态），仅保留删除能力。
 */
import { useRef } from 'react';
import type { ProColumns, ActionType } from '@ant-design/pro-components';
import ListTable from '@/components/common/ListTable';
import { Avatar, Popconfirm, App } from 'antd';
import { DeleteOutlined } from '@ant-design/icons';
import { useQueryClient } from '@tanstack/react-query';
import { useTranslation } from 'react-i18next';
import dayjs from 'dayjs';

import { TABLE } from '@/config/constants';
import { useProTableScrollY } from '@/hooks/useProTableScrollY';
import { fetchListComments, useDeleteComment } from '@/api/hooks';
import type { Comment } from '@/api/types';

const PAGE_SIZE_MAX = 50; // 后端 pageSize 上限

const CommentList = () => {
  const { t } = useTranslation('comment');
  const actionRef = useRef<ActionType>(null);
  const containerRef = useRef<HTMLDivElement>(null);
  const tableScrollY = useProTableScrollY(containerRef);
  const queryClient = useQueryClient();
  const { message } = App.useApp();

  const deleteMutation = useDeleteComment({
    onSuccess: () => {
      message.success(t('deleteSuccess'));
      actionRef.current?.reload();
      queryClient.invalidateQueries({ queryKey: ['listComments'] });
      queryClient.invalidateQueries({ queryKey: ['dashboardOverview'] });
    },
    onError: (error: Error) => {
      message.error(error.message || t('deleteFailed'));
    },
  });

  const columns: ProColumns<Comment>[] = [
    {
      title: 'ID',
      dataIndex: 'id',
      width: 70,
      search: false,
    },
    {
      title: t('user'),
      dataIndex: 'user',
      width: 160,
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
      render: (_, record) => {
        const text = String(record.content ?? '');
        return text.length > 60 ? `${text.slice(0, 60)}...` : text;
      },
    },
    {
      title: t('videoId'),
      dataIndex: 'videoId',
      width: 90,
      search: false,
    },
    {
      title: t('likeCount'),
      dataIndex: 'likeCount',
      width: 80,
      search: false,
      render: (_, record) => String(record.likeCount ?? '0'),
    },
    {
      title: t('replyCount'),
      dataIndex: 'replyCount',
      width: 80,
      search: false,
      render: (_, record) => String(record.replyCount ?? '0'),
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
      width: 90,
      fixed: 'right',
      render: (_, record) => [
        <Popconfirm
          key="delete"
          title={t('deleteConfirmTitle')}
          description={t('deleteConfirmDesc', { moduleName: t('moduleName') })}
          onConfirm={() => {
            record.id && deleteMutation.mutate(record.id);
          }}
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
    <div
      ref={containerRef}
      className="page-container-content"
      style={{ padding: '0 8px', height: '100%' }}
    >
      <ListTable<Comment>
        actionRef={actionRef}
        columns={columns}
        headerTitle={t('commentList')}
        request={async (params) => {
          const response = await fetchListComments({
            // 后端 pageSize 上限 50，超出会被截断导致分页错乱
            page: params.current || 1,
            pageSize: Math.min(params.pageSize || TABLE.DEFAULT_PAGE_SIZE, PAGE_SIZE_MAX),
          });
          return {
            data: response.items || [],
            total: Number(response.total ?? 0),
            success: true,
          };
        }}
        rowKey="id"
        search={false}
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
        scroll={{ x: 900, y: tableScrollY }}
      />
    </div>
  );
};

export default CommentList;
