/**
 * GoWind shortplay Admin BFF 类型定义
 *
 * 对齐 docs/API.md「Admin 端（:6600 /admin/v1）」与 backend proto（protojson）：
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

// ========== 认证 ==========

export interface Authenticator {
  accessToken?: string;
  refreshToken?: string;
  expiresIn?: number;
  tokenType?: string;
}

export interface LoginUser {
  id?: number;
  username?: string;
  nickname?: string;
  avatarUrl?: string;
}

export interface LoginResponse {
  authenticator?: Authenticator;
  user?: LoginUser;
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

// ========== 用户 ==========

export interface AppUser {
  id?: number;
  username?: string;
  nickname?: string;
  avatarUrl?: string;
  bio?: string;
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
