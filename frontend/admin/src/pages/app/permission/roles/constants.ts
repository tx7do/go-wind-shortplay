// 基座拷贝文件（源：go-wind-cms frontend/admin 同路径实现）：为方便后续整文件重拷贝同步，
// 保持上游代码形态（any 占位/编辑期 setState 回填等），lint 严格规则已在 eslint.config.js 集中降档。
/**
 * 角色模块枚举映射常量（从 go-wind-cms permission/role/constants.ts 拷贝）。
 * 裁剪：短剧 Role proto 无数据权限范围（五档）/字段权限/授权组织单元字段，
 * 相应常量段与 cms 相比整体移除；权限树构建工具原样保留。
 */

type TFn = (key: string, options?: Record<string, any>) => string;

// ========== 角色状态（与菜单模块一致：ON/OFF） ==========

export const STATUS_COLORS: Record<string, string> = {
  ON: 'success',
  OFF: 'error',
};

export function getStatusMap(t: TFn) {
  return {
    ON: { text: t('statusMap.ON'), color: STATUS_COLORS.ON },
    OFF: { text: t('statusMap.OFF'), color: STATUS_COLORS.OFF },
  };
}

export function getStatusOptions(t: TFn) {
  return [
    { label: t('statusMap.ON'), value: 'ON' },
    { label: t('statusMap.OFF'), value: 'OFF' },
  ];
}

// ========== 权限树构建 ==========

interface TreeNode {
  key: number | string;
  title: string;
  children?: TreeNode[];
}

/**
 * 根据权限组和权限列表构建权限树。
 * 权限组 API 返回嵌套结构（children 含子组），需递归处理。
 * 每个组节点下附加匹配的权限（通过 groupId 关联）。
 */
export function buildPermissionTree(
  groups: Array<{ id?: number | string; title?: string; name?: string; code?: string; children?: any[] }>,
  permissions: Array<{
    id?: number | string;
    title?: string;
    name?: string;
    code?: string;
    groupId?: number | string;
  }>,
): TreeNode[] {
  if (!groups || groups.length === 0) return [];

  return groups.map((group) => {
    // 子权限组（递归）
    const subGroups = buildPermissionTree(group.children || [], permissions);
    // 匹配的权限
    const matchedPerms = (permissions || [])
      .filter((p) => String(p.groupId) === String(group.id))
      .map((p) => ({
        key: Number(p.id),
        title: p.title || p.name || p.code || String(p.id),
      }));

    const children = [...subGroups, ...matchedPerms];
    return {
      key: `g_${group.id}`,
      title: group.title || group.name || group.code || String(group.id),
      children: children.length > 0 ? children : undefined,
    };
  });
}

/**
 * 从权限树勾选值中提取所有数字 ID（过滤掉非数字值）
 */
export function filterNumbers(values: any[]): number[] {
  if (!Array.isArray(values)) return [];
  return values
    .flat(Infinity)
    .filter((v) => typeof v === 'number' && !isNaN(v))
    .map((v) => Number(v));
}

/**
 * 递归收集树中所有「叶子节点」（无 children）的 key。
 * 用于提交勾选值时剥离父节点 key：
 * 这些 Tree 默认开启父子联动，勾选某父节点下全部子节点时父节点会被自动勾选，
 * 其 key（权限组/父菜单的 ID）会混入 checkedKeys。若直接 filterNumbers 提交，
 * 组/父菜单 ID 会被后端当作权限/菜单 ID 处理，可能造成越权绑定。
 * 这里用叶子集合对 checkedKeys 求交集，只保留真正的叶子 ID。
 */
export function extractLeafIds(checkedKeys: any[], treeData: any[]): number[] {
  if (!Array.isArray(checkedKeys) || !Array.isArray(treeData)) return [];
  const leafIds = new Set<string | number>();
  const collect = (nodes: any[]) => {
    for (const node of nodes) {
      if (node.children?.length > 0) {
        collect(node.children);
      } else {
        leafIds.add(node.key);
      }
    }
  };
  collect(treeData);
  // 只返回数字 key（权限 ID），过滤字符串 key（权限组 g_xxx）
  return checkedKeys
    .flat(Infinity)
    .filter((v) => leafIds.has(v) && typeof v === 'number')
    .map((v) => Number(v));
}


// ========== 权限继承（父子角色） ==========

/**
 * 按父角色权限上限集（cap）过滤权限树数据源——在 buildPermissionTree 之前调用。
 * 只保留 cap 内的权限点，以及（递归）仍含至少一个保留权限点的权限组。
 * cap 为 null/undefined/空数组表示无父角色（根角色），原样返回全量。
 */
export function filterPermissionsByCap(
  groups: any[],
  permissions: any[],
  capIds: number[] | null | undefined,
): { groups: any[]; permissions: any[] } {
  if (!capIds || capIds.length === 0) return { groups, permissions };
  const cap = new Set(capIds.map(Number));
  const kept = (permissions || []).filter((p) => cap.has(Number(p.id)));
  const filterGroups = (list: any[]): any[] =>
    (list || [])
      .map((g) => ({ ...g, children: filterGroups(g.children || []) }))
      .filter(
        (g) => g.children.length > 0 || kept.some((p) => String(p.groupId) === String(g.id)),
      );
  return { groups: filterGroups(groups), permissions: kept };
}

/**
 * 收集自身及其全部后代角色 ID（按 parentId 嵌套关系）。
 * 父角色候选下拉用它排除自身与后代，防止在前端就构造出环（后端另有兜底校验）。
 */
export function collectSelfAndDescendantIds(items: any[], selfId?: number): number[] {
  if (!selfId) return [];
  const byParent = new Map<number, number[]>();
  for (const it of items || []) {
    const pid = Number(it.parentId || 0);
    if (!byParent.has(pid)) byParent.set(pid, []);
    byParent.get(pid)!.push(Number(it.id));
  }
  const result = new Set<number>([Number(selfId)]);
  const stack = [Number(selfId)];
  while (stack.length > 0) {
    const cur = stack.pop()!;
    for (const child of byParent.get(cur) || []) {
      if (!result.has(child)) {
        result.add(child);
        stack.push(child);
      }
    }
  }
  return [...result];
}

/**
 * 把角色列表按 parentId 嵌套为 TreeSelect 数据（森林，缺父的孤行落为根节点），
 * 排除 excludeIds（自身及后代）。
 */
export function buildRoleTreeOptions(
  items: any[],
  excludeIds: number[],
): { value: number; title: string; children?: any[] }[] {
  const excluded = new Set(excludeIds.map(Number));
  const nodes = new Map<number, { value: number; title: string; children?: any[]; pid: number }>();
  for (const it of items || []) {
    const id = Number(it.id);
    if (excluded.has(id)) continue;
    nodes.set(id, {
      value: id,
      title: it.name || it.code || String(id),
      pid: Number(it.parentId || 0),
    });
  }
  const roots: { value: number; title: string; children?: any[] }[] = [];
  for (const node of nodes.values()) {
    const parent = node.pid > 0 ? nodes.get(node.pid) : undefined;
    if (parent) {
      (parent.children ??= []).push(node);
    } else {
      roots.push(node);
    }
  }
  const strip = (list: any[]): any[] =>
    list.map((n) => {
      const { pid: _pid, ...rest } = n;
      if (rest.children?.length > 0) {
        rest.children = strip(rest.children);
      } else {
        delete rest.children;
      }
      return rest;
    });
  return strip(roots) as { value: number; title: string; children?: any[] }[];
}
