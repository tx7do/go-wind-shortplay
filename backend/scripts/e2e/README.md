# E2E 脚本（admin REST / app REST 级断言）

可重跑的业务流断言脚本，无需浏览器。浏览器级 GUI 验证仍走 Playwright 手工流程。

## 前置

- admin(:7600)/core/app(:7700) 已启动，且**清代理启动**（`HTTP_PROXY='' NO_PROXY='*'`）
- redis 容器名 `redis-server`（密码取 `backend/.env` 的 `REDIS_PASSWORD`）
- `pip install pycryptodome`
- 管理员账号 admin/admin

> **适用范围**：`common.py` 的基址已指向本仓端口（7600/7700）。
> 基座基建域脚本（`test_notification.py` / `test_oidc_login.py` /
> `test_image_transform.py` 等）随基座保留可用；`test_page_review.py` /
> `test_experiment_conversion.py` / `test_components.py` /
> `test_content_references.py` / `test_flow_rules.py` /
> `test_media_references.py` 面向已裁剪的 CMS 内容/实验/flow 域，
> 仅作上游存档，本仓不可跑通。

## 脚本

| 脚本 | 覆盖流 |
|---|---|
| `test_notification.py` | 站内信发送/收件/已读（基座 internal_message 域） |
| `test_oidc_login.py` | OIDC 登录链路（基座 authentication 域） |
| `test_image_transform.py` | 媒体即时图片变换（media-assets content） |
| `test_page_review.py` 等 | （CMS 内容/实验/flow 域，已随域裁剪，存档不可跑） |

## 用法

```bash
cd backend/scripts/e2e
python test_notification.py
```

脚本自建自清数据，退出码 0=全过 / 1=有失败。

## 注意

- app 侧请求走 `curl --noproxy '*'`（common.app_curl），规避本机代理劫持
- 新增端点部署后需在管理页点一次「接口同步」并绑角色，否则 E2E 401/403
