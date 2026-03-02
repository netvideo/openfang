#!/usr/bin/env bash
# OpenFang 中国版安装脚本 - 使用国内镜像加速
# 使用方法: curl -sSf https://openfang.cn/install-cn.sh | sh
#
# 环境变量:
#   OPENFANG_INSTALL_DIR  — 自定义安装目录 (默认: ~/.openfang/bin)
#   OPENFANG_VERSION      — 安装特定版本 (默认: 最新版)
#   OPENFANG_USE_MIRROR — 是否使用国内镜像 (默认: true)

set -euo pipefail

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 国内镜像配置
MIRRORS=(
    "https://ghproxy.com/https://github.com"
    "https://mirror.ghproxy.com/https://github.com"
    "https://gh.api.99988866.xyz/https://github.com"
    "https://gh.msx.workers.dev/https://github.com"
)

REPO="RightNow-AI/openfang"
INSTALL_DIR="${OPENFANG_INSTALL_DIR:-$HOME/.openfang/bin}"
USE_MIRROR="${OPENFANG_USE_MIRROR:-true}"

# 检测最佳镜像
detect_best_mirror() {
    if [ "$USE_MIRROR" != "true" ]; then
        echo "https://github.com"
        return
    fi

    echo -e "${BLUE}→ 检测最佳下载镜像...${NC}"
    local best_mirror=""
    local best_time=999999

    for mirror in "${MIRRORS[@]}"; do
        local test_url="${mirror}/${REPO}/releases/latest"
        local start_time=$(date +%s%N)
        
        if timeout 5 curl -fsSL -o /dev/null "$test_url" 2>/dev/null; then
            local end_time=$(date +%s%N)
            local elapsed=$(( (end_time - start_time) / 1000000 ))
            
            if [ $elapsed -lt $best_time ]; then
                best_time=$elapsed
                best_mirror=$mirror
            fi
            
            echo -e "  ${GREEN}✓${NC} ${mirror} (${elapsed}ms)"
        else
            echo -e "  ${RED}✗${NC} ${mirror} (超时)"
        fi
    done

    if [ -z "$best_mirror" ]; then
        echo -e "${YELLOW}⚠ 所有镜像都不可用，将直接使用 GitHub${NC}"
        best_mirror="https://github.com"
    else
        echo -e "${GREEN}✓ 最佳镜像: ${best_mirror}${NC}"
    fi

    echo "$best_mirror"
}

# 检测平台
detect_platform() {
    OS=$(uname -s | tr '[:upper:]' '[:lower:]')
    ARCH=$(uname -m)
    
    case "$ARCH" in
        x86_64|amd64) ARCH="x86_64" ;;
        aarch64|arm64) ARCH="aarch64" ;;
        *) 
            echo -e "${RED}✗ 不支持的架构: $ARCH${NC}"
            exit 1 
            ;;
    esac
    
    case "$OS" in
        linux) PLATFORM="${ARCH}-unknown-linux-gnu" ;;
        darwin) PLATFORM="${ARCH}-apple-darwin" ;;
        mingw*|msys*|cygwin*)
            echo ""
            echo -e "${YELLOW}Windows 用户，请使用 PowerShell:${NC}"
            echo '    irm https://openfang.sh/install.ps1 | iex'
            echo ""
            echo "  或者下载 .msi 安装包:"
            echo "    https://github.com/$REPO/releases/latest"
            echo ""
            echo "  或者使用 cargo 安装:"
            echo "    cargo install --git https://github.com/$REPO openfang-cli"
            exit 1
            ;;
        *) 
            echo -e "${RED}✗ 不支持的操作系统: $OS${NC}"
            exit 1 
            ;;
    esac
}

# 安装函数
install() {
    detect_platform
    
    local BASE_URL=$(detect_best_mirror)

    echo ""
    echo -e "${BLUE}  OpenFang 安装程序 (中国镜像版)${NC}"
    echo -e "${BLUE}  ==============================${NC}"
    echo ""

    # 获取最新版本
    if [ -n "${OPENFANG_VERSION:-}" ]; then
        VERSION="$OPENFANG_VERSION"
        echo -e "${BLUE}→ 使用指定版本: $VERSION${NC}"
    else
        echo -e "${BLUE}→ 获取最新版本...${NC}"
        VERSION=$(curl -fsSL "${BASE_URL}/${REPO}/releases/latest" | grep -oP 'tag_name":\s*"\K[^"]+' || true)
        
        if [ -z "$VERSION" ]; then
            # 尝试备用方法
            VERSION=$(curl -fsSL "${BASE_URL}/${REPO}/releases/latest" 2>/dev/null | grep -o '"tag_name": "[^"]*"' | head -1 | cut -d'"' -f4)
        fi
    fi

    if [ -z "$VERSION" ]; then
        echo -e "${RED}✗ 无法获取最新版本${NC}"
        echo -e "${YELLOW}  尝试从源码安装:${NC}"
        echo "    cargo install --git https://github.com/$REPO openfang-cli"
        exit 1
    fi

    echo -e "${GREEN}✓ 最新版本: $VERSION${NC}"

    URL="${BASE_URL}/${REPO}/releases/download/${VERSION}/openfang-${PLATFORM}.tar.gz"
    CHECKSUM_URL="${URL}.sha256"

    echo -e "${BLUE}→ 安装 OpenFang $VERSION (平台: $PLATFORM)...${NC}"
    mkdir -p "$INSTALL_DIR"

    # 下载到临时目录
    TMPDIR=$(mktemp -d)
    ARCHIVE="$TMPDIR/openfang.tar.gz"
    CHECKSUM_FILE="$TMPDIR/checksum.sha256"

    cleanup() { rm -rf "$TMPDIR"; }
    trap cleanup EXIT

    echo -e "${BLUE}→ 下载安装包...${NC}"
    if ! curl -fsSL --retry 3 --retry-delay 2 --connect-timeout 10 --max-time 300 "$URL" -o "$ARCHIVE" 2>/dev/null; then
        echo -e "${RED}✗ 下载失败${NC}"
        echo -e "${YELLOW}  可能原因:${NC}"
        echo "    - 网络连接问题"
        echo "    - GitHub 访问受限"
        echo ""
        echo -e "${YELLOW}  建议:${NC}"
        echo "    1. 检查网络连接"
        echo "    2. 尝试使用 VPN 或代理"
        echo "    3. 从源码安装: cargo install --git https://github.com/$REPO openfang-cli"
        exit 1
    fi
    echo -e "${GREEN}✓ 下载完成${NC}"

    # 验证校验和（如果可用）
    echo -e "${BLUE}→ 验证文件完整性...${NC}"
    if curl -fsSL --retry 2 --connect-timeout 5 --max-time 30 "$CHECKSUM_URL" -o "$CHECKSUM_FILE" 2>/dev/null; then
        EXPECTED=$(cut -d ' ' -f 1 < "$CHECKSUM_FILE")
        if command -v sha256sum &>/dev/null; then
            ACTUAL=$(sha256sum "$ARCHIVE" | cut -d ' ' -f 1)
        elif command -v shasum &>/dev/null; then
            ACTUAL=$(shasum -a 256 "$ARCHIVE" | cut -d ' ' -f 1)
        else
            ACTUAL=""
        fi
        if [ -n "$ACTUAL" ]; then
            if [ "$EXPECTED" != "$ACTUAL" ]; then
                echo -e "${RED}✗ 文件校验失败!${NC}"
                echo -e "  期望: $EXPECTED"
                echo -e "  实际: $ACTUAL"
                exit 1
            fi
            echo -e "${GREEN}✓ 文件完整性验证通过${NC}"
        else
            echo -e "${YELLOW}⚠ 未找到 sha256sum/shasum，跳过校验${NC}"
        fi
    else
        echo -e "${YELLOW}⚠ 无法获取校验文件，跳过校验${NC}"
    fi

    # 解压
    echo -e "${BLUE}→ 解压安装包...${NC}"
    if ! tar xzf "$ARCHIVE" -C "$INSTALL_DIR"; then
        echo -e "${RED}✗ 解压失败${NC}"
        exit 1
    fi
    chmod +x "$INSTALL_DIR/openfang"
    echo -e "${GREEN}✓ 解压完成${NC}"

    # 添加到 PATH
    echo -e "${BLUE}→ 配置环境变量...${NC}"
    SHELL_RC=""
    case "${SHELL:-}" in
        */zsh) SHELL_RC="$HOME/.zshrc" ;;
        */bash) SHELL_RC="$HOME/.bashrc" ;;
        */fish) SHELL_RC="$HOME/.config/fish/config.fish" ;;
    esac

    if [ -n "$SHELL_RC" ] && ! grep -q "openfang" "$SHELL_RC" 2>/dev/null; then
        case "${SHELL:-}" in
            */fish)
                mkdir -p "$(dirname "$SHELL_RC")"
                echo "set -gx PATH \"$INSTALL_DIR\" \$PATH" >> "$SHELL_RC"
                ;;
            *)
                echo "export PATH=\"$INSTALL_DIR:\$PATH\"" >> "$SHELL_RC"
                ;;
        esac
        echo -e "${GREEN}✓ 已添加 $INSTALL_DIR 到 $SHELL_RC${NC}"
    else
        echo -e "${YELLOW}⚠ PATH 配置已存在或无法确定 shell 类型${NC}"
    fi

    # 验证安装
    echo -e "${BLUE}→ 验证安装...${NC}"
    if "$INSTALL_DIR/openfang" --version >/dev/null 2>&1; then
        INSTALLED_VERSION=$("$INSTALL_DIR/openfang" --version 2>/dev/null || echo "$VERSION")
        echo ""
        echo -e "${GREEN}╔════════════════════════════════════════╗${NC}"
        echo -e "${GREEN}║   OpenFang 安装成功!                   ║${NC}"
        echo -e "${GREEN}║   版本: ${INSTALLED_VERSION}${NC}"
        echo -e "${GREEN}╚════════════════════════════════════════╝${NC}"
    else
        echo ""
        echo -e "${YELLOW}⚠ 无法验证安装，但二进制文件已安装到 $INSTALL_DIR/openfang${NC}"
    fi

    echo ""
    echo -e "${BLUE}开始使用:${NC}"
    echo -e "  ${GREEN}openfang init${NC}        # 运行初始化向导"
    echo -e "  ${GREEN}openfang start${NC}       # 启动服务"
    echo -e "  ${GREEN}openfang --help${NC}      # 查看帮助"
    echo ""
    echo -e "${YELLOW}提示:${NC}"
    echo "  - 如果 'openfang' 命令不可用，请重新加载 shell 配置:"
    echo "      source $SHELL_RC"
    echo "  - 或者使用完整路径运行: $INSTALL_DIR/openfang"
    echo ""
}

# 主程序
main() {
    # 检查依赖
    check_dependencies
    
    # 执行安装
    install
}

# 运行主程序
main "$@"