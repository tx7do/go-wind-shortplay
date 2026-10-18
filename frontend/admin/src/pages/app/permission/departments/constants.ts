/* eslint-disable @typescript-eslint/no-explicit-any, @typescript-eslint/no-unused-vars, react-hooks/set-state-in-effect */
// 基座拷贝文件（源：go-wind-cms frontend/admin 同路径实现）：为方便后续整文件重拷贝同步，
// 保持上游代码形态（any 占位/编辑期 setState 回填等），仅按文件禁用本仓更严格的 lint 规则。
/**
 * 组织架构模块枚举映射常量
 */

type TFn = (key: string, options?: Record<string, any>) => string;

// ========== 组织状态（ON/OFF） ==========

export const STATUS_COLORS: Record<string, string> = {
  ON: 'success',
  OFF: 'error',
};

export function getStatusMap(t: TFn) {
  return {
    ON: { text: t('statusMap.ON'), color: STATUS_COLORS.ON },
    OFF: { text: t('statusMap.OFF'), color: STATUS_COLORS.OFF },
  };
}

export function getStatusOptions(t: TFn) {
  return [
    { label: t('statusMap.ON'), value: 'ON' },
    { label: t('statusMap.OFF'), value: 'OFF' },
  ];
}

// ========== 组织类型 ==========

export const ORG_TYPE_COLORS: Record<string, string> = {
  COMPANY: 'blue',
  DIVISION: 'cyan',
  DEPARTMENT: 'green',
  TEAM: 'processing',
  PROJECT: 'purple',
  COMMITTEE: 'orange',
  REGION: 'geekblue',
  SUBSIDIARY: 'default',
  BRANCH: 'default',
  OTHER: 'default',
};

export function getOrgTypeMap(t: TFn) {
  return {
    COMPANY: { text: t('typeMap.COMPANY'), color: ORG_TYPE_COLORS.COMPANY },
    DIVISION: { text: t('typeMap.DIVISION'), color: ORG_TYPE_COLORS.DIVISION },
    DEPARTMENT: { text: t('typeMap.DEPARTMENT'), color: ORG_TYPE_COLORS.DEPARTMENT },
    TEAM: { text: t('typeMap.TEAM'), color: ORG_TYPE_COLORS.TEAM },
    PROJECT: { text: t('typeMap.PROJECT'), color: ORG_TYPE_COLORS.PROJECT },
    COMMITTEE: { text: t('typeMap.COMMITTEE'), color: ORG_TYPE_COLORS.COMMITTEE },
    REGION: { text: t('typeMap.REGION'), color: ORG_TYPE_COLORS.REGION },
    SUBSIDIARY: { text: t('typeMap.SUBSIDIARY'), color: ORG_TYPE_COLORS.SUBSIDIARY },
    BRANCH: { text: t('typeMap.BRANCH'), color: ORG_TYPE_COLORS.BRANCH },
    OTHER: { text: t('typeMap.OTHER'), color: ORG_TYPE_COLORS.OTHER },
  };
}

export function getOrgTypeOptions(t: TFn) {
  return [
    { label: t('typeMap.COMPANY'), value: 'COMPANY' },
    { label: t('typeMap.DIVISION'), value: 'DIVISION' },
    { label: t('typeMap.DEPARTMENT'), value: 'DEPARTMENT' },
    { label: t('typeMap.TEAM'), value: 'TEAM' },
    { label: t('typeMap.PROJECT'), value: 'PROJECT' },
    { label: t('typeMap.COMMITTEE'), value: 'COMMITTEE' },
    { label: t('typeMap.REGION'), value: 'REGION' },
    { label: t('typeMap.SUBSIDIARY'), value: 'SUBSIDIARY' },
    { label: t('typeMap.BRANCH'), value: 'BRANCH' },
    { label: t('typeMap.OTHER'), value: 'OTHER' },
  ];
}
