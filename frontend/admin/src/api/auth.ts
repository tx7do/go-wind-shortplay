/**
 * 管理员认证接口：POST /admin/v1/login、/admin/v1/logout
 */
import { post } from './request';
import type { AuthUser } from '../utils/auth';

/** LoginResponse（identity.service.v1），并兼容扁平 accessToken 结构 */
interface LoginResponseData {
  authenticator?: {
    accessToken?: string;
    refreshToken?: string;
    expiresIn?: number;
    tokenType?: string;
  };
  user?: AuthUser;
  accessToken?: string;
}

/** 管理员登录：成功返回 token 与用户信息 */
export async function login(username: string, password: string): Promise<{ token: string; user: AuthUser }> {
  const data = await post<LoginResponseData>('/login', { username, password });
  const token = data.authenticator?.accessToken ?? data.accessToken;
  if (!token) {
    throw new Error('登录响应缺少 accessToken');
  }
  const user: AuthUser = { ...data.user, username: data.user?.username ?? username };
  return { token, user };
}

/** 管理员登出（吊销令牌；失败不影响本地清理） */
export function logout(): Promise<void> {
  return post<void>('/logout', {});
}
