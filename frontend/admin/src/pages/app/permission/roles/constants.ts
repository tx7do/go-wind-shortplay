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
