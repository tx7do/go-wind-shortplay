/**
 * 用户管理接口（Admin 端 /admin/v1/users）
 */
import { del, get, post, put } from './request';
import type { PageParams, PageResult, User, UserStatus } from '../types';
import { normalizePage } from './page';

export interface ListUsersParams extends PageParams {
  /** 关键字（用户名 / 昵称搜索） */
  query?: string;
}

/** 用户列表（分页 + 关键字搜索） */
export async function listUsers(params: ListUsersParams): Promise<PageResult<User>> {
  const data = await get<PageResult<User>>('/users', {
    params: {
      page: params.page,
      pageSize: params.pageSize,
      query: params.query || undefined,
    },
  });
  return normalizePage(data);
}

/** 创建用户（username/password/nickname 必填） */
export function createUser(payload: {
  username: string;
  password: string;
  nickname: string;
  bio?: string;
}): Promise<User> {
  return post<User>('/users', { ...payload, bio: payload.bio ? payload.bio.trim() : undefined });
}

/** 编辑用户（nickname/bio/password，password 传则重置密码） */
export function updateUser(
  id: number,
  payload: { nickname?: string; password?: string; bio?: string },
): Promise<User> {
  return put<User>(`/users/${id}`, {
    nickname: payload.nickname,
    password: payload.password || undefined,
    bio: payload.bio ? payload.bio.trim() : undefined,
  });
}

/** 启用 / 禁用用户（status：2 正常 / 1 禁用） */
export function updateUserStatus(id: number, status: UserStatus): Promise<User> {
  return put<User>(`/users/${id}/status`, { status });
}

/** 删除用户 */
export function deleteUser(id: number): Promise<void> {
  return del<void>(`/users/${id}`);
}
