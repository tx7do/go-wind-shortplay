/**
 * 举报工单状态与展示映射
 *
 * protojson 铁律：后端枚举字段是字符串全名（"REPORT_STATUS_PENDING"）；
 * 列表接口的 filter 参数用数字字符串（"1" 待处理 / "2" 已通过 / "3" 已驳回）。
 */
import { REPORT_STATUS, REPORT_TARGET_TYPE, type ReportStatus } from '@/api/types';

export interface ReportStatusConfig {
  filter: string;
  value: ReportStatus;
  labelKey: string;
  color: string;
}

/** 状态顺序与 Tab 顺序一致：全部/待处理/已通过/已驳回 */
export const REPORT_STATUS_LIST: ReportStatusConfig[] = [
  { filter: '1', value: REPORT_STATUS.PENDING, labelKey: 'statusPending', color: 'processing' },
  { filter: '2', value: REPORT_STATUS.RESOLVED, labelKey: 'statusResolved', color: 'success' },
  { filter: '3', value: REPORT_STATUS.DISMISSED, labelKey: 'statusDismissed', color: 'default' },
];

export function getReportStatusConfig(status: unknown): ReportStatusConfig {
  return (
    REPORT_STATUS_LIST.find((item) => item.value === status) ?? {
      filter: '',
      value: String(status) as ReportStatus,
      labelKey: 'statusPending',
      color: 'default',
    }
  );
}

/** 举报目标类型 → 展示文案 i18n key（report ns） */
export function getTargetTypeLabelKey(targetType: unknown): string {
  switch (targetType) {
    case REPORT_TARGET_TYPE.VIDEO:
      return 'targetVideo';
    case REPORT_TARGET_TYPE.COMMENT:
      return 'targetComment';
    case REPORT_TARGET_TYPE.USER:
      return 'targetUser';
    default:
      return 'targetVideo';
  }
}
