/**
 * 登录态管理：token / 用户信息持久化到 localStorage，
 * 并通过 React Context 向组件树提供当前登录态（内置状态管理，不引入 redux）。
 */
import { createContext, useCallback, useContext, useMemo, useState } from 'react';
import type { ReactNode } from 'react';

const TOKEN_KEY = 'admin_token';
const USER_KEY = 'admin_user';

/** 当前登录的管理员用户信息 */
export interface AuthUser {
  id?: number;
  username?: string;
  nickname?: string;
  avatarUrl?: string;
}

/** 从 localStorage 读取 token */
export function getToken(): string | null {
  return localStorage.getItem(TOKEN_KEY);
}

/** 从 localStorage 读取用户信息 */
export function getStoredUser(): AuthUser | null {
  const raw = localStorage.getItem(USER_KEY);
  if (!raw) return null;
  try {
    return JSON.parse(raw) as AuthUser;
  } catch {
    return null;
  }
}

/** 清空本地登录态（token + 用户信息） */
export function clearToken(): void {
  localStorage.removeItem(TOKEN_KEY);
  localStorage.removeItem(USER_KEY);
}

interface AuthContextValue {
  token: string | null;
  user: AuthUser | null;
  /** 登录成功后调用：写入本地并同步 Context */
  signIn: (token: string, user: AuthUser) => void;
  /** 退出登录：清空本地并同步 Context */
  signOut: () => void;
}

const AuthContext = createContext<AuthContextValue | null>(null);

export function AuthProvider({ children }: { children: ReactNode }) {
  const [token, setToken] = useState<string | null>(() => getToken());
  const [user, setUser] = useState<AuthUser | null>(() => getStoredUser());

  const signIn = useCallback((nextToken: string, nextUser: AuthUser) => {
    localStorage.setItem(TOKEN_KEY, nextToken);
    localStorage.setItem(USER_KEY, JSON.stringify(nextUser));
    setToken(nextToken);
    setUser(nextUser);
  }, []);

  const signOut = useCallback(() => {
    clearToken();
    setToken(null);
    setUser(null);
  }, []);

  const value = useMemo(
    () => ({ token, user, signIn, signOut }),
    [token, user, signIn, signOut],
  );

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>;
}

/** 获取登录态 Context（必须在 AuthProvider 内使用） */
export function useAuth(): AuthContextValue {
  const ctx = useContext(AuthContext);
  if (!ctx) {
    throw new Error('useAuth 必须在 AuthProvider 内使用');
  }
  return ctx;
}
