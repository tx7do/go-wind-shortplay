import { useMemo } from 'react';
import { Descriptions, Drawer, Image, Space, Tag, Typography } from 'antd';
import { useTranslation } from 'react-i18next';
import dayjs from 'dayjs';

import type { Video } from '@/api/types';
import { resolveMediaUrl } from '@/utils/media';
import { formatDuration, getVideoStatusConfig, toNum } from './constants';

interface VideoDetailDrawerProps {
  open: boolean;
  data: Video | null;
  onClose: () => void;
  /** 底部操作区（审核/下架/删除按钮由列表页注入，保持页面内聚） */
  extra?: React.ReactNode;
}

/**
 * 视频详情抽屉：<video controls> 预览 + 封面 + 标签 + 计数 + 驳回原因。
 * 数据直接使用列表行（后端列表与详情同构，省一次 GET /videos/{id}；
 * 行数据缺失关键字段时由列表页负责刷新）。
 */
const VideoDetailDrawer = ({ open, data, onClose, extra }: VideoDetailDrawerProps) => {
  const { t } = useTranslation('video');

  const statusConfig = useMemo(() => getVideoStatusConfig(data?.status), [data?.status]);
  const videoSrc = resolveMediaUrl(data?.videoUrl);
  const resolution =
    data?.width && data?.height ? `${data.width}×${data.height}` : '-';

  const formatTime = (value?: string) =>
    value && dayjs(value).isValid() ? dayjs(value).format('YYYY-MM-DD HH:mm:ss') : '-';

  return (
    <Drawer
      title={t('detail')}
      size={560}
      open={open}
      onClose={onClose}
      destroyOnHidden
      footer={extra ? <Space style={{ display: 'flex', justifyContent: 'flex-end' }}>{extra}</Space> : null}
    >
      {data && (
        <>
          {/* 视频预览（videoUrl 是对象键，按媒体基地址拼播放 URL） */}
          {videoSrc ? (
            <video
              key={videoSrc}
              src={videoSrc}
              controls
              playsInline
              poster={data.coverUrl || undefined}
              style={{ width: '100%', maxHeight: 320, borderRadius: 8, background: '#000' }}
            />
          ) : (
            <Typography.Text type="secondary">-</Typography.Text>
          )}

          <Descriptions
            column={2}
            size="small"
            style={{ marginTop: 16 }}
            items={[
              { key: 'title', label: t('title'), span: 2, children: data.title || '-' },
              {
                key: 'status',
                label: t('status'),
                children: (
                  <Tag color={statusConfig.color}>{t(statusConfig.labelKey)}</Tag>
                ),
              },
              {
                key: 'publishedAt',
                label: t('publishedAt'),
                children: formatTime(data.publishedAt),
              },
              {
                key: 'duration',
                label: t('duration'),
                children: formatDuration(data.duration),
              },
              { key: 'authorId', label: t('authorId'), children: data.authorId ?? '-' },
              {
                key: 'resolution',
                label: t('resolution'),
                span: 2,
                children: resolution,
              },
              {
                key: 'description',
                label: t('description'),
                span: 2,
                children: data.description || '-',
              },
              {
                key: 'tags',
                label: t('tags'),
                span: 2,
                children: data.tags?.length ? (
                  <Space wrap size={4}>
                    {data.tags.map((tag) => (
                      <Tag key={tag} color="blue" style={{ marginBottom: 2 }}>
                        {tag}
                      </Tag>
                    ))}
                  </Space>
                ) : (
                  '-'
                ),
              },
              {
                key: 'counts',
                label: t('statsInfo'),
                span: 2,
                children: (
                  <Space wrap size={8}>
                    <Tag>{`${t('viewCount')} ${toNum(data.viewCount).toLocaleString()}`}</Tag>
                    <Tag>{`${t('likeCount')} ${toNum(data.likeCount).toLocaleString()}`}</Tag>
                    <Tag>{`${t('collectCount')} ${toNum(data.collectCount).toLocaleString()}`}</Tag>
                    <Tag>{`${t('commentCount')} ${toNum(data.commentCount).toLocaleString()}`}</Tag>
                  </Space>
                ),
              },
              ...(data.rejectReason
                ? [
                    {
                      key: 'rejectReason',
                      label: t('rejectReason'),
                      span: 2 as const,
                      children: (
                        <Typography.Text type="danger">{data.rejectReason}</Typography.Text>
                      ),
                    },
                  ]
                : []),
              {
                key: 'createdAt',
                label: t('createdAt'),
                children: formatTime(data.createdAt),
              },
              {
                key: 'updatedAt',
                label: t('updatedAt'),
                children: formatTime(data.updatedAt),
              },
              ...(data.coverUrl
                ? [
                    {
                      key: 'cover',
                      label: t('cover'),
                      span: 2 as const,
                      children: (
                        <Image
                          src={data.coverUrl}
                          alt="cover"
                          width={160}
                          style={{ borderRadius: 6 }}
                        />
                      ),
                    },
                  ]
                : []),
            ]}
          />
        </>
      )}
    </Drawer>
  );
};

export default VideoDetailDrawer;
