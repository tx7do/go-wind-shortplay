/**
 * 认证辅助 API（基座链路）：图形验证码 / 当前登录管理账号。
 *
 * - GET /admin/v1/captcha → {captchaId, imageBase64(dataURL)}，登录时经
 *   X-Captcha-Id / X-Captcha-Value 请求头一次性校验；
 * - GET /admin/v1/me → 基座 i_user（含租户/组织/岗位/角色），登录成功后拉取
 *   以恢复身份与角色码。
 */
import { adminHttp } from '@/api/client';
import type { AdminUser, CaptchaResponse } from '@/api/types';

/** 获取图形验证码（基座 cms fetchGenerateCaptcha 同形状） */
export async function fetchGenerateCaptcha(): Promise<CaptchaResponse> {
  return adminHttp.get<CaptchaResponse>('captcha');
}

/** 获取当前登录管理账号（基座 i_user 形状） */
export async function fetchMe(): Promise<AdminUser> {
  return adminHttp.get<AdminUser>('me');
}

/** GET /admin/v1/perm-codes 响应：{codes:[...]} */
export async function fetchPermCodes(): Promise<string[]> {
  const res = await adminHttp.get<{ codes?: string[] }>('perm-codes');
  return res?.codes ?? [];
}
