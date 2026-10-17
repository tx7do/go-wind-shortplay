##################################
# 第一阶段：构建GO可执行文件
##################################

ARG GO_VERSION=1.26.4
FROM golang:${GO_VERSION}-alpine AS builder

ARG SERVICE_NAME=core
ARG APP_VERSION=0.1.0

# 设置工作目录
WORKDIR /src

# 复制项目源代码到工作目录
COPY . /src

# 下载依赖（构建时按需替换代理：--build-arg GOPROXY=...）
ARG GOPROXY=https://goproxy.cn,direct
RUN GOPROXY=${GOPROXY} GOSUMDB=off go mod download

# 编译可执行文件
RUN CGO_ENABLED=0 \
    GOOS=linux \
    GOARCH=amd64 \
    go build -ldflags "-X main.version=$APP_VERSION" \
    -o /src/bin/${SERVICE_NAME}-server ./app/${SERVICE_NAME}/service/cmd/server/

# 复制配置文件到统一目录
RUN mkdir -p /src/bin/configs && \
    if [ -d "/src/app/${SERVICE_NAME}/service/configs" ]; then \
      cp -r /src/app/${SERVICE_NAME}/service/configs/* /src/bin/configs/ 2>/dev/null || true; \
    fi

##################################
# 第二阶段：创建最终的运行时镜像
##################################

FROM docker.io/alpine:latest

ARG SERVICE_NAME=core

RUN apk --no-cache add ca-certificates tzdata

# core 服务抽帧封面依赖 FFmpeg（缺失时静默降级为无封面，不影响发布）
RUN apk --no-cache add ffmpeg || true

WORKDIR /app

COPY --from=builder /src/bin/${SERVICE_NAME}-server /app/bin/server
COPY --from=builder /src/bin/configs/ /app/configs/

RUN adduser -D appuser
USER appuser:appuser

CMD ["/app/bin/server", "-c", "/app/configs"]
