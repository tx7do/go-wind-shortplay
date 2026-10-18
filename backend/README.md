# GoWind ShortPlay Backend

GoWind ShortPlay（风行短剧）后端 —— 基于 [go-wind-cms](https://github.com/tx7do/go-wind-cms) `backend/`
基座源码移植裁剪（Phase 1），保留身份/权限/审计/字典/媒体/存储/任务/通知/站内信等全部基建域，
短视频社区业务域（video/feed 等）按基座既有模式于 Phase 2 接入；详见 [AGENTS.md](./AGENTS.md)。

- 后端基于 [golang](https://go.dev/) + [微服务框架 go-kratos](https://go-kratos.dev/)

## 技术栈

- [Kratos](https://go-kratos.dev/) -- B站微服务框架
- [Consul](https://www.consul.io/) / [Etcd](https://etcd.io/) -- 服务发现和配置管理
- [OpenTelemetry](https://opentelemetry.io/) -- 分布式可观察系统
- 手写依赖装配（wiring.go，无 DI 框架）
- [OpenAPI](https://www.openapis.org/) -- RESTful API 文档
- [MinIO](https://min.io/) -- 对象存储服务器
- [Redis](https://redis.io/) -- 非关系型数据库
- [PostgreSQL](https://www.postgresql.org/) / [MySQL](https://www.mysql.com/) -- 关系型数据库
- [Ent](https://entgo.io/) / [GORM](https://gorm.io/index.html) -- Golang ORM框架
- [ElasticSearch](https://www.elastic.co/cn/elasticsearch) -- 搜索引擎

## API文档

### Swagger UI

- [Admin Swagger UI](http://localhost:6600/docs/)
- [App Swagger UI](http://localhost:6700/docs/)

### openapi.yaml

- [Admin openapi.yaml](http://localhost:6600/docs/openapi.yaml)
- [Front openapi.yaml](http://localhost:6700/docs/openapi.yaml)

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
