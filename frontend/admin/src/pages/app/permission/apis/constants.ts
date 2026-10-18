/* eslint-disable @typescript-eslint/no-explicit-any, @typescript-eslint/no-unused-vars, react-hooks/set-state-in-effect */
// 基座拷贝文件（源：go-wind-cms frontend/admin 同路径实现）：为方便后续整文件重拷贝同步，
// 保持上游代码形态（any 占位/编辑期 setState 回填等），仅按文件禁用本仓更严格的 lint 规则。
/**
 * API 模块枚举映射常量
 * 页面和 Drawer 共用
 */

/** HTTP 方法颜色映射 */
export const METHOD_COLOR_MAP: Record<string, string> = {
  GET: 'success',
  POST: 'processing',
  PUT: 'warning',
  DELETE: 'error',
  PATCH: 'default',
  HEAD: 'default',
  OPTIONS: 'default',
};

/** 获取 HTTP 方法对应的 Tag 预设色名，未匹配时回退中性 default */
export function getMethodColor(method: string | undefined): string {
  return METHOD_COLOR_MAP[method || ''] || 'default';
}
