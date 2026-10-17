/**
 * 举报管理：
 * - GET /reports 表格（分页，状态筛选 filter=1 待处理 / 2 已通过 / 3 已驳回）
 * - 详情（举报人 / 目标类型 / 目标 ID / 原因 / 说明）
 * - 处理（PUT /reports/{id}/handle，action=1 通过处置 / 2 驳回，可选 note）
 */
import { useCallback, useEffect, useState } from 'react';
import {
  Button,
  Descriptions,
  Form,
  Input,
  Modal,
  Popconfirm,
  Radio,
  Space,
  Table,
  Tabs,
  Tag,
  message,
} from 'antd';
import type { ColumnsType } from 'antd/es/table';
import { getReport, handleReport, listReports } from '../../api/report';
import type { Report } from '../../types';
import {
  REPORT_STATUS_MAP,
  TARGET_TYPE_MAP,
  formatDateTime,
} from '../../utils/format';

/** 状态 Tab 项（'' 表示全部） */
const STATUS_TABS: { key: string; label: string }[] = [
  { key: 'all', label: '全部' },
  { key: '1', label: '待处理' },
  { key: '2', label: '已通过' },
  { key: '3', label: '已驳回' },
];

interface HandleFormValues {
  action: 1 | 2;
  note?: string;
}

export default function ReportsPage() {
  const [list, setList] = useState<Report[]>([]);
  const [total, setTotal] = useState(0);
  const [loading, setLoading] = useState(false);
  const [page, setPage] = useState(1);
  const [pageSize, setPageSize] = useState(10);
  const [statusTab, setStatusTab] = useState<string>('all');

  // 详情弹窗（直接展示行数据，必要时拉取详情兜底）
  const [detail, setDetail] = useState<Report | null>(null);

  // 处理弹窗
  const [handleTarget, setHandleTarget] = useState<Report | null>(null);
  const [handleForm] = Form.useForm<HandleFormValues>();
  const [submitting, setSubmitting] = useState(false);

  const fetchList = useCallback(
    async (params: { page: number; pageSize: number; statusTab: string }) => {
      setLoading(true);
      try {
        const data = await listReports({
          page: params.page,
          pageSize: params.pageSize,
          filter:
            params.statusTab !== 'all' ? (Number(params.statusTab) as 1 | 2 | 3) : undefined,
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
    fetchList({ page, pageSize, statusTab });
  }, [fetchList, page, pageSize, statusTab]);

  const refresh = () => fetchList({ page, pageSize, statusTab });

  /** 打开详情：尝试拉取最新详情，失败回退行数据 */
  const openDetail = async (record: Report) => {
    setDetail(record);
    try {
      const data = await getReport(record.id);
      setDetail(data);
    } catch {
      // 保留行数据展示
    }
  };

  /** 提交处理 */
  const submitHandle = async (values: HandleFormValues) => {
    if (!handleTarget) return;
    setSubmitting(true);
    try {
      await handleReport(handleTarget.id, values.action, values.note);
      message.success(values.action === 1 ? '已通过并处置目标' : '已驳回该工单');
      setHandleTarget(null);
      refresh();
    } catch {
      // 错误已由拦截器统一提示
    } finally {
      setSubmitting(false);
    }
  };

  const columns: ColumnsType<Report> = [
    { title: 'ID', dataIndex: 'id', width: 80 },
    {
      title: '举报人',
      key: 'reporter',
      width: 150,
      render: (_value, record) => record.reporter?.nickname || `用户 ${record.reporterId ?? '—'}`,
    },
    {
      title: '目标类型',
      dataIndex: 'targetType',
      width: 100,
      render: (t: number) => <Tag>{TARGET_TYPE_MAP[t] ?? '未知'}</Tag>,
    },
    { title: '目标 ID', dataIndex: 'targetId', width: 90 },
    { title: '原因', dataIndex: 'reason', ellipsis: true },
    {
      title: '状态',
      dataIndex: 'status',
      width: 100,
      render: (s: number) => (
        <Tag color={REPORT_STATUS_MAP[s]?.color}>{REPORT_STATUS_MAP[s]?.label ?? '未知'}</Tag>
      ),
    },
    { title: '创建时间', dataIndex: 'createdAt', width: 170, render: formatDateTime },
    {
      title: '操作',
      key: 'actions',
      fixed: 'right',
      width: 140,
      render: (_value, record) => (
        <Space size={0}>
          <Button type="link" size="small" onClick={() => openDetail(record)}>
            详情
          </Button>
          <Popconfirm
            title="确认处理该举报？"
            description="将通过并处置目标，或驳回该工单。"
            okText="去处理"
            cancelText="取消"
            onConfirm={() => {
              handleForm.resetFields();
              setHandleTarget(record);
            }}
            disabled={record.status !== 1}
          >
            <Button type="link" size="small" disabled={record.status !== 1}>
              处理
            </Button>
          </Popconfirm>
        </Space>
      ),
    },
  ];

  return (
    <div className="page-table">
      <Tabs
        activeKey={statusTab}
        items={STATUS_TABS.map((t) => ({ key: t.key, label: t.label }))}
        onChange={(key) => {
          setStatusTab(key);
          setPage(1);
        }}
      />
      <Table<Report>
        rowKey="id"
        columns={columns}
        dataSource={list}
        loading={loading}
        scroll={{ x: 1000 }}
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

      {/* 详情弹窗 */}
      <Modal
        open={!!detail}
        title={detail ? `举报工单 #${detail.id}` : '举报详情'}
        footer={null}
        onCancel={() => setDetail(null)}
      >
        {detail && (
          <Descriptions column={1} size="small" bordered>
            <Descriptions.Item label="举报人">
              {detail.reporter?.nickname || '—'}（ID：{detail.reporterId ?? detail.reporter?.id ?? '—'}）
            </Descriptions.Item>
            <Descriptions.Item label="目标类型">
              <Tag>{TARGET_TYPE_MAP[detail.targetType] ?? '未知'}</Tag>
            </Descriptions.Item>
            <Descriptions.Item label="目标 ID">{detail.targetId}</Descriptions.Item>
            <Descriptions.Item label="举报原因">{detail.reason || '—'}</Descriptions.Item>
            <Descriptions.Item label="补充说明">{detail.description || '—'}</Descriptions.Item>
            <Descriptions.Item label="状态">
              <Tag color={REPORT_STATUS_MAP[detail.status]?.color}>
                {REPORT_STATUS_MAP[detail.status]?.label ?? '未知'}
              </Tag>
            </Descriptions.Item>
            {detail.status !== 1 && (
              <>
                <Descriptions.Item label="处理备注">{detail.handleNote || '—'}</Descriptions.Item>
                <Descriptions.Item label="处理时间">{formatDateTime(detail.handledAt)}</Descriptions.Item>
              </>
            )}
            <Descriptions.Item label="创建时间">{formatDateTime(detail.createdAt)}</Descriptions.Item>
          </Descriptions>
        )}
      </Modal>

      {/* 处理弹窗 */}
      <Modal
        open={!!handleTarget}
        title="处理举报工单"
        okText="提交"
        cancelText="取消"
        confirmLoading={submitting}
        onCancel={() => setHandleTarget(null)}
        onOk={() => handleForm.submit()}
      >
        {handleTarget && (
          <p style={{ color: '#999' }}>
            工单 #{handleTarget.id}：举报{TARGET_TYPE_MAP[handleTarget.targetType] ?? '未知'}{' '}
            {handleTarget.targetId}（举报人：{handleTarget.reporter?.nickname || handleTarget.reporterId}）
          </p>
        )}
        <Form<HandleFormValues>
          form={handleForm}
          layout="vertical"
          initialValues={{ action: 1 }}
          onFinish={submitHandle}
        >
          <Form.Item name="action" label="处理动作" rules={[{ required: true, message: '请选择处理动作' }]}>
            <Radio.Group
              options={[
                { label: '通过并处置目标', value: 1 },
                { label: '驳回（仅关闭工单）', value: 2 },
              ]}
            />
          </Form.Item>
          <Form.Item name="note" label="处理备注（可选）">
            <Input.TextArea rows={3} maxLength={200} showCount placeholder="处理说明" />
          </Form.Item>
        </Form>
      </Modal>
    </div>
  );
}
