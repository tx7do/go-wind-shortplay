/**
 * 视频管理：
 * - GET /videos 表格（分页、按状态 Tab 筛选、query 关键字）
 * - 状态列 Tag（1 草稿 / 2 审核中 / 3 已发布 / 4 驳回 / 5 下架）
 * - 行操作：详情抽屉（含视频预览）、审核通过、驳回（必填原因）、下架（必填原因）、删除
 */
import { useCallback, useEffect, useState } from 'react';
import {
  Button,
  Form,
  Image,
  Input,
  Modal,
  Popconfirm,
  Space,
  Table,
  Tabs,
  Tag,
  message,
} from 'antd';
import type { ColumnsType } from 'antd/es/table';
import { ReloadOutlined, SearchOutlined } from '@ant-design/icons';
import { changeVideoStatus, deleteVideo, listVideos } from '../../api/video';
import VideoDetailDrawer from '../../components/VideoDetailDrawer';
import type { Video, VideoStatus } from '../../types';
import { VIDEO_STATUS_MAP, formatDateTime, formatNumber } from '../../utils/format';

/** 状态 Tab 项（undefined 表示全部） */
const STATUS_TABS: { key: string; label: string }[] = [
  { key: 'all', label: '全部' },
  { key: '1', label: '草稿' },
  { key: '2', label: '审核中' },
  { key: '3', label: '已发布' },
  { key: '4', label: '驳回' },
  { key: '5', label: '下架' },
];

/** 驳回 / 下架弹窗状态 */
interface ReasonModalState {
  open: boolean;
  /** 4 驳回 / 5 下架 */
  status: 4 | 5;
  video: Video | null;
}

export default function VideosPage() {
  // 列表状态
  const [list, setList] = useState<Video[]>([]);
  const [total, setTotal] = useState(0);
  const [loading, setLoading] = useState(false);
  const [page, setPage] = useState(1);
  const [pageSize, setPageSize] = useState(10);
  const [statusTab, setStatusTab] = useState<string>('all');
  // 搜索框输入值与已生效的关键字（回车 / 点查询后才触发请求）
  const [keywordInput, setKeywordInput] = useState('');
  const [keyword, setKeyword] = useState('');

  // 详情抽屉
  const [detailVideo, setDetailVideo] = useState<Video | null>(null);

  // 驳回 / 下架弹窗
  const [reasonState, setReasonState] = useState<ReasonModalState>({ open: false, status: 4, video: null });
  const [reasonForm] = Form.useForm<{ reason: string }>();
  const [submitting, setSubmitting] = useState(false);

  /** 拉取视频列表 */
  const fetchList = useCallback(
    async (params: { page: number; pageSize: number; statusTab: string; keyword: string }) => {
      setLoading(true);
      try {
        const data = await listVideos({
          page: params.page,
          pageSize: params.pageSize,
          query: params.keyword || undefined,
          status:
            params.statusTab !== 'all' ? (Number(params.statusTab) as VideoStatus) : undefined,
        });
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
    fetchList({ page, pageSize, statusTab, keyword });
  }, [fetchList, page, pageSize, statusTab, keyword]);

  /** 刷新当前列表 */
  const refresh = () => fetchList({ page, pageSize, statusTab, keyword });

  /** 审核通过（status=3） */
  const confirmApprove = (video: Video) => {
    Modal.confirm({
      title: '审核通过',
      content: `确认通过视频「${video.title}」的审核吗？`,
      okText: '通过',
      cancelText: '取消',
      onOk: async () => {
        await changeVideoStatus(video.id, 3);
        message.success('已通过审核');
        refresh();
      },
    });
  };

  /** 提交驳回 / 下架（必填原因） */
  const submitReason = async (values: { reason: string }) => {
    const { video, status } = reasonState;
    if (!video) return;
    setSubmitting(true);
    try {
      await changeVideoStatus(video.id, status, values.reason);
      message.success(status === 4 ? '已驳回' : '已下架');
      setReasonState({ open: false, status: 4, video: null });
      refresh();
    } catch {
      // 错误已由拦截器统一提示
    } finally {
      setSubmitting(false);
    }
  };

  /** 删除视频 */
  const handleDelete = async (video: Video) => {
    await deleteVideo(video.id);
    message.success('已删除');
    refresh();
  };

  /** 表格列定义 */
  const columns: ColumnsType<Video> = [
    { title: 'ID', dataIndex: 'id', width: 70 },
    {
      title: '封面',
      dataIndex: 'coverUrl',
      width: 96,
      render: (url?: string) =>
        url ? <Image src={url} width={64} height={36} style={{ objectFit: 'cover', borderRadius: 4 }} /> : '—',
    },
    { title: '标题', dataIndex: 'title', ellipsis: true },
    {
      title: '标签',
      dataIndex: 'tags',
      width: 180,
      render: (tags?: string[]) =>
        tags?.length ? (
          <>
            {tags.slice(0, 3).map((t) => (
              <Tag key={t} style={{ marginBottom: 4 }}>
                {t}
              </Tag>
            ))}
          </>
        ) : (
          '—'
        ),
    },
    {
      title: '状态',
      dataIndex: 'status',
      width: 90,
      render: (s: number) => (
        <Tag color={VIDEO_STATUS_MAP[s]?.color}>{VIDEO_STATUS_MAP[s]?.label ?? '未知'}</Tag>
      ),
    },
    { title: '播放', dataIndex: 'viewCount', width: 90, render: formatNumber },
    { title: '点赞', dataIndex: 'likeCount', width: 90, render: formatNumber },
    { title: '评论', dataIndex: 'commentCount', width: 90, render: formatNumber },
    { title: '发布时间', dataIndex: 'publishedAt', width: 160, render: formatDateTime },
    {
      title: '操作',
      key: 'actions',
      fixed: 'right',
      width: 230,
      render: (_value, record) => (
        <Space size={0} wrap>
          <Button type="link" size="small" onClick={() => setDetailVideo(record)}>
            详情
          </Button>
          {record.status === 2 && (
            <Button type="link" size="small" onClick={() => confirmApprove(record)}>
              通过
            </Button>
          )}
          {record.status === 2 && (
            <Button
              type="link"
              size="small"
              danger
              onClick={() => {
                reasonForm.resetFields();
                setReasonState({ open: true, status: 4, video: record });
              }}
            >
              驳回
            </Button>
          )}
          {record.status === 3 && (
            <Button
              type="link"
              size="small"
              danger
              onClick={() => {
                reasonForm.resetFields();
                setReasonState({ open: true, status: 5, video: record });
              }}
            >
              下架
            </Button>
          )}
          <Popconfirm
            title="删除视频"
            description="确定删除该视频吗？此操作不可恢复。"
            okText="删除"
            okButtonProps={{ danger: true }}
            cancelText="取消"
            onConfirm={() => handleDelete(record)}
          >
            <Button type="link" size="small" danger>
              删除
            </Button>
          </Popconfirm>
        </Space>
      ),
    },
  ];

  return (
    <div className="page-table">
      {/* 状态 Tab 筛选 + 关键字搜索 */}
      <Tabs
        activeKey={statusTab}
        items={STATUS_TABS.map((t) => ({ key: t.key, label: t.label }))}
        onChange={(key) => {
          setStatusTab(key);
          setPage(1);
        }}
        tabBarExtraContent={
          <Space>
            <Input
              allowClear
              placeholder="按标题搜索"
              prefix={<SearchOutlined />}
              style={{ width: 220 }}
              value={keywordInput}
              onChange={(e) => setKeywordInput(e.target.value)}
              onPressEnter={() => {
                setKeyword(keywordInput);
                setPage(1);
              }}
            />
            <Button
              icon={<SearchOutlined />}
              onClick={() => {
                setKeyword(keywordInput);
                setPage(1);
              }}
            >
              查询
            </Button>
            <Button
              icon={<ReloadOutlined />}
              onClick={() => {
                setKeywordInput('');
                setKeyword('');
                setPage(1);
                fetchList({ page: 1, pageSize, statusTab, keyword: '' });
              }}
            >
              重置
            </Button>
          </Space>
        }
      />

      <Table<Video>
        rowKey="id"
        columns={columns}
        dataSource={list}
        loading={loading}
        scroll={{ x: 1200 }}
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

      {/* 视频详情抽屉 */}
      <VideoDetailDrawer video={detailVideo} onClose={() => setDetailVideo(null)} />

      {/* 驳回 / 下架弹窗（原因必填） */}
      <Modal
        open={reasonState.open}
        title={reasonState.status === 4 ? '驳回视频' : '下架视频'}
        okText="确认"
        cancelText="取消"
        confirmLoading={submitting}
        onCancel={() => setReasonState({ open: false, status: 4, video: null })}
        onOk={() => reasonForm.submit()}
      >
        <p style={{ color: '#999' }}>
          {reasonState.video ? `视频：${reasonState.video.title}` : ''}
        </p>
        <Form<{ reason: string }> form={reasonForm} layout="vertical" onFinish={submitReason}>
          <Form.Item
            name="reason"
            label={reasonState.status === 4 ? '驳回原因' : '下架原因'}
            rules={[{ required: true, message: '请填写原因（必填）' }]}
          >
            <Input.TextArea rows={3} maxLength={200} showCount placeholder="请填写原因" />
          </Form.Item>
        </Form>
      </Modal>
    </div>
  );
}
