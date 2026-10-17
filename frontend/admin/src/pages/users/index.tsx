/**
 * 用户管理：
 * - GET /users（分页、query 搜索）
 * - 创建用户（POST，username/password/nickname）
 * - 编辑（PUT，nickname/bio/password）
 * - 启用 / 禁用（PUT /users/{id}/status，status 2 正常 / 1 禁用）
 * - 删除（DELETE）
 */
import { useCallback, useEffect, useState } from 'react';
import {
  Button,
  Form,
  Input,
  Modal,
  Popconfirm,
  Space,
  Table,
  Tag,
  message,
} from 'antd';
import type { ColumnsType } from 'antd/es/table';
import { PlusOutlined, ReloadOutlined, SearchOutlined } from '@ant-design/icons';
import { createUser, deleteUser, listUsers, updateUser, updateUserStatus } from '../../api/user';
import type { User } from '../../types';
import { USER_STATUS_MAP, formatDateTime } from '../../utils/format';

/** 创建 / 编辑弹窗状态 */
interface UserModalState {
  open: boolean;
  /** null 表示新建 */
  editing: User | null;
}

interface UserFormValues {
  username?: string;
  nickname: string;
  password?: string;
  bio?: string;
}

export default function UsersPage() {
  const [list, setList] = useState<User[]>([]);
  const [total, setTotal] = useState(0);
  const [loading, setLoading] = useState(false);
  const [page, setPage] = useState(1);
  const [pageSize, setPageSize] = useState(10);
  // 搜索框输入值与已生效关键字
  const [keywordInput, setKeywordInput] = useState('');
  const [keyword, setKeyword] = useState('');

  const [modalState, setModalState] = useState<UserModalState>({ open: false, editing: null });
  const [form] = Form.useForm<UserFormValues>();
  const [submitting, setSubmitting] = useState(false);

  const fetchList = useCallback(
    async (params: { page: number; pageSize: number; keyword: string }) => {
      setLoading(true);
      try {
        const data = await listUsers({
          page: params.page,
          pageSize: params.pageSize,
          query: params.keyword || undefined,
        });
        setList(data.items);
        setTotal(data.total);
      } catch {
        // 错误已由拦截器统一提示
      } finally {
        setLoading(false);
      }
    },
    [],
  );

  useEffect(() => {
    fetchList({ page, pageSize, keyword });
  }, [fetchList, page, pageSize, keyword]);

  const refresh = () => fetchList({ page, pageSize, keyword });

  /** 打开新建弹窗 */
  const openCreate = () => {
    form.resetFields();
    setModalState({ open: true, editing: null });
  };

  /** 打开编辑弹窗（回填昵称 / 简介；密码留空表示不修改） */
  const openEdit = (record: User) => {
    form.resetFields();
    form.setFieldsValue({ username: record.username, nickname: record.nickname, bio: record.bio });
    setModalState({ open: true, editing: record });
  };

  /** 提交创建 / 编辑 */
  const submitModal = async (values: UserFormValues) => {
    const editing = modalState.editing;
    setSubmitting(true);
    try {
      if (editing) {
        await updateUser(editing.id, {
          nickname: values.nickname,
          password: values.password || undefined,
          bio: values.bio,
        });
        message.success('用户已更新');
      } else {
        await createUser({
          username: (values.username ?? '').trim(),
          password: values.password ?? '',
          nickname: values.nickname,
          bio: values.bio,
        });
        message.success('用户已创建');
      }
      setModalState({ open: false, editing: null });
      refresh();
    } catch {
      // 错误已由拦截器统一提示
    } finally {
      setSubmitting(false);
    }
  };

  /** 启用 / 禁用（status：2 正常 / 1 禁用） */
  const toggleStatus = async (record: User) => {
    const nextStatus = record.status === 2 ? 1 : 2;
    await updateUserStatus(record.id, nextStatus);
    message.success(nextStatus === 2 ? '已启用' : '已禁用');
    refresh();
  };

  /** 删除用户 */
  const handleDelete = async (record: User) => {
    await deleteUser(record.id);
    message.success('已删除');
    refresh();
  };

  const columns: ColumnsType<User> = [
    { title: 'ID', dataIndex: 'id', width: 80 },
    { title: '用户名', dataIndex: 'username', width: 160 },
    { title: '昵称', dataIndex: 'nickname', width: 160, render: (v?: string) => v || '—' },
    {
      title: '状态',
      dataIndex: 'status',
      width: 90,
      render: (s: number) => (
        <Tag color={USER_STATUS_MAP[s]?.color}>{USER_STATUS_MAP[s]?.label ?? '未知'}</Tag>
      ),
    },
    { title: '简介', dataIndex: 'bio', ellipsis: true, render: (v?: string) => v || '—' },
    { title: '创建时间', dataIndex: 'createdAt', width: 170, render: formatDateTime },
    {
      title: '操作',
      key: 'actions',
      fixed: 'right',
      width: 200,
      render: (_value, record) => (
        <Space size={0}>
          <Button type="link" size="small" onClick={() => openEdit(record)}>
            编辑
          </Button>
          <Popconfirm
            title={record.status === 2 ? '禁用该用户？' : '启用该用户？'}
            description={record.status === 2 ? '禁用后该用户将无法登录。' : '启用后该用户可正常登录。'}
            okText="确认"
            cancelText="取消"
            onConfirm={() => toggleStatus(record)}
          >
            <Button type="link" size="small" danger={record.status === 2}>
              {record.status === 2 ? '禁用' : '启用'}
            </Button>
          </Popconfirm>
          <Popconfirm
            title="删除用户"
            description="确定删除该用户吗？此操作不可恢复。"
            okText="删除"
            okButtonProps={{ danger: true }}
            cancelText="取消"
            onConfirm={() => handleDelete(record)}
          >
            <Button type="link" size="small" danger>
              删除
            </Button>
          </Popconfirm>
        </Space>
      ),
    },
  ];

  return (
    <div className="page-table">
      {/* 工具栏：搜索 + 新建 */}
      <Space style={{ marginBottom: 16 }} wrap>
        <Input
          allowClear
          placeholder="按用户名 / 昵称搜索"
          prefix={<SearchOutlined />}
          style={{ width: 240 }}
          value={keywordInput}
          onChange={(e) => setKeywordInput(e.target.value)}
          onPressEnter={() => {
            setKeyword(keywordInput);
            setPage(1);
          }}
        />
        <Button
          type="primary"
          icon={<SearchOutlined />}
          onClick={() => {
            setKeyword(keywordInput);
            setPage(1);
          }}
        >
          查询
        </Button>
        <Button
          icon={<ReloadOutlined />}
          onClick={() => {
            setKeywordInput('');
            setKeyword('');
            setPage(1);
            fetchList({ page: 1, pageSize, keyword: '' });
          }}
        >
          重置
        </Button>
        <Button type="primary" icon={<PlusOutlined />} onClick={openCreate}>
          新建用户
        </Button>
      </Space>

      <Table<User>
        rowKey="id"
        columns={columns}
        dataSource={list}
        loading={loading}
        scroll={{ x: 1000 }}
        pagination={{
          current: page,
          pageSize,
          total,
          showSizeChanger: true,
          pageSizeOptions: [10, 20, 50],
          showTotal: (t) => `共 ${t} 条`,
          onChange: (p, ps) => {
            setPage(p);
            setPageSize(ps);
          },
        }}
      />

      {/* 创建 / 编辑用户弹窗 */}
      <Modal
        open={modalState.open}
        title={modalState.editing ? `编辑用户 #${modalState.editing.id}` : '新建用户'}
        okText="保存"
        cancelText="取消"
        confirmLoading={submitting}
        onCancel={() => setModalState({ open: false, editing: null })}
        onOk={() => form.submit()}
      >
        <Form<UserFormValues> form={form} layout="vertical" onFinish={submitModal}>
          <Form.Item
            name="username"
            label="用户名"
            rules={modalState.editing ? [] : [{ required: true, message: '请输入用户名' }]}
          >
            <Input placeholder="登录名（唯一）" disabled={!!modalState.editing} autoComplete="off" />
          </Form.Item>
          <Form.Item
            name="nickname"
            label="昵称"
            rules={[{ required: true, message: '请输入昵称' }]}
          >
            <Input placeholder="昵称" />
          </Form.Item>
          <Form.Item
            name="password"
            label={modalState.editing ? '新密码（留空则不修改）' : '初始密码'}
            rules={modalState.editing ? [] : [{ required: true, message: '请输入密码' }]}
          >
            <Input.Password
              placeholder={modalState.editing ? '留空表示不修改密码' : '初始密码'}
              autoComplete="new-password"
            />
          </Form.Item>
          <Form.Item name="bio" label="简介（可选）">
            <Input.TextArea rows={2} maxLength={200} placeholder="个人简介" />
          </Form.Item>
        </Form>
      </Modal>
    </div>
  );
}
