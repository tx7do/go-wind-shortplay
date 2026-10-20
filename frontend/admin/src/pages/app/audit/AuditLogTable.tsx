import { useRef } from 'react';
import type { ActionType, ProColumns } from '@ant-design/pro-components';
import ListTable from '@/components/common/ListTable';
import { TABLE } from '@/config/constants';
import { useProTableScrollY } from '@/hooks/useProTableScrollY';
import type { ListParams } from '@/api/hooks';
import type { ListResponse } from '@/api/types';

interface AuditLogTableProps<T> {
  columns: ProColumns<T>[];
  headerTitle: string;
  fetcher: (params: ListParams) => Promise<ListResponse<T>>;
}

/**
 * 审计日志通用列表（基座 audit 域五个日志页共用）：
 * 只读分页列表，列定义由各页面注入；查询参数直接透传 PagingRequest。
 */
const AuditLogTable = <T extends { id?: number }>({
  columns,
  headerTitle,
  fetcher,
}: AuditLogTableProps<T>) => {
  const actionRef = useRef<ActionType>(null);
  const containerRef = useRef<HTMLDivElement>(null);
  const tableScrollY = useProTableScrollY(containerRef);

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
        request={async (params) => {
          const response = await fetcher({
            page: params.current || 1,
            pageSize: params.pageSize || TABLE.DEFAULT_PAGE_SIZE,
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
