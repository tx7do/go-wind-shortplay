/**
 * 用户管理列表页
 * 模式对齐底座 opm/user（ProTable + Drawer 新建/编辑），去组织/角色/租户：
 * 列表（用户名/昵称模糊搜索）+ 新建/编辑 + 启用禁用 + 删除。
 */
import { useRef, useState } from 'react';
import type { ProColumns, ActionType } from '@ant-design/pro-components';
import ListTable from '@/components/common/ListTable';
import { Avatar, Button, Popconfirm, Switch, Tag, App } from 'antd';
import { DeleteOutlined, EditOutlined, PlusOutlined, UserOutlined } from '@ant-design/icons';
import { useQueryClient } from '@tanstack/react-query';
import { useTranslation } from 'react-i18next';
import dayjs from 'dayjs';

import { TABLE } from '@/config/constants';
import { useProTableScrollY } from '@/hooks/useProTableScrollY';
import {
  fetchListUsers,
  useDeleteUser,
  useUpdateUserStatus,
} from '@/api/hooks';
import { USER_STATUS } from '@/api/types';
import type { AppUser } from '@/api/types';
import UserDrawer from './UserDrawer';

const PAGE_SIZE_MAX = 50; // 后端 pageSize 上限

const UserManagement = () => {
  const { t } = useTranslation('user');
  const actionRef = useRef<ActionType>(null);
  const containerRef = useRef<HTMLDivElement>(null);
  const tableScrollY = useProTableScrollY(containerRef);
  const queryClient = useQueryClient();
  const { message } = App.useApp();

  const [drawerOpen, setDrawerOpen] = useState(false);
  const [drawerMode, setDrawerMode] = useState<'create' | 'edit'>('create');
  const [editingUser, setEditingUser] = useState<AppUser | null>(null);

  const refresh = () => {
    actionRef.current?.reload();
    queryClient.invalidateQueries({ queryKey: ['listUsers'] });
  };

  const deleteMutation = useDeleteUser({
    onSuccess: () => {
      message.success(t('deleteSuccess'));
      refresh();
    },
    onError: (error: Error) => {
      message.error(error.message || t('deleteFailed'));
    },
  });

  const statusMutation = useUpdateUserStatus({
    onSuccess: () => {
      message.success(t('statusChangeSuccess'));
      refresh();
    },
    onError: (error: Error) => {
      message.error(error.message || t('statusChangeFailed'));
    },
  });

  const isDisabled = (record: AppUser) => record.status === USER_STATUS.DISABLED;

  const columns: ProColumns<AppUser>[] = [
    {
      title: 'ID',
      dataIndex: 'id',
      width: 70,
      search: false,
    },
    {
      title: t('username'),
      dataIndex: 'query',
      width: 160,
      fieldProps: {
        placeholder: t('queryPlaceholder'),
        allowClear: true,
      },
      render: (_, record) => (
        <span style={{ display: 'inline-flex', alignItems: 'center', gap: 8 }}>
          <Avatar src={record.avatarUrl} size="small" icon={<UserOutlined />}>
            {(record.nickname ?? record.username ?? '?').slice(0, 1)}
          </Avatar>
          {record.username}
        </span>
      ),
    },
    {
      title: t('nickname'),
      dataIndex: 'nickname',
      search: false,
      width: 160,
      ellipsis: true,
    },
    {
      title: t('bio'),
      dataIndex: 'bio',
      search: false,
      width: 220,
      ellipsis: true,
      render: (_, record) => record.bio || '-',
    },
    {
      title: t('status'),
      dataIndex: 'status',
      width: 120,
      search: false,
      render: (_, record) => {
        const disabled = isDisabled(record);
        return (
          <Popconfirm
            title={disabled ? t('enableConfirmTitle') : t('disableConfirmTitle')}
            description={disabled ? undefined : t('disableConfirmDesc')}
            onConfirm={() =>
              record.id != null &&
              statusMutation.mutate({
                id: record.id,
                status: disabled ? USER_STATUS.NORMAL : USER_STATUS.DISABLED,
              })
            }
            okText={t('common:button.ok')}
            cancelText={t('common:button.cancel')}
          >
            <span style={{ display: 'inline-flex', alignItems: 'center', gap: 8, cursor: 'pointer' }}>
              <Tag color={disabled ? 'error' : 'success'}>
                {disabled ? t('statusDisabled') : t('statusNormal')}
              </Tag>
              <Switch
                size="small"
                checked={!disabled}
                loading={statusMutation.isPending}
              />
            </span>
          </Popconfirm>
        );
      },
    },
    {
      title: t('createdAt'),
      dataIndex: 'createdAt',
      search: false,
      width: 160,
      render: (_, record) =>
        record.createdAt ? dayjs(record.createdAt).format('YYYY-MM-DD HH:mm') : '',
    },
    {
      title: t('action'),
      valueType: 'option',
      width: 120,
      fixed: 'right',
      render: (_, record) => [
        <a
          key="edit"
          onClick={() => {
            setEditingUser(record);
            setDrawerMode('edit');
            setDrawerOpen(true);
          }}
        >
          <EditOutlined />
        </a>,
        <Popconfirm
          key="delete"
          title={t('deleteConfirmTitle')}
          description={t('deleteConfirmDesc', { moduleName: t('moduleName') })}
          onConfirm={() => record.id != null && deleteMutation.mutate(record.id)}
          okText={t('common:button.ok')}
          cancelText={t('common:button.cancel')}
        >
          <a style={{ color: 'var(--ant-color-error)' }}>
            <DeleteOutlined />
          </a>
        </Popconfirm>,
      ],
    },
  ];

  return (
    <>
      <div
        ref={containerRef}
        className="page-container-content"
        style={{ padding: '0 8px', height: '100%' }}
      >
        <ListTable<AppUser>
          actionRef={actionRef}
          columns={columns}
          headerTitle={t('userList')}
          request={async (params) => {
            const response = await fetchListUsers({
              page: params.current || 1,
              pageSize: Math.min(params.pageSize || TABLE.DEFAULT_PAGE_SIZE, PAGE_SIZE_MAX),
              query: typeof params.query === 'string' ? params.query : undefined,
            });
            return {
              data: response.items || [],
              total: Number(response.total ?? 0),
              success: true,
            };
          }}
          rowKey="id"
          search={{
            labelWidth: 'auto',
            defaultCollapsed: false,
            span: 8,
          }}
          pagination={{
            defaultPageSize: TABLE.DEFAULT_PAGE_SIZE,
            showSizeChanger: true,
            showQuickJumper: true,
            pageSizeOptions: ['10', '20', '50'],
          }}
          toolBarRender={() => [
            <Button
              key="create"
              type="primary"
              icon={<PlusOutlined />}
              size="small"
              onClick={() => {
                setEditingUser(null);
                setDrawerMode('create');
                setDrawerOpen(true);
              }}
            >
              {t('create')}
            </Button>,
          ]}
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

      <UserDrawer
        open={drawerOpen}
        mode={drawerMode}
        data={editingUser}
        onClose={() => {
          setDrawerOpen(false);
          setEditingUser(null);
        }}
        onSuccess={refresh}
      />
    </>
  );
};

export default UserManagement;
