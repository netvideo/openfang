# 生产发布检查清单

在标记 `v0.1.0` 并交付给用户之前必须完成的所有事项。项目按依赖关系排序 -- 从上到下完成它们。

---

## 1. 生成 Tauri 签名密钥对

**状态：** 阻塞性 -- 没有此功能，自动更新器将失效。没有用户会收到更新。

Tauri 更新器需要 Ed25519 密钥对。私钥签名每个发布包，公钥嵌入到应用程序二进制文件中，以便它可以验证更新。

```bash
# 安装 Tauri CLI（如果尚未安装）
cargo install tauri-cli --locked

# 生成密钥对
cargo tauri signer generate -w ~/.tauri/openfang.key
```

命令将输出：

```
Your public key was generated successfully:
dW50cnVzdGVkIGNvb...  <-- 复制此内容

Your private key was saved to: ~/.tauri/openfang.key
```

保存两个值。您在步骤 2 和 3 中需要它们。

---

## 2. 在 `tauri.conf.json` 中设置公钥

**状态：** 阻塞性 -- 构建前必须替换占位符。

打开 `crates/openfang-desktop/tauri.conf.json` 并替换：

```json
"pubkey": "PLACEHOLDER_REPLACE_WITH_GENERATED_PUBKEY"
```

使用步骤 1 中的实际公钥字符串：

```json
"pubkey": "dW50cnVzdGVkIGNvb..."
```

---

## 3. 添加 GitHub 仓库密钥

**状态：** 阻塞性 -- 没有这些，CI/CD 发布工作流将失败。

转到 **GitHub 仓库 → 设置 → 密钥和变量 → 操作 → 新仓库密钥** 并添加：

| 密钥名称 | 值 | 必需 |
|---|---|---|
| `TAURI_SIGNING_PRIVATE_KEY` | `~/.tauri/openfang.key` 的内容 | 是 |
| `TAURI_SIGNING_PRIVATE_KEY_PASSWORD` | 密钥生成期间设置的密码（或空字符串） | 是 |

### 可选 -- macOS 代码签名

没有这些，macOS 用户将看到"来自未识别开发者的应用程序"警告。需要 Apple 开发者帐户（每年 99 美元）。

| 密钥名称 | 值 |
|---|---|
| `APPLE_CERTIFICATE` | Base64 编码的 `.p12` 证书文件 |
| `APPLE_CERTIFICATE_PASSWORD` | .p12 文件的密码 |
| `APPLE_SIGNING_IDENTITY` | 例如 `Developer ID Application: Your Name (TEAMID)` |
| `APPLE_ID` | 您的 Apple ID 邮箱 |
| `APPLE_PASSWORD` | 来自 appleid.apple.com 的 App 专用密码 |
| `APPLE_TEAM_ID` | 您的 10 字符团队 ID |

生成 base64 证书：
```bash
base64 -i Certificates.p12 | pbcopy
```

### 可选 -- Windows 代码签名

没有此功能，Windows SmartScreen 可能会警告用户。需要 EV 代码签名证书。

在 `tauri.conf.json` 中的 `bundle.windows` 下设置 `certificateThumbprint`，并将证书添加到 CI 中的 Windows 运行器。

---

## 4. 创建图标资源

**状态：** 验证 -- 图标可能是占位符。

以下图标文件必须存在于 `crates/openfang-desktop/icons/` 中：

| 文件 | 大小 | 用途 |
|---|---|---|
| `icon.png` | 1024x1024 | 源图标，macOS .icns 生成 |
| `icon.ico` | 多尺寸 | Windows 任务栏、安装程序 |
| `32x32.png` | 32x32 | 系统托盘、小上下文 |
| `128x128.png` | 128x128 | 应用程序列表 |
| `128x128@2x.png` | 256x256 | HiDPI/Retina 显示器 |

验证它们是真正的品牌图标（不是 Tauri 默认图标）。从单个源 SVG 生成：

```bash
# 使用 ImageMagick
convert icon.svg -resize 1024x1024 icon.png
convert icon.svg -resize 32x32 32x32.png
convert icon.svg -resize 128x128 128x128.png
convert icon.svg -resize 256x256 128x128@2x.png
convert icon.svg -resize 256x256 -define icon:auto-resize=256,128,64,48,32,16 icon.ico
```

---

## 5. 设置 `openfang.sh` 域名

**状态：** 安装脚本阻塞 -- 用户运行 `curl -sSf https://openfang.sh | sh`。

选项：
- **GitHub Pages**：将 `openfang.sh` 指向 GitHub Pages 站点，将 `/` 重定向到 `scripts/install.sh`，将 `/install.ps1` 重定向到来自仓库最新发布的 `scripts/install.ps1`。
- **Cloudflare Workers / Vercel**：使用适当的 `Content-Type: text/plain` 标头提供安装脚本。
- **Raw GitHub 重定向**：使用 `openfang.sh` 作为 `raw.githubusercontent.com/RightNow-AI/openfang/main/scripts/install.sh` 的 CNAME（不太可靠）。

安装脚本引用：
- `https://openfang.sh` → 提供 `scripts/install.sh`
- `https://openfang.sh/install.ps1` → 提供 `scripts/install.ps1`

在域名设置完成之前，用户可以通过以下方式安装：
```bash
curl -sSf https://raw.githubusercontent.com/RightNow-AI/openfang/main/scripts/install.sh | sh
```

---

## 6. 验证 Dockerfile 构建

**状态：** 验证 -- Dockerfile 必须生成可用的镜像。

```bash
docker build -t openfang:local .
docker run --rm openfang:local --version
docker run --rm -p 4200:4200 -v openfang-data:/data openfang:local start
```

确认：
- 二进制文件运行并打印版本
- `start` 命令启动内核和 API 服务器
- 端口 4200 可访问
- `/data` 卷在容器重启之间持久化

---

## 7. 本地验证安装脚本

**状态：** 发布前验证。

### Linux/macOS
```bash
# 针对真实 GitHub 发布进行测试（第一个标签之后）
bash scripts/install.sh

# 或仅测试语法
bash -n scripts/install.sh
shellcheck scripts/install.sh
```

### Windows (PowerShell)
```powershell
# 针对真实 GitHub 发布进行测试（第一个标签之后）
powershell -ExecutionPolicy Bypass -File scripts/install.ps1

# 或仅语法检查
pwsh -NoProfile -Command "Get-Content scripts/install.ps1 | Out-Null"
```

### Docker 冒烟测试
```bash
docker build -f scripts/docker/install-smoke.Dockerfile .
```

---

## 8. 为 v0.1.0 编写 CHANGELOG.md

**状态：** 验证 -- 确认它涵盖所有已发布的功能。

发布工作流在每个 GitHub 发布正文中包含指向 `CHANGELOG.md` 的链接。确保它存在于仓库根目录并涵盖：

- 所有 14 个包及其功能
- 关键功能：40 个通道、60 个技能、20 个提供商、51 个模型
- 安全系统（9 个 SOTA + 7 个关键修复）
- 带自动更新器的桌面应用程序
- 从 OpenClaw 迁移的路径
- Docker 和 CLI 安装选项

---

## 9. 第一次发布 -- 标记并推送

完成步骤 1-8 后：

```bash
# 确保版本在各处匹配
grep '"version"' crates/openfang-desktop/tauri.conf.json
grep '^version' Cargo.toml

# 提交任何最终更改
git add -A
git commit -m "chore: prepare v0.1.0 release"

# 标记并推送
git tag v0.1.0
git push origin main --tags
```

这会触发发布工作流，它将：
1. 为 4 个目标构建桌面安装程序（Linux、macOS x86、macOS ARM、Windows）
2. 为自动更新器生成签名的 `latest.json`
3. 为 5 个目标构建 CLI 二进制文件
4. 构建并推送多架构 Docker 镜像
5. 创建包含所有工件的 GitHub 发布

---

## 10. 发布后验证

发布工作流完成后（约 15-30 分钟）：

### GitHub 发布页面
- [ ] `.msi` 和 `.exe` 存在（Windows 桌面）
- [ ] `.dmg` 存在（macOS 桌面）
- [ ] `.AppImage` 和 `.deb` 存在（Linux 桌面）
- [ ] `latest.json` 存在（自动更新器清单）
- [ ] CLI `.tar.gz` 归档存在（5 个目标）
- [ ] CLI `.zip` 存在（Windows）
- [ ] 每个 CLI 归档的 SHA256 校验和文件存在

### 自动更新器清单
访问：`https://github.com/RightNow-AI/openfang/releases/latest/download/latest.json`

- [ ] JSON 有效
- [ ] 包含 `signature` 字段（非空字符串）
- [ ] 包含所有平台的下载 URL
- [ ] 版本与标签匹配

### Docker 镜像
```bash
docker pull ghcr.io/RightNow-AI/openfang:latest
docker pull ghcr.io/RightNow-AI/openfang:0.1.0

# 验证两种架构
docker run --rm ghcr.io/RightNow-AI/openfang:latest --version
```

### 桌面应用程序自动更新（使用 v0.1.1 测试）
1. 从发布版安装 v0.1.0
2. 标记 v0.1.1 并推送
3. 等待发布工作流完成
4. 打开 v0.1.0 应用程序 -- 10 秒后它应该：
   - 显示 "OpenFang 正在更新..." 通知
   - 下载并安装 v0.1.1
   - 自动重新启动到 v0.1.1
5. 右键单击托盘 → "检查更新" → 应显示 "已是最新版本"

### 安装脚本
```bash
# Linux/macOS
curl -sSf https://openfang.sh | sh
openfang --version  # 应打印 v0.1.0

# Windows PowerShell
irm https://openfang.sh/install.ps1 | iex
openfang --version
```

---

## 快速参考 -- 什么阻塞什么

```
步骤 1 (密钥生成) ──┬──> 步骤 2 (配置中的公钥)
                  └──> 步骤 3 (GitHub 中的密钥)
                         │
步骤 4 (图标) ──────────┤
步骤 5 (域名) ─────────┤
步骤 6 (Dockerfile) ─────┤
步骤 7 (安装脚本) ┤
步骤 8 (CHANGELOG) ──────┘
                         │
                         v
                  步骤 9 (标记 + 推送)
                         │
                         v
                  步骤 10 (验证)
```

步骤 4-8 可以并行完成。步骤 1-3 是顺序的，必须先完成。
