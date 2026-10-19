// 基座拷贝文件（源：go-wind-cms frontend/admin src/pages/app/permission/permission/index.tsx，
// 本仓落位 permission/groups，后端菜单种子 component=permission/groups）：
// 为方便后续整文件重拷贝同步，保持上游代码形态，lint 严格规则已在 eslint.config.js 集中降档。
// 页面 = 左侧权限分组树 + 右侧权限点列表（menuIds/apiIds 关联勾选）。
import { Splitter } from 'antd';
import { useState } from 'react';

import ContentContainer from '@/layouts/components/PageContainer/ContentContainer';
import PermissionGroupList from './PermissionGroupList';
import PermissionList from './PermissionList';

/**
 * 权限组管理页面
 * 使用 Splitter 实现左右分栏布局
 */
const PermissionPointManagement = () => {
  const [currentGroupId, setCurrentGroupId] = useState<number | null>(null);

  return (
    <ContentContainer heightMode="fixed" padding="16px" bottomMargin={0}>
      <Splitter style={{ height: '100%', flex: 1, minHeight: 0 }}>
        <Splitter.Panel collapsible defaultSize="40%" min="25%" max="55%" style={{ display: 'flex', flexDirection: 'column' }}>
          <PermissionGroupList currentGroupId={currentGroupId} onGroupSelect={setCurrentGroupId} />
        </Splitter.Panel>
        <Splitter.Panel style={{ display: 'flex', flexDirection: 'column' }}>
          <PermissionList groupId={currentGroupId} />
        </Splitter.Panel>
      </Splitter>
    </ContentContainer>
  );
};

export default PermissionPointManagement;
