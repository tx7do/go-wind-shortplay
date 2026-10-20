import { Table, Descriptions, Drawer, Image, Space, Tag, Typography } from 'antd';
import type { ColumnsType } from 'antd/es/table';
import { useTranslation } from 'react-i18next';
import dayjs from 'dayjs';

import { useGetSeries } from '@/api/hooks';
import type { Video } from '@/api/types';
import { formatDuration, getEpisodeStatusConfig, toNum } from './constants';

interface SeriesDetailDrawerProps {
  open: boolean;
  /** 列表行（剧信息直接展示）；选集经 GET /admin/v1/series/{id} 拉取（含未发布） */
  seriesId?: number;
  onClose: () => void;
}

/**
 * 剧集详情抽屉：剧信息 + 剧内选集小表（集号/封面/标题/状态/时长）。
 * admin 视角全集可见（含草稿/审核中/驳回/下架）。
 */
const SeriesDetailDrawer = ({ open, seriesId, onClose }: SeriesDetailDrawerProps) => {
  const { t } = useTranslation('series');
  // 详情随抽屉打开拉取（关闭即停轮询，无缓存压力）
  const { data, isFetching } = useGetSeries(open ? seriesId : undefined);
  const series = data?.series;
  const episodes = data?.items ?? [];

  const formatTime = (value?: string) =>
    value && dayjs(value).isValid() ? dayjs(value).format('YYYY-MM-DD HH:mm:ss') : '-';

  const episodeColumns: ColumnsType<Video> = [
    {
      title: t('episodeNumber'),
      dataIndex: 'episodeNumber',
      width: 64,
      render: (_, record) => record.episodeNumber ?? '-',
    },
    {
      title: t('cover'),
      dataIndex: 'coverUrl',
      width: 84,
      render: (_, record) =>
        record.coverUrl ? (
          <Image
            src={record.coverUrl}
            alt={record.title}
            width={64}
            height={36}
            style={{ objectFit: 'cover', borderRadius: 4 }}
          />
        ) : (
          '-'
        ),
    },
    {
      title: t('episodeTitle'),
      dataIndex: 'title',
      ellipsis: true,
    },
    {
      title: t('episodeStatus'),
      dataIndex: 'status',
      width: 88,
      render: (_, record) => {
        const config = getEpisodeStatusConfig(record.status);
        return <Tag color={config.color}>{t(config.labelKey)}</Tag>;
      },
    },
    {
      title: t('episodeDuration'),
      dataIndex: 'duration',
      width: 80,
      render: (_, record) => formatDuration(record.duration),
    },
    {
      title: t('episodeViewCount'),
      dataIndex: 'viewCount',
      width: 80,
      render: (_, record) => toNum(record.viewCount).toLocaleString(),
    },
  ];

  return (
    <Drawer title={t('detail')} size={720} open={open} onClose={onClose} destroyOnHidden>
      {series && (
        <>
          <Descriptions
            column={2}
            size="small"
            items={[
              { key: 'title', label: t('title'), children: series.title || '-' },
              { key: 'authorId', label: t('authorId'), children: series.authorId ?? '-' },
              {
                key: 'counts',
                label: t('episodeCounts'),
                children: (
                  <Space wrap size={4}>
                    <Tag>{`${t('publishedCount')} ${toNum(series.publishedCount).toLocaleString()}`}</Tag>
                    <Tag>{`${t('totalCount')} ${toNum(series.episodeCount).toLocaleString()}`}</Tag>
                  </Space>
                ),
              },
              {
                key: 'createdAt',
                label: t('createdAt'),
                children: formatTime(series.createdAt),
              },
              {
                key: 'description',
                label: t('description'),
                span: 4,
                children: series.description || '-',
              },
              ...(series.coverUrl
                ? [
                    {
                      key: 'cover',
                      label: t('cover'),
                      span: 4 as const,
                      children: (
                        <Image
                          src={series.coverUrl}
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

          <Typography.Title level={5} style={{ marginTop: 20 }}>
            {t('episodeList', { count: episodes.length })}
          </Typography.Title>
          <Table<Video>
            rowKey="id"
            columns={episodeColumns}
            dataSource={episodes}
            loading={isFetching}
            size="small"
            pagination={false}
            scroll={{ x: 560 }}
            locale={{ emptyText: t('episodeEmpty') }}
          />
        </>
      )}
    </Drawer>
  );
};

export default SeriesDetailDrawer;
