import type { ProColumns } from '@ant-design/pro-components';
import { useTranslation } from 'react-i18next';
import dayjs from 'dayjs';

import AuditLogTable from '../AuditLogTable';
import { fetchListPermissionAuditLogs } from '@/api/hooks';
import type { PermissionAuditLog } from '@/api/types';

/** 审计日志页（基座审计菜单：只读列表） */
const PermissionAuditLogPage = () => {
  const { t } = useTranslation('audit');
  const columns: ProColumns<PermissionAuditLog>[] = [
  { title: 'ID', dataIndex: 'id', width: 70, search: false },
  { title: t('username'), dataIndex: 'username', width: 130 },
  { title: t('resourceType'), dataIndex: 'resourceType', width: 140 },
  { title: t('resourceId'), dataIndex: 'resourceId', width: 100 },
  { title: t('action'), dataIndex: 'action', width: 120, render: (_, r) => String(r.action ?? '-') },
  { title: t('success'), dataIndex: 'success', width: 90, render: (_, r) => (r.success ? t('successTrue') : t('successFalse')) },
  { title: t('createdAt'), dataIndex: 'createdAt', width: 160, render: (_, r) => (r.createdAt ? dayjs(r.createdAt).format('YYYY-MM-DD HH:mm:ss') : '-') },
  ];

  return <AuditLogTable<PermissionAuditLog> columns={columns} headerTitle={t('permissionTitle')} fetcher={fetchListPermissionAuditLogs} />;
};

export default PermissionAuditLogPage;
