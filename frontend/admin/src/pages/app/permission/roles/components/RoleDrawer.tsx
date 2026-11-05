// 基座拷贝文件（源：go-wind-cms frontend/admin 同路径实现）：为方便后续整文件重拷贝同步，
// 保持上游代码形态（any 占位/编辑期 setState 回填等），lint 严格规则已在 eslint.config.js 集中降档。
import { useRef, useState, useEffect } from 'react';
import type { ProFormInstance } from '@ant-design/pro-components';
import {
  DrawerForm,
  ProFormText,
  ProFormDigit,
  ProFormTextArea,
  ProFormRadio,
  ProFormTreeSelect,
} from '@ant-design/pro-components';
import { App, Tree, Spin } from 'antd';
import { useQueryClient } from '@tanstack/react-query';
import { useTranslation } from 'react-i18next';
import type { permissionservicev1_Role as Role } from '@/api/generated/admin/service/v1';
import { useCreateRole, useUpdateRole, fetchGetRole, fetchListRoles } from '@/api/hooks/role';
import { fetchListPermissionGroups } from '@/api/hooks/permission-group';
import { fetchListPermissions } from '@/api/hooks/permission';
import { PaginationQuery } from '@/core';
import {
  getStatusOptions,
  buildPermissionTree,
  extractLeafIds,
  filterPermissionsByCap,
  collectSelfAndDescendantIds,
  buildRoleTreeOptions,
} from '../constants';

interface RoleDrawerProps {
  open: boolean;
  mode: 'create' | 'edit';
  data?: Role;
  onClose: () => void;
  onSuccess: () => void;
}

/**
 * 角色编辑/创建抽屉组件
 *
 * 从 go-wind-cms permission/role/components/RoleDrawer.tsx 拷贝，裁剪三块
 * cms 专属能力（短剧 Role proto 无对应字段，提交会被 protojson 拒/忽略）：
 * 1. 数据权限范围五档（dataScope）与 SELECTED_UNITS 授权组织单元树；
 * 2. 字段权限（User 资源隐藏字段）勾选；
 * 3. 描述字段的 AI 生成按钮（短剧后端无 AI 服务）。
 */
const RoleDrawer: React.FC<RoleDrawerProps> = ({ open, mode, data, onClose, onSuccess }) => {
  const { t } = useTranslation('role');
  const formRef = useRef<ProFormInstance>(null);
  const queryClient = useQueryClient();
  const { message, modal } = App.useApp();

  const [confirmLoading, setConfirmLoading] = useState(false);
  const [treeData, setTreeData] = useState<any[]>([]);
  const [checkedKeys, setCheckedKeys] = useState<number[]>([]);
  const [treeVersion, setTreeVersion] = useState(0);
  const [treeLoading, setTreeLoading] = useState(false);
  // 权限继承：父角色候选树（排除自身及后代防环）、当前选中父角色（0=根角色）、
  // 父角色权限上限集（null=无父角色，不收窄）
  const [roleTreeData, setRoleTreeData] = useState<any[]>([]);
  const [selectedParentId, setSelectedParentId] = useState(0);
  const [permCapIds, setPermCapIds] = useState<number[] | null>(null);
  // 权限树全量数据源（groups + permissions），父角色切换时按 cap 过滤重建
  const treeSourceRef = useRef<{ groups: any[]; permissions: any[] } | null>(null);

  // 按父角色上限集重建权限树；返回本次生效的 cap（供调用方做勾选收敛）。
  // 拉取父角色失败时按全量展示，保存仍由后端子集校验兜底。
  const rebuildTree = async (parentId: number | null): Promise<number[] | null> => {
    const src = treeSourceRef.current;
    if (!src) return null;
    let cap: number[] | null = null;
    if (parentId) {
      try {
        const parent = await fetchGetRole({ id: parentId });
        cap = ((parent as any)?.permissions || [])
          .map((v: any) => Number(v))
          .filter((v: any) => Number.isFinite(v));
      } catch (error) {
        console.error('加载父角色权限上限失败:', error);
      }
    }
    setPermCapIds(cap);
    const filtered = filterPermissionsByCap(src.groups, src.permissions, cap);
    if (filtered.groups.length === 0 && filtered.permissions.length > 0) {
      // 无权限组时，直接罗列权限（平铺，不嵌套）
      setTreeData(filtered.permissions.map((p) => ({
        key: Number(p.id),
        title: p.name || p.code || String(p.id),
      })));
    } else {
      setTreeData(buildPermissionTree(filtered.groups, filtered.permissions));
    }
    setTreeVersion((v) => v + 1);
    return cap;
  };

  // 切换父角色：重建权限树，并把已勾权限收敛到新 cap 内（后端保存时还有子集校验兜底）
  const handleParentChange = async (pid: number) => {
    setSelectedParentId(pid);
    formRef.current?.setFieldValue('parentId', pid);
    const cap = await rebuildTree(pid || null);
    if (pid && cap) {
      setCheckedKeys((prev) => prev.filter((k) => typeof k === 'number' && cap!.includes(k)));
    }
  };

  // 加载权限树数据
  useEffect(() => {
    if (open) {
      setTreeLoading(true);
      Promise.all([
        fetchListPermissionGroups(new PaginationQuery({ formValues: { status: 'ON' } })),
        fetchListPermissions(new PaginationQuery({ formValues: { status: 'ON' } })),
        fetchListRoles(new PaginationQuery({ paging: { page: 1, pageSize: 1000 }, formValues: { status: 'ON' } })),
      ])
        .then(async ([groupRes, permRes, roleRes]) => {
          treeSourceRef.current = {
            groups: groupRes?.items || [],
            permissions: permRes?.items || [],
          };
          setRoleTreeData(
            buildRoleTreeOptions(
              roleRes?.items || [],
              collectSelfAndDescendantIds(roleRes?.items || [], data?.id),
            ),
          );
          await rebuildTree(mode === 'edit' ? Number(data?.parentId || 0) : null);
        })
        .catch((error) => {
          console.error('加载权限树数据失败:', error);
          setTreeData([]);
        })
        .finally(() => setTreeLoading(false));
    } else {
      // 关闭即清空：权限勾选/树/父角色选择都是组件级 state，Drawer DOM 卸载
      // 不会清它们——不重置会把上个角色的勾选残留进下一次创建（静默越权）。
      treeSourceRef.current = null;
      setPermCapIds(null);
      setSelectedParentId(0);
      setTreeData([]);
      setCheckedKeys([]);
      setRoleTreeData([]);
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [open]);

  // 编辑模式填充表单
  useEffect(() => {
    if (open && mode === 'edit' && data) {
      setTimeout(() => {
        formRef.current?.setFieldsValue({
          name: data.name || '',
          code: data.code || '',
          sortOrder: (data as any).sortOrder ?? 1,
          status: data.status || 'ON',
          description: (data as any).description || '',
          // 父角色回填为数值（0=根角色），保证清空选择时提交的是显式 0 而非 undefined
          parentId: Number((data as any).parentId || 0),
        });
      }, 0);
      setSelectedParentId(Number((data as any).parentId || 0));
      // 设置已勾选的权限
      const perms = (data as any).permissions;
      if (Array.isArray(perms)) {
        setCheckedKeys(perms.filter((v: any) => typeof v === 'number'));
      }
    }
  }, [open, mode, data]);

  const createMutation = useCreateRole({
    onSuccess: () => {
      message.success(t('createSuccess'));
      onSuccess();
      onClose();
      queryClient.invalidateQueries({ queryKey: ['listRoles'] });
    },
    onError: (error: Error) => {
      message.error(error.message || t('createFailed'));
    },
  });

  const updateMutation = useUpdateRole({
    onSuccess: () => {
      message.success(t('updateSuccess'));
      onSuccess();
      onClose();
      queryClient.invalidateQueries({ queryKey: ['listRoles'] });
    },
    onError: (error: Error) => {
      message.error(error.message || t('updateFailed'));
    },
  });

  const handleSubmit = async (values: any) => {
    const submittedPerms = extractLeafIds(checkedKeys, treeData);

    // 保存收敛确认：存量越权（超出父角色上限）的已勾权限点在收窄后的树上不可见，
    // 提交时会被剥离，先向操作者确认（编辑时校验语义的前端引导；后端亦有校验兜底）。
    const storedPerms: number[] = Array.isArray((data as any)?.permissions)
      ? (data as any).permissions.filter((v: any) => typeof v === 'number')
      : [];
    const outOfCap = permCapIds
      ? storedPerms.filter((id) => !permCapIds!.includes(Number(id)))
      : [];

    const doSubmit = async () => {
      setConfirmLoading(true);
      try {
        const payload = {
          ...values,
          // 用叶子交集剥离权限组父节点 ID（父子联动会自动勾选父节点，
          // 组 ID 混入提交会被后端当作权限 ID，可能越权绑定）。
          permissions: submittedPerms,
          // 父角色始终随表单提交：0=根角色（清空父角色须显式 0 进 updateMask，
          // 否则后端三态语义会把它当"未声明"静默跳过）。
          parentId: selectedParentId || 0,
        };

        if (mode === 'create') {
          await createMutation.mutateAsync({ data: payload });
        } else if (data?.id) {
          await updateMutation.mutateAsync({ id: data.id, values: payload });
        }
      } finally {
        setConfirmLoading(false);
      }
    };

    if (outOfCap.length > 0) {
      modal.confirm({
        title: t('permTrimConfirmTitle'),
        content: t('permTrimConfirmContent', { count: outOfCap.length }),
        okText: t('common:button.submit'),
        cancelText: t('common:button.cancel'),
        onOk: doSubmit,
      });
      return;
    }
    await doSubmit();
  };

  return (
    <DrawerForm
      formRef={formRef}
      title={mode === 'create' ? t('create') : t('edit')}
      open={open}
      onOpenChange={(visible) => {
        if (!visible) {
          formRef.current?.resetFields();
          setCheckedKeys([]);
          // 权限继承中间态一并清空，防上个角色残留进下一次创建
          treeSourceRef.current = null;
          setPermCapIds(null);
          setSelectedParentId(0);
          setRoleTreeData([]);
          onClose();
        }
      }}
      initialValues={{
        sortOrder: 1,
        status: 'ON',
      }}
      onFinish={handleSubmit}
      submitter={{
        searchConfig: {
          submitText: t('common:button.submit'),
          resetText: t('common:button.cancel'),
        },
        submitButtonProps: {
          loading: confirmLoading || createMutation.isPending || updateMutation.isPending,
        },
        resetButtonProps: { onClick: onClose },
      }}
      drawerProps={{ destroyOnHidden: true, onClose, size: 600 }}
    >
      <ProFormText
        name="name"
        label={t('name')}
        placeholder={t('namePlaceholder')}
        rules={[{ required: true, message: t('requiredName') }]}
        fieldProps={{ allowClear: true }}
      />

      <ProFormText
        name="code"
        label={t('code')}
        placeholder={t('codePlaceholder')}
        rules={[{ required: true, message: t('requiredCode') }]}
        fieldProps={{ allowClear: true }}
      />

      <ProFormDigit
        name="sortOrder"
        label={t('sortOrder')}
        placeholder={t('sortOrderPlaceholder')}
        rules={[{ required: true }]}
        fieldProps={{ precision: 0, min: 0 }}
      />

      <ProFormRadio.Group
        name="status"
        label={t('status')}
        rules={[{ required: true, message: t('requiredStatus') }]}
        options={getStatusOptions(t)}
        fieldProps={{ optionType: 'button', buttonStyle: 'solid' }}
      />

      <ProFormTextArea
        name="description"
        label={t('description')}
        placeholder={t('descriptionPlaceholder')}
        fieldProps={{ allowClear: true, rows: 2 }}
      />

      {/* 权限继承：父角色（可选）。子角色的可选权限与保存校验均受父角色约束 */}
      <ProFormTreeSelect
        name="parentId"
        label={t('parentId')}
        placeholder={t('parentIdPlaceholder')}
        fieldProps={{
          showSearch: true,
          treeDefaultExpandAll: true,
          treeNodeFilterProp: 'title',
          allowClear: true,
          treeData: roleTreeData,
          onChange: (value: any) => {
            handleParentChange(typeof value === 'number' ? value : 0);
          },
        }}
      />

      {/* 权限树（创建/编辑均可勾选，随 Create/Update 提交；后端更新链路已修复
          「mask 剥离 permissions 致授权清空」缺陷，编辑提交权限即生效） */}
      <div className="mb-6">
        <label className="block mb-2 text-sm font-medium text-[color:var(--ant-color-text)]">
          {t('permissions')}
        </label>
        {permCapIds != null && (
          <p className="mb-1.5 text-xs text-[color:var(--ant-color-text-quaternary)]">
            {t('permCapHint')}
          </p>
        )}
        <Spin spinning={treeLoading}>
          {treeData.length > 0 ? (
            <div className="rounded-lg border border-[color:var(--ant-color-border-secondary)] bg-[color:var(--ant-color-fill-quaternary)] p-2.5">
              <Tree
                checkable
                checkedKeys={checkedKeys}
                onCheck={(checked) => {
                  setCheckedKeys(checked as number[]);
                }}
                treeData={treeData}
                defaultExpandAll
                key={treeVersion}
                className="max-h-80 overflow-auto"
              />
            </div>
          ) : (
            <div className="rounded-lg border border-dashed border-[color:var(--ant-color-border)] py-4 text-center text-sm text-[color:var(--ant-color-text-quaternary)]">
              {treeLoading ? '' : 'No permission data'}
            </div>
          )}
        </Spin>
      </div>
    </DrawerForm>
  );
};

export default RoleDrawer;
