# 贡献指南

感谢你对 GoWind ShortPlay（风行短剧）的关注！本文档说明如何向本项目提交代码、文档与问题反馈。在开始之前，请先阅读 [README.md](./README.md) 了解项目定位与技术栈。

参与本项目即代表你同意在讨论、Issue 与 PR 中保持友善与专业。

## 快速上手

1. **Fork 并克隆仓库**

   ```bash
   git clone https://github.com/<your-name>/go-wind-shortplay.git
   cd go-wind-shortplay
   git remote add upstream https://github.com/<org>/go-wind-shortplay.git
   ```

2. **搭建开发环境**

   - 依赖服务准备、后端启动、前端运行：见 [README 快速开始](./README.md#快速开始)
   - 首次安装工具链：`cd backend && make init`（protoc 插件 + buf / ent / golangci-lint）
   - 后端开发规约：[backend/AGENTS.md](./backend/AGENTS.md)

3. **创建分支**

   请基于最新的 `main` 创建特性分支，不要直接在 `main` 上开发：

   ```bash
   git checkout main
   git pull upstream main
   git checkout -b feat/your-feature
   ```

## 开发约定

### 代码生成

本项目依赖代码生成，**请不要手工编辑生成产物**：

| 产物 | 生成命令 | 说明 |
|------|---------|------|
| Go API / HTTP / gRPC / 校验代码 | `make api` | 由 `backend/api/protos/` 下的 proto 生成至 `backend/api/gen/go/` |
| OpenAPI 文档 | `make openapi` | admin / app 两份产物分别写到各服务 `cmd/server/assets/openapi.yaml`，由服务内嵌提供 Swagger |
| Ent ORM 代码 | `make ent` | 由 `app/core/service/internal/data/ent/schema/` 下的 schema 生成 |
| 一键生成 | `make gen` | ent + api + openapi |

修改 `.proto` 或 `ent/schema` 后请重新生成并**连同产物一并提交**。

> 漏跑生成的后果很直接：gen 目录与 proto / schema 不一致，接口对不上或字段缺失，联调时才暴露。改完契约先 `make gen`，再写业务代码。

### 输入校验

字段约束请在 proto 中用 protoc-gen-validate 的 `(validate.rules)` 声明（配套 `import "validate/validate.proto";`），避免在 service 层手写判空。生成器会产出对应的 `*.pb.validate.go`。**注意**：给关键入参加完约束后，请实测确认真的会拦，别以为写了规则就自动生效。

### 代码规范

- **Go**：遵循 [Go Code Review Comments](https://go.dev/wiki/CodeReviewComments)。提交前在 `backend/` 下跑 `make lint`（golangci-lint）和 `go vet ./...`。分层规约、命名与错误处理细则见 [backend/AGENTS.md](./backend/AGENTS.md)。
- **前端**：各应用有独立的 eslint 配置，提交前跑所在应用的 lint / typecheck / analyze（门禁命令见根 [AGENTS.md](./AGENTS.md)）。
- **命名与风格**：新代码应与所在文件既有风格保持一致（缩进、注释密度、命名习惯）。

### 提交规范

本项目采用 [Conventional Commits](https://www.conventionalcommits.org/zh-hans/)。提交信息格式：

```
<type>(<scope>): <subject>
```

| type | 用途 |
|------|------|
| `feat` | 新功能 |
| `fix` | 缺陷修复 |
| `refactor` | 重构（不改变外部行为） |
| `perf` | 性能优化 |
| `style` | 代码格式（不影响逻辑） |
| `docs` | 文档 |
| `test` | 补充测试 |
| `build` | 构建系统、依赖 |
| `chore` | 杂项、脚手架 |
| `ci` | CI 配置 |

- `scope` 可选，对应受影响的模块（如 `admin`、`app`、`core`、`video`、`feed`）
- `subject` 使用中文或英文均可，简明描述，结尾不加句号
- **示例**：`feat(core): 评论楼中楼列表接口`

破坏性变更在 type 后加 `!`（如 `feat(api)!:`）并在正文说明迁移方式。大改动请添加正文说明动机与影响范围，必要时附 Issue 链接。

## 提交 Pull Request

1. 确保门禁全绿：backend `make lint` + `go vet ./...` + `go test ./...`；frontend/admin `pnpm run typecheck` + `pnpm run lint`；frontend/app `flutter analyze` + `flutter test`（改动落在哪端跑哪端）
2. 若改动涉及 proto / schema，确认已重新生成并提交产物：`make gen`
3. PR 标题遵循上述提交规范
4. PR 描述请写清：类型、动机、改动内容、**影响范围**（落在哪一端/哪个服务）、自测情况
5. 一个 PR 只解决一个问题，便于评审与回退

### 评审标准

- 是否改动生成产物、是否漏跑生成
- 是否破坏属主与权限校验（viewer 身份必须取自鉴权上下文，不信任客户端传入的 user_id）
- 是否绕过瘦网关边界（admin/app BFF 直连数据库属于架构违规，数据操作必须收敛在 core）
- 状态流转是否走 `validateTransition`、计数是否走 ledger 事务（禁止直接 Set）
- 是否引入新的硬编码密钥 / 凭据（应走配置或环境变量）
- 是否补齐了相应测试
- 文档是否同步更新

## 反馈问题

- 缺陷请开 Issue，写清：环境（OS / Go / Node / Flutter 版本）、复现步骤、期望与实际行为、相关日志
- 新功能建议请开 Issue 并说明使用场景与预期效果
- 安全漏洞请按 [SECURITY.md](./SECURITY.md) 流程私下上报，**勿直接开公开 Issue**

## 致谢

你的每一次贡献——无论代码、文档还是问题反馈——都让 GoWind ShortPlay 更好。感谢你的参与。
