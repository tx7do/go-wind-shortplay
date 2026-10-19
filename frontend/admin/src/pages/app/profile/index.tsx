import { useState } from 'react';
import { Card, Tabs } from 'antd';
import type { TabsProps } from 'antd';
import { useTranslation } from 'react-i18next';
import ContentContainer from '@/layouts/components/PageContainer/ContentContainer';
import BaseSetting from './BaseSetting';
import EditPassword from './EditPassword';
import SecureSetting from './SecureSetting';
import NotificationPreference from './NotificationPreference';

/**
 * 个人中心页面 — 左页签栏布局（基座 255daaeb 三端统一形态；220px 页签栏 +
 * 壳层 pane 标题 + ContentContainer scrollable 修内容区滚动）。
 * 与基座差异：会话/MFA/账号绑定/租户用量 pane 依赖本后端未实现的接口，
 * 不移植；本地支持的通知偏好 pane 接入。
 */
const UserProfile = () => {
  const { t } = useTranslation('profile');
  const [activeKey, setActiveKey] = useState('1');

  const handleSwitchTab = (key: string) => {
    setActiveKey(key);
  };

  const settingList: TabsProps['items'] = [
    {
      key: '1',
      label: t('tab.basicSettings'),
      children: <BaseSetting />,
    },
    {
      key: '2',
      label: t('tab.editPassword'),
      children: <EditPassword />,
    },
    {
      key: '3',
      label: t('tab.securitySettings'),
      children: <SecureSetting onSwitchTab={handleSwitchTab} />,
    },
    {
      key: '4',
      label: t('tab.notification'),
      children: <NotificationPreference />,
    },
  ];

  return (
    <ContentContainer heightMode="fixed" padding="24px" scrollable>
      <Card styles={{ body: { display: 'flex', gap: 0, height: '100%' } }}>
        <Tabs
          tabPosition="left"
          activeKey={activeKey}
          onChange={setActiveKey}
          items={settingList.map((item) => ({
            ...item,
            children: (
              <div style={{ paddingLeft: 24, paddingTop: 8 }}>
                <h2 style={{ margin: '0 0 24px', fontSize: 18, fontWeight: 600 }}>{item.label}</h2>
                {item.children}
              </div>
            ),
          }))}
          style={{ width: '100%', height: '100%' }}
          tabBarStyle={{ width: 220, marginRight: 0 }}
        />
      </Card>
    </ContentContainer>
  );
};

export default UserProfile;
