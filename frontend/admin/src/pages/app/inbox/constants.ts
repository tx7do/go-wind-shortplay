/**
 * 收件箱模块枚举映射常量。
 * 与基座差异：本后端管理端链路未读即 SENT（已读直接置 READ，不落 RECEIVED），
 * 因此 SENT 显示为「未读」而非基座的「已发送」。
 */

type TFn = (key: string, options?: Record<string, any>) => string;

// ========== 接收者消息状态 ==========

export const RECIPIENT_STATUS_COLORS: Record<string, string> = {
  SENT: 'processing',
  RECEIVED: 'processing',
  READ: 'success',
  REVOKED: 'warning',
  DELETED: 'error',
};

export function getRecipientStatusMap(t: TFn) {
  return {
    SENT: { text: t('statusMap.SENT'), color: RECIPIENT_STATUS_COLORS.SENT },
    RECEIVED: { text: t('statusMap.RECEIVED'), color: RECIPIENT_STATUS_COLORS.RECEIVED },
    READ: { text: t('statusMap.READ'), color: RECIPIENT_STATUS_COLORS.READ },
    REVOKED: { text: t('statusMap.REVOKED'), color: RECIPIENT_STATUS_COLORS.REVOKED },
    DELETED: { text: t('statusMap.DELETED'), color: RECIPIENT_STATUS_COLORS.DELETED },
  };
}

export function getRecipientStatusOptions(t: TFn) {
  return [
    { label: t('statusMap.SENT'), value: 'SENT' },
    { label: t('statusMap.RECEIVED'), value: 'RECEIVED' },
    { label: t('statusMap.READ'), value: 'READ' },
    { label: t('statusMap.REVOKED'), value: 'REVOKED' },
    { label: t('statusMap.DELETED'), value: 'DELETED' },
  ];
}
