/**
 * 用户管理列表页（/admin/v1/users：短剧 App 用户域 AppUser 契约）
 *
 * 布局与请求模式对齐基座列表页（ContentContainer + ListTable +
 * PaginationQuery request + TableExportButton，同 go-wind-cms opm/user）；
 * 域形状按本仓后端 proto（username/nickname/avatarUrl/bio/status 1禁用-2正常）
 * 保持，附短剧特有的「作品」抽屉（GET /videos?authorId=）。
 */
import { useRef, useState } from 'react';
import type { ProColumns, ActionType } from '@ant-design/pro-components';
import TableExportButton from '@/components/common/TableExportButton';
import ListTable from '@/components/common/ListTable';
import { Avatar, Button, Popconfirm, Switch, Tag, App } from 'antd';
import {
  DeleteOutlined,
  EditOutlined,
  PlaySquareOutlined,
  PlusOutlined,
  UserOutlined,
} from '@ant-design/icons';
import { useQueryClient } from '@tanstack/react-query';
import { useTranslation } from 'react-i18next';
import dayjs from 'dayjs';

import { TABLE } from '@/config/constants';
import { useProTableScrollY } from '@/hooks/useProTableScrollY';
import { PaginationQuery } from '@/core';
import ContentContainer from '@/layouts/components/PageContainer/ContentContainer';
import {
  fetchListUsers,
  useDeleteUser,
  useUpdateUserStatus,
} from '@/api/hooks';
import { USER_STATUS_VALUE } from '@/api/types';
import type { AppUser } from '@/api/types';
import UserDrawer from './UserDrawer';
import UserVideosDrawer from './UserVideosDrawer';

const UserManagement = () => {
  const { t } = useTranslation('user');
  const actionRef = useRef<ActionType>(null);
  const queryClient = useQueryClient();
  const { message } = App.useApp();

  const containerRef = useRef<HTMLDivElement>(null);
  const tableScrollY = useProTableScrollY(containerRef);

  const [drawerOpen, setDrawerOpen] = useState(false);
  const [drawerMode, setDrawerMode] = useState<'create' | 'edit'>('create');
  const [editingUser, setEditingUser] = useState<AppUser | null>(null);

  // 「作品」抽屉：查看该用户发布的视频（GET /videos?authorId=）
  const [worksUser, setWorksUser] = useState<AppUser | null>(null);
  const [worksOpen, setWorksOpen] = useState(false);

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

  // 基座转发契约：status 1禁用 / 2正常（实测 protojson 数字形态，宽容接住字符串）
  const isDisabled = (record: AppUser) => {
    const v = Number(record.status ?? 0);
    return v === 1 || String(record.status ?? '').toUpperCase().includes('DISABLED');
  };

  const columns: ProColumns<AppUser>[] = [
    {
      title: 'ID',
      dataIndex: 'id',
      width: 70,
      hideInSearch: true,
    },
    {
      title: t('username'),
      dataIndex: 'username',
      width: 160,
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
      width: 160,
      ellipsis: true,
    },
    {
      title: t('bio'),
      dataIndex: 'bio',
      hideInSearch: true,
      width: 220,
      ellipsis: true,
      render: (_, record) => record.bio || '-',
    },
    {
      title: t('status'),
      dataIndex: 'status',
      width: 120,
      hideInSearch: true,
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
                status: disabled ? USER_STATUS_VALUE.NORMAL : USER_STATUS_VALUE.DISABLED,
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
      hideInSearch: true,
      width: 160,
      render: (_, record) =>
        record.createdAt ? dayjs(record.createdAt).format('YYYY-MM-DD HH:mm') : '',
    },
    {
      title: t('action'),
      valueType: 'option',
      width: 150,
      fixed: 'right',
      render: (_, record) => [
        <a
          key="works"
          onClick={() => {
            setWorksUser(record);
            setWorksOpen(true);
          }}
        >
          <PlaySquareOutlined /> {t('works')}
        </a>,
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
      <ContentContainer heightMode="fixed" padding="16px" bottomMargin={0}>
        <div ref={containerRef} className="page-container-content">
          <ListTable<AppUser>
            actionRef={actionRef}
            columns={columns}
            headerTitle={t('userList')}
            request={async (params) => {
              // 基座请求模式：PaginationQuery 序列化（字符串值自动 __contains）
              const query = new PaginationQuery({
                paging: {
                  page: params.current || 1,
                  pageSize: params.pageSize || TABLE.DEFAULT_PAGE_SIZE,
                },
                formValues: Object.fromEntries(
                  Object.entries(params).filter(
                    ([key]) => !['current', 'pageSize'].includes(key),
                  ),
                ),
              });

              const response = await fetchListUsers(query);

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
            }}
            pagination={{
              defaultPageSize: TABLE.DEFAULT_PAGE_SIZE,
              showSizeChanger: true,
              showQuickJumper: true,
            }}
            toolBarRender={() => [
              <TableExportButton
                key="export"
                fetcher={fetchListUsers}
                columns={columns}
                filename="users"
              />,
              <Button
                key="create"
                type="primary"
                icon={<PlusOutlined />}
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
              density: true,
              fullScreen: true,
              setting: true,
              reload: true,
            }}
            size="middle"
            bordered
            cardBordered={false}
            scroll={{ x: 1100, y: tableScrollY }}
          />
        </div>
      </ContentContainer>

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

      {/* 用户作品抽屉（authorId 过滤的视频列表） */}
      <UserVideosDrawer
        open={worksOpen}
        user={worksUser}
        onClose={() => {
          setWorksOpen(false);
          setWorksUser(null);
        }}
      />
    </>
  );
};

export default UserManagement;
