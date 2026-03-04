#!/usr/bin/env bash
# OpenFang 中国镜像一键配置脚本
# 自动配置所有开发环境的国内镜像源
# 使用方法: curl -fsSL https://openfang.cn/setup-cn-mirrors.sh | bash

set -euo pipefail

# 版本号
SCRIPT_VERSION="1.0.0"

# 颜色定义
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m' # No Color

# 日志函数
log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# 打印 banner
print_banner() {
    echo ""
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║                                                              ║${NC}"
    echo -e "${CYAN}║       OpenFang 中国镜像配置工具 v${SCRIPT_VERSION}                    ║${NC}"
    echo -e "${CYAN}║                                                              ║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

# 检测操作系统
detect_os() {
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        if [ -f /etc/os-release ]; then
            . /etc/os-release
            echo "$ID"
        else
            echo "linux"
        fi
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        echo "macos"
    else
        echo "unknown"
    fi
}

# 检测最佳 GitHub 代理
detect_best_github_mirror() {
    log_info "正在检测最佳 GitHub 代理..."
    
    local mirrors=(
        "https://ghproxy.com/https://github.com/"
        "https://mirror.ghproxy.com/https://github.com/"
        "https://gh.api.99988866.xyz/https://github.com/"
        "https://gh.msx.workers.dev/https://github.com/"
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
            log_info "  ✓ ${mirror} (${elapsed}ms)"
        else
            log_warn "  ✗ ${mirror} (超时)"
        fi
    done
    
    if [ -n "$best_mirror" ]; then
        echo "$best_mirror"
    else
        echo "https://github.com/"
    fi
}

# 配置 Rust Cargo
configure_cargo() {
    log_info "配置 Rust Cargo 镜像..."
    
    mkdir -p ~/.cargo
    
    cat > ~/.cargo/config.toml << 'EOF'
[registry]
default = "rsproxy-sparse"

[registries]
rsproxy-sparse = { index = "sparse+https://rsproxy.cn/crates.io-index/" }
rsproxy = { index = "https://rsproxy.cn/crates.io-index" }
ustc = { index = "https://mirrors.ustc.edu.cn/crates.io-index/" }
tsinghua = { index = "https://mirrors.tuna.tsinghua.edu.cn/git/crates.io-index.git" }

[net]
git-fetch-with-cli = true

[http]
timeout = 300
multiplexing = false

# 针对中国大陆网络优化
[source.crates-io]
replace-with = 'rsproxy-sparse'
EOF
    
    log_success "Cargo 镜像配置完成"
    log_info "  - 默认镜像: rsproxy-sparse (字节跳动)"
    log_info "  - 备用镜像: ustc (中科大), tsinghua (清华)"
}

# 配置 Git
github_mirror=""
configure_git() {
    log_info "配置 Git 代理..."
    
    github_mirror=$(detect_best_github_mirror)
    
    if [ "$github_mirror" != "https://github.com/" ]; then
        git config --global url."${github_mirror}".insteadOf "https://github.com/"
        log_success "Git 代理配置完成"
        log_info "  - 使用镜像: ${github_mirror}"
    else
        log_warn "无法连接到 GitHub 代理，使用直连"
        log_info "  - 直连地址: https://github.com/"
    fi
}

# 配置 Python pip
configure_pip() {
    log_info "配置 Python pip 镜像..."
    
    mkdir -p ~/.pip
    
    cat > ~/.pip/pip.conf << 'EOF'
[global]
index-url = https://pypi.tuna.tsinghua.edu.cn/simple
trusted-host = pypi.tuna.tsinghua.edu.cn

[install]
use-mirrors = true
mirrors = https://pypi.tuna.tsinghua.edu.cn
EOF
    
    log_success "pip 镜像配置完成"
    log_info "  - 使用镜像: 清华大学 TUNA"
}

# 配置 npm
configure_npm() {
    log_info "配置 npm 镜像..."
    
    if command -v npm &>/dev/null; then
        npm config set registry https://registry.npmmirror.com
        log_success "npm 镜像配置完成"
        log_info "  - 使用镜像: 淘宝 NPM (npmmirror)"
    else
        log_warn "npm 未安装，跳过配置"
    fi
}

# 配置 Go
configure_go() {
    log_info "配置 Go 模块代理..."
    
    if command -v go &>/dev/null; then
        go env -w GOPROXY=https://goproxy.cn,direct
        go env -w GOSUMDB=sum.golang.google.cn
        log_success "Go 代理配置完成"
        log_info "  - 使用代理: 七牛云 Goproxy"
    else
        log_warn "Go 未安装，跳过配置"
    fi
}

# 配置 Docker
configure_docker() {
    log_info "配置 Docker 镜像..."
    
    if command -v docker &>/dev/null; then
        sudo mkdir -p /etc/docker
        sudo tee /etc/docker/daemon.json > /dev/null << 'EOF'
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
    "max-size": "10m",
    "max-file": "3"
  }
}
EOF
        log_success "Docker 镜像配置完成"
        log_info "  - 主要镜像: 中科大 USTC"
        log_info "  - 备用镜像: 网易、百度云、DaoCloud、腾讯云"
        log_warn "  ⚠️  请重启 Docker 服务: sudo systemctl restart docker"
    else
        log_warn "Docker 未安装，跳过配置"
    fi
}

# 主函数
main() {
    print_banner
    
    local os_type=$(detect_os)
    log_info "检测到操作系统: ${os_type}"
    
    # 配置各项镜像
    configure_cargo
    configure_git
    configure_pip
    configure_npm
    configure_go
    configure_docker
    
    # 打印总结
    echo ""
    echo -e "${GREEN}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║                                                              ║${NC}"
    echo -e "${GREEN}║              所有镜像配置已完成！✓                           ║${NC}"
    echo -e "${GREEN}║                                                              ║${NC}"
    echo -e "${GREEN}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    log_info "已配置的镜像源："
    log_info "  1. Rust Cargo     → 字节跳动 (rsproxy.cn)"
    log_info "  2. GitHub         → ${github_mirror:-https://github.com/}"
    log_info "  3. Python pip     → 清华大学 (TUNA)"
    log_info "  4. Node.js npm    → 淘宝 (npmmirror.com)"
    log_info "  5. Go Modules     → 七牛云 (goproxy.cn)"
    log_info "  6. Docker Hub     → 中科大 (USTC)"
    echo ""
    log_warn "注意事项："
    log_warn "  • 请重新打开终端窗口使配置生效"
    log_warn "  • 如果 Docker 配置修改，请执行: sudo systemctl restart docker"
    log_warn "  • 可以使用 'cargo build' 测试 Rust 镜像是否生效"
    log_warn "  • 可以使用 'docker pull hello-world' 测试 Docker 镜像"
    echo ""
    log_info "如需重新配置，请再次运行此脚本"
    echo ""
}

# 运行主程序
main "$@"
