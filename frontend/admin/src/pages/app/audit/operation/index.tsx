import type { ProColumns } from '@ant-design/pro-components';
import { useTranslation } from 'react-i18next';
import dayjs from 'dayjs';

import AuditLogTable from '../AuditLogTable';
import { fetchListOperationAuditLogs } from '@/api/hooks';
import type { OperationAuditLog } from '@/api/types';

/** 审计日志页（基座审计菜单：只读列表） */
const OperationAuditLogPage = () => {
  const { t } = useTranslation('audit');
  const columns: ProColumns<OperationAuditLog>[] = [
  { title: 'ID', dataIndex: 'id', width: 70, search: false },
  { title: t('username'), dataIndex: 'username', width: 130 },
  { title: t('resourceType'), dataIndex: 'resourceType', width: 130 },
  { title: t('resourceId'), dataIndex: 'resourceId', width: 100 },
  { title: t('action'), dataIndex: 'action', width: 110, render: (_, r) => String(r.action ?? '-') },
  { title: t('success'), dataIndex: 'success', width: 90, render: (_, r) => (r.success ? t('successTrue') : t('successFalse')) },
  { title: t('ipAddress'), dataIndex: 'ipAddress', width: 130 },
  { title: t('createdAt'), dataIndex: 'createdAt', width: 160, render: (_, r) => (r.createdAt ? dayjs(r.createdAt).format('YYYY-MM-DD HH:mm:ss') : '-') },
  ];

  return <AuditLogTable<OperationAuditLog> columns={columns} headerTitle={t('operationTitle')} fetcher={fetchListOperationAuditLogs} />;
};

export default OperationAuditLogPage;
