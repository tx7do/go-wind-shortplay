import { useMemo, useState, type ReactNode } from 'react';
import ReactECharts from 'echarts-for-react';
import { Card, Col, Row, Segmented, Spin, Table, Empty } from 'antd';
import type { ColumnsType } from 'antd/es/table';
import {
  ArrowRightOutlined,
  CommentOutlined,
  EyeOutlined,
  HeartOutlined,
  LineChartOutlined,
  PlaySquareOutlined,
  TrophyOutlined,
  UserOutlined,
  VideoCameraOutlined,
  WarningOutlined,
} from '@ant-design/icons';
import { useNavigate } from 'react-router-dom';
import { useTranslation } from 'react-i18next';
import dayjs from 'dayjs';
import 'dayjs/locale/zh-cn';

import { useI18n } from '@/core/i18n';
import { usePreferences } from '@/core/preferences/hooks/usePreferences';
import ContentContainer from '@/layouts/components/PageContainer/ContentContainer';
import {
  TOP_METRIC,
  type DashboardOverview,
  type DashboardTrendItem,
  type TopMetric,
  type Video,
} from '@/api/types';
import { useGetDashboardOverview, useGetDashboardTrends, useListTopVideos } from '@/api/hooks';
import { useGetProfile } from '@/api/hooks/profile';
import { useAuthStore } from '@/stores';

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
  icon: ReactNode;
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

/** 按时段问候语：<12 早安，12~18 午安，其余（含凌晨）晚上好 */
function getGreetingKey(hour: number): string {
  if (hour >= 5 && hour < 12) return 'banner.morning';
  if (hour >= 12 && hour < 18) return 'banner.afternoon';
  return 'banner.evening';
}

/** 欢迎横幅：问候 + 今日发布/总播放概要 + 快捷入口卡片（点击跳转对应管理页） */
function WelcomeBanner({ overview }: { overview?: DashboardOverview }) {
  const { t, i18n } = useTranslation('dashboard');
  const navigate = useNavigate();
  const profileQuery = useGetProfile();

  // 昵称：优先个人中心资料，回退登录态 userInfo（刷新后已持久化）。
  // 注意 hook 必须无条件调用，取值后再做回退链。
  const authNickname = useAuthStore((state) => state.userInfo?.nickname);
  const authUsername = useAuthStore((state) => state.userInfo?.username);
  const nickname =
    profileQuery.data?.nickname || authNickname || authUsername || 'Admin';

  // 日期行：随界面语言本地化（dayjs zh-cn 需显式引入）
  const isZh = (i18n.language || 'zh-CN').startsWith('zh');
  const dateText = isZh
    ? dayjs().locale('zh-cn').format('YYYY年M月D日 dddd')
    : dayjs().format('dddd, MMMM D, YYYY');

  const quickEntries = [
    {
      key: 'videos',
      icon: <VideoCameraOutlined />,
      title: t('banner.quickVideos'),
      desc: t('banner.quickVideosDesc'),
      path: '/videos',
    },
    {
      key: 'reports',
      icon: <WarningOutlined />,
      title: t('banner.quickReports'),
      desc: t('banner.quickReportsDesc'),
      path: '/reports',
    },
    {
      key: 'roles',
      icon: <UserOutlined />,
      title: t('banner.quickRoles'),
      desc: t('banner.quickRolesDesc'),
      path: '/permission/roles',
    },
  ];

  return (
    <div
      style={{
        position: 'relative',
        overflow: 'hidden',
        borderRadius: 12,
        padding: '24px 28px',
        background: 'linear-gradient(120deg, #006BE6 0%, #2B7FD9 55%, #13A8A8 100%)',
        color: '#fff',
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'space-between',
        gap: 24,
        flexWrap: 'wrap',
        // ContentContainer 是固定高度的列向 flex：禁止本块被压缩裁切，超出交给滚动
        flexShrink: 0,
      }}
    >
      {/* 背景装饰圆（不响应鼠标） */}
      <div
        aria-hidden
        style={{
          position: 'absolute',
          top: -60,
          right: 220,
          width: 220,
          height: 220,
          borderRadius: '50%',
          background: 'rgba(255,255,255,0.08)',
          pointerEvents: 'none',
        }}
      />
      <div
        aria-hidden
        style={{
          position: 'absolute',
          bottom: -80,
          right: -30,
          width: 200,
          height: 200,
          borderRadius: '50%',
          background: 'rgba(255,255,255,0.06)',
          pointerEvents: 'none',
        }}
      />

      {/* 左侧：问候 + 日期 + 今日概要 */}
      <div style={{ position: 'relative', zIndex: 1, minWidth: 260 }}>
        <div style={{ fontSize: 22, fontWeight: 600, lineHeight: 1.4 }}>
          {t(getGreetingKey(dayjs().hour()))}，{nickname}
        </div>
        <div style={{ marginTop: 6, fontSize: 13, color: 'rgba(255,255,255,0.78)' }}>
          {dateText}
        </div>
        <div style={{ marginTop: 14, display: 'flex', gap: 12, flexWrap: 'wrap' }}>
          <span
            style={{
              display: 'inline-flex',
              alignItems: 'center',
              gap: 6,
              padding: '5px 12px',
              borderRadius: 999,
              background: 'rgba(255,255,255,0.16)',
              fontSize: 13,
            }}
          >
            <VideoCameraOutlined />
            {t('banner.todayPublished')}
            <strong style={{ fontSize: 15 }}>{toNum(overview?.todayPublished).toLocaleString()}</strong>
          </span>
          <span
            style={{
              display: 'inline-flex',
              alignItems: 'center',
              gap: 6,
              padding: '5px 12px',
              borderRadius: 999,
              background: 'rgba(255,255,255,0.16)',
              fontSize: 13,
            }}
          >
            <EyeOutlined />
            {t('banner.totalViews')}
            <strong style={{ fontSize: 15 }}>{toNum(overview?.totalViews).toLocaleString()}</strong>
          </span>
        </div>
      </div>

      {/* 右侧：快捷入口卡片 */}
      <div style={{ position: 'relative', zIndex: 1, display: 'flex', gap: 12, flexWrap: 'wrap' }}>
        {quickEntries.map((entry) => (
          <div
            key={entry.key}
            onClick={() => navigate(entry.path)}
            style={{
              cursor: 'pointer',
              width: 168,
              padding: '14px 16px',
              borderRadius: 10,
              background: 'rgba(255,255,255,0.14)',
              backdropFilter: 'blur(4px)',
              transition: 'background 0.2s',
            }}
            onMouseEnter={(e) => {
              e.currentTarget.style.background = 'rgba(255,255,255,0.26)';
            }}
            onMouseLeave={(e) => {
              e.currentTarget.style.background = 'rgba(255,255,255,0.14)';
            }}
          >
            <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
              <span style={{ fontSize: 20 }}>{entry.icon}</span>
              <ArrowRightOutlined style={{ fontSize: 12, opacity: 0.7 }} />
            </div>
            <div style={{ marginTop: 10, fontSize: 14, fontWeight: 600 }}>{entry.title}</div>
            <div style={{ marginTop: 2, fontSize: 12, color: 'rgba(255,255,255,0.75)' }}>
              {entry.desc}
            </div>
          </div>
        ))}
      </div>
    </div>
  );
}

/** 近 7 日趋势折线图（发布/播放/点赞三条线；后端未就绪时渲染空态，不报错） */
function TrendChartCard() {
  const { t } = useI18n('dashboard');
  const { isDark } = usePreferences();
  const trendsQuery = useGetDashboardTrends(7);

  // items 直接进入下方 useMemo 依赖：data 缺失时 ?? [] 每次渲染都会产出新数组
  // 引用，导致 memo 无效——这里用 useMemo 固定引用，data 不变则 items 不变。
  const items = useMemo<DashboardTrendItem[]>(
    () => trendsQuery.data?.items ?? [],
    [trendsQuery.data],
  );
  const hasData = !trendsQuery.isError && items.length > 0;

  const option = useMemo(() => {
    const textColor = isDark ? '#8B949E' : '#676E7C';
    const axisLineColor = isDark ? 'rgba(255,255,255,0.12)' : 'rgba(0,0,0,0.10)';
    const splitLineColor = isDark ? 'rgba(255,255,255,0.08)' : 'rgba(0,0,0,0.06)';
    return {
      backgroundColor: 'transparent',
      color: ['#006BE6', '#13C2C2', '#F5222D'],
      legend: {
        bottom: 0,
        icon: 'circle',
        itemWidth: 8,
        itemHeight: 8,
        textStyle: { color: textColor },
      },
      tooltip: { trigger: 'axis' },
      grid: { bottom: 44, containLabel: true, left: '1%', right: '2%', top: 24 },
      xAxis: {
        type: 'category',
        boundaryGap: false,
        data: items.map((item) => item.date ?? ''),
        axisLine: { lineStyle: { color: axisLineColor } },
        axisLabel: { color: textColor },
        axisTick: { show: false },
      },
      yAxis: {
        type: 'value',
        minInterval: 1,
        splitLine: { lineStyle: { color: splitLineColor } },
        axisLabel: { color: textColor },
      },
      series: [
        {
          name: t('trend.published'),
          type: 'line',
          smooth: true,
          symbolSize: 6,
          data: items.map((item) => toNum(item.published)),
          areaStyle: { opacity: 0.08 },
        },
        {
          name: t('trend.plays'),
          type: 'line',
          smooth: true,
          symbolSize: 6,
          data: items.map((item) => toNum(item.plays)),
          areaStyle: { opacity: 0.08 },
        },
        {
          name: t('trend.likes'),
          type: 'line',
          smooth: true,
          symbolSize: 6,
          data: items.map((item) => toNum(item.likes)),
          areaStyle: { opacity: 0.08 },
        },
      ],
    };
  }, [items, isDark, t]);

  return (
    <Card
      title={
        <span style={{ display: 'inline-flex', alignItems: 'center', gap: 8 }}>
          <LineChartOutlined /> {t('trend.title')}
        </span>
      }
      styles={{ body: { paddingTop: 12 } }}
    >
      {trendsQuery.isLoading ? (
        <Spin style={spinStyle} />
      ) : !hasData ? (
        // 后端未就绪 / 无数据：空态兜底，不抛错不阻断
        <Empty
          image={Empty.PRESENTED_IMAGE_SIMPLE}
          description={
            <span style={{ color: 'var(--ant-color-text-secondary)' }}>
              {t('trend.empty')}
              <br />
              <span style={{ fontSize: 12 }}>{t('trend.emptyHint')}</span>
            </span>
          }
          style={{ padding: '56px 0' }}
        />
      ) : (
        <ReactECharts option={option} notMerge style={chartBaseStyle} />
      )}
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

/** 视频 TOP10 排行（metric 切换 + 横向条形图，TOP1 在顶部）；narrow = 右 1/3 窄栏竖排 */
const TopVideosCard = ({ layout = 'wide' }: { layout?: 'wide' | 'narrow' }) => {
  const { t } = useI18n('dashboard');
  const [metric, setMetric] = useState<TopMetric>(TOP_METRIC.VIEW);
  const { data, isLoading } = useListTopVideos(metric, 10);

  // items 直接进入下方 useMemo 依赖：data 缺失时 ?? [] 每次渲染都会产出新数组
  // 引用，导致 memo 无效——这里用 useMemo 固定引用，data 不变则 items 不变。
  const items = useMemo(() => data?.items ?? [], [data]);
  const narrow = layout === 'narrow';

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
        // 窄栏（右 1/3）时头部放不下指标切换，移入卡片体内竖排
        narrow ? undefined : (
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
        )
      }
      styles={{ body: { paddingTop: 12 } }}
    >
      {narrow && (
        <Segmented
          block
          value={metric}
          onChange={(v) => setMetric(v as TopMetric)}
          options={[
            { label: t('top.metricView'), value: TOP_METRIC.VIEW },
            { label: t('top.metricLike'), value: TOP_METRIC.LIKE },
            { label: t('top.metricCollect'), value: TOP_METRIC.COLLECT },
            { label: t('top.metricComment'), value: TOP_METRIC.COMMENT },
          ]}
          style={{ marginBottom: 12 }}
        />
      )}
      {isLoading ? (
        <Spin style={spinStyle} />
      ) : items.length === 0 ? (
        <div style={{ textAlign: 'center', padding: '60px 0', color: 'var(--ant-color-text-secondary)' }}>
          {t('top.empty')}
        </div>
      ) : narrow ? (
        // 窄栏（右 1/3）：图表与明细表竖向堆叠
        <>
          <ReactECharts option={option} notMerge style={{ height: 260, width: '100%' }} />
          <Table<Video>
            columns={columns}
            dataSource={items}
            rowKey="id"
            pagination={false}
            size="small"
            style={{ marginTop: 12 }}
            scroll={{ y: 240 }}
          />
        </>
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
 * 数据看板：欢迎横幅（问候 + 今日概要 + 快捷入口）→ 7 统计卡 → 近 7 日趋势（左 2/3）
 * + TOP10 排行（右 1/3）。
 * 数据源 GET /dashboard/overview、GET /dashboard/trends?days=7 与
 * GET /dashboard/top-videos（metric 切换）；趋势接口未就绪时渲染空态不报错。
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
      {/* 欢迎横幅：问候 + 今日发布/总播放概要 + 快捷入口 */}
      <WelcomeBanner overview={o} />

      {/* 统计卡：7 项核心指标（flexShrink:0 防止在固定高度容器内被压缩） */}
      <Row gutter={[16, 16]} style={{ marginTop: 16, flexShrink: 0 }}>
        {statItems.map((item) => (
          <Col key={item.title} lg={6} sm={12} xs={24}>
            <StatCard icon={item.icon} title={item.title} tone={item.tone} value={item.value} />
          </Col>
        ))}
      </Row>

      {/* 近 7 日趋势（左 2/3）+ 视频 TOP10 排行（右 1/3） */}
      <Row gutter={[16, 16]} style={{ marginTop: 16, flexShrink: 0 }}>
        <Col lg={16} xs={24}>
          <TrendChartCard />
        </Col>
        <Col lg={8} xs={24}>
          <TopVideosCard layout="narrow" />
        </Col>
      </Row>
    </ContentContainer>
  );
};

export default Dashboard;
