# sql/ — 数据库种子说明（go-wind-shortplay）

本目录不再存放 CMS 演示数据 SQL（`postgresql-demo-data.sql` / `mysql-demo-data.sql`
已随内容域裁剪一并移除：其中过半 INSERT 目标是被裁剪的内容类表，且演示文章/页面
对 shortplay 无意义）。

当前数据库初始化完全走基座机制的 **Go 侧自动初始化**，无需手工执行 SQL：

1. **建表**：core 服务启动时按 `data.yaml` 的 `migrate: true` 执行
   `client.Schema.Create(...)`（ent schema 即迁移源，见
   `app/core/service/internal/data/client/`）。
2. **种子**：各服务构造期 `init()` 守卫空表后写入默认数据（`pkg/constants/default_data.go`）：
   - 默认用户与凭证（`admin / admin`，超级管理员）
   - 默认角色（平台管理员 / 租户管理员模板）、默认权限与权限组
   - 默认菜单（管理后台导航树）
   - 默认语言、默认通知路由规则

> Phase 2（shortplay 业务域移植）如需短视频域演示数据，在本目录新增
> `postgresql-seed.sql` 并在本文档同步执行说明。
