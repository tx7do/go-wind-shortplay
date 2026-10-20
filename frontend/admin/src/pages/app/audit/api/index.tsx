import type { ProColumns } from '@ant-design/pro-components';
import { useTranslation } from 'react-i18next';
import dayjs from 'dayjs';

import AuditLogTable from '../AuditLogTable';
import { fetchListApiAuditLogs } from '@/api/hooks';
import type { ApiAuditLog } from '@/api/types';

/** 审计日志页（基座审计菜单：只读列表） */
const ApiAuditLogPage = () => {
  const { t } = useTranslation('audit');
  const columns: ProColumns<ApiAuditLog>[] = [
  { title: 'ID', dataIndex: 'id', width: 70, search: false },
  { title: t('username'), dataIndex: 'username', width: 120 },
  { title: t('httpMethod'), dataIndex: 'httpMethod', width: 90 },
  { title: t('path'), dataIndex: 'path', ellipsis: true },
  { title: t('apiOperation'), dataIndex: 'apiOperation', ellipsis: true },
  { title: t('latencyMs'), dataIndex: 'latencyMs', width: 100 },
  { title: t('createdAt'), dataIndex: 'createdAt', width: 160, render: (_, r) => (r.createdAt ? dayjs(r.createdAt).format('YYYY-MM-DD HH:mm:ss') : '-') },
  ];

  return <AuditLogTable<ApiAuditLog> columns={columns} headerTitle={t('apiTitle')} fetcher={fetchListApiAuditLogs} />;
};

export default ApiAuditLogPage;
