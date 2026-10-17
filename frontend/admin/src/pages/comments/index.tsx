/**
 * 评论管理：GET /comments 表格（分页），删除（DELETE /comments/{id}，Popconfirm）。
 */
import { useCallback, useEffect, useState } from 'react';
import { Button, Popconfirm, Space, Table, Tag, message } from 'antd';
import type { ColumnsType } from 'antd/es/table';
import { ReloadOutlined } from '@ant-design/icons';
import { deleteComment, listComments } from '../../api/comment';
import type { Comment } from '../../types';
import { formatDateTime, formatNumber } from '../../utils/format';

export default function CommentsPage() {
  const [list, setList] = useState<Comment[]>([]);
  const [total, setTotal] = useState(0);
  const [loading, setLoading] = useState(false);
  const [page, setPage] = useState(1);
  const [pageSize, setPageSize] = useState(10);

  const fetchList = useCallback(
    async (p: number, ps: number) => {
      setLoading(true);
      try {
        const data = await listComments({ page: p, pageSize: ps });
        setList(data.items);
        setTotal(data.total);
      } catch {
        // 错误已由拦截器统一提示
      } finally {
        setLoading(false);
      }
    },
    [],
  );

  useEffect(() => {
    fetchList(page, pageSize);
  }, [fetchList, page, pageSize]);

  const refresh = () => fetchList(page, pageSize);

  /** 删除评论 */
  const handleDelete = async (record: Comment) => {
    await deleteComment(record.id);
    message.success('已删除');
    refresh();
  };

  const columns: ColumnsType<Comment> = [
    { title: 'ID', dataIndex: 'id', width: 80 },
    { title: '视频 ID', dataIndex: 'videoId', width: 90 },
    {
      title: '评论人',
      key: 'user',
      width: 160,
      render: (_value, record) =>
        record.user?.nickname ? (
          <Space size={4}>
            <span>{record.user.nickname}</span>
            <Tag>ID {record.user.id ?? record.userId ?? '—'}</Tag>
          </Space>
        ) : (
          `用户 ${record.userId ?? '—'}`
        ),
    },
    { title: '内容', dataIndex: 'content', ellipsis: true },
    { title: '点赞', dataIndex: 'likeCount', width: 80, render: formatNumber },
    { title: '评论时间', dataIndex: 'createdAt', width: 170, render: formatDateTime },
    {
      title: '操作',
      key: 'actions',
      width: 90,
      render: (_value, record) => (
        <Popconfirm
          title="删除评论"
          description="确定删除该评论吗？此操作不可恢复。"
          okText="删除"
          okButtonProps={{ danger: true }}
          cancelText="取消"
          onConfirm={() => handleDelete(record)}
        >
          <Button type="link" size="small" danger>
            删除
          </Button>
        </Popconfirm>
      ),
    },
  ];

  return (
    <div className="page-table">
      <Space style={{ marginBottom: 12 }}>
        <Button icon={<ReloadOutlined />} onClick={refresh}>
          刷新
        </Button>
        <span style={{ color: '#999' }}>共 {formatNumber(total)} 条评论</span>
      </Space>
      <Table<Comment>
        rowKey="id"
        columns={columns}
        dataSource={list}
        loading={loading}
        scroll={{ x: 900 }}
        pagination={{
          current: page,
          pageSize,
          total,
          showSizeChanger: true,
          pageSizeOptions: [10, 20, 50],
          showTotal: (t) => `共 ${t} 条`,
          onChange: (p, ps) => {
            setPage(p);
            setPageSize(ps);
          },
        }}
      />
    </div>
  );
}
