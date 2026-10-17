/**
 * 系统配置接口（Admin 端 /admin/v1/sysconf）
 */
import { get, put } from './request';
import type { SysConf } from '../types';

export interface UpdateSysConfPayload {
  maxUploadSizeMb: number;
  maxDurationSeconds: number;
  manualReviewEnabled: boolean;
  registerEnabled: boolean;
  allowedVideoTypes: string[];
}

/** 获取系统配置 */
export function getSysConf(): Promise<SysConf> {
  return get<SysConf>('/sysconf');
}

/** 更新系统配置 */
export function updateSysConf(payload: UpdateSysConfPayload): Promise<SysConf> {
  return put<SysConf>('/sysconf', payload);
}
