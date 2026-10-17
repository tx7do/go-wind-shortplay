import { useRef, useState } from 'react';
import type { ProColumns, ActionType } from '@ant-design/pro-components';
import ListTable from '@/components/common/ListTable';
import { Button, Radio, Tabs, Tag, App, Modal, Form, Input } from 'antd';
import { AuditOutlined, EyeOutlined } from '@ant-design/icons';
import { useQueryClient } from '@tanstack/react-query';
import { useTranslation } from 'react-i18next';
import dayjs from 'dayjs';

import { TABLE } from '@/config/constants';
import { useProTableScrollY } from '@/hooks/useProTableScrollY';
import { fetchListReports, useHandleReport } from '@/api/hooks';
import { HANDLE_ACTION } from '@/api/types';
import type { Report } from '@/api/types';
import { getReportStatusConfig, getTargetTypeLabelKey, REPORT_STATUS_LIST } from './constants';
import ReportDetailDrawer from './ReportDetailDrawer';

/**
 * 举报管理列表页
 * 状态 Tab（filter 传数字字符串）+ 详情 Drawer + 处理（通过处置/驳回 + 备注）
 */
const ReportList = () => {
  const { t } = useTranslation('report');
  const actionRef = useRef<ActionType>(null);
  const containerRef = useRef<HTMLDivElement>(null);
  const tableScrollY = useProTableScrollY(containerRef);
  const queryClient = useQueryClient();
  const { message } = App.useApp();

  // 状态 Tab：'' = 全部
  const [activeFilter, setActiveFilter] = useState<string>('');

  // 详情抽屉
  const [detailOpen, setDetailOpen] = useState(false);
  const [detailRow, setDetailRow] = useState<Report | null>(null);

  // 处理弹窗
  const [handleOpen, setHandleOpen] = useState(false);
  const [handleRow, setHandleRow] = useState<Report | null>(null);
  const [form] = Form.useForm();

  const refresh = () => {
    actionRef.current?.reload();
    queryClient.invalidateQueries({ queryKey: ['listReports'] });
  };

  const handleMutation = useHandleReport({
    onSuccess: () => {
      message.success(t('handleSuccess'));
      setHandleOpen(false);
      setHandleRow(null);
      refresh();
    },
    onError: (error: Error) => {
      message.error(error.message || t('handleFailed'));
    },
  });

  const openDetail = (row: Report) => {
    setDetailRow(row);
    setDetailOpen(true);
  };

  const columns: ProColumns<Report>[] = [
    {
      title: 'ID',
      dataIndex: 'id',
      width: 70,
      search: false,
    },
    {
      title: t('reporter'),
      dataIndex: 'reporter',
      width: 140,
      search: false,
      render: (_, record) => record.reporter?.nickname || record.reporterId || '-',
    },
    {
      title: t('targetType'),
      dataIndex: 'targetType',
      width: 100,
      search: false,
      render: (_, record) => (
        <Tag color="blue">{t(getTargetTypeLabelKey(record.targetType))}</Tag>
      ),
    },
    {
      title: t('targetId'),
      dataIndex: 'targetId',
      width: 90,
      search: false,
    },
    {
      title: t('reason'),
      dataIndex: 'reason',
      width: 160,
      ellipsis: true,
      search: false,
      render: (_, record) => (record.reason ? <Tag color="error">{record.reason}</Tag> : '-'),
    },
    {
      title: t('description'),
      dataIndex: 'description',
      ellipsis: true,
      search: false,
    },
    {
      title: t('status'),
      dataIndex: 'filter',
      width: 100,
      valueType: 'select',
      fieldProps: {
        options: REPORT_STATUS_LIST.map((item) => ({
          label: t(item.labelKey),
          value: item.filter,
        })),
      },
      render: (_, record) => {
        const config = getReportStatusConfig(record.status);
        return <Tag color={config.color}>{t(config.labelKey)}</Tag>;
      },
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
      width: 150,
      fixed: 'right',
      render: (_, record) => {
        const actions = [
          <a key="detail" onClick={() => openDetail(record)}>
            <EyeOutlined /> {t('detail')}
          </a>,
        ];
        if (record.status === 'REPORT_STATUS_PENDING') {
          actions.push(
            <a
              key="handle"
              onClick={() => {
                setHandleRow(record);
                setHandleOpen(true);
              }}
            >
              <AuditOutlined /> {t('handle')}
            </a>,
          );
        }
        return actions;
      },
    },
  ];

  const tabItems = [
    { key: '', label: t('tabAll') },
    ...REPORT_STATUS_LIST.map((item) => ({ key: item.filter, label: t(item.labelKey) })),
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
        <ListTable<Report>
          actionRef={actionRef}
          columns={columns}
          headerTitle={t('reportList')}
          params={{ filter: activeFilter }}
          request={async (params) => {
            const response = await fetchListReports({
              page: params.current || 1,
              pageSize: params.pageSize || TABLE.DEFAULT_PAGE_SIZE,
              filter: activeFilter || undefined,
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
          scroll={{ x: 1100, y: tableScrollY }}
        />
      </div>

      <ReportDetailDrawer
        open={detailOpen}
        data={detailRow}
        onClose={() => {
          setDetailOpen(false);
          setDetailRow(null);
        }}
        extra={
          detailRow?.status === 'REPORT_STATUS_PENDING' && (
            <Button
              type="primary"
              icon={<AuditOutlined />}
              onClick={() => {
                setHandleRow(detailRow);
                setHandleOpen(true);
              }}
            >
              {t('handle')}
            </Button>
          )
        }
      />

      {/* 处理弹窗：通过处置 / 驳回 + 备注 */}
      <Modal
        title={`${t('handleTitle')} #${handleRow?.id ?? ''}`}
        open={handleOpen}
        confirmLoading={handleMutation.isPending}
        okText={t('common:button.ok')}
        cancelText={t('common:button.cancel')}
        onOk={() => {
          if (!handleRow) return;
          const action =
            form.getFieldValue('handleAction') === 'dismiss'
              ? HANDLE_ACTION.DISMISS
              : HANDLE_ACTION.RESOLVE;
          handleMutation.mutate({
            id: handleRow.id!,
            action,
            note: form.getFieldValue('note') || undefined,
          });
        }}
        onCancel={() => {
          setHandleOpen(false);
          setHandleRow(null);
        }}
        destroyOnHidden
      >
        {handleRow && (
          <div style={{ marginBottom: 12, color: 'var(--ant-color-text-secondary)', fontSize: 13 }}>
            {t('reason')}: <Tag color="error">{handleRow.reason || '-'}</Tag>
            {handleRow.description && <span> / {handleRow.description}</span>}
          </div>
        )}
        <Form form={form} layout="vertical" initialValues={{ handleAction: 'resolve' }}>
          <Form.Item name="handleAction" label={t('handleAction')}>
            <Radio.Group
              options={[
                { label: t('resolve'), value: 'resolve' },
                { label: t('dismiss'), value: 'dismiss' },
              ]}
              optionType="button"
            />
          </Form.Item>
          <Form.Item name="note" label={t('note')}>
            <Input.TextArea rows={3} placeholder={t('notePlaceholder')} maxLength={200} showCount />
          </Form.Item>
        </Form>
      </Modal>
    </>
  );
};

export default ReportList;
