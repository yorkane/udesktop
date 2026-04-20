# udesktop — Midscene 自动化远程桌面容器

[![Build and Push](https://github.com/yorkane/udesktop/actions/workflows/docker-publish.yml/badge.svg)](https://github.com/yorkane/udesktop/actions/workflows/docker-publish.yml)

基于 [gezp/docker-ubuntu-desktop](https://github.com/gezp/docker-ubuntu-desktop) (Ubuntu 24.04) 构建的容器化远程桌面环境，专为 **[Midscene.js](https://midscenejs.com/)** AI 驱动的浏览器/桌面自动化而设计。

## ✨ 功能特性

### 🖥️ 远程桌面
- 三种 VNC 后端可选：**KasmVNC** / **noVNC** (TurboVNC) / **NoMachine**
- 可配置分辨率（`VNC_RESOLUTION`）
- 无缝剪贴板桥接（浏览器 ↔ VNC 双向同步）

### 🤖 Midscene 自动化
- **[midscene-relay](https://github.com/yorkane/midscene-relay)**：Chrome CDP 中继服务，支持远程 Midscene SDK / Playwright 访问
  - Web Relay（WebSocket，端口 `3768`）：Chrome 扩展 ↔ Midscene SDK 桥接
  - CDP Proxy（端口 `9223`）：透明代理 Chrome DevTools Protocol
  - Computer Relay（端口 `3767`）：桌面级自动化中继
- **midscene-pc**：桌面自动化客户端（随桌面自动启动）
- **Midscene.js Chrome 扩展**：预装并自动加载

### 🌐 Chrome 浏览器
- Google Chrome for Testing（最新稳定版）
- 预装扩展：[SwitchyOmega](https://github.com/nicehash/SwitchyOmega) 代理管理 + Midscene.js
- 远程调试端口（`--remote-debugging-port=9222`）
- 支持自动启动、代理配置、自定义 URL

### 🛠️ 开发工具
- Node.js v24 + npm + pnpm
- code-server（浏览器内 VS Code，可选）
- SSH 服务（可选）
- Git、ImageMagick、jq 等常用工具

### ☁️ 存储
- rclone 挂载 S3 兼容存储到 `/mnt/s3`
- 宿主机 S3 挂载辅助脚本（`mount_s3.sh`）

### 🚀 CI/CD
- GitHub Actions 自动构建并推送至 `ghcr.io/yorkane/midpc`
- 当 `Dockerfile` 变更时自动触发

---

## 快速开始

### 使用预构建镜像（推荐）

```bash
# 拉取最新镜像
docker pull ghcr.io/yorkane/midpc:latest

# 创建环境配置
cp env_example .env
# 编辑 .env 填入你的配置

# 启动
docker compose up -d
```

### 本地构建

```bash
# （可选）预下载构建资源以加速构建
bash preload.sh

# 构建镜像
docker build -t midpc .

# 启动
docker compose up -d
```

### 使用 Docker 运行（不使用 Compose）

```bash
docker run -d --name midpc \
    --privileged \
    --shm-size=4g \
    --device /dev/fuse:/dev/fuse \
    -p 4000:4000 \
    -p 3767:3767 \
    -p 3768:3768 \
    -p 9223:9223 \
    -e REMOTE_DESKTOP=novnc \
    -e USER=ubuntu \
    -e PASSWORD=ubuntu \
    -e VNC_RESOLUTION=1920x1080 \
    -e DISABLE_HTTPS=1 \
    -e CHROME_AUTO_START=1 \
    ghcr.io/yorkane/midpc:latest
```

---

## 访问方式

| 服务 | 端口 | 说明 |
|------|------|------|
| **远程桌面 (VNC)** | `4000` | `http://<host-ip>:4000` |
| **Midscene Computer Relay** | `3767` | 桌面自动化 WebSocket 端点 |
| **Midscene Web Relay** | `3768` | Chrome 扩展 WebSocket 端点 |
| **CDP Proxy** | `9223` | Chrome DevTools Protocol 代理 |
| **code-server** | `5000` | `http://<host-ip>:5000` （需启用） |
| **SSH** | `22` | `ssh ubuntu@<host-ip> -p <映射端口>` （需启用） |

---

## 环境变量

### 桌面与用户

| 变量 | 默认值 | 说明 |
|------|--------|------|
| `REMOTE_DESKTOP` | — | VNC 后端：`kasmvnc` / `novnc` / `nomachine` |
| `USER` | `ubuntu` | 系统用户名 |
| `PASSWORD` | `ubuntu` | 系统密码 |
| `VNC_RESOLUTION` | `1280x1024` | 桌面分辨率（如 `1920x1080`） |
| `DISABLE_HTTPS` | — | 设为 `1` 使用 HTTP 而非 HTTPS |

### 服务开关

| 变量 | 默认值 | 说明 |
|------|--------|------|
| `ENABLE_SSH` | `0` | 设为 `1` 启用 SSH 服务 |
| `ENABLE_CODE_SERVER` | `0` | 设为 `1` 启用 code-server |
| `MIDSCENE_RELAY_AUTO_START` | `1` | 设为 `1` 自动启动 midscene-relay |

### Midscene Relay

| 变量 | 默认值 | 说明 |
|------|--------|------|
| `ENABLE_WEB_RELAY` | `true` | 启用 Web Relay（Chrome 扩展桥接） |
| `ENABLE_CDP_PROXY` | `true` | 启用 CDP 代理 |
| `ENABLE_COMPUTER_RELAY` | `true` | 启用 Computer Relay（桌面自动化） |
| `RELAY_URL` | `ws://0.0.0.0:3768` | Web Relay 监听地址 |
| `COMPUTER_RELAY_URL` | `ws://0.0.0.0:3767` | Computer Relay 监听地址 |

### Chrome

| 变量 | 默认值 | 说明 |
|------|--------|------|
| `CHROME_AUTO_START` | — | 设为 `1` 随桌面自动启动 Chrome |
| `CHROME_URL` | — | Chrome 自动打开的 URL |
| `CHROME_PROXY_SERVER` | — | Chrome 专用代理服务器 |
| `CHROME_NO_PROXY` | — | Chrome 不走代理的地址列表 |

### 网络代理

| 变量 | 默认值 | 说明 |
|------|--------|------|
| `HTTP_PROXY` | — | 系统级 HTTP 代理 |
| `HTTPS_PROXY` | — | 系统级 HTTPS 代理 |
| `NO_PROXY` | — | 不走代理的域名列表 |

### S3 存储挂载（可选）

| 变量 | 默认值 | 说明 |
|------|--------|------|
| `S3_ENDPOINT` | — | S3 兼容存储端点 URL |
| `S3_REGION` | `us-east-1` | 存储区域 |
| `S3_ACCESS_KEY` | — | 访问密钥 |
| `S3_SECRET_KEY` | — | 密钥 |
| `S3_BUCKET` | — | 挂载的桶名称 |

---

## 架构概览

```
┌──────────────────────────────────────────────────────┐
│                    Docker Container                  │
│                                                      │
│  ┌──────────┐   ┌──────────────┐   ┌──────────────┐ │
│  │  XFCE4   │   │    Chrome     │   │  midscene-pc │ │
│  │ Desktop  │   │  + Extensions │   │  (桌面自动化) │ │
│  └────┬─────┘   └──────┬───────┘   └──────────────┘ │
│       │                │                              │
│  ┌────┴─────┐   ┌──────┴───────┐                     │
│  │ KasmVNC  │   │midscene-relay│                     │
│  │ / noVNC  │   │              │                     │
│  │ :4000    │   │ Web    :3768 │                     │
│  └──────────┘   │ CDP    :9223 │                     │
│                 │ Computer:3767│                     │
│                 └──────────────┘                     │
│                                                      │
│  ┌──────────┐   ┌──────────────┐   ┌──────────────┐ │
│  │   SSH    │   │ code-server  │   │  rclone S3   │ │
│  │  (可选)  │   │   (可选)     │   │  /mnt/s3     │ │
│  └──────────┘   └──────────────┘   └──────────────┘ │
└──────────────────────────────────────────────────────┘
```

---

## 预装软件

| 软件 | 版本 | 说明 |
|------|------|------|
| Ubuntu Desktop | 24.04 (XFCE4) | 基础桌面环境 |
| Node.js | v24.15.0 | JavaScript 运行时 |
| pnpm | latest | 包管理器 |
| Chrome for Testing | latest stable | 自动化友好的 Chrome |
| midscene-relay | latest | CDP 中继服务 |
| midscene-pc | latest (global) | 桌面自动化客户端 |
| rclone | 系统包 | S3 存储挂载 |
| ImageMagick | 系统包 | 图像处理 |

### Chrome 预装扩展
- **SwitchyOmega** — 代理切换管理
- **Midscene.js** — AI 驱动的浏览器自动化

---

## 文件说明

| 文件 | 说明 |
|------|------|
| `Dockerfile` | 镜像构建定义 |
| `docker-compose.yml` | Compose 编排配置 |
| `start.sh` | 容器入口脚本，按序启动所有服务 |
| `custom_env_init.sh` | 用户初始化钩子（Chrome 配置、自动启动项、VNC 设置） |
| `start_kasmvnc.sh` | KasmVNC 启动脚本（分辨率、剪贴板、日志级别） |
| `start_novnc.sh` | noVNC (TurboVNC) 启动脚本 |
| `novnc_clipboard.js` | noVNC 无缝剪贴板桥接（浏览器 ↔ VNC） |
| `mount_s3.sh` | 宿主机 S3 挂载辅助脚本 |
| `preload.sh` | 预下载构建资源（Node.js、Chrome、扩展） |
| `preload/` | 预下载资源缓存目录（加速 Docker 构建） |
| `env_example` | 环境变量示例文件 |
| `.github/workflows/docker-publish.yml` | CI/CD 自动构建并推送镜像 |

---

## 构建加速（preload）

首次构建镜像时，Dockerfile 会从网络下载 Node.js、Chrome、扩展等大文件。可以使用 `preload.sh` 预先下载到 `preload/` 目录，后续构建时自动使用本地缓存：

```bash
bash preload.sh    # 下载约 220MB 资源到 preload/
docker build -t midpc .  # 构建时优先使用本地文件
```

---

## 镜像分发

```bash
# 导出为压缩包
docker save midpc | xz -v -T16 > midpc.tar.xz

# 从压缩包导入
xz -d -k < midpc.tar.xz | docker load

# 推送至阿里云 ACR
docker tag midpc wasu-wtvdev-registry-test-registry.cn-hangzhou.cr.aliyuncs.com/pub/midpc
docker push wasu-wtvdev-registry-test-registry.cn-hangzhou.cr.aliyuncs.com/pub/midpc
```

---

## License

[Apache License 2.0](LICENSE)
