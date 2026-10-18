/**
 * 用户作品抽屉：内嵌视频表格，复用视频列表 fetchListVideos（GET /videos?authorId=）。
 *
 * 契约见 docs/API.md「Admin 端增补」：视频列表新增 authorId 过滤。后端端点由主线
 * 并行开发，这里先按契约实现；开关由 Drawer 挂载（destroyOnHidden）即 enabled 控制——
 * 未打开不挂载、不发请求，联调失败时表格走 ListTable 统一错误态（可重试），不炸页面。
 */
import type { ProColumns } from '@ant-design/pro-components';
import { Drawer, Image, Tag } from 'antd';
import { useTranslation } from 'react-i18next';
import dayjs from 'dayjs';

import ListTable from '@/components/common/ListTable';
import { TABLE } from '@/config/constants';
import { fetchListVideos } from '@/api/hooks';
import type { AppUser, Video } from '@/api/types';
import { formatDuration, getVideoStatusConfig } from '@/pages/app/video/constants';

interface UserVideosDrawerProps {
  open: boolean;
  /** 目标用户（authorId 来源）；关闭时置空 */
  user: AppUser | null;
  onClose: () => void;
}

/** 抽屉内嵌表格列（视频列表精简版：封面缩略 / 标题 / 状态 / 时长 / 播放 / 点赞 / 创建时间） */
function useVideoColumns(): ProColumns<Video>[] {
  const { t } = useTranslation('video');

  return [
    {
      title: t('cover'),
      dataIndex: 'coverUrl',
      search: false,
      width: 100,
      render: (_, record) =>
        record.coverUrl ? (
          <Image
            src={record.coverUrl}
            alt={record.title}
            width={78}
            height={44}
            style={{ objectFit: 'cover', borderRadius: 4 }}
          />
        ) : (
          '-'
        ),
    },
    {
      title: t('title'),
      dataIndex: 'query',
      ellipsis: true,
      fieldProps: {
        placeholder: t('queryPlaceholder'),
        allowClear: true,
      },
      // 搜索键名对齐后端：标题模糊搜索走 ?query=（展示仍读 record.title）
      search: {
        transform: (value: string) => ({ query: value }),
      },
      render: (_, record) => record.title || '-',
    },
    {
      title: t('status'),
      dataIndex: 'status',
      search: false,
      width: 90,
      render: (_, record) => {
        const config = getVideoStatusConfig(record.status);
        return <Tag color={config.color}>{t(config.labelKey)}</Tag>;
      },
    },
    {
      title: t('duration'),
      dataIndex: 'duration',
      search: false,
      width: 80,
      render: (_, record) => formatDuration(record.duration),
    },
    {
      title: t('viewCount'),
      dataIndex: 'viewCount',
      search: false,
      width: 90,
      render: (_, record) => String(record.viewCount ?? '0'),
    },
    {
      title: t('likeCount'),
      dataIndex: 'likeCount',
      search: false,
      width: 90,
      render: (_, record) => String(record.likeCount ?? '0'),
    },
    {
      title: t('createdAt'),
      dataIndex: 'createdAt',
      search: false,
      width: 150,
      render: (_, record) =>
        record.createdAt ? dayjs(record.createdAt).format('YYYY-MM-DD HH:mm') : '',
    },
  ];
}

const UserVideosDrawer = ({ open, user, onClose }: UserVideosDrawerProps) => {
  const { t } = useTranslation('user');
  const columns = useVideoColumns();

  return (
    <Drawer
      title={
        user
          ? `${t('worksTitle')} · ${user.nickname || user.username || `ID ${user.id}`}`
          : t('worksTitle')
      }
      width={920}
      open={open}
      onClose={onClose}
      destroyOnHidden
    >
      <ListTable<Video>
        columns={columns}
        headerTitle={t('works')}
        search={{
          labelWidth: 'auto',
          defaultCollapsed: false,
          span: 8,
        }}
        params={{ authorId: user?.id }}
        request={async (params) => {
          // enabled 控制：抽屉未打开或无有效用户时不发请求（防御式，正常不会走到）
          if (!open || user?.id == null) {
            return { data: [], total: 0, success: true };
          }
          const response = await fetchListVideos({
            page: params.current || 1,
            pageSize: params.pageSize || TABLE.DEFAULT_PAGE_SIZE,
            query: typeof params.query === 'string' ? params.query : undefined,
            authorId: user.id,
          });
          return {
            data: response.items || [],
            total: Number(response.total ?? 0),
            success: true,
          };
        }}
        rowKey="id"
        pagination={{
          defaultPageSize: TABLE.DEFAULT_PAGE_SIZE,
          showSizeChanger: true,
          showQuickJumper: true,
        }}
        options={{
          density: false,
          fullScreen: false,
          setting: false,
          reload: true,
        }}
        size="small"
        bordered
        cardBordered={false}
        scroll={{ x: 860 }}
      />
    </Drawer>
  );
};

export default UserVideosDrawer;
