/**
 * axios 统一封装：
 * - baseURL：默认 http://127.0.0.1:6600，可由 .env 的 VITE_API_BASE 覆盖（开发态填 /api 走 Vite 代理）；
 * - 请求拦截：自动携带 Authorization: Bearer <token>（token 存 localStorage）；
 * - 响应拦截：成功直接返回 data；失败解析后端错误结构 {"code","reason","message"}，
 *   用 antd message.error 提示 message；401 时清除 token 并跳回登录页。
 */
import axios from 'axios';
import type { AxiosRequestConfig } from 'axios';
import { message } from 'antd';
import { clearToken, getToken } from '../utils/auth';

/** 后端网关地址：默认本地 6600，可用 .env 的 VITE_API_BASE 覆盖 */
const API_BASE = import.meta.env.VITE_API_BASE || 'http://127.0.0.1:6600';

/** Admin 端统一前缀（docs/API.md：Admin 端 :6600 /admin/v1） */
export const ADMIN_API_BASE = `${API_BASE.replace(/\/+$/, '')}/admin/v1`;

/** 后端统一错误响应结构 */
interface ApiErrorBody {
  code?: number;
  reason?: string;
  message?: string;
}

const instance = axios.create({
  baseURL: ADMIN_API_BASE,
  timeout: 15000,
});

// 请求拦截：注入 Bearer Token
instance.interceptors.request.use((config) => {
  const token = getToken();
  if (token) {
    config.headers.set('Authorization', `Bearer ${token}`);
  }
  return config;
});

// 响应拦截：剥壳返回 data；统一错误提示；401 清理登录态
instance.interceptors.response.use(
  (response) => response.data,
  (error: unknown) => {
    if (axios.isAxiosError(error)) {
      const status = error.response?.status;
      const body = error.response?.data as ApiErrorBody | undefined;

      // 401：登录过期，清除 token 并整页刷新回登录页（让路由守卫与 Context 同步生效）
      if (status === 401) {
        clearToken();
        if (!window.location.hash.startsWith('#/login')) {
          message.error('登录已过期，请重新登录');
          window.location.hash = '#/login';
          window.location.reload();
        }
        return Promise.reject(error);
      }

      // 后端错误结构：{"code":..,"reason":"..","message":".."}
      const msg = body?.message || error.message || '请求失败';
      message.error(msg);
      return Promise.reject(error);
    }

    message.error('网络异常，请稍后重试');
    return Promise.reject(error);
  },
);

/**
 * 泛型便捷方法：响应拦截器已剥壳（返回 response.data），因此 T 即响应 body 类型。
 */
async function get<T>(url: string, config?: AxiosRequestConfig): Promise<T> {
  return instance.get(url, config) as unknown as Promise<T>;
}

async function post<T>(url: string, data?: unknown, config?: AxiosRequestConfig): Promise<T> {
  return instance.post(url, data, config) as unknown as Promise<T>;
}

async function put<T>(url: string, data?: unknown, config?: AxiosRequestConfig): Promise<T> {
  return instance.put(url, data, config) as unknown as Promise<T>;
}

async function del<T = void>(url: string, config?: AxiosRequestConfig): Promise<T> {
  return instance.delete(url, config) as unknown as Promise<T>;
}

export { get, post, put, del };
export default instance;
