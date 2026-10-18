/**
 * RBAC 域契约类型（手维护的最小子集）
 *
 * 路径与 go-wind-cms 的生成代码保持一致（`@/api/generated/admin/service/v1`），
 * 使从 cms 拷贝的页面/hook 可以原样 import、后续重拷贝零改动。短剧后端的
 * permission/identity proto 与 cms 基座逐字一致（role/menu/api/org_unit.proto
 * 已 diff 验证），本文件即按 cms 生成产物的形状裁剪而来——只保留 RBAC 四页、
 * 权限点/权限组与角色授权树用到的类型；短剧自有业务域（AppUser 等）仍在
 * `@/api/types`。后端 proto 变更时须同步此文件（对照 cms `make api` 产物）。
 *
 * 序列化约定（与全仓一致）：枚举是字符串全名（如 status: "ON"）、
 * int64 是 JSON 字符串、int32/uint32 是数字。
 */

/** google.protobuf.Timestamp 的 protojson 形态（RFC3339 字符串） */
export type wellKnownTimestamp = string;

/** google.protobuf.FieldMask 的 protojson 形态（逗号分隔字段名字符串） */
export type wellKnownFieldMask = string;

// ==============================
// 角色（permission.service.v1 / Role）
// ==============================

export type permissionservicev1_Role_Status = 'OFF' | 'ON';

export type permissionservicev1_Role_Type = 'SYSTEM' | 'TEMPLATE' | 'TENANT';

// 角色
export type permissionservicev1_Role = {
  code?: string;
  createdAt?: wellKnownTimestamp;
  createdBy?: number;
  deletedAt?: wellKnownTimestamp;
  deletedBy?: number;
  description?: string;
  id?: number;
  isProtected?: boolean;
  name?: string;
  permissions: number[] | undefined;
  sortOrder?: number;
  status?: permissionservicev1_Role_Status;
  tenantId?: number;
  tenantName?: string;
  type?: permissionservicev1_Role_Type;
  updatedAt?: wellKnownTimestamp;
  updatedBy?: number;
};

export type permissionservicev1_ListRoleResponse = {
  items: permissionservicev1_Role[] | undefined;
  total: number | undefined;
};

// 角色数据 - 请求
export type permissionservicev1_GetRoleRequest = {
  code?: string;
  id?: number;
  name?: string;
  viewMask?: wellKnownFieldMask;
};

// 创建角色 - 请求
export type permissionservicev1_CreateRoleRequest = {
  data: permissionservicev1_Role | undefined;
};

// 更新角色 - 请求
export type permissionservicev1_UpdateRoleRequest = {
  allowMissing?: boolean;
  data: permissionservicev1_Role | undefined;
  id: number | undefined;
  updateMask: undefined | wellKnownFieldMask;
};

// 删除角色 - 请求
export type permissionservicev1_DeleteRoleRequest = {
  code?: string;
  id?: number;
  tenantId?: number;
};

// ==============================
// 菜单（permission.service.v1 / Menu）
// ==============================

export type permissionservicev1_Menu_Status = 'OFF' | 'ON';

export type permissionservicev1_Menu_Type = 'BUTTON' | 'CATALOG' | 'EMBEDDED' | 'LINK' | 'MENU';

// 路由元信息
export type permissionservicev1_MenuMeta = {
  activeIcon?: string;
  activePath?: string;
  affixTab?: boolean;
  affixTabOrder?: number;
  authority: string[] | undefined;
  badge?: string;
  badgeType?: string;
  badgeVariants?: string;
  hideChildrenInMenu?: boolean;
  hideInBreadcrumb?: boolean;
  hideInMenu?: boolean;
  hideInTab?: boolean;
  icon?: string;
  iframeSrc?: string;
  ignoreAccess?: boolean;
  keepAlive?: boolean;
  link?: string;
  loaded?: boolean;
  maxNumOfOpenTab?: number;
  menuVisibleWithForbidden?: boolean;
  openInNewWindow?: boolean;
  order?: number;
  title?: string;
};

// 菜单
export type permissionservicev1_Menu = {
  alias?: string;
  children: permissionservicev1_Menu[] | undefined;
  component?: string;
  createdAt?: wellKnownTimestamp;
  createdBy?: number;
  deletedAt?: wellKnownTimestamp;
  deletedBy?: number;
  id?: number;
  meta?: permissionservicev1_MenuMeta;
  name?: string;
  parentId?: number;
  path?: string;
  redirect?: string;
  status?: permissionservicev1_Menu_Status;
  type?: permissionservicev1_Menu_Type;
  updatedAt?: wellKnownTimestamp;
  updatedBy?: number;
};

export type permissionservicev1_ListMenuResponse = {
  items: permissionservicev1_Menu[] | undefined;
  total: number | undefined;
};

// 查询菜单详情 - 请求
export type permissionservicev1_GetMenuRequest = {
  id?: number;
  viewMask?: wellKnownFieldMask;
};

// 创建菜单 - 请求
export type permissionservicev1_CreateMenuRequest = {
  data: permissionservicev1_Menu | undefined;
};

// 更新菜单 - 请求
export type permissionservicev1_UpdateMenuRequest = {
  allowMissing?: boolean;
  data: permissionservicev1_Menu | undefined;
  id: number | undefined;
  updateMask: undefined | wellKnownFieldMask;
};

// 删除菜单 - 请求
export type permissionservicev1_DeleteMenuRequest = {
  id?: number;
  operatorId?: number;
};

// ==============================
// API 资源（permission.service.v1 / Api）
// ==============================

// API作用域
export type permissionservicev1_Api_Scope = 'ADMIN' | 'API_SCOPE_INVALID' | 'APP';

// API状态
export type permissionservicev1_Api_Status = 'OFF' | 'ON';

// API资源
export type permissionservicev1_Api = {
  createdAt?: wellKnownTimestamp;
  createdBy?: number;
  deletedAt?: wellKnownTimestamp;
  deletedBy?: number;
  description?: string;
  id?: number;
  method?: string;
  module?: string;
  moduleDescription?: string;
  operation?: string;
  path?: string;
  scope?: permissionservicev1_Api_Scope;
  status?: permissionservicev1_Api_Status;
  updatedAt?: wellKnownTimestamp;
  updatedBy?: number;
};

export type permissionservicev1_ListApiResponse = {
  items: permissionservicev1_Api[] | undefined;
  total: number | undefined;
};

// 查询 - 请求
export type permissionservicev1_GetApiRequest = {
  id?: number;
  viewMask?: wellKnownFieldMask;
};

// 创建 - 请求
export type permissionservicev1_CreateApiRequest = {
  data: permissionservicev1_Api | undefined;
};

// 更新 - 请求
export type permissionservicev1_UpdateApiRequest = {
  allowMissing?: boolean;
  data: permissionservicev1_Api | undefined;
  id: number | undefined;
  updateMask: undefined | wellKnownFieldMask;
};

// 删除 - 请求
export type permissionservicev1_DeleteApiRequest = {
  id?: number;
};

// ==============================
// 组织单元（identity.service.v1 / OrgUnit，部门页数据源）
// ==============================

// 组织单元类型
export type identityservicev1_OrgUnit_Type =
  | 'BRANCH'
  | 'COMMITTEE'
  | 'COMPANY'
  | 'DEPARTMENT'
  | 'DIVISION'
  | 'OTHER'
  | 'PROJECT'
  | 'REGION'
  | 'SUBSIDIARY'
  | 'TEAM';

// 组织单元状态
export type identityservicev1_OrgUnit_Status = 'OFF' | 'ON';

// 组织单元
export type identityservicev1_OrgUnit = {
  address?: string;
  attributes: { [key: string]: string } | undefined;
  businessScopes: string[] | undefined;
  children: identityservicev1_OrgUnit[] | undefined;
  code?: string;
  contactUserId?: number;
  contactUserName?: string;
  country?: string;
  createdAt?: wellKnownTimestamp;
  createdBy?: number;
  deletedAt?: wellKnownTimestamp;
  deletedBy?: number;
  description?: string;
  email?: string;
  endAt?: wellKnownTimestamp;
  externalId?: string;
  id?: number;
  isLegalEntity?: boolean;
  latitude?: number;
  leaderId?: number;
  leaderName?: string;
  legalEntityOrgId?: number;
  longitude?: number;
  name?: string;
  parentId?: number;
  path?: string;
  permissionTags: string[] | undefined;
  phone?: string;
  registrationNumber?: string;
  remark?: string;
  sortOrder?: number;
  startAt?: wellKnownTimestamp;
  status?: identityservicev1_OrgUnit_Status;
  taxId?: string;
  tenantId?: number;
  tenantName?: string;
  timezone?: string;
  type?: identityservicev1_OrgUnit_Type;
  updatedAt?: wellKnownTimestamp;
  updatedBy?: number;
};

export type identityservicev1_ListOrgUnitResponse = {
  items: identityservicev1_OrgUnit[] | undefined;
  total: number | undefined;
};

// 获取组织单元数据 - 请求
export type identityservicev1_GetOrgUnitRequest = {
  id?: number;
  viewMask?: wellKnownFieldMask;
};

// 创建组织单元 - 请求
export type identityservicev1_CreateOrgUnitRequest = {
  data: identityservicev1_OrgUnit | undefined;
};

// 更新组织单元 - 请求
export type identityservicev1_UpdateOrgUnitRequest = {
  allowMissing?: boolean;
  data: identityservicev1_OrgUnit | undefined;
  id: number | undefined;
  updateMask: undefined | wellKnownFieldMask;
};

// 删除组织单元 - 请求
export type identityservicev1_DeleteOrgUnitRequest = {
  id?: number;
};

// ==============================
// 权限点（permission.service.v1 / Permission，角色授权树叶子）
// ==============================

// 权限点状态
export type permissionservicev1_Permission_Status = 'OFF' | 'ON';

// 权限点
export type permissionservicev1_Permission = {
  apiIds: number[] | undefined;
  code?: string;
  createdAt?: wellKnownTimestamp;
  createdBy?: number;
  deletedAt?: wellKnownTimestamp;
  deletedBy?: number;
  description?: string;
  groupId?: number;
  groupName?: string;
  id?: number;
  menuIds: number[] | undefined;
  name?: string;
  status?: permissionservicev1_Permission_Status;
  updatedAt?: wellKnownTimestamp;
  updatedBy?: number;
};

export type permissionservicev1_ListPermissionResponse = {
  items: permissionservicev1_Permission[] | undefined;
  total: number | undefined;
};

// 查询 - 请求
export type permissionservicev1_GetPermissionRequest = {
  code?: string;
  id?: number;
  viewMask?: wellKnownFieldMask;
};

// 创建 - 请求
export type permissionservicev1_CreatePermissionRequest = {
  data: permissionservicev1_Permission | undefined;
};

// 更新 - 请求
export type permissionservicev1_UpdatePermissionRequest = {
  allowMissing?: boolean;
  data: permissionservicev1_Permission | undefined;
  id: number | undefined;
  updateMask: undefined | wellKnownFieldMask;
};

// 删除 - 请求
export type permissionservicev1_DeletePermissionRequest = {
  code?: string;
  groupId?: number;
  id?: number;
};

// ==============================
// 权限组（permission.service.v1 / PermissionGroup，角色授权树分组）
// ==============================

// 权限组状态
export type permissionservicev1_PermissionGroup_Status = 'OFF' | 'ON';

// 权限组
export type permissionservicev1_PermissionGroup = {
  children: permissionservicev1_PermissionGroup[] | undefined;
  createdAt?: wellKnownTimestamp;
  createdBy?: number;
  deletedAt?: wellKnownTimestamp;
  deletedBy?: number;
  description?: string;
  id?: number;
  module?: string;
  name?: string;
  parentId?: number;
  path?: string;
  sortOrder?: number;
  status?: permissionservicev1_PermissionGroup_Status;
  updatedAt?: wellKnownTimestamp;
  updatedBy?: number;
};

export type permissionservicev1_ListPermissionGroupResponse = {
  items: permissionservicev1_PermissionGroup[] | undefined;
  total: number | undefined;
};

// 查询 - 请求
export type permissionservicev1_GetPermissionGroupRequest = {
  id?: number;
  viewMask?: wellKnownFieldMask;
};

// 创建 - 请求
export type permissionservicev1_CreatePermissionGroupRequest = {
  data: permissionservicev1_PermissionGroup | undefined;
};

// 更新 - 请求
export type permissionservicev1_UpdatePermissionGroupRequest = {
  allowMissing?: boolean;
  data: permissionservicev1_PermissionGroup | undefined;
  id: number | undefined;
  updateMask: undefined | wellKnownFieldMask;
};

// 删除 - 请求
export type permissionservicev1_DeletePermissionGroupRequest = {
  id?: number;
};
