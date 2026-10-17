/**
 * 与后端 REST 契约（docs/API.md，backend/api/protos）对应的共享类型定义。
 * 字段均为 camelCase JSON；proto 中的 optional 字段在 JSON 里可能缺省，故多为可选。
 */

/** 分页请求参数（page 从 1 起，pageSize 缺省 10、上限 50） */
export interface PageParams {
  page?: number;
  pageSize?: number;
}

/** 分页列表响应 */
export interface PageResult<T> {
  items: T[];
  total: number;
}

/** 视频状态：1 草稿 / 2 审核中 / 3 已发布 / 4 驳回 / 5 下架 */
export type VideoStatus = 1 | 2 | 3 | 4 | 5;

/** 视频对象 */
export interface Video {
  id: number;
  title: string;
  description?: string;
  coverUrl?: string;
  videoUrl?: string;
  /** 时长（秒） */
  duration?: number;
  width?: number;
  height?: number;
  status: VideoStatus;
  authorId?: number;
  tags?: string[];
  likeCount?: number;
  collectCount?: number;
  commentCount?: number;
  viewCount?: number;
  /** 驳回原因 */
  rejectReason?: string;
  publishedAt?: string;
  createdAt?: string;
  updatedAt?: string;
}

/** 用户简要信息（评论人 / 举报人等场景的冗余展示） */
export interface UserBrief {
  id?: number;
  nickname?: string;
  avatarUrl?: string;
}

/** 用户状态：1 禁用 / 2 正常 */
export type UserStatus = 1 | 2;

/** 用户对象 */
export interface User {
  id: number;
  username?: string;
  nickname?: string;
  avatarUrl?: string;
  bio?: string;
  status: UserStatus;
  createdAt?: string;
  updatedAt?: string;
}

/** 评论对象 */
export interface Comment {
  id: number;
  videoId: number;
  userId?: number;
  user?: UserBrief;
  content: string;
  parentId?: number;
  likeCount?: number;
  replyCount?: number;
  createdAt?: string;
}

/** 举报目标类型：1 视频 / 2 评论 / 3 用户 */
export type ReportTargetType = 1 | 2 | 3;

/** 举报工单状态：1 待处理 / 2 已通过（已处置）/ 3 已驳回 */
export type ReportStatus = 1 | 2 | 3;

/** 举报工单 */
export interface Report {
  id: number;
  reporterId?: number;
  reporter?: UserBrief;
  targetType: ReportTargetType;
  targetId: number;
  /** 举报原因 */
  reason?: string;
  /** 补充说明 */
  description?: string;
  status: ReportStatus;
  handledBy?: number;
  handleNote?: string;
  handledAt?: string;
  createdAt?: string;
}

/** 数据看板总览 */
export interface Overview {
  totalVideos?: number;
  publishedVideos?: number;
  totalViews?: number;
  totalLikes?: number;
  totalComments?: number;
  totalUsers?: number;
  todayPublished?: number;
}

/** 看板排行指标 */
export type TopMetric = 'VIEW' | 'LIKE' | 'COLLECT' | 'COMMENT';

/** 系统配置 */
export interface SysConf {
  /** 单视频大小上限（MB） */
  maxUploadSizeMb: number;
  /** 单视频时长上限（秒） */
  maxDurationSeconds: number;
  /** 人工审核开关（false 则发布直接可见） */
  manualReviewEnabled: boolean;
  /** 开放注册开关 */
  registerEnabled: boolean;
  /** 允许的视频类型（扩展名） */
  allowedVideoTypes: string[];
  updatedAt?: string;
}
