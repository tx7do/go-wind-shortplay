# GoWind ShortPlay Backend

GoWind ShortPlay（风印短剧）后端 —— 基于 [go-wind-cms](https://github.com/tx7do/go-wind-cms) `backend/`
基座源码移植裁剪，保留身份/权限/认证/审计/字典/媒体/存储/任务/通知/站内信等全部基建域，
短视频社区业务域（video / feed / report / sysconf / uba 等）按基座既有模式接入；
详见 [AGENTS.md](./AGENTS.md)。

- 后端基于 [golang](https://go.dev/) + [微服务框架 go-kratos](https://go-kratos.dev/)

## 技术栈

- [Kratos](https://go-kratos.dev/) -- B站微服务框架
- [Etcd](https://etcd.io/) -- 服务发现（三服务 gRPC 注册/发现）
- [OpenTelemetry](https://opentelemetry.io/) -- 分布式可观察系统
- 手写依赖装配（wiring.go，无 DI 框架）
- [OpenAPI](https://www.openapis.org/) -- RESTful API 文档（`make openapi`）
- [MinIO](https://min.io/) -- 对象存储服务器
- [Redis](https://redis.io/) -- 缓存 / 验证码 / asynq 队列
- [PostgreSQL](https://www.postgresql.org/) -- 关系型数据库（pgx/v5）
- [Ent](https://entgo.io/) -- Golang ORM 框架
- [Asynq](https://github.com/hibiken/asynq) -- 异步任务队列

## API文档

### Swagger UI

服务 configs 的 `server.rest.enable_swagger` **缺省 false**（`/docs/` 404）。
需要时把对应服务 `configs/server.yaml` 的该开关改为 `true` 再启动：

- [Admin Swagger UI](http://localhost:7600/docs/)
- [App Swagger UI](http://localhost:7700/docs/)

### openapi.yaml

静态资产（`make openapi` 产物，无需启动服务）：

- `app/admin/service/assets/openapi.yaml`
- `app/app/service/assets/openapi.yaml`

## 生成Protobuf API

本项目使用[buf.build](https://buf.build/)进行Protobuf API构建。

相关命令行工具和插件的具体安装方法请参见：[Kratos微服务框架API工程化指南](https://juejin.cn/post/7191095845096259641)

本项目提供了两种生成API代码的方式：`Makefile`和`gow cli`。

一键生成API的所有代码，该命令可以在后端项目的任何位置执行：

```bash
gow api
```

### 生成GO代码

```bash
cd `{项目根目录}/backend`
make api
```

### 生成TypeScript代码

```bash
cd `{项目根目录}/backend`
make ts
```

### 生成OpenAPI v3文档

```bash
cd `{项目根目录}/backend`
make openapi
```

## 其他代码生成

### 生成ent代码

```bash
cd `{项目根目录}/backend/app/{服务名}/service`
make ent
```

### 构建Docker镜像

```bash
make docker
```

## 构建程序

```bash
cd `{项目根目录}/backend/app/{服务名}/service`
make build
```

### 调试运行

```bash
cd `{项目根目录}/backend/app/{服务名}/service`
make run
```

## Docker部署
