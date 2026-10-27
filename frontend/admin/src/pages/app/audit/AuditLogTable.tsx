import { useRef, useState } from 'react';
import type { ActionType, ProColumns } from '@ant-design/pro-components';
import ListTable from '@/components/common/ListTable';
import { Input, App } from 'antd';
import { DownloadOutlined } from '@ant-design/icons';
import { TABLE } from '@/config/constants';
import { useProTableScrollY } from '@/hooks/useProTableScrollY';
import { useTranslation } from 'react-i18next';
import { type ListParams } from '@/api/hooks';
import { adminHttp } from '@/api/client';
import type { ListResponse } from '@/api/types';

interface AuditLogTableProps<T> {
  columns: ProColumns<T>[];
  headerTitle: string;
  fetcher: (params: ListParams) => Promise<ListResponse<T>>;
  /** 关键字搜索的后端过滤键（如 username___contains）；缺省不出搜索框 */
  searchKey?: string;
  /** 服务端导出 type（login/api/operation/data-access/permission）；缺省不出导出按钮 */
  exportType?: string;
}

/**
 * 审计日志通用列表（基座 audit 域五个日志页共用）：
 * 只读分页列表，列定义由各页面注入；查询参数直接透传 PagingRequest。
 */
const AuditLogTable = <T extends { id?: number }>({
  columns,
  headerTitle,
  fetcher,
  searchKey,
  exportType,
}: AuditLogTableProps<T>) => {
  const actionRef = useRef<ActionType>(null);
  const containerRef = useRef<HTMLDivElement>(null);
  const tableScrollY = useProTableScrollY(containerRef);
  const { message } = App.useApp();
  const { t } = useTranslation('audit');
  const [keyword, setKeyword] = useState('');
  const [exporting, setExporting] = useState(false);

  // 审计导出走服务端端点（Authorization 头经 axios 拦截器注入），
  // blob 拉回后触发浏览器下载
  const handleExport = async () => {
    if (!exportType) return;
    setExporting(true);
    try {
      const res = await adminHttp.get<Blob>('audit-logs:export', {
        params: {
          type: exportType,
          ...(keyword ? { query: keyword } : {}),
        },
        responseType: 'blob',
      });
      const url = URL.createObjectURL(res as unknown as Blob);
      const a = document.createElement('a');
      a.href = url;
      a.download = `audit-${exportType}-${Date.now()}.csv`;
      a.click();
      URL.revokeObjectURL(url);
      message.success(t('exportSuccess'));
    } catch {
      message.error(t('exportFailed'));
    } finally {
      setExporting(false);
    }
  };

  return (
    <div
      ref={containerRef}
      className="page-container-content"
      style={{ padding: '0 8px', height: '100%' }}
    >
      <ListTable<T>
        actionRef={actionRef}
        columns={columns}
        headerTitle={headerTitle}
        toolBarRender={
          searchKey || exportType
            ? () => [
                searchKey ? (
                  <Input.Search
                    key="search"
                    allowClear
                    placeholder={headerTitle}
                    style={{ width: 220 }}
                    onSearch={(value) => {
                      setKeyword(value.trim());
                      actionRef.current?.reload();
                    }}
                  />
                ) : (
                  <span key="search-spacer" />
                ),
                exportType ? (
                  <a key="export" onClick={() => void handleExport()}>
                    {exporting ? t('exporting') : ''}{!exporting && <DownloadOutlined />} {exporting ? '...' : t('export')}
                  </a>
                ) : (
                  <span key="export-spacer" />
                ),
              ]
            : undefined
        }
        request={async (params) => {
          const response = await fetcher({
            page: params.current || 1,
            pageSize: params.pageSize || TABLE.DEFAULT_PAGE_SIZE,
            query: searchKey && keyword ? JSON.stringify({ [searchKey]: keyword }) : undefined,
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
        scroll={{ x: 1000, y: tableScrollY }}
      />
    </div>
  );
};

export default AuditLogTable;
