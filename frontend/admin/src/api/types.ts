/**
 * GoWind shortplay Admin BFF 类型定义
 *
 * 对齐 docs/API.md「Admin 端（:7600 /admin/v1）」与 backend proto（protojson）：
 * - 枚举字段是字符串全名（"VIDEO_STATUS_PUBLISHED" 等）；
 * - int64/uint64 序列化为 JSON 字符串（"likeCount":"1"），这里用 string | number
 *   接住后统一经 toNum() 转数值；
 * - uint32/int32 是数字（id、authorId 等）。
 */

// ========== 枚举全名（请求方向必须传全名） ==========

export const VIDEO_STATUS = {
  UNSPECIFIED: 'VIDEO_STATUS_UNSPECIFIED',
  DRAFT: 'VIDEO_STATUS_DRAFT',
  REVIEWING: 'VIDEO_STATUS_REVIEWING',
  PUBLISHED: 'VIDEO_STATUS_PUBLISHED',
  REJECTED: 'VIDEO_STATUS_REJECTED',
  OFFLINE: 'VIDEO_STATUS_OFFLINE',
} as const;

export type VideoStatus = (typeof VIDEO_STATUS)[keyof typeof VIDEO_STATUS];

/** 列表 filter 参数（数字字符串 "1"~"5"）→ 枚举全名 */
export const VIDEO_STATUS_FILTER: Record<string, VideoStatus> = {
  '1': VIDEO_STATUS.DRAFT,
  '2': VIDEO_STATUS.REVIEWING,
  '3': VIDEO_STATUS.PUBLISHED,
  '4': VIDEO_STATUS.REJECTED,
  '5': VIDEO_STATUS.OFFLINE,
};

export const USER_STATUS = {
  UNSPECIFIED: 'USER_STATUS_UNSPECIFIED',
  DISABLED: 'USER_STATUS_DISABLED',
  NORMAL: 'USER_STATUS_NORMAL',
} as const;

export type UserStatus = (typeof USER_STATUS)[keyof typeof USER_STATUS];

export const REPORT_STATUS = {
  UNSPECIFIED: 'REPORT_STATUS_UNSPECIFIED',
  PENDING: 'REPORT_STATUS_PENDING',
  RESOLVED: 'REPORT_STATUS_RESOLVED',
  DISMISSED: 'REPORT_STATUS_DISMISSED',
} as const;

export type ReportStatus = (typeof REPORT_STATUS)[keyof typeof REPORT_STATUS];

/** 列表 filter 参数："1" 待处理 / "2" 已通过 / "3" 已驳回 */
export const REPORT_STATUS_FILTER: Record<string, ReportStatus> = {
  '1': REPORT_STATUS.PENDING,
  '2': REPORT_STATUS.RESOLVED,
  '3': REPORT_STATUS.DISMISSED,
};

export const HANDLE_ACTION = {
  UNSPECIFIED: 'HANDLE_ACTION_UNSPECIFIED',
  RESOLVE: 'HANDLE_ACTION_RESOLVE',
  DISMISS: 'HANDLE_ACTION_DISMISS',
} as const;

export const REPORT_TARGET_TYPE = {
  UNSPECIFIED: 'REPORT_TARGET_TYPE_UNSPECIFIED',
  VIDEO: 'REPORT_TARGET_TYPE_VIDEO',
  COMMENT: 'REPORT_TARGET_TYPE_COMMENT',
  USER: 'REPORT_TARGET_TYPE_USER',
} as const;

export const TOP_METRIC = {
  VIEW: 'METRIC_VIEW',
  LIKE: 'METRIC_LIKE',
  COLLECT: 'METRIC_COLLECT',
  COMMENT: 'METRIC_COMMENT',
} as const;

export type TopMetric = (typeof TOP_METRIC)[keyof typeof TOP_METRIC];

// ========== 通用 ==========

/** protojson Timestamp：RFC3339 字符串 */
export type ProtoTimestamp = string;

/** int64/uint64 的 JSON 形态（字符串，兼容数字） */
export type Int64 = string | number;

/** protojson 枚举运行时形态（字符串全名，兼容数字） */
export type ProtoEnum = string | number;

/** 分页响应公共形态 */
export interface ListResponse<T> {
  items?: T[];
  total?: Int64;
}

// ========== 认证（基座契约：cms authentication） ==========

/**
 * POST /admin/v1/login 响应（基座形状，curl 实测）：
 * {token_type:"bearer", access_token:"jwt...", expires_in:"5400", refresh_expires_in:"43200"}
 * ⚠ 登录响应是全站唯一的 snake_case 端点（cms 基座生成类型按 proto 字段名
 * 序列化 access_token 等），其余端点均为 protojson camelCase。
 * expires_in 为 int64（字符串形态），这里宽容接住数字。
 */
export interface LoginResponse {
  token_type?: string;
  access_token?: string;
  /** int64：字符串形态（"5400"） */
  expires_in?: Int64;
  refresh_expires_in?: Int64;
  // ---- camelCase 兼容位（防御后端切换 protojson json_name 风格）----
  tokenType?: string;
  accessToken?: string;
  expiresIn?: Int64;
  refreshExpiresIn?: Int64;
}

/** GET /admin/v1/captcha 响应（基座形状）：{captchaId, imageBase64(dataURL)} */
export interface CaptchaResponse {
  captchaId?: string;
  imageBase64?: string;
}

/** GET /admin/v1/me 响应（基座 i_user 形状，裁剪展示）：租户/组织/岗位/角色齐备 */
export interface AdminUser {
  id?: number;
  tenantId?: number;
  orgUnitIds?: number[];
  orgUnitNames?: string[];
  positionIds?: number[];
  positionNames?: string[];
  roleIds?: number[];
  /** 角色编码（"platform:admin" 等） */
  roles?: string[];
  roleNames?: string[];
  username?: string;
  nickname?: string;
  realname?: string;
  avatar?: string;
  email?: string;
  mobile?: string;
  gender?: string;
  status?: string;
  createdAt?: ProtoTimestamp;
  updatedAt?: ProtoTimestamp;
}

// ========== 视频 ==========

export interface Video {
  id?: number;
  title?: string;
  description?: string;
  coverUrl?: string;
  videoUrl?: string;
  duration?: number;
  width?: number;
  height?: number;
  status?: ProtoEnum;
  authorId?: number;
  tags?: string[];
  likeCount?: Int64;
  collectCount?: Int64;
  commentCount?: Int64;
  viewCount?: Int64;
  rejectReason?: string;
  publishedAt?: ProtoTimestamp;
  createdAt?: ProtoTimestamp;
  updatedAt?: ProtoTimestamp;
}

export interface ChangeVideoStatusRequest {
  status: VideoStatus;
  reason?: string;
}

/** PUT /videos/{id} 编辑视频（标题 / 简介 / 封面 / 标签） */
export interface UpdateVideoRequest {
  title?: string;
  description?: string;
  coverUrl?: string;
  tags?: string[];
}

// ========== 评论 ==========

export interface UserBrief {
  id?: number;
  nickname?: string;
  avatarUrl?: string;
}

export interface Comment {
  id?: number;
  videoId?: number;
  userId?: number;
  user?: UserBrief;
  content?: string;
  parentId?: number;
  likeCount?: Int64;
  replyCount?: Int64;
  createdAt?: ProtoTimestamp;
}

// ========== 举报 ==========

export interface Report {
  id?: number;
  reporterId?: number;
  reporter?: UserBrief;
  targetType?: ProtoEnum;
  targetId?: number;
  /** 举报原因（枚举码字符串） */
  reason?: string;
  description?: string;
  status?: ProtoEnum;
  handledBy?: number;
  handleNote?: string;
  handledAt?: ProtoTimestamp;
  createdAt?: ProtoTimestamp;
}

export interface HandleReportRequest {
  action: (typeof HANDLE_ACTION)[keyof typeof HANDLE_ACTION];
  note?: string;
}

// ========== 用户（业务 App 用户，/admin/v1/users：基座转发 identity 后按 AppUser 形状映射） ==========

export interface AppUser {
  id?: number;
  username?: string;
  nickname?: string;
  avatarUrl?: string;
  bio?: string;
  /** 1禁用 / 2正常（protojson int32 数字形态） */
  status?: ProtoEnum;
  createdAt?: ProtoTimestamp;
  updatedAt?: ProtoTimestamp;
}

export interface CreateUserRequest {
  username: string;
  password: string;
  nickname: string;
  avatarUrl?: string;
  bio?: string;
}

export interface UpdateUserRequest {
  nickname?: string;
  avatarUrl?: string;
  bio?: string;
  password?: string;
}

// ========== 看板 ==========

export interface DashboardOverview {
  totalVideos?: Int64;
  publishedVideos?: Int64;
  totalViews?: Int64;
  totalLikes?: Int64;
  totalComments?: Int64;
  totalUsers?: Int64;
  todayPublished?: Int64;
}

/**
 * 单日趋势（docs/API.md「Admin 端增补」：GET /dashboard/trends?days=N）。
 * published 按视频 published_at 落日统计；plays/likes 按 uba_events 当日
 * VIDEO_PLAY / VIDEO_LIKE 事件计数。
 */
export interface DashboardTrendItem {
  /** 日期（"2026-10-18"） */
  date?: string;
  /** 当日发布数 */
  published?: Int64;
  /** 当日播放数 */
  plays?: Int64;
  /** 当日点赞数 */
  likes?: Int64;
}

export interface DashboardTrendsResponse {
  items?: DashboardTrendItem[];
}

// ========== 系统配置 ==========

export interface SysConf {
  maxUploadSizeMb?: number;
  maxDurationSeconds?: number;
  manualReviewEnabled?: boolean;
  registerEnabled?: boolean;
  allowedVideoTypes?: string[];
  updatedAt?: ProtoTimestamp;
}

export interface UpdateSysConfRequest {
  maxUploadSizeMb?: number;
  maxDurationSeconds?: number;
  manualReviewEnabled?: boolean;
  registerEnabled?: boolean;
  allowedVideoTypes?: string[];
}

// ========== 组织与权限（基座 RBAC 契约：cms i_role/i_menu/i_api/i_department） ==========

/**
 * 基座实体状态枚举：字符串全名 "ON"/"OFF"（实测 protojson 下发裸值名）。
 * 读取方向配合 isStatusDisabled() 宽容判断（兼容数字与任意前缀全名）。
 */
export const ENTITY_STATUS = {
  ON: 'ON',
  OFF: 'OFF',
} as const;

/** 业务 App 用户状态（AppUser.status：1禁用 / 2正常，实测数字形态） */
export const USER_STATUS_VALUE = {
  DISABLED: '1',
  NORMAL: '2',
} as const;

/**
 * 宽容判断实体是否为「禁用」态：
 * 兼容 protojson 数字、值名带前缀（"MENU_STATUS_DISABLED"）与裸名（"DISABLED"/"OFF"）。
 */
export function isStatusDisabled(status?: ProtoEnum | boolean | null): boolean {
  if (status === true) return false;
  if (typeof status === 'number') return status === 1; // 基座 OFF=0/ON=1
  const s = String(status ?? '');
  if (/^\d+$/.test(s)) return Number(s) === 0 || Number(s) === 1;
  return /DISABLED|^OFF$/i.test(s);
}

/** 菜单类型（基座 menu.proto：CATALOG=0/MENU=1/BUTTON=2/EMBEDDED=3/LINK=4） */
export const MENU_TYPE = {
  CATALOG: 'CATALOG',
  MENU: 'MENU',
  BUTTON: 'BUTTON',
  EMBEDDED: 'EMBEDDED',
  LINK: 'LINK',
} as const;

export type MenuType = (typeof MENU_TYPE)[keyof typeof MENU_TYPE];

/** 权限点 HTTP 方法（基座 api.proto method 为字符串，实测下发 "GET"/"DELETE" 等） */
export type ApiMethod = 'GET' | 'POST' | 'PUT' | 'DELETE' | 'PATCH' | 'HEAD' | 'OPTIONS' | string;

/** HTTP 方法 → 展示短名（兼容 "API_METHOD_GET" 全名形态） */
export function apiMethodShortLabel(method: unknown): string {
  return String(method ?? '').replace(/^API_METHOD_/, '');
}

/** 角色（基座 Role：{data} 信封读写；permissions 为权限点 ID 列表） */
export interface SysRole {
  id?: number; // uint32 数字
  name?: string;
  code?: string;
  sortOrder?: number;
  status?: ProtoEnum; // "ON"/"OFF"
  description?: string;
  isProtected?: boolean;
  type?: ProtoEnum; // "SYSTEM"/"TEMPLATE"/"TENANT"
  /** 绑定的权限点 ID 列表（角色-权限点授权） */
  permissions?: number[];
  tenantId?: number;
  tenantName?: string;
  createdAt?: ProtoTimestamp;
  updatedAt?: ProtoTimestamp;
}

/** 菜单 meta（基座 Menu.Meta，vben 风格路由元信息，仅列常用字段） */
export interface SysMenuMeta {
  title?: string;
  order?: number;
  icon?: string;
  authority?: string[];
  keepAlive?: boolean;
  hideInMenu?: boolean;
  hideChildrenInMenu?: boolean;
  hideInBreadcrumb?: boolean;
  hideInTab?: boolean;
  affixTab?: boolean;
}

/** 菜单（基座 Menu：name 为路由名、meta.title 为显示名；列表平铺返回带 parentId/children） */
export interface SysMenu {
  id?: number;
  status?: ProtoEnum; // "ON"/"OFF"
  type?: ProtoEnum; // "CATALOG"/"MENU"/"BUTTON"/"EMBEDDED"/"LINK"
  path?: string;
  redirect?: string;
  alias?: string;
  /** 路由名（如 "InternalMessageList"） */
  name?: string;
  /** 组件路径（如 "app/internal_message/message/index.vue"） */
  component?: string;
  meta?: SysMenuMeta;
  parentId?: number;
  children?: SysMenu[];
  createdAt?: ProtoTimestamp;
  updatedAt?: ProtoTimestamp;
}

/** 权限点（基座 Api：{id,operation,path,method,module,moduleDescription,description,scope,status}） */
export interface SysApi {
  id?: number;
  /** gRPC 全名操作（如 "NotificationChannelService_Delete"） */
  operation?: string;
  path?: string;
  method?: ProtoEnum; // "GET"/"POST"/...
  /** 所属服务模块（如 "NotificationChannelService"） */
  module?: string;
  moduleDescription?: string;
  description?: string;
  scope?: ProtoEnum; // "ADMIN"/"APP"
  status?: ProtoEnum; // "ON"/"OFF"
  createdAt?: ProtoTimestamp;
  updatedAt?: ProtoTimestamp;
}

/** 部门（基座 OrgUnit，/admin/v1/org-units：树形组织，type 为组织类型枚举） */
export interface SysDepartment {
  id?: number;
  parentId?: number;
  name?: string;
  code?: string;
  type?: ProtoEnum; // "DIVISION"/"REGION"/...
  path?: string;
  sortOrder?: number;
  leaderId?: number;
  leaderName?: string;
  tenantId?: number;
  remark?: string;
  description?: string;
  status?: ProtoEnum; // "ON"/"OFF"
  children?: SysDepartment[];
  createdAt?: ProtoTimestamp;
  updatedAt?: ProtoTimestamp;
}

/** 权限点（基座 Permission，/admin/v1/permissions：角色授权的授权对象） */
export interface SysPermission {
  id?: number;
  name?: string;
  code?: string;
  description?: string;
  status?: ProtoEnum; // "ON"/"OFF"
  groupId?: number;
  groupName?: string;
  menuIds?: number[];
  apiIds?: number[];
  createdAt?: ProtoTimestamp;
}

/** 权限组（基座 PermissionGroup，/admin/v1/permission-groups：嵌套树） */
export interface SysPermissionGroup {
  id?: number;
  name?: string;
  path?: string;
  module?: string;
  sortOrder?: number;
  status?: ProtoEnum;
  parentId?: number;
  children?: SysPermissionGroup[];
  createdAt?: ProtoTimestamp;
}

/** 个人资料：基座 GET/PUT /admin/v1/me（形状见 AdminUser） */
export type ProfileResponse = AdminUser;

/** PUT /admin/v1/me 请求：{data:{...}, updateMask:"a,b"}（基座 UpdateUser 信封） */
export interface UpdateProfileRequest {
  nickname?: string;
  avatar?: string;
  realname?: string;
  mobile?: string;
  email?: string;
  /** 性别枚举名（MALE/FEMALE/SECRET），基座白名单可改 */
  gender?: string;
}

export interface ChangePasswordRequest {
  oldPassword: string;
  newPassword: string;
}

/** GET /navigation 节点（当前用户菜单树，BUTTON 类型不下发） */
export interface NavigationNode {
  id?: number;
  parentId?: number;
  name?: string;
  path?: string;
  component?: string;
  icon?: string;
  sort?: number;
  type?: ProtoEnum;
  visible?: boolean;
  children?: NavigationNode[];
}

/** 站内通知（复用 notify 域） */
export const NOTIFY_TYPE = {
  LIKE: 'NOTIFY_TYPE_LIKE',
  COMMENT: 'NOTIFY_TYPE_COMMENT',
  FOLLOW: 'NOTIFY_TYPE_FOLLOW',
  SYSTEM: 'NOTIFY_TYPE_SYSTEM',
} as const;

export interface AdminNotification {
  id?: number;
  type?: ProtoEnum;
  sender?: UserBrief;
  videoId?: number;
  commentId?: number;
  content?: string;
  isRead?: boolean;
  createdAt?: ProtoTimestamp;
}

/** GET /notifications 响应（列表自带 unreadCount） */
export interface ListNotificationsResponse {
  items?: AdminNotification[];
  total?: Int64;
  unreadCount?: Int64;
}
