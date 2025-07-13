FROM oven/bun:latest AS builder

WORKDIR /build
COPY web/package.json .
RUN bun install
COPY ./web .
COPY ./VERSION .
RUN DISABLE_ESLINT_PLUGIN='true' VITE_REACT_APP_VERSION=$(cat VERSION) bun run build

FROM golang:alpine AS builder2

ENV GO111MODULE=on \
    CGO_ENABLED=0 \
    GOOS=linux \
    GOPROXY=https://goproxy.cn,https://goproxy.org,https://goproxy.io,https://proxy.golang.com.cn,https://mirrors.aliyun.com/goproxy/,https://goproxy.qiniu.com,https://repo.huaweicloud.com/go/proxy/,https://proxy.golang.org,direct

WORKDIR /build

ADD go.mod go.sum ./
RUN go mod download

COPY . .
COPY --from=builder /build/dist ./web/dist
RUN go build -ldflags "-s -w -X 'one-api/common.Version=$(cat VERSION)'" -o one-api

FROM alpine

# 增加为阿里云等镜像源（阿里云国内最快）
# https://mirrors.aliyun.com/alpine/|https://mirrors.ustc.edu.cn/alpine/|https://repo.huaweicloud.com/alpine/|https://mirrors.tuna.tsinghua.edu.cn/alpine/
RUN sed -i 's|https://dl-cdn.alpinelinux.org/alpine/|https://mirrors.aliyun.com/alpine/|g' /etc/apk/repositories \
    && apk update --no-cache \
    && apk upgrade --no-cache \
    && apk add --no-cache ca-certificates tzdata ffmpeg \
    && update-ca-certificates    

COPY --from=builder2 /build/one-api /
EXPOSE 3000
WORKDIR /data
ENTRYPOINT ["/one-api"]
