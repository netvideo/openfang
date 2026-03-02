# OpenFang 中国版镜像配置指南

本文档汇总了在中国大陆使用 OpenFang 时的镜像加速配置。

## 1. 快速安装（推荐）

### 使用国内安装脚本

```bash
# 使用国内镜像安装
curl -fsSL https://openfang.cn/install-cn.sh | bash

# 或使用 wget
wget -qO- https://openfang.cn/install-cn.sh | bash
```

### Docker 安装（国内镜像版）

```bash
# 构建中国版镜像
docker build -f Dockerfile.cn -t openfang:cn .

# 运行
docker run -d -p 4200:4200 -v $(pwd)/data:/data openfang:cn
```

## 2. 各组件镜像配置

### 2.1 Rust Crates（Cargo）

创建或编辑 `~/.cargo/config.toml`:

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

# 其他镜像源配置示例（备用）
# [source.crates-io]
# replace-with = 'rsproxy'
# 
# [source.rsproxy]
# registry = "https://rsproxy.cn/crates.io-index"
```

#### 常用 Cargo 镜像对比

| 镜像 | 地址 | 速度 | 推荐度 |
|------|------|------|--------|
| 字节跳动 | rsproxy.cn | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ |
| 中科大 | USTC | ⭐⭐⭐⭐ | ⭐⭐⭐⭐ |
| 清华 | TUNA | ⭐⭐⭐⭐ | ⭐⭐⭐⭐ |

### 2.2 APT 软件源（Debian/Ubuntu）

编辑 `/etc/apt/sources.list`:

```bash
# 阿里云镜像（推荐）
deb https://mirrors.aliyun.com/debian/ bookworm main non-free non-free-firmware
deb https://mirrors.aliyun.com/debian/ bookworm-updates main non-free non-free-firmware
deb https://mirrors.aliyun.com/debian/ bookworm-backports main non-free non-free-firmware
deb https://mirrors.aliyun.com/debian-security/ bookworm-security main non-free non-free-firmware

# 或中科大镜像
deb https://mirrors.ustc.edu.cn/debian/ bookworm main contrib non-free non-free-firmware
deb https://mirrors.ustc.edu.cn/debian/ bookworm-updates main contrib non-free non-free-firmware
deb https://mirrors.ustc.edu.cn/debian/ bookworm-backports main contrib non-free non-free-firmware
deb https://mirrors.ustc.edu.cn/debian-security/ bookworm-security main contrib non-free non-free-firmware

# 或清华大学镜像
deb https://mirrors.tuna.tsinghua.edu.cn/debian/ bookworm main contrib non-free non-free-firmware
deb https://mirrors.tuna.tsinghua.edu.cn/debian/ bookworm-updates main contrib non-free non-free-firmware
deb https://mirrors.tuna.tsinghua.edu.cn/debian/ bookworm-backports main contrib non-free non-free-firmware
deb https://mirrors.tuna.tsinghua.edu.cn/debian-security/ bookworm-security main contrib non-free non-free-firmware
```

应用更改:

```bash
sudo apt-get update
```

### 2.3 Docker 镜像

创建或编辑 `/etc/docker/daemon.json`:

```json
{
  "registry-mirrors": [
    "https://docker.mirrors.ustc.edu.cn",
    "https://hub-mirror.c.163.com",
    "https://mirror.baidubce.com",
    "https://docker.m.daocloud.io",
    "https://ccr.ccs.tencentyun.com"
  ]
}
```

重启 Docker:

```bash
sudo systemctl restart docker
```

#### Docker Hub 镜像对比

| 镜像 | 地址 | 速度 | 推荐度 |
|------|------|------|--------|
| 中科大 | USTC | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ |
| 网易云 | 163 | ⭐⭐⭐⭐ | ⭐⭐⭐⭐ |
| 百度云 | Baidu | ⭐⭐⭐⭐ | ⭐⭐⭐⭐ |
| DaoCloud | DaoCloud | ⭐⭐⭐⭐ | ⭐⭐⭐⭐ |

### 2.4 GitHub 加速

#### Git 代理配置

```bash
# 使用 ghproxy（推荐）
git config --global url."https://ghproxy.com/https://github.com/".insteadOf "https://github.com/"

# 或使用 mirror.ghproxy
git config --global url."https://mirror.ghproxy.com/https://github.com/".insteadOf "https://github.com/"

# 或使用 gh.api.99988866.xyz
git config --global url."https://gh.api.99988866.xyz/https://github.com/".insteadOf "https://github.com/"

# 或使用 gh.msx.workers.dev
git config --global url."https://gh.msx.workers.dev/https://github.com/".insteadOf "https://github.com/"
```

#### GitHub 代理对比

| 代理 | 地址 | 速度 | 推荐度 |
|------|------|------|--------|
| ghproxy | ghproxy.com | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ |
| mirror.ghproxy | mirror.ghproxy.com | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ |
| gh.api | gh.api.99988866.xyz | ⭐⭐⭐⭐ | ⭐⭐⭐⭐ |
| gh.msx | gh.msx.workers.dev | ⭐⭐⭐⭐ | ⭐⭐⭐⭐ |

### 2.5 Python pip

创建或编辑 `~/.pip/pip.conf` (Linux/macOS) 或 `%APPDATA%\pip\pip.ini` (Windows):

```ini
[global]
index-url = https://pypi.tuna.tsinghua.edu.cn/simple
trusted-host = pypi.tuna.tsinghua.edu.cn

[install]
use-mirrors = true
mirrors = https://pypi.tuna.tsinghua.edu.cn
```

#### pip 镜像对比

| 镜像 | 地址 | 速度 | 推荐度 |
|------|------|------|--------|
| 清华 | TUNA | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ |
| 阿里云 | Aliyun | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ |
| 中科大 | USTC | ⭐⭐⭐⭐ | ⭐⭐⭐⭐ |
| 豆瓣 | Douban | ⭐⭐⭐ | ⭐⭐⭐ |

### 2.6 Node.js npm

```bash
# 使用淘宝镜像
npm config set registry https://registry.npmmirror.com

# 或使用阿里云
npm config set registry https://registry.npmmirror.com

# 恢复官方源
npm config set registry https://registry.npmjs.org
```

#### npm 镜像对比

| 镜像 | 地址 | 速度 | 推荐度 |
|------|------|------|--------|
| 淘宝 | npmmirror | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ |
| 阿里云 | Aliyun | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ |

### 2.7 Go 模块

```bash
# 启用 Go 模块代理
go env -w GOPROXY=https://goproxy.cn,direct

# 或使用阿里云
go env -w GOPROXY=https://mirrors.aliyun.com/goproxy/,direct

# 恢复官方
go env -w GOPROXY=https://proxy.golang.org,direct
```

#### Go 代理对比

| 代理 | 地址 | 速度 | 推荐度 |
|------|------|------|--------|
| 七牛云 | goproxy.cn | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ |
| 阿里云 | Aliyun | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ |

## 3. 一键配置脚本

创建 `setup-cn-mirrors.sh`:

```bash
#!/usr/bin/env bash
# OpenFang 中国镜像一键配置脚本

set -euo pipefail

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}OpenFang 中国镜像配置工具${NC}"
echo -e "${BLUE}==========================${NC}"
echo ""

# 配置 Rust Cargo
configure_cargo() {
    echo -e "${BLUE}→ 配置 Rust Cargo 镜像...${NC}"
    
    mkdir -p ~/.cargo
    cat > ~/.cargo/config.toml << 'EOF'
[registry]
default = "rsproxy-sparse"

[registries]
rsproxy-sparse = { index = "sparse+https://rsproxy.cn/crates.io-index/" }

[net]
git-fetch-with-cli = true

[http]
timeout = 300
multiplexing = false
EOF
    
    echo -e "${GREEN}✓ Cargo 镜像配置完成${NC}"
}

# 配置 Git
configure_git() {
    echo -e "${BLUE}→ 配置 Git 代理...${NC}"
    
    # 测试哪个代理最快
    local mirrors=(
        "https://ghproxy.com/https://github.com/"
        "https://mirror.ghproxy.com/https://github.com/"
        "https://gh.api.99988866.xyz/https://github.com/"
    )
    
    local best_mirror=""
    local best_time=999999
    
    for mirror in "${mirrors[@]}"; do
        local start=$(date +%s%N)
        if timeout 5 curl -fsSL "${mirror}rust-lang/rust" -o /dev/null 2>/dev/null; then
            local end=$(date +%s%N)
            local elapsed=$(( (end - start) / 1000000 ))
            if [ $elapsed -lt $best_time ]; then
                best_time=$elapsed
                best_mirror=$mirror
            fi
            echo -e "  ${GREEN}✓${NC} ${mirror} (${elapsed}ms)"
        else
            echo -e "  ${RED}✗${NC} ${mirror} (超时)"
        fi
    done
    
    if [ -n "$best_mirror" ]; then
        git config --global url."${best_mirror}".insteadOf "https://github.com/"
        echo -e "${GREEN}✓ Git 代理配置完成 (使用: ${best_mirror})${NC}"
    else
        echo -e "${YELLOW}⚠ 所有代理都不可用，保持默认配置${NC}"
    fi
}

# 配置 pip
configure_pip() {
    echo -e "${BLUE}→ 配置 Python pip 镜像...${NC}"
    
    mkdir -p ~/.pip
    cat > ~/.pip/pip.conf << 'EOF'
[global]
index-url = https://pypi.tuna.tsinghua.edu.cn/simple
trusted-host = pypi.tuna.tsinghua.edu.cn

[install]
use-mirrors = true
mirrors = https://pypi.tuna.tsinghua.edu.cn
EOF
    
    echo -e "${GREEN}✓ pip 镜像配置完成${NC}"
}

# 配置 npm
configure_npm() {
    echo -e "${BLUE}→ 配置 npm 镜像...${NC}"
    
    if command -v npm &>/dev/null; then
        npm config set registry https://registry.npmmirror.com
        echo -e "${GREEN}✓ npm 镜像配置完成${NC}"
    else
        echo -e "${YELLOW}⚠ npm 未安装，跳过${NC}"
    fi
}

# 配置 Go
configure_go() {
    echo -e "${BLUE}→ 配置 Go 模块代理...${NC}"
    
    if command -v go &>/dev/null; then
        go env -w GOPROXY=https://goproxy.cn,direct
        echo -e "${GREEN}✓ Go 代理配置完成${NC}"
    else
        echo -e "${YELLOW}⚠ Go 未安装，跳过${NC}"
    fi
}

# 配置 Docker
configure_docker() {
    echo -e "${BLUE}→ 配置 Docker 镜像...${NC}"
    
    if command -v docker &>/dev/null; then
        sudo mkdir -p /etc/docker
        sudo tee /etc/docker/daemon.json > /dev/null << 'EOF'
{
  "registry-mirrors": [
    "https://docker.mirrors.ustc.edu.cn",
    "https://hub-mirror.c.163.com",
    "https://mirror.baidubce.com",
    "https://docker.m.daocloud.io"
  ]
}
EOF
        echo -e "${GREEN}✓ Docker 镜像配置完成${NC}"
        echo -e "${YELLOW}⚠ 请重启 Docker 服务: sudo systemctl restart docker${NC}"
    else
        echo -e "${YELLOW}⚠ Docker 未安装，跳过${NC}"
    fi
}

# 主函数
main() {
    echo ""
    echo -e "${BLUE}╔════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║       OpenFang 中国镜像配置工具                        ║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    # 检查操作系统
    if [[ "$OSTYPE" != "linux-gnu"* ]] && [[ "$OSTYPE" != "darwin"* ]]; then
        echo -e "${RED}✗ 不支持的操作系统: $OSTYPE${NC}"
        exit 1
    fi
    
    # 配置各项镜像
    configure_cargo
    configure_git
    configure_pip
    configure_npm
    configure_go
    configure_docker
    
    echo ""
    echo -e "${GREEN}╔════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║       所有镜像配置完成！                               ║${NC}"
    echo -e "${GREEN}╚════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${YELLOW}提示:${NC}"
    echo "  - 请重新打开终端窗口使环境变量生效"
    echo "  - 如果 Docker 配置修改，请重启 Docker: sudo systemctl restart docker"
    echo "  - 如果遇到问题，可以运行 ./setup-cn-mirrors.sh 重新配置"
    echo ""
}

# 运行主程序
main "$@"