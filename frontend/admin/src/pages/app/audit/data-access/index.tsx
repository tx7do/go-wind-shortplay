import type { ProColumns } from '@ant-design/pro-components';
import { useTranslation } from 'react-i18next';
import dayjs from 'dayjs';

import AuditLogTable from '../AuditLogTable';
import { fetchDataAccessAuditLogs } from '@/api/hooks';
import type { DataAccessAuditLog } from '@/api/types';

/** 审计日志页（基座审计菜单：只读列表） */
const DataAccessAuditLogPage = () => {
  const { t } = useTranslation('audit');
  const columns: ProColumns<DataAccessAuditLog>[] = [
  { title: 'ID', dataIndex: 'id', width: 70, search: false },
  { title: t('username'), dataIndex: 'username', width: 120 },
  { title: t('dataSource'), dataIndex: 'dataSource', width: 110 },
  { title: t('tableName'), dataIndex: 'tableName', width: 130 },
  { title: t('accessType'), dataIndex: 'accessType', width: 120, render: (_, r) => String(r.accessType ?? '-') },
  { title: t('affectedRows'), dataIndex: 'affectedRows', width: 100 },
  { title: t('success'), dataIndex: 'success', width: 90, render: (_, r) => (r.success ? t('successTrue') : t('successFalse')) },
  { title: t('createdAt'), dataIndex: 'createdAt', width: 160, render: (_, r) => (r.createdAt ? dayjs(r.createdAt).format('YYYY-MM-DD HH:mm:ss') : '-') },
  ];

  return <AuditLogTable<DataAccessAuditLog> columns={columns} headerTitle={t('dataAccessTitle')} fetcher={fetchDataAccessAuditLogs} />;
};

export default DataAccessAuditLogPage;
