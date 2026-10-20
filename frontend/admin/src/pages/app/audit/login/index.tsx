import type { ProColumns } from '@ant-design/pro-components';
import { useTranslation } from 'react-i18next';
import dayjs from 'dayjs';

import AuditLogTable from '../AuditLogTable';
import { fetchListLoginAuditLogs } from '@/api/hooks';
import type { LoginAuditLog } from '@/api/types';

/** 审计日志页（基座审计菜单：只读列表） */
const LoginAuditLogPage = () => {
  const { t } = useTranslation('audit');
  const columns: ProColumns<LoginAuditLog>[] = [
  { title: 'ID', dataIndex: 'id', width: 70, search: false },
  { title: t('username'), dataIndex: 'username', width: 140 },
  { title: t('ipAddress'), dataIndex: 'ipAddress', width: 140 },
  { title: t('actionType'), dataIndex: 'actionType', width: 120, render: (_, r) => String(r.actionType ?? '-') },
  { title: t('status'), dataIndex: 'status', width: 110, render: (_, r) => String(r.status ?? '-') },
  { title: t('failureReason'), dataIndex: 'failureReason', ellipsis: true, render: (_, r) => r.failureReason || '-' },
  { title: t('createdAt'), dataIndex: 'createdAt', width: 160, render: (_, r) => (r.createdAt ? dayjs(r.createdAt).format('YYYY-MM-DD HH:mm:ss') : '-') },
  ];

  return <AuditLogTable<LoginAuditLog> columns={columns} headerTitle={t('loginTitle')} fetcher={fetchListLoginAuditLogs} />;
};

export default LoginAuditLogPage;
