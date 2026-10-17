/**
 * 视频详情抽屉：<video> 在线预览 + 封面 / 简介 / 标签 / 驳回原因等完整信息。
 * 打开时重新拉取 GET /videos/{id}，失败则回退展示列表行数据。
 */
import { useEffect, useState } from 'react';
import { Descriptions, Drawer, Image, Spin, Tag } from 'antd';
import { getVideo } from '../api/video';
import type { Video } from '../types';
import { VIDEO_STATUS_MAP, formatDateTime, formatDuration, formatNumber } from '../utils/format';

interface VideoDetailDrawerProps {
  video: Video | null;
  onClose: () => void;
}

export default function VideoDetailDrawer({ video, onClose }: VideoDetailDrawerProps) {
  const [detail, setDetail] = useState<Video | null>(null);
  const [loading, setLoading] = useState(false);

  useEffect(() => {
    if (!video) {
      setDetail(null);
      return;
    }
    let cancelled = false;
    setLoading(true);
    getVideo(video.id)
      .then((data) => {
        if (!cancelled) setDetail(data);
      })
      .catch(() => {
        // 详情接口失败时回退为列表行数据
        if (!cancelled) setDetail(video);
      })
      .finally(() => {
        if (!cancelled) setLoading(false);
      });
    return () => {
      cancelled = true;
    };
  }, [video]);

  const status = detail ? VIDEO_STATUS_MAP[detail.status] : undefined;

  return (
    <Drawer
      title={detail ? `视频详情 #${detail.id}` : '视频详情'}
      width={560}
      open={!!video}
      onClose={onClose}
      destroyOnClose
    >
      <Spin spinning={loading}>
        {detail && (
          <>
            {detail.videoUrl ? (
              <video
                controls
                src={detail.videoUrl}
                poster={detail.coverUrl}
                style={{ width: '100%', maxHeight: 320, background: '#000', borderRadius: 8 }}
              >
                您的浏览器不支持 video 标签
              </video>
            ) : (
              <p style={{ color: '#999' }}>暂无视频地址，无法预览</p>
            )}

            <Descriptions
              column={1}
              size="small"
              bordered
              style={{ marginTop: 16 }}
              items={[
                { key: 'title', label: '标题', children: detail.title || '—' },
                { key: 'status', label: '状态', children: <Tag color={status?.color}>{status?.label ?? '未知'}</Tag> },
                { key: 'author', label: '作者 ID', children: detail.authorId ?? '—' },
                {
                  key: 'desc',
                  label: '简介',
                  children: detail.description || '—',
                },
                {
                  key: 'tags',
                  label: '标签',
                  children: detail.tags?.length ? (
                    <>
                      {detail.tags.map((t) => (
                        <Tag key={t}>{t}</Tag>
                      ))}
                    </>
                  ) : (
                    '—'
                  ),
                },
                {
                  key: 'duration',
                  label: '时长 / 分辨率',
                  children: `${formatDuration(detail.duration)}${detail.width && detail.height ? ` / ${detail.width}x${detail.height}` : ''}`,
                },
                {
                  key: 'counts',
                  label: '播放 / 点赞 / 收藏 / 评论',
                  children: `${formatNumber(detail.viewCount)} / ${formatNumber(detail.likeCount)} / ${formatNumber(detail.collectCount)} / ${formatNumber(detail.commentCount)}`,
                },
                ...(detail.status === 4
                  ? [{ key: 'reject', label: '驳回原因', children: detail.rejectReason || '—' }]
                  : []),
                { key: 'videoUrl', label: '视频地址', children: detail.videoUrl || '—' },
                { key: 'coverUrl', label: '封面', children: detail.coverUrl ? <Image src={detail.coverUrl} width={160} /> : '—' },
                { key: 'publishedAt', label: '发布时间', children: formatDateTime(detail.publishedAt) },
                { key: 'createdAt', label: '创建时间', children: formatDateTime(detail.createdAt) },
              ]}
            />
          </>
        )}
      </Spin>
    </Drawer>
  );
}
