/**
 * 顶栏通知铃
 *
 * 从 cms HeaderContent 的通知弹出框适配：
 * - 原版依赖 SSE 实时推送（internal-message 域），本后端无管理端 SSE，
 *   未读数改为 react-query 30s 轮询（useGetUnreadCount 内置 refetchInterval）；
 * - 角标（GET /notifications/unread-count）+ 弹出层（最近 5 条，GET /notifications）+
 *   全部已读 / 单条已读；点击带 videoId 的通知跳 /videos 页；
 * - 「查看全部」抽屉提供分页列表与「只看未读」过滤。
 */
import { useState } from 'react';
import { App as AntdApp, Badge, Button, Drawer, Empty, Popover, Switch, Tooltip } from 'antd';
import { BellOutlined, CheckOutlined } from '@ant-design/icons';
import dayjs from 'dayjs';
import relativeTime from 'dayjs/plugin/relativeTime';
import 'dayjs/locale/zh-cn';
import { useNavigate } from 'react-router-dom';
import { useTranslation } from 'react-i18next';
import { useQuery } from '@tanstack/react-query';

import {
  fetchListNotifications,
  getNotificationTypeLabel,
  useGetUnreadCount,
  useMarkAllNotificationsRead,
  useMarkNotificationsRead,
} from '@/api/hooks/profile';
import type { AdminNotification } from '@/api/types';
import { usePreferencesStore } from '@/core/preferences/store';
import { getPresetColor } from '@/utils/color';

dayjs.extend(relativeTime);

/** 通知列表的相对时间（如"5 分钟前"）；跟随界面语言 */
const fromNow = (value?: string, locale?: string): string => {
  if (!value) return '-';
  const d = dayjs(value);
  if (!d.isValid()) return '-';
  return locale?.startsWith('zh') ? d.locale('zh-cn').fromNow() : d.fromNow();
};

interface NotificationBellProps {
  btnStyle?: React.CSSProperties;
}

const NotificationBell = ({ btnStyle }: NotificationBellProps) => {
  const { t } = useTranslation('notification');
  const { message } = AntdApp.useApp();
  const navigate = useNavigate();
  const appLocale = usePreferencesStore((state) => state.preferences.app.locale);

  // 弹出层 / 抽屉开关
  const [popoverOpen, setPopoverOpen] = useState(false);
  const [drawerOpen, setDrawerOpen] = useState(false);

  // 未读数角标（30s 轮询见 hook 内部）
  const { data: unread } = useGetUnreadCount();
  const unreadCount = Number(unread?.count ?? 0);

  // 弹层列表：最近 5 条（已读+未读混合），未读带圆点加粗
  const { data: recentRes, isLoading: recentLoading } = useQuery({
    queryKey: ['listAdminNotifications', { pageNum: 1, pageSize: 5 }],
    queryFn: () => fetchListNotifications({ pageNum: 1, pageSize: 5 }),
    enabled: popoverOpen,
  });
  const recentItems = recentRes?.items ?? [];

  // 抽屉列表：分页 + 只看未读
  const [drawerPage, setDrawerPage] = useState(1);
  const [unreadOnly, setUnreadOnly] = useState(false);
  const drawerPageSize = 20;
  const { data: listRes, isLoading: listLoading } = useQuery({
    queryKey: ['listAdminNotifications', { pageNum: drawerPage, pageSize: drawerPageSize, unreadOnly }],
    queryFn: () => fetchListNotifications({ pageNum: drawerPage, pageSize: drawerPageSize, unreadOnly }),
    enabled: drawerOpen,
  });
  const listItems = listRes?.items ?? [];
  const listTotal = Number(listRes?.total ?? 0);

  const markReadMutation = useMarkNotificationsRead();
  const markAllMutation = useMarkAllNotificationsRead({
    onSuccess: () => message.success(t('markAllReadSuccess')),
    onError: (error: Error) => message.error(error.message || t('markAllReadFailed')),
  });

  /** 单条已读（未读才调接口） */
  const markOneRead = (item: AdminNotification) => {
    if (item.isRead || item.id == null) return;
    markReadMutation.mutate({ ids: [item.id] });
  };

  /** 点击通知：标记已读；带 videoId 的跳 /videos 页 */
  const handleItemClick = (item: AdminNotification) => {
    markOneRead(item);
    setPopoverOpen(false);
    setDrawerOpen(false);
    if (item.videoId != null) {
      navigate('/videos');
    }
  };

  /** 单条通知行（弹层与抽屉共用渲染） */
  const renderItem = (item: AdminNotification, index: number) => {
    const unreadItem = !item.isRead;
    const typeLabel = getNotificationTypeLabel(item.type);
    return (
      <div
        key={item.id ?? index}
        className="notification-item"
        style={{
          display: 'flex',
          alignItems: 'center',
          padding: '9px 8px',
          borderRadius: 8,
          cursor: 'pointer',
          gap: 10,
        }}
        onClick={() => handleItemClick(item)}
      >
        {/* 未读圆点 */}
        <span
          className="notification-item__dot"
          style={{
            width: 6,
            height: 6,
            borderRadius: '50%',
            flexShrink: 0,
            marginTop: 6,
            background: unreadItem ? 'var(--ant-color-primary)' : 'transparent',
          }}
        />
        <div style={{ flex: 1, minWidth: 0 }}>
          <div
            style={{
              fontSize: 13,
              fontWeight: unreadItem ? 600 : 400,
              color: unreadItem ? 'var(--ant-color-text)' : 'var(--ant-color-text-secondary)',
              overflow: 'hidden',
              textOverflow: 'ellipsis',
              whiteSpace: 'nowrap',
            }}
          >
            {item.content || '-'}
          </div>
          <div
            style={{
              display: 'flex',
              alignItems: 'center',
              gap: 6,
              marginTop: 2,
              fontSize: 12,
              color: 'var(--ant-color-text-secondary)',
            }}
          >
            {item.sender?.nickname && <span style={{ color: getPresetColor(item.sender.nickname) }}>{item.sender.nickname}</span>}
            <span>{t(`type.${typeLabel}`)}</span>
            {item.videoId != null && <span>· {t('hasVideo')}</span>}
          </div>
        </div>
        {/* 单条已读按钮 */}
        {unreadItem && item.id != null && (
          <Tooltip title={t('markRead')}>
            <Button
              type="text"
              size="small"
              icon={<CheckOutlined />}
              onClick={(e) => {
                e.stopPropagation();
                markOneRead(item);
              }}
            />
          </Tooltip>
        )}
        <span style={{ fontSize: 12, color: 'var(--ant-color-text-secondary)', flexShrink: 0 }}>
          {fromNow(item.createdAt, appLocale)}
        </span>
      </div>
    );
  };

  const renderList = (items: AdminNotification[], loading: boolean, emptyText: string) => (
    <div style={{ maxHeight: 420, overflowY: 'auto', minWidth: 300 }}>
      {items.length > 0 ? (
        items.map((item, index) => renderItem(item, index))
      ) : (
        <Empty description={loading ? t('loading') : emptyText} image={Empty.PRESENTED_IMAGE_SIMPLE} style={{ padding: '16px 0' }} />
      )}
    </div>
  );

  // 弹出层内容：标题 + 未读数 + 全部已读 / 最近 5 条 / 查看全部入口
  const popoverContent = (
    <div className="notification-popover" style={{ width: 336 }}>
      <div
        style={{
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'space-between',
          padding: '2px 2px 10px',
          borderBottom: '1px solid var(--ant-color-border)',
          marginBottom: 4,
        }}
      >
        <div style={{ display: 'flex', alignItems: 'center', gap: 8, fontSize: 14, fontWeight: 600 }}>
          {t('pageTitle')}
          {unreadCount > 0 && (
            <span
              style={{
                fontSize: 12,
                fontWeight: 400,
                lineHeight: '18px',
                padding: '0 8px',
                borderRadius: 10,
                color: 'var(--ant-color-primary)',
                background: 'color-mix(in srgb, var(--ant-color-primary) 12%, transparent)',
              }}
            >
              {t('unreadCount', { count: unreadCount })}
            </span>
          )}
        </div>
        <Button
          type="text"
          size="small"
          icon={<CheckOutlined />}
          loading={markAllMutation.isPending}
          disabled={unreadCount <= 0}
          onClick={() => markAllMutation.mutate()}
        >
          {t('markAllRead')}
        </Button>
      </div>

      {renderList(recentItems, recentLoading, t('noMessages'))}

      <div
        style={{
          borderTop: '1px solid var(--ant-color-border)',
          textAlign: 'center',
          padding: '8px 0 0',
          marginTop: 4,
        }}
      >
        <Button
          type="link"
          size="small"
          onClick={() => {
            setPopoverOpen(false);
            setDrawerPage(1);
            setDrawerOpen(true);
          }}
        >
          {t('viewAll')}
        </Button>
      </div>
    </div>
  );

  return (
    <>
      <Popover
        content={popoverContent}
        trigger="click"
        placement="bottomRight"
        open={popoverOpen}
        onOpenChange={setPopoverOpen}
        styles={{ body: { padding: '10px 10px 6px' } } as never}
      >
        <Badge count={unreadCount} size="small" offset={[0, 4]}>
          <Tooltip title={t('pageTitle')}>
            <Button type="text" icon={<BellOutlined />} size="small" style={btnStyle} />
          </Tooltip>
        </Badge>
      </Popover>

      {/* 全量通知抽屉：分页 + 只看未读 */}
      <Drawer
        title={t('pageTitle')}
        open={drawerOpen}
        onClose={() => setDrawerOpen(false)}
        width={420}
        destroyOnHidden
        extra={
          <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
            <span style={{ fontSize: 13 }}>{t('unreadOnly')}</span>
            <Switch size="small" checked={unreadOnly} onChange={(v) => { setUnreadOnly(v); setDrawerPage(1); }} />
          </div>
        }
      >
        {renderList(listItems, listLoading, t('noMessages'))}
        {listTotal > drawerPageSize && (
          <div style={{ display: 'flex', justifyContent: 'flex-end', marginTop: 12 }}>
            <Button
              size="small"
              disabled={drawerPage <= 1}
              onClick={() => setDrawerPage((p) => p - 1)}
            >
              {t('prevPage')}
            </Button>
            <span style={{ lineHeight: '24px', padding: '0 12px', fontSize: 13 }}>
              {drawerPage} / {Math.max(1, Math.ceil(listTotal / drawerPageSize))}
            </span>
            <Button
              size="small"
              disabled={drawerPage >= Math.ceil(listTotal / drawerPageSize)}
              onClick={() => setDrawerPage((p) => p + 1)}
            >
              {t('nextPage')}
            </Button>
          </div>
        )}
      </Drawer>
    </>
  );
};

export default NotificationBell;
