# 基于 gezp/docker-ubuntu-desktop 镜像的远程桌面

基于 [gezp/docker-ubuntu-desktop](https://github.com/gezp/docker-ubuntu-desktop) 镜像，增加了以下功能：
- rclone 挂载 S3 存储
- Node.js 22
- Google Chrome 浏览器

## 功能特性

- 远程桌面访问 (KasmVNC/NoMachine/noVNC)
- SSH 访问
- code-server (浏览器中的 VS Code)
- S3 存储挂载支持 (rclone)
- VNC 分辨率配置
- Node.js 22 运行环境
- Google Chrome 浏览器 (桌面快捷方式 + 自动启动)

## 环境变量配置

### S3 配置
- `S3_ENDPOINT` - S3 端点 URL
- `S3_REGION` - S3 区域
- `S3_ACCESS_KEY` - 访问密钥
- `S3_SECRET_KEY` - 秘密密钥
- `S3_BUCKET` - 要挂载的桶名称

### VNC 配置
- `VNC_RESOLUTION` - 桌面分辨率 (如 `1280x1024`, `1920x1080`)
- `DISABLE_HTTPS` - 设置为 `1` 禁用 HTTPS (使用 HTTP)

### Chrome 配置
- `CHROME_AUTO_START` - 设置为 `1` 启动时自动打开 Chrome
- `CHROME_URL` - 自动打开 Chrome 时的 URL (可选)

### 用户配置
- `USER` - 用户名 (默认: ubuntu)
- `PASSWORD` - 密码 (默认: ubuntu)
- `REMOTE_DESKTOP` - 远程桌面类型 (nomachine/kasmvnc/novnc)

## 快速开始

### 构建镜像

```bash
cd /code/udesktop
sudo docker build -t midpc .
```

### 使用 Docker 运行

```bash
sudo docker run -d --name midpc \
    --privileged \
    --shm-size=4g \
    --device /dev/fuse:/dev/fuse \
    -p 4000:4000 \
    -p 5000:5000 \
    -p 10022:22 \
    -e REMOTE_DESKTOP=kasmvnc \
    -e USER=ubuntu \
    -e PASSWORD=ubuntu \
    -e VNC_RESOLUTION=1920x1080 \
    -e DISABLE_HTTPS=1 \
    -e CHROME_AUTO_START=1 \
    -e S3_ENDPOINT=https://your-s3-endpoint \
    -e S3_REGION=your-region \
    -e S3_ACCESS_KEY=your-access-key \
    -e S3_SECRET_KEY=your-secret-key \
    -e S3_BUCKET=your-bucket \
    midpc
```

### 使用 Docker Compose 运行

```bash
cd /code/udesktop
sudo docker-compose up -d
```

## 访问方式

| 服务 | 端口 | 访问方式 |
|------|------|----------|
| KasmVNC 远程桌面 | 4000 | http://\<host-ip\>:4000 |
| code-server | 5000 | http://\<host-ip\>:5000 |
| SSH | 10022 | `ssh ubuntu@<host-ip> -p 10022` |

## S3 挂载

S3 存储会自动挂载到容器内的 `/mnt/s3` 目录。

## 预装软件

- **Node.js**: v22.22.0
- **npm**: 10.9.4
- **Chrome**: 146.0.7651.0 (桌面有快捷方式)
- **midscene-pc**: latest (global)

## 文件说明

- `Dockerfile` - 基于 gezp/ubuntu-desktop:24.04，安装 Node.js、Chrome、rclone
- `start.sh` - 启动脚本，配置 S3、Chrome 自动启动等
- `start_kasmvnc.sh` - KasmVNC 启动脚本，支持分辨率和日志级别配置
- `docker-compose.yml` - Docker Compose 配置文件
- `mount_s3.sh` - 宿主机挂载 S3 存储的脚本

## 项目配置 (.env)

为了安全起见，项目配置已迁移至 `.env` 文件。

### 配置步骤
1. 复制示例配置文件：
   ```bash
   cp env_example .env
   ```
2. 编辑 `.env` 文件，填入您的实际配置（如密码、S3 凭证、代理设置等）。
3. 使用 `sudo docker-compose up -d` 启动。

### 主要配置项
| 变量名 | 说明 |
|--------|------|
| `USER` / `PASSWORD` | 系统用户名及密码 |
| `CHROME_URL` | Chrome 自动打开的网址 |
| `HTTP_PROXY` | 系统级 HTTP 代理 |
| `NO_PROXY` | 不走代理的域名列表 |
| `S3_*` | S3 存储挂载凭证（可选） |

### Chrome 代理配置
如果在 `.env` 中设置了 `HTTP_PROXY`，系统会自动应用到 Chrome。
如需为 Chrome 单独设置代理，可使用：
- `CHROME_PROXY_SERVER`
- `CHROME_NO_PROXY`
