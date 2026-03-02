# OpenFang 中国版构建与部署指南

本文档详细介绍如何在中国大陆环境下快速构建和部署 OpenFang，包括完整的镜像加速配置。

---

## 目录

- [快速开始](#快速开始)
- [环境准备](#环境准备)
- [镜像配置](#镜像配置)
- [构建方式](#构建方式)
- [部署方案](#部署方案)
- [常见问题](#常见问题)

---

## 快速开始

### 一键安装（推荐）

```bash
# 使用国内镜像安装脚本
curl -fsSL https://openfang.cn/install-cn.sh | bash

# 或使用 wget
wget -qO- https://openfang.cn/install-cn.sh | bash
```

### 快速启动

```bash
# 初始化配置
openfang init

# 启动服务
openfang start

# 查看状态
openfang status
```

---

## 环境准备

### 系统要求

| 组件 | 最低要求 | 推荐配置 |
|------|----------|----------|
| CPU | 2核 | 4核+ |
| 内存 | 4GB | 8GB+ |
| 磁盘 | 20GB | 50GB+ SSD |
| 网络 | 10Mbps | 100Mbps+ |

### 支持的操作系统

- **Linux**: Ubuntu 20.04+, Debian 11+, CentOS 8+, RHEL 8+
- **macOS**: 12.0+ (Monterey+)
- **Windows**: Windows 10/11 + WSL2

### 前置依赖

```bash
# Ubuntu/Debian
sudo apt-get update
sudo apt-get install -y curl git build-essential pkg-config libssl-dev

# CentOS/RHEL
sudo yum install -y curl git gcc gcc-c++ make openssl-devel

# macOS (安装 Homebrew 后)
brew install curl git openssl
```

---

## 镜像配置

### 1. Rust Cargo 镜像

创建 `~/.cargo/config.toml`:

```toml
[registry]
default = "rsproxy-sparse"

[registries]
rsproxy-sparse = { index = "sparse+https://rsproxy.cn/crates.io-index/" }
ustc = { index = "https://mirrors.ustc.edu.cn/crates.io-index/" }
tsinghua = { index = "https://mirrors.tuna.tsinghua.edu.cn/git/crates.io-index.git" }

[net]
git-fetch-with-cli = true

[http]
timeout = 300
multiplexing = false
```

**推荐镜像对比**:

| 镜像 | 地址 | 更新频率 | 稳定性 | 推荐度 |
|------|------|----------|--------|--------|
| 字节跳动 (rsproxy) | rsproxy.cn | 实时 | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ |
| 中科大 (USTC) | USTC | 5分钟 | ⭐⭐⭐⭐ | ⭐⭐⭐⭐ |
| 清华 (TUNA) | TUNA | 5分钟 | ⭐⭐⭐⭐ | ⭐⭐⭐⭐ |

### 2. APT 软件源

**Ubuntu/Debian - 阿里云镜像**:

```bash
# 备份原配置
sudo cp /etc/apt/sources.list /etc/apt/sources.list.backup

# 替换为阿里云镜像
sudo tee /etc/apt/sources.list << 'EOF'
deb https://mirrors.aliyun.com/ubuntu/ jammy main restricted universe multiverse
deb https://mirrors.aliyun.com/ubuntu/ jammy-updates main restricted universe multiverse
deb https://mirrors.aliyun.com/ubuntu/ jammy-backports main restricted universe multiverse
deb https://mirrors.aliyun.com/ubuntu/ jammy-security main restricted universe multiverse
EOF

# 更新
sudo apt-get update
```

**Debian - 阿里云镜像**:

```bash
sudo tee /etc/apt/sources.list << 'EOF'
deb https://mirrors.aliyun.com/debian/ bookworm main non-free non-free-firmware
deb https://mirrors.aliyun.com/debian/ bookworm-updates main non-free non-free-firmware
deb https://mirrors.aliyun.com/debian/ bookworm-backports main non-free non-free-firmware
deb https://mirrors.aliyun.com/debian-security/ bookworm-security main non-free non-free-firmware
EOF

sudo apt-get update
```

### 3. Docker 镜像

创建或编辑 `/etc/docker/daemon.json`:

```json
{
  "registry-mirrors": [
    "https://docker.mirrors.ustc.edu.cn",
    "https://hub-mirror.c.163.com",
    "https://mirror.baidubce.com",
    "https://docker.m.daocloud.io",
    "https://ccr.ccs.tencentyun.com"
  ],
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "100m",
    "max-file": "3"
  }
}
```

重启 Docker:

```bash
sudo systemctl restart docker
```

### 4. GitHub 加速

#### Git 代理配置

```bash
# 使用 ghproxy（推荐）
git config --global url."https://ghproxy.com/https://github.com/".insteadOf "https://github.com/"

# 或使用 mirror.ghproxy
git config --global url."https://mirror.ghproxy.com/https://github.com/".insteadOf "https://github.com/"

# 查看配置
git config --global --list | grep url

# 取消配置（恢复原始）
git config --global --unset url."https://ghproxy.com/https://github.com/".insteadOf
```

#### GitHub 代理对比

| 代理 | 地址 | 速度 | 稳定性 | 推荐度 |
|------|------|------|--------|--------|
| ghproxy | ghproxy.com | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ |
| mirror.ghproxy | mirror.ghproxy.com | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ |
| gh.api | gh.api.99988866.xyz | ⭐⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐⭐ |
| gh.msx | gh.msx.workers.dev | ⭐⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐⭐ |

### 5. Python pip

创建 `~/.pip/pip.conf`:

```ini
[global]
index-url = https://pypi.tuna.tsinghua.edu.cn/simple
trusted-host = pypi.tuna.tsinghua.edu.cn
timeout = 120
retries = 5

[install]
use-mirrors = true
mirrors = https://pypi.tuna.tsinghua.edu.cn
```

或使用命令配置:

```bash
# 清华镜像
pip config set global.index-url https://pypi.tuna.tsinghua.edu.cn/simple

# 阿里云镜像
pip config set global.index-url https://mirrors.aliyun.com/pypi/simple/

# 豆瓣镜像
pip config set global.index-url https://pypi.douban.com/simple/

# 查看配置
pip config list
```

### 6. Node.js npm

```bash
# 使用淘宝镜像
npm config set registry https://registry.npmmirror.com

# 或使用阿里云
npm config set registry https://registry.npmmirror.com

# 查看配置
npm config get registry

# 恢复官方源
npm config set registry https://registry.npmjs.org
```

### 7. Go 模块

```bash
# 启用 Go 模块代理
go env -w GOPROXY=https://goproxy.cn,direct

# 或使用阿里云
go env -w GOPROXY=https://mirrors.aliyun.com/goproxy/,direct

# 恢复官方
go env -w GOPROXY=https://proxy.golang.org,direct

# 查看配置
go env GOPROXY
```

### 8. 一键配置脚本

已创建 `scripts/setup-cn-mirrors.sh`，运行:

```bash
chmod +x scripts/setup-cn-mirrors.sh
./scripts/setup-cn-mirrors.sh
```

这将自动配置所有镜像。

---

## 构建方式

### 方式一：源码构建（推荐）

#### 1. 克隆仓库

```bash
# 使用 GitHub 代理加速
git config --global url."https://ghproxy.com/https://github.com/".insteadOf "https://github.com/"

# 克隆仓库
git clone https://github.com/RightNow-AI/openfang.git
cd openfang

# 切换到国内版分支
git checkout china
```

#### 2. 配置镜像

```bash
# 运行镜像配置脚本
./scripts/setup-cn-mirrors.sh

# 或手动配置
# 1. 配置 Cargo 镜像 ( ~/.cargo/config.toml )
# 2. 配置 APT 镜像 ( /etc/apt/sources.list )
# 3. 配置 GitHub 代理
```

#### 3. 构建项目

```bash
# 安装依赖（Ubuntu/Debian）
sudo apt-get update
sudo apt-get install -y pkg-config libssl-dev

# 构建（使用国内镜像）
cargo build --release

# 或使用并行构建加速
cargo build --release -j$(nproc)
```

#### 4. 安装

```bash
# 创建安装目录
mkdir -p ~/.openfang/bin

# 复制二进制文件
cp target/release/openfang ~/.openfang/bin/

# 添加到 PATH
export PATH="$HOME/.openfang/bin:$PATH"
echo 'export PATH="$HOME/.openfang/bin:$PATH"' >> ~/.bashrc
```

#### 5. 验证安装

```bash
# 检查版本
openfang --version

# 运行诊断
cargo run -- doctor

# 初始化配置
openfang init
```

### 方式二：Docker 构建

#### 使用中国版 Dockerfile

```bash
# 构建中国版镜像
docker build -f Dockerfile.cn -t openfang:cn .

# 运行容器
docker run -d \
  -p 4200:4200 \
  -v $(pwd)/data:/data \
  --name openfang-cn \
  openfang:cn

# 查看日志
docker logs -f openfang-cn
```

#### Docker Compose 配置

创建 `docker-compose.cn.yml`:

```yaml
version: '3.8'

services:
  openfang:
    build:
      context: .
      dockerfile: Dockerfile.cn
    container_name: openfang-cn
    restart: unless-stopped
    ports:
      - "4200:4200"
    volumes:
      - ./data:/data
      - ./config:/etc/openfang
    environment:
      - OPENFANG_HOME=/data
      - RUST_LOG=info
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:4200/api/health"]
      interval: 30s
      timeout: 10s
      retries: 3

  # 可选：Nginx 反向代理
  nginx:
    image: registry.cn-hangzhou.aliyuncs.com/library/nginx:alpine
    container_name: openfang-nginx
    restart: unless-stopped
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./nginx.conf:/etc/nginx/nginx.conf
      - ./ssl:/etc/nginx/ssl
    depends_on:
      - openfang
```

部署：

```bash
# 启动服务
docker-compose -f docker-compose.cn.yml up -d

# 查看状态
docker-compose -f docker-compose.cn.yml ps

# 查看日志
docker-compose -f docker-compose.cn.yml logs -f
```

### 方式三：直接下载预编译二进制

使用国内安装脚本：

```bash
# 使用国内镜像安装脚本
curl -fsSL https://openfang.cn/install-cn.sh | bash

# 或使用 wget
wget -qO- https://openfang.cn/install-cn.sh | bash
```

---

## 部署方案

### 方案一：本地开发环境

适合开发测试：

```bash
# 1. 克隆代码
git clone https://github.com/RightNow-AI/openfang.git
cd openfang
git checkout china

# 2. 配置国内镜像
./scripts/setup-cn-mirrors.sh

# 3. 构建
cargo build --release

# 4. 运行
./target/release/openfang start
```

### 方案二：服务器部署（生产环境）

#### 单机部署

```bash
# 1. 安装
./scripts/install-cn.sh

# 2. 配置环境变量
export GROQ_API_KEY="your-api-key"
export OPENFANG_HOME="/data/openfang"

# 3. 创建配置目录
mkdir -p $OPENFANG_HOME

# 4. 创建 systemd 服务
sudo tee /etc/systemd/system/openfang.service > /dev/null << 'EOF'
[Unit]
Description=OpenFang Agent OS
After=network.target

[Service]
Type=simple
User=openfang
Group=openfang
ExecStart=/usr/local/bin/openfang start
ExecStop=/usr/local/bin/openfang stop
Restart=on-failure
RestartSec=5
Environment="RUST_LOG=info"
Environment="OPENFANG_HOME=/data/openfang"

[Install]
WantedBy=multi-user.target
EOF

# 5. 创建用户
sudo useradd -r -s /bin/false openfang

# 6. 设置权限
sudo chown -R openfang:openfang /data/openfang

# 7. 启动服务
sudo systemctl daemon-reload
sudo systemctl enable openfang
sudo systemctl start openfang

# 8. 查看状态
sudo systemctl status openfang
sudo journalctl -u openfang -f
```

#### 使用 Docker Compose 部署

```yaml
# docker-compose.production.yml
version: '3.8'

services:
  openfang:
    build:
      context: .
      dockerfile: Dockerfile.cn
    container_name: openfang
    restart: unless-stopped
    ports:
      - "4200:4200"
    volumes:
      - /data/openfang:/data
      - ./config:/etc/openfang:ro
    environment:
      - OPENFANG_HOME=/data
      - RUST_LOG=info
      - GROQ_API_KEY=${GROQ_API_KEY}
      - ANTHROPIC_API_KEY=${ANTHROPIC_API_KEY}
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:4200/api/health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s
    deploy:
      resources:
        limits:
          cpus: '4'
          memory: 8G
        reservations:
          cpus: '2'
          memory: 4G

  # Nginx 反向代理 + SSL
  nginx:
    image: registry.cn-hangzhou.aliyuncs.com/library/nginx:alpine
    container_name: openfang-nginx
    restart: unless-stopped
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./nginx/nginx.conf:/etc/nginx/nginx.conf:ro
      - ./nginx/ssl:/etc/nginx/ssl:ro
      - ./nginx/html:/usr/share/nginx/html:ro
    depends_on:
      - openfang
    deploy:
      resources:
        limits:
          cpus: '0.5'
          memory: 512M

  # 可选: 使用 Redis 作为缓存
  redis:
    image: registry.cn-hangzhou.aliyuncs.com/library/redis:7-alpine
    container_name: openfang-redis
    restart: unless-stopped
    volumes:
      - /data/redis:/data
    command: redis-server --appendonly yes
    deploy:
      resources:
        limits:
          cpus: '0.5'
          memory: 512M

  # 可选: 使用 PostgreSQL 作为数据库
  postgres:
    image: registry.cn-hangzhou.aliyuncs.com/library/postgres:15-alpine
    container_name: openfang-postgres
    restart: unless-stopped
    environment:
      POSTGRES_USER: openfang
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
      POSTGRES_DB: openfang
    volumes:
      - /data/postgres:/var/lib/postgresql/data
    deploy:
      resources:
        limits:
          cpus: '1'
          memory: 1G

networks:
  default:
    name: openfang-network
```

部署：

```bash
# 1. 创建目录结构
mkdir -p /data/openfang/{data,postgres,redis}
mkdir -p ./config ./nginx/{ssl,html}

# 2. 创建环境变量文件
tee .env > /dev/null << 'EOF'
# API Keys
GROQ_API_KEY=your-groq-api-key
ANTHROPIC_API_KEY=your-anthropic-api-key
OPENAI_API_KEY=your-openai-api-key

# Database
POSTGRES_PASSWORD=your-secure-password

# Domain
DOMAIN=openfang.yourdomain.com
EOF

# 3. 创建 Nginx 配置
tee nginx/nginx.conf > /dev/null << 'EOF'
events {
    worker_connections 1024;
}

http {
    include /etc/nginx/mime.types;
    default_type application/octet-stream;

    log_format main '$remote_addr - $remote_user [$time_local] "$request" '
                    '$status $body_bytes_sent "$http_referer" '
                    '"$http_user_agent" "$http_x_forwarded_for"';

    access_log /var/log/nginx/access.log main;
    error_log /var/log/nginx/error.log warn;

    sendfile on;
    tcp_nopush on;
    tcp_nodelay on;
    keepalive_timeout 65;
    types_hash_max_size 2048;
    client_max_body_size 100M;

    # Gzip compression
    gzip on;
    gzip_vary on;
    gzip_proxied any;
    gzip_comp_level 6;
    gzip_types text/plain text/css text/xml application/json application/javascript application/rss+xml application/atom+xml image/svg+xml;

    # Upstream for OpenFang
    upstream openfang {
        server openfang:4200;
        keepalive 32;
    }

    # HTTP -> HTTPS redirect
    server {
        listen 80;
        server_name _;
        return 301 https://$host$request_uri;
    }

    # HTTPS server
    server {
        listen 443 ssl http2;
        server_name _;

        # SSL certificates (mount your certs to /etc/nginx/ssl)
        ssl_certificate /etc/nginx/ssl/cert.pem;
        ssl_certificate_key /etc/nginx/ssl/key.pem;

        # SSL configuration
        ssl_protocols TLSv1.2 TLSv1.3;
        ssl_ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384;
        ssl_prefer_server_ciphers off;
        ssl_session_cache shared:SSL:10m;
        ssl_session_timeout 1d;

        # Security headers
        add_header X-Frame-Options "SAMEORIGIN" always;
        add_header X-Content-Type-Options "nosniff" always;
        add_header X-XSS-Protection "1; mode=block" always;
        add_header Referrer-Policy "strict-origin-when-cross-origin" always;

        # Proxy to OpenFang
        location / {
            proxy_pass http://openfang;
            proxy_http_version 1.1;
            
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
            
            # WebSocket support
            proxy_set_header Upgrade $http_upgrade;
            proxy_set_header Connection "upgrade";
            
            # Timeouts
            proxy_connect_timeout 60s;
            proxy_send_timeout 60s;
            proxy_read_timeout 60s;
        }

        # Static files caching
        location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg|woff|woff2|ttf|eot)$ {
            proxy_pass http://openfang;
            expires 1y;
            add_header Cache-Control "public, immutable";
            access_log off;
        }
    }
}
EOF

# 4. 生成自签名证书（测试用）
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout nginx/ssl/key.pem \
  -out nginx/ssl/cert.pem \
  -subj "/C=CN/ST=Beijing/L=Beijing/O=OpenFang/CN=openfang.local"

# 5. 启动服务
docker-compose -f docker-compose.production.yml up -d

# 6. 查看状态
docker-compose -f docker-compose.production.yml ps
docker-compose -f docker-compose.production.yml logs -f openfang
```

---

## 常见问题

### 1. 构建失败

**问题**: `cargo build` 下载依赖超时

**解决**:
```bash
# 1. 确保已配置 Cargo 镜像
cat ~/.cargo/config.toml

# 2. 清理缓存并重试
cargo clean
rm -rf ~/.cargo/registry/cache
rm -rf ~/.cargo/git/checkouts
cargo build --release

# 3. 如果使用 git 依赖超时，配置 git 代理
git config --global url."https://ghproxy.com/https://github.com/".insteadOf "https://github.com/"
```

### 2. Docker 镜像拉取失败

**问题**: `docker pull` 超时或失败

**解决**:
```bash
# 1. 检查镜像配置
cat /etc/docker/daemon.json

# 2. 重启 Docker
sudo systemctl restart docker

# 3. 手动拉取测试
docker pull registry.cn-hangzhou.aliyuncs.com/library/nginx:alpine

# 4. 如果使用阿里云镜像，确保配置了正确的镜像地址
```

### 3. API 密钥配置

**问题**: 启动后提示 API 密钥无效

**解决**:
```bash
# 1. 设置环境变量
export GROQ_API_KEY="gsk_xxxxxxxxxxxxxxxxxxxxxxxx"
export ANTHROPIC_API_KEY="sk-ant-xxxxxxxxxxxxxxxxxxxxxxxx"

# 2. 添加到 shell 配置文件
echo 'export GROQ_API_KEY="gsk_xxxxxxxxxxxxxxxxxxxxxxxx"' >> ~/.bashrc

# 3. 或使用 --env 参数启动
openfang start --env GROQ_API_KEY="gsk_xxxxxxxxxxxxxxxxxxxxxxxx"

# 4. 检查 API 密钥是否生效
openfang doctor
```

### 4. 端口占用

**问题**: 启动提示端口 4200 被占用

**解决**:
```bash
# 1. 查找占用端口的进程
sudo lsof -i :4200
# 或
sudo netstat -tulpn | grep 4200

# 2. 结束占用进程
sudo kill -9 <PID>

# 3. 或使用不同端口启动
openfang start --port 4201

# 4. 修改配置文件
# 编辑 ~/.openfang/config.toml
# [api]
# port = 4201
```

### 5. 内存不足

**问题**: 构建或运行时内存不足

**解决**:
```bash
# 1. 增加交换空间
sudo fallocate -l 4G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile

# 2. 永久启用交换
sudo tee -a /etc/fstab << 'EOF'
/swapfile none swap sw 0 0
EOF

# 3. 限制构建并行度（减少内存使用）
cargo build --release -j2

# 4. 使用 Docker 部署（推荐）
docker-compose -f docker-compose.cn.yml up -d
```

---

## 性能优化

### 构建优化

```bash
# 1. 使用 release 模式构建
cargo build --release

# 2. 启用链接时优化 (LTO)
# 在 Cargo.toml 中添加:
# [profile.release]
# lto = true
# codegen-units = 1

# 3. 使用更快的链接器 (Linux)
# 安装 lld
sudo apt-get install lld

# 在 ~/.cargo/config.toml 中添加:
# [target.x86_64-unknown-linux-gnu]
# linker = "clang"
# rustflags = ["-C", "link-arg=-fuse-ld=lld"]

# 4. 并行编译
cargo build --release -j$(nproc)
```

### 运行时优化

```bash
# 1. 使用 jemalloc 分配器
# 在 Cargo.toml 中添加:
# [dependencies]
# tikv-jemallocator = "0.5"

# 2. 调整线程池大小
export RAYON_NUM_THREADS=$(nproc)

# 3. 使用透明大页 (THP)
echo always | sudo tee /sys/kernel/mm/transparent_hugepage/enabled

# 4. 调整文件描述符限制
ulimit -n 65535
```

---

## 监控与日志

### 日志查看

```bash
# 查看 OpenFang 日志
openfang logs

# 实时查看
openfang logs -f

# 查看特定级别
openfang logs --level error

# Docker 部署查看日志
docker-compose -f docker-compose.cn.yml logs -f openfang
```

### 健康检查

```bash
# 运行诊断工具
openfang doctor

# API 健康检查
curl http://localhost:4200/api/health

# 完整系统检查
openfang status
```

### 性能监控

```bash
# 查看资源使用
top -p $(pgrep openfang)

# 查看网络连接
ss -tunap | grep openfang

# 查看磁盘使用
df -h

# Docker 资源使用
docker stats openfang-cn
```

---

## 备份与恢复

### 数据备份

```bash
# 备份 OpenFang 数据
tar czvf openfang-backup-$(date +%Y%m%d).tar.gz ~/.openfang/

# 备份数据库
cp ~/.openfang/memory.db ./backup/

# Docker 数据备份
docker run --rm -v openfang_data:/data -v $(pwd):/backup alpine tar czf /backup/openfang-data.tar.gz -C /data .
```

### 数据恢复

```bash
# 恢复 OpenFang 数据
tar xzvf openfang-backup-20240101.tar.gz -C ~/

# 恢复数据库
cp ./backup/memory.db ~/.openfang/

# Docker 数据恢复
docker run --rm -v openfang_data:/data -v $(pwd):/backup alpine sh -c "cd /data && tar xzf /backup/openfang-data.tar.gz"
```

---

## 更新与升级

### 源码更新

```bash
# 1. 拉取最新代码
cd openfang
git fetch origin
git pull origin china

# 2. 重新构建
cargo build --release

# 3. 替换二进制文件
cp target/release/openfang ~/.openfang/bin/

# 4. 重启服务
openfang restart
```

### Docker 更新

```bash
# 1. 拉取最新代码
git pull origin china

# 2. 重新构建镜像
docker-compose -f docker-compose.cn.yml build --no-cache

# 3. 滚动更新
docker-compose -f docker-compose.cn.yml up -d

# 4. 清理旧镜像
docker image prune -f
```

### 自动更新脚本

创建 `update.sh`:

```bash
#!/bin/bash
# OpenFang 自动更新脚本

set -e

REPO_DIR="/opt/openfang"
BACKUP_DIR="/backup/openfang"
LOG_FILE="/var/log/openfang-update.log"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a $LOG_FILE
}

# 创建备份
backup() {
    log "创建备份..."
    mkdir -p $BACKUP_DIR
    tar czf $BACKUP_DIR/openfang-$(date +%Y%m%d-%H%M%S).tar.gz -C $REPO_DIR .
    log "备份完成"
}

# 更新代码
update_code() {
    log "更新代码..."
    cd $REPO_DIR
    git fetch origin
    git reset --hard origin/china
    log "代码更新完成"
}

# 构建
build() {
    log "开始构建..."
    cd $REPO_DIR
    cargo build --release
    log "构建完成"
}

# 部署
deploy() {
    log "部署新版本..."
    cp $REPO_DIR/target/release/openfang /usr/local/bin/
    systemctl restart openfang
    log "部署完成"
}

# 健康检查
health_check() {
    log "执行健康检查..."
    sleep 5
    if curl -f http://localhost:4200/api/health > /dev/null 2>&1; then
        log "✓ 健康检查通过"
        return 0
    else
        log "✗ 健康检查失败"
        return 1
    fi
}

# 回滚
rollback() {
    log "执行回滚..."
    LATEST_BACKUP=$(ls -t $BACKUP_DIR/*.tar.gz | head -1)
    if [ -f "$LATEST_BACKUP" ]; then
        systemctl stop openfang
        rm -rf $REPO_DIR/*
        tar xzf $LATEST_BACKUP -C $REPO_DIR
        build
        deploy
        log "回滚完成"
    else
        log "未找到备份文件"
    fi
}

# 主函数
main() {
    log "开始更新流程..."
    
    backup
    update_code
    build
    deploy
    
    if health_check; then
        log "✓ 更新成功"
        exit 0
    else
        log "✗ 更新失败，执行回滚"
        rollback
        exit 1
    fi
}

# 执行
main "$@"
```

设置定时更新：

```bash
# 添加执行权限
chmod +x /opt/openfang/update.sh

# 创建 systemd 定时器
sudo tee /etc/systemd/system/openfang-update.timer > /dev/null << 'EOF'
[Unit]
Description=OpenFang Auto Update Timer

[Timer]
OnCalendar=daily
Persistent=true

[Install]
WantedBy=timers.target
EOF

sudo tee /etc/systemd/system/openfang-update.service > /dev/null << 'EOF'
[Unit]
Description=OpenFang Auto Update
After=openfang.service

[Service]
Type=oneshot
ExecStart=/opt/openfang/update.sh
User=root
StandardOutput=append:/var/log/openfang-update.log
StandardError=append:/var/log/openfang-update.log
EOF

# 启用定时器
sudo systemctl daemon-reload
sudo systemctl enable openfang-update.timer
sudo systemctl start openfang-update.timer

# 查看定时器状态
sudo systemctl list-timers --all
```

---

## 性能调优

### 系统参数优化

```bash
# 编辑 /etc/sysctl.conf
sudo tee -a /etc/sysctl.conf > /dev/null << 'EOF'
# 网络优化
net.core.somaxconn = 65535
net.core.netdev_max_backlog = 65535
net.ipv4.tcp_max_syn_backlog = 65535
net.ipv4.tcp_fin_timeout = 30
net.ipv4.tcp_keepalive_time = 1200
net.ipv4.tcp_max_tw_buckets = 5000
net.ipv4.ip_local_port_range = 1024 65535
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_tw_recycle = 0

# 内存优化
vm.swappiness = 10
vm.vfs_cache_pressure = 50
vm.dirty_ratio = 15
vm.dirty_background_ratio = 5
EOF

# 应用配置
sudo sysctl -p

# 文件描述符限制
sudo tee -a /etc/security/limits.conf > /dev/null << 'EOF'
* soft nofile 65535
* hard nofile 65535
* soft nproc 65535
* hard nproc 65535
EOF
```

### OpenFang 性能配置

编辑 `~/.openfang/config.toml`:

```toml
[api]
host = "0.0.0.0"
port = 4200
# 增加工作线程
workers = 8
# 启用 Keep-Alive
keep_alive = 300

[llm]
# 启用连接池
connection_pool_size = 20
# 超时设置
request_timeout = 120
connect_timeout = 30

[memory]
# 使用 SSD 存储路径
database = "/data/openfang/memory.db"
# 缓存设置
cache_size = 10000

[runtime]
# 工作线程数
worker_threads = 8
# 最大并发请求
max_concurrent_requests = 1000

[logging]
level = "info"
# 日志轮转
max_file_size = "100MB"
max_files = 10
```

---

## 总结

本指南涵盖了中国大陆环境下 OpenFang 的完整构建和部署流程：

1. **镜像配置**：提供了所有必要的国内镜像源配置
2. **多种构建方式**：源码构建、Docker 构建、直接下载
3. **部署方案**：本地开发、单机部署、集群部署
4. **运维管理**：更新升级、备份恢复、监控日志
5. **性能优化**：系统调优、配置优化

**快速开始命令汇总**:

```bash
# 1. 安装
./scripts/install-cn.sh

# 2. 配置镜像
./scripts/setup-cn-mirrors.sh

# 3. 构建
cargo build --release

# 4. 启动
openfang start

# 5. Docker 部署
docker-compose -f docker-compose.cn.yml up -d
```

**获取更多帮助**:

- 官方文档: https://docs.openfang.cn
- GitHub Issues: https://github.com/RightNow-AI/openfang/issues
- 社区论坛: https://forum.openfang.cn

---

*最后更新: 2024年*
*版本: OpenFang China Edition v1.0*