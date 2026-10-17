/**
 * 数据看板：
 * - GET /dashboard/overview 统计卡片（总视频/在线视频/总播放/总点赞/总评论/用户数/今日发布）
 * - GET /dashboard/top-videos 排行表，支持 metric 切换（VIEW/LIKE/COLLECT/COMMENT）
 */
import { useEffect, useState } from 'react';
import type { ReactNode } from 'react';
import { Card, Col, Radio, Row, Spin, Table, Tag } from 'antd';
import type { ColumnsType } from 'antd/es/table';
import {
  CommentOutlined,
  EyeOutlined,
  FireOutlined,
  HeartOutlined,
  PlayCircleOutlined,
  TeamOutlined,
  VideoCameraOutlined,
} from '@ant-design/icons';
import { getOverview, listTopVideos } from '../../api/dashboard';
import type { Overview, TopMetric, Video } from '../../types';
import { METRIC_OPTIONS, formatDateTime, formatNumber } from '../../utils/format';

/** 总览统计卡片配置 */
const OVERVIEW_CARDS: {
  key: keyof Overview;
  title: string;
  icon: ReactNode;
  color: string;
}[] = [
  { key: 'totalVideos', title: '总视频数', icon: <VideoCameraOutlined />, color: '#1677ff' },
  { key: 'publishedVideos', title: '在线视频', icon: <PlayCircleOutlined />, color: '#52c41a' },
  { key: 'totalViews', title: '总播放量', icon: <EyeOutlined />, color: '#722ed1' },
  { key: 'totalLikes', title: '总点赞数', icon: <HeartOutlined />, color: '#eb2f96' },
  { key: 'totalComments', title: '总评论数', icon: <CommentOutlined />, color: '#fa8c16' },
  { key: 'totalUsers', title: '用户总数', icon: <TeamOutlined />, color: '#13c2c2' },
  { key: 'todayPublished', title: '今日发布', icon: <FireOutlined />, color: '#f5222d' },
];

/** 排行表列定义 */
const TOP_COLUMNS: ColumnsType<Video> = [
  {
    title: '排名',
    key: 'rank',
    width: 70,
    render: (_value, _record, index) => {
      const colors = ['#f5222d', '#fa8c16', '#faad14'];
      return index < 3 ? (
        <Tag color={colors[index]} style={{ fontWeight: 600 }}>
          {index + 1}
        </Tag>
      ) : (
        <span>{index + 1}</span>
      );
    },
  },
  { title: '视频标题', dataIndex: 'title', ellipsis: true },
  { title: '作者 ID', dataIndex: 'authorId', width: 90 },
  { title: '播放量', dataIndex: 'viewCount', width: 110, render: formatNumber },
  { title: '点赞数', dataIndex: 'likeCount', width: 110, render: formatNumber },
  { title: '收藏数', dataIndex: 'collectCount', width: 110, render: formatNumber },
  { title: '评论数', dataIndex: 'commentCount', width: 110, render: formatNumber },
  { title: '发布时间', dataIndex: 'publishedAt', width: 170, render: formatDateTime },
];

export default function DashboardPage() {
  const [overview, setOverview] = useState<Overview>({});
  const [overviewLoading, setOverviewLoading] = useState(true);

  const [metric, setMetric] = useState<TopMetric>('VIEW');
  const [topVideos, setTopVideos] = useState<Video[]>([]);
  const [topLoading, setTopLoading] = useState(false);

  // 加载运营总览
  useEffect(() => {
    let cancelled = false;
    setOverviewLoading(true);
    getOverview()
      .then((data) => {
        if (!cancelled) setOverview(data ?? {});
      })
      .catch(() => {
        // 错误已由拦截器统一提示
      })
      .finally(() => {
        if (!cancelled) setOverviewLoading(false);
      });
    return () => {
      cancelled = true;
    };
  }, []);

  // 按指标加载 TOP 排行
  useEffect(() => {
    let cancelled = false;
    setTopLoading(true);
    listTopVideos(metric, 10)
      .then((data) => {
        if (!cancelled) setTopVideos(data.items);
      })
      .catch(() => {
        // 错误已由拦截器统一提示
      })
      .finally(() => {
        if (!cancelled) setTopLoading(false);
      });
    return () => {
      cancelled = true;
    };
  }, [metric]);

  return (
    <div>
      {/* 统计卡片 */}
      <Spin spinning={overviewLoading}>
        <Row gutter={[16, 16]}>
          {OVERVIEW_CARDS.map((card) => (
            <Col key={card.key} xs={12} sm={12} md={8} lg={6}>
              <Card size="small">
                <Card.Meta
                  avatar={
                    <span style={{ fontSize: 28, color: card.color }}>
                      {card.icon}
                    </span>
                  }
                  title={<span style={{ fontSize: 13, color: '#999' }}>{card.title}</span>}
                  description={<span style={{ fontSize: 24, fontWeight: 600, color: 'rgba(0,0,0,0.88)' }}>{formatNumber(overview[card.key])}</span>}
                />
              </Card>
            </Col>
          ))}
        </Row>
      </Spin>

      {/* TOP 排行 */}
      <Card
        title="视频 TOP 10 排行"
        style={{ marginTop: 16 }}
        extra={
          <Radio.Group
            optionType="button"
            buttonStyle="solid"
            value={metric}
            onChange={(e) => setMetric(e.target.value as TopMetric)}
            options={METRIC_OPTIONS}
          />
        }
      >
        <Table<Video>
          rowKey="id"
          size="small"
          columns={TOP_COLUMNS}
          dataSource={topVideos}
          loading={topLoading}
          pagination={false}
          scroll={{ x: 900 }}
        />
      </Card>
    </div>
  );
}
