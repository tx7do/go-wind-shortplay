import { useMemo, useState } from 'react';
import ReactECharts from 'echarts-for-react';
import { Card, Col, Row, Segmented, Spin, Table } from 'antd';
import type { ColumnsType } from 'antd/es/table';
import {
  CommentOutlined,
  EyeOutlined,
  HeartOutlined,
  PlaySquareOutlined,
  TrophyOutlined,
  UserOutlined,
  VideoCameraOutlined,
} from '@ant-design/icons';
import { useI18n } from '@/core/i18n';
import ContentContainer from '@/layouts/components/PageContainer/ContentContainer';
import {
  TOP_METRIC,
  type TopMetric,
  type Video,
} from '@/api/types';
import { useGetDashboardOverview, useListTopVideos } from '@/api/hooks';

// protojson int64 经 JSON 序列化为字符串("2")，统一转 number（对齐底座 toNum）。
function toNum(v: number | string | undefined): number {
  return Number(v ?? 0);
}

const chartBaseStyle = { height: 360, width: '100%' } as const;
const spinStyle = { display: 'block', margin: '80px auto' } as const;

/** 概览统计卡（形态沿用底座 dashboard：圆形图标 + 主数字） */
function StatCard({
  icon,
  title,
  value,
  tone,
}: {
  icon: React.ReactNode;
  title: string;
  value: number;
  tone: string;
}) {
  return (
    <Card styles={{ body: { padding: '20px 24px' } }}>
      <div style={{ display: 'flex', alignItems: 'center', gap: 16 }}>
        <div
          style={{
            width: 48,
            height: 48,
            borderRadius: '50%',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            fontSize: 22,
            color: '#fff',
            background: tone,
            flexShrink: 0,
          }}
        >
          {icon}
        </div>
        <div style={{ flex: 1, minWidth: 0 }}>
          <div style={{ fontSize: 13, color: 'var(--ant-color-text-secondary)' }}>
            {title}
          </div>
          <div style={{ fontSize: 26, fontWeight: 600, lineHeight: 1.3 }}>
            {value.toLocaleString()}
          </div>
        </div>
      </div>
    </Card>
  );
}

/** metric → Video 计数字段映射（top-videos 返回完整 Video，按所选指标取数） */
const METRIC_FIELD: Record<string, (v: Video) => number> = {
  [TOP_METRIC.VIEW]: (v) => toNum(v.viewCount),
  [TOP_METRIC.LIKE]: (v) => toNum(v.likeCount),
  [TOP_METRIC.COLLECT]: (v) => toNum(v.collectCount),
  [TOP_METRIC.COMMENT]: (v) => toNum(v.commentCount),
};

/** 视频 TOP10 排行（metric 切换 + 横向条形图，TOP1 在顶部） */
const TopVideosCard = () => {
  const { t } = useI18n('dashboard');
  const [metric, setMetric] = useState<TopMetric>(TOP_METRIC.VIEW);
  const { data, isLoading } = useListTopVideos(metric, 10);

  const items = data?.items ?? [];

  const option = useMemo(() => {
    // echarts 的 y 类轴自下而上，reverse 使 TOP1 显示在顶部
    const titles = items
      .map((item) => item.title || t('top.titleFallback'))
      .reverse();
    const counter = METRIC_FIELD[metric];
    const counts = items.map((item) => (counter ? counter(item) : 0)).reverse();
    return {
      grid: { bottom: 0, containLabel: true, left: '1%', right: '8%', top: '2%' },
      series: [
        {
          data: counts,
          itemStyle: { color: '#006BE6' },
          label: { position: 'right', show: true },
          name: t('top.count'),
          type: 'bar',
        },
      ],
      tooltip: {
        trigger: 'axis',
      },
      xAxis: { minInterval: 1, type: 'value' },
      yAxis: {
        axisTick: { show: false },
        axisLabel: {
          formatter: (value: string) => (value.length > 10 ? `${value.slice(0, 10)}…` : value),
        },
        data: titles,
        type: 'category',
      },
    };
  }, [items, metric, t]);

  // 排行明细列（与图表互补：作者 / 精确计数）
  const columns: ColumnsType<Video> = [
    {
      title: t('top.rank'),
      width: 60,
      align: 'center',
      render: (_, __, index) => index + 1,
    },
    {
      title: t('top.video'),
      ellipsis: true,
      render: (_, record) => (
        <span>
          {record.coverUrl && (
            <img
              src={record.coverUrl}
              alt=""
              style={{ width: 32, height: 20, objectFit: 'cover', borderRadius: 4, marginRight: 8 }}
            />
          )}
          {record.title || t('top.titleFallback')}
        </span>
      ),
    },
    {
      title: t('top.count'),
      width: 90,
      align: 'right',
      render: (_, record) => (METRIC_FIELD[metric]?.(record) ?? 0).toLocaleString(),
    },
  ];

  return (
    <Card
      title={
        <span style={{ display: 'inline-flex', alignItems: 'center', gap: 8 }}>
          <TrophyOutlined /> {t('top.title')}
        </span>
      }
      extra={
        <Segmented
          value={metric}
          onChange={(v) => setMetric(v as TopMetric)}
          options={[
            { label: t('top.metricView'), value: TOP_METRIC.VIEW },
            { label: t('top.metricLike'), value: TOP_METRIC.LIKE },
            { label: t('top.metricCollect'), value: TOP_METRIC.COLLECT },
            { label: t('top.metricComment'), value: TOP_METRIC.COMMENT },
          ]}
        />
      }
      styles={{ body: { paddingTop: 12 } }}
    >
      {isLoading ? (
        <Spin style={spinStyle} />
      ) : items.length === 0 ? (
        <div style={{ textAlign: 'center', padding: '60px 0', color: 'var(--ant-color-text-secondary)' }}>
          {t('top.empty')}
        </div>
      ) : (
        <Row gutter={[16, 16]}>
          <Col lg={14} xs={24}>
            <ReactECharts option={option} notMerge style={chartBaseStyle} />
          </Col>
          <Col lg={10} xs={24}>
            <Table<Video>
              columns={columns}
              dataSource={items}
              rowKey="id"
              pagination={false}
              size="small"
              scroll={{ y: 320 }}
            />
          </Col>
        </Row>
      )}
    </Card>
  );
};

/**
 * 数据看板：7 统计卡（视频/播放/点赞/评论/用户/今日发布）+ TOP10 排行。
 * 数据源 GET /dashboard/overview 与 GET /dashboard/top-videos（metric 切换）。
 */
const Dashboard = () => {
  const { t } = useI18n('dashboard');
  const overviewQuery = useGetDashboardOverview();
  const o = overviewQuery.data;

  const statItems = [
    { icon: <VideoCameraOutlined />, title: t('stats.totalVideos'), tone: '#13c2c2', value: toNum(o?.totalVideos) },
    { icon: <PlaySquareOutlined />, title: t('stats.publishedVideos'), tone: '#006BE6', value: toNum(o?.publishedVideos) },
    { icon: <EyeOutlined />, title: t('stats.totalViews'), tone: '#5ab1ef', value: toNum(o?.totalViews) },
    { icon: <HeartOutlined />, title: t('stats.totalLikes'), tone: '#f5222d', value: toNum(o?.totalLikes) },
    { icon: <CommentOutlined />, title: t('stats.totalComments'), tone: '#722ed1', value: toNum(o?.totalComments) },
    { icon: <UserOutlined />, title: t('stats.totalUsers'), tone: '#52c41a', value: toNum(o?.totalUsers) },
    { icon: <PlaySquareOutlined />, title: t('stats.todayPublished'), tone: '#fa8c16', value: toNum(o?.todayPublished) },
  ];

  return (
    <ContentContainer heightMode="auto" scrollable padding="16px">
      {/* 统计卡：7 项核心指标 */}
      <Row gutter={[16, 16]}>
        {statItems.map((item) => (
          <Col key={item.title} lg={6} sm={12} xs={24}>
            <StatCard icon={item.icon} title={item.title} tone={item.tone} value={item.value} />
          </Col>
        ))}
      </Row>

      {/* 视频 TOP10 排行（播放/点赞/收藏/评论指标切换） */}
      <div style={{ marginTop: 16 }}>
        <TopVideosCard />
      </div>
    </ContentContainer>
  );
};

export default Dashboard;
