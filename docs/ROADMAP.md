# 架构决策与服务拆分研判（ADR）

> 2026-10-17 · Phase 1 开工前研判结论

## 决策：一个 core 服务，不拆微服务

原需求草案中的 VideoService / FeedService / InteractionService **不拆成独立进程**，合并为一个 core 服务，在 core 内部按领域分模块。三服务架构（admin / app / core）指的是**网关 BFF 与核心服务的分层**，与 go-wind-cms 完全一致。

## 理由

1. **生态惯例**：go-wind-cms 的 core 是模块化单体，单进程承载约 20 个领域（identity/content/comment/interaction/media/notify/ai…）。shortplay MVP 仅 3-4 个领域，远低于拆分阈值。
2. **数据耦合天然**：Feed 一条数据 = 视频元数据 + 作者（关注态）+ 点赞/收藏计数 + 已看过滤。拆开则每页 Feed 跨服务扇出、计数与视频分属两库、删除联动变分布式事务——耦合没消除，只多了网络开销。
3. **真实瓶颈在字节流**：短视频 MVP 的压力在 MinIO/CDN 带宽，API QPS 对企业内部小流量毫无压力；水平扩容路径是 core 无状态多副本 + LB，不需要拆服务。
4. **开源部署极简**：docker compose 共 5 个容器（postgres/redis/minio/core/admin/app 共 6），再拆就是 9 个，直接劝退自部署用户。

## 可抽取设计（为 Phase 3 商业包留口子）

真正需要独立进程的是转码集群（Kafka+FFmpeg）与 AI 推荐集群——本来就不在开源版。现在的边界设计保证将来能无痛抽走：

1. proto 按领域独立：`api/protos/{video,feed,interaction,report,uba,...}`，契约边界已定
2. core 内 service/repo 严格按领域划分，跨域走 service 层组装（repo 禁止互相 import）
3. 封面抽帧 / UBA 落库当前为进程内执行；商业版替换为 Asynq/Kafka worker 时 API 契约零改动（`upload_helper.extractCoverLocal` 是唯一挂接点）
4. 计数列事务内增减（MVP）；Redis INCR + 异步落库为高并发升级路径，接口形态不变

## Phase 3 商业增值包（闭源，不进本仓库）

| 模块 | 形态 |
|------|------|
| 媒体处理集群 | Kafka 消费 + FFmpeg 转码，多码率 HLS / 多尺寸封面 / 水印；替换 `extractCoverLocal` 挂接点 |
| AI 推荐服务 | Go+ONNX 轻量召回排序，替换 feed_service 三路规则召回 |
| 内容安全 | 第三方鉴黄 / 敏感词，拦截后进人工复审工单（report 域已预留） |
| SaaS 多租户 | ent TenantID mixin + viewer 隔离（cms 同款），需回填 mixin |
| 直播 | 独立大模块，独立仓库 |
| 企业增强 | SSO / 审计日志 / 压测与集群部署方案 |
