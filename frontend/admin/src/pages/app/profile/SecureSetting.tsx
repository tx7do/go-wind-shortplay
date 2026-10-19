import { List, Button } from 'antd';
import { useTranslation } from 'react-i18next';

interface SecureSettingProps {
  onSwitchTab: (key: string) => void;
}

/**
 * 安全设置（基座形态：安全项列表 + 跳转修改）。
 * 与基座差异：MFA 依赖本后端未实现的接口，仅保留登录密码一项。
 */
const SecureSetting = ({ onSwitchTab }: SecureSettingProps) => {
  const { t } = useTranslation('profile');

  return (
    <List
      dataSource={[
        {
          key: 'password',
          title: t('secureSetting.password'),
          description: t('secureSetting.passwordDesc'),
        },
      ]}
      renderItem={(item) => (
        <List.Item
          actions={[
            <Button type="link" onClick={() => onSwitchTab('2')}>
              {t('secureSetting.modify')}
            </Button>,
          ]}
        >
          <List.Item.Meta title={item.title} description={item.description} />
        </List.Item>
      )}
    />
  );
};

export default SecureSetting;
