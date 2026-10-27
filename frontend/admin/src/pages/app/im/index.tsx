/**
 * 私信监管列表页（管理端只读）
 * 内容合规用：全量私信（发送人/接收人/内容过滤），不提供处置操作。
 */
import { useRef } from 'react';
import type { ProColumns, ActionType } from '@ant-design/pro-components';
import ListTable from '@/components/common/ListTable';
import { Avatar } from 'antd';
import { useTranslation } from 'react-i18next';
import dayjs from 'dayjs';

import { TABLE } from '@/config/constants';
import { useProTableScrollY } from '@/hooks/useProTableScrollY';
import { fetchListImMessages } from '@/api/hooks';
import type { ImAdminMessage } from '@/api/types';

const PAGE_SIZE_MAX = 50; // 后端 pageSize 上限

const ImAuditList = () => {
  const { t } = useTranslation('im');
  const actionRef = useRef<ActionType>(null);
  const containerRef = useRef<HTMLDivElement>(null);
  const tableScrollY = useProTableScrollY(containerRef);

  const columns: ProColumns<ImAdminMessage>[] = [
    {
      title: 'ID',
      dataIndex: 'id',
      width: 70,
      search: false,
    },
    {
      title: t('sender'),
      dataIndex: 'sender',
      width: 150,
      render: (_, record) => (
        <span style={{ display: 'inline-flex', alignItems: 'center', gap: 8 }}>
          <Avatar src={record.sender?.avatarUrl} size="small">
            {(record.sender?.nickname ?? '?').slice(0, 1)}
          </Avatar>
          {record.sender?.nickname || record.senderId || '-'}
        </span>
      ),
    },
    {
      title: t('receiverId'),
      dataIndex: 'receiverId',
      width: 100,
    },
    {
      title: t('content'),
      dataIndex: 'content',
      ellipsis: true,
    },
    {
      title: t('conversationId'),
      dataIndex: 'conversationId',
      width: 100,
      search: false,
    },
    {
      title: t('createdAt'),
      dataIndex: 'createdAt',
      search: false,
      width: 160,
      render: (_, record) =>
        record.createdAt ? dayjs(record.createdAt).format('YYYY-MM-DD HH:mm') : '',
    },
  ];

  return (
    <div
      ref={containerRef}
      className="page-container-content"
      style={{ padding: '0 8px', height: '100%' }}
    >
      <ListTable<ImAdminMessage>
        actionRef={actionRef}
        columns={columns}
        headerTitle={t('messageList')}
        request={async (params) => {
          const response = await fetchListImMessages({
            // 后端 pageSize 上限 50，超出会被截断导致分页错乱
            page: params.current || 1,
            pageSize: Math.min(params.pageSize || TABLE.DEFAULT_PAGE_SIZE, PAGE_SIZE_MAX),
            ...(params.content ? { content___icontains: params.content } : {}),
            ...(params.senderId ? { sender_id: params.senderId } : {}),
            ...(params.receiverId ? { receiver_id: params.receiverId } : {}),
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
        scroll={{ x: 800, y: tableScrollY }}
      />
    </div>
  );
};

export default ImAuditList;
