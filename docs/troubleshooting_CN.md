# 故障排除与常见问题

OpenFang 的常见问题、诊断方法和常见问题解答。

## 目录

- [快速诊断](#快速诊断)
- [安装问题](#安装问题)
- [配置问题](#配置问题)
- [LLM 提供程序问题](#llm-提供程序问题)
- [通道问题](#通道问题)
- [智能体问题](#智能体问题)
- [API 问题](#api-问题)
- [桌面应用问题](#桌面应用问题)
- [性能](#性能)
- [常见问题](#常见问题)

---

## 快速诊断

运行内置诊断工具：

```bash
openfang doctor
```

这将检查：
- 配置文件是否存在且为有效的 TOML
- API 密钥是否在环境中设置
- 数据库是否可访问
- 守护进程状态（运行或未运行）
- 端口可用性
- 工具依赖（Python、signal-cli 等）

### 检查守护进程状态

```bash
openfang status
```

### 通过 API 检查健康状态

```bash
curl http://127.0.0.1:4200/api/health
curl http://127.0.0.1:4200/api/health/detail  # 需要认证
```

### 查看日志

OpenFang 使用 `tracing` 进行结构化日志记录。通过环境变量设置日志级别：

```bash
RUST_LOG=info openfang start          # 默认
RUST_LOG=debug openfang start         # 详细
RUST_LOG=openfang=debug openfang start  # 仅 OpenFang 调试，依赖项为 info
```

---

## 安装问题

### `cargo install` 失败并显示编译错误

**原因**：Rust 工具链太旧或缺少系统依赖。

**修复**：
```bash
rustup update stable
rustup default stable
rustc --version  # 需要 1.75+
```

在 Linux 上，你可能还需要：
```bash
# Debian/Ubuntu
sudo apt install pkg-config libssl-dev libsqlite3-dev

# Fedora
sudo dnf install openssl-devel sqlite-devel
```

### 安装后找不到 `openfang` 命令

**修复**：确保 `~/.cargo/bin` 在你的 PATH 中：
```bash
export PATH="$HOME/.cargo/bin:$PATH"
# 添加到 ~/.bashrc 或 ~/.zshrc 以持久化
```

### Docker 容器无法启动

**常见原因**：
- 未提供 API 密钥：`docker run -e GROQ_API_KEY=... ghcr.io/RightNow-AI/openfang`
- 端口已被占用：更改端口映射 `-p 3001:4200`
- 卷挂载权限被拒绝：检查目录权限

---

## 配置问题

### "找不到配置文件"

**修复**：运行 `openfang init` 创建默认配置：
```bash
openfang init
```

这将创建带有合理默认值的 `~/.openfang/config.toml`。

### 启动时显示 "缺少 API 密钥" 警告

**原因**：环境中未找到 LLM 提供程序 API 密钥。

**修复**：设置至少一个提供程序密钥：
```bash
export GROQ_API_KEY="gsk_..."     # Groq（有免费套餐）
# 或
export ANTHROPIC_API_KEY="sk-ant-..."
# 或
export OPENAI_API_KEY="sk-..."
```

添加到你的 shell 配置文件以跨会话持久化。

### 配置验证错误

手动运行验证：
```bash
openfang config show
```

常见问题：
- TOML 语法格式错误（使用 TOML 验证器）
- 端口号无效（必须在 1-65535 范围内）
- 通道配置中缺少必填字段

### "端口已被占用"

**修复**：在配置中更改端口或终止现有进程：
```bash
# 更改 API 端口
# 在 config.toml 中：
# [api]
# listen_addr = "127.0.0.1:3001"

# 或查找并终止使用该端口的进程
# Linux/macOS：
lsof -i :4200
# Windows：
netstat -aon | findstr :4200
```

---

## LLM 提供程序问题

### "认证失败" / 401 错误

**原因**：
- API 密钥未设置或错误
- API 密钥过期或被撤销
- 环境变量名称错误

**修复**：验证你的密钥：
```bash
# 检查环境变量是否已设置
echo $GROQ_API_KEY

# 测试提供程序
curl http://127.0.0.1:4200/api/providers/groq/test -X POST
```

### "速率受限" / 429 错误

**原因**：对 LLM 提供程序的请求过多。

**修复**：
- 驱动程序自动使用指数退避重试
- 减少智能体能力中的 `max_llm_tokens_per_hour`
- 切换到具有更高速率限制的提供程序
- 使用多个提供程序进行模型路由

### 响应缓慢

**可能原因**：
- 提供程序 API 延迟（尝试 Groq 以获得快速推理）
- 大上下文窗口（使用 `/compact` 缩小会话）
- 复杂的工具链（检查响应中的迭代计数）

**修复**：使用按智能体的模型覆盖为简单任务使用更快的模型：
```toml
[model]
provider = "groq"
model = "llama-3.1-8b-instant"  # 快速、小型模型
```

### "找不到模型"

**修复**：检查可用模型：
```bash
curl http://127.0.0.1:4200/api/models
```

或使用别名：
```toml
[model]
model = "llama"  # llama-3.3-70b-versatile 的别名
```

查看完整别名列表：
```bash
curl http://127.0.0.1:4200/api/models/aliases
```

### Ollama / 本地模型无法连接

**修复**：确保本地服务器正在运行：
```bash
# Ollama
ollama serve  # 默认：http://localhost:11434

# vLLM
python -m vllm.entrypoints.openai.api_server --model ...

# LM Studio
# 从 LM Studio UI 启动，启用 API 服务器
```

---

## 通道问题

### Telegram 机器人无响应

**检查清单**：
1. 机器人令牌正确：`echo $TELEGRAM_BOT_TOKEN`
2. 机器人已启动（在 Telegram 中发送 `/start`）
3. 如果设置了 `allowed_users`，你的 Telegram 用户 ID 在列表中
4. 检查日志中的 "Telegram adapter" 消息

### Discord 机器人离线

**检查清单**：
1. 机器人令牌正确
2. **Message Content Intent** 已在 Discord 开发者门户中启用
3. 机器人已被邀请加入服务器并具有正确的权限
4. 检查日志中的 Gateway 连接

### Slack 机器人无法接收消息

**检查清单**：
1. `SLACK_BOT_TOKEN`（xoxb-）和 `SLACK_APP_TOKEN`（xapp-）都已设置
2. 已在 Slack 应用设置中启用 Socket Mode
3. 机器人已被添加到应该监控的频道中
4. 所需权限范围：`chat:write`、`app_mentions:read`、`im:history`、`im:read`、`im:write`

### 基于 Webhook 的通道（WhatsApp、LINE、Viber 等）

**检查清单**：
1. 你的服务器可公开访问（或使用 ngrok 等隧道）
2. Webhook URL 已在平台仪表板中正确配置
3. Webhook 端口已打开且未被防火墙阻止
4. 配置和平台仪表板之间的验证令牌匹配

### "通道适配器启动失败"

**常见原因**：
- 令牌丢失或无效
- 端口已被占用（对于基于 Webhook 的通道）
- 网络连接问题

检查特定错误的日志：
```bash
RUST_LOG=openfang_channels=debug openfang start
```

---

## 智能体问题

### 智能体陷入循环

**原因**：智能体反复使用相同的参数调用相同的工具。

**自动保护**：OpenFang 内置了循环保护：
- **警告** 在 3 次相同的工具调用后
- **阻止** 在 5 次相同的工具调用后
- **断路器** 在 30 次总阻止调用后（停止智能体）

**手动修复**：取消智能体的当前运行：
```bash
curl -X POST http://127.0.0.1:4200/api/agents/{id}/stop
```

或通过聊天命令：`/stop`

### 智能体上下文不足

**原因**：对话历史记录对于模型的上下文窗口来说太长。

**修复**：压缩会话：
```bash
curl -X POST http://127.0.0.1:4200/api/agents/{id}/session/compact
```

或通过聊天命令：`/compact`

当会话达到阈值时，默认启用自动压缩（可在 `[compaction]` 中配置）。

### 智能体不使用工具

**原因**：工具未在智能体的能力中授予。

**修复**：检查智能体的清单：
```toml
[capabilities]
tools = ["file_read", "web_fetch", "shell_exec"]  # 必须列出每个工具
# 或
# tools = ["*"]  # 授予所有工具（谨慎使用）
```

### 智能体响应中出现 "权限被拒绝" 错误

**原因**：智能体尝试使用不在其能力中的工具或访问资源。

**修复**：将所需的能力添加到智能体清单。常见的有：
- `tools = [...]` 用于工具访问
- `network = ["*"]` 用于网络访问
- `memory_write = ["self.*"]` 用于内存写入
- `shell = ["*"]` 用于 shell 命令（谨慎使用）

### 智能体生成失败

**检查**：
1. TOML 清单有效：`openfang agent spawn --dry-run manifest.toml`
2. LLM 提供程序已配置且具有有效密钥
3. 清单中指定的模型存在于目录中

---

## API 问题

### 401 未授权

**原因**：需要 API 密钥但未提供。

**修复**：包含 Bearer 令牌：
```bash
curl -H "Authorization: Bearer your-api-key" http://127.0.0.1:4200/api/agents
```

### 429 请求过多

**原因**：触发了 GCRA 速率限制器。

**修复**：等待 `Retry-After` 周期，或在配置中增加速率限制：
```toml
[api]
rate_limit_per_second = 20  # 根据需要增加
```

### 浏览器 CORS 错误

**原因**：尝试从不同来源访问 API。

**修复**：将你的来源添加到 CORS 配置：
```toml
[api]
cors_origins = ["http://localhost:5173", "https://your-app.com"]
```

### WebSocket 断开连接

**可能原因**：
- 空闲超时（发送定期 ping）
- 网络中断（自动重新连接）
- 智能体崩溃（检查日志）

**客户端修复**：实现带有指数退避的重新连接逻辑。

### OpenAI 兼容 API 无法与我的工具配合使用

**检查清单**：
1. 使用 `POST /v1/chat/completions`（不是 `/api/agents/{id}/message`）
2. 将模型设置为 `openfang:agent-name`（例如 `openfang:coder`）
3. 流式传输：设置 `"stream": true` 以获得 SSE 响应
4. 图片：使用 `image_url` 和 `data:image/png;base64,...` 格式

---

## 桌面应用问题

### 应用无法启动

**检查清单**：
1. 一次只能运行一个实例（单实例强制执行）
2. 检查守护进程是否已在相同端口上运行
3. 尝试删除 `~/.openfang/daemon.json` 并重启

### 应用中白屏/空白屏幕

**原因**：嵌入式 API 服务器尚未启动。

**修复**：等待几秒钟。如果持续存在，检查日志中的服务器启动错误。

### 系统托盘图标丢失

**平台特定**：
- **Linux**：需要系统托盘（例如 GNOME 上的 `libappindicator`）
- **macOS**：应该开箱即用
- **Windows**：检查通知区域设置，可能需要显示隐藏图标

---

## 性能

### 内存使用率高

**提示**：
- 减少并发智能体的数量
- 对长时间运行的智能体使用会话压缩
- 使用较小的模型（对于简单任务使用 Llama 8B 而不是 70B）
- 清除旧会话：`DELETE /api/sessions/{id}`

### 启动缓慢

**正常启动**：内核 <200ms，带通道适配器 ~1-2s。

如果更慢：
- 检查数据库大小（`~/.openfang/data/openfang.db`）
- 减少启用的通道数量
- 检查网络连接（启动时建立 MCP 服务器连接）

### CPU 使用率高

**可能原因**：
- WASM 沙箱执行（燃料限制，应该自终止）
- 多个智能体同时运行
- 通道适配器重新连接（指数退避）

---

## 常见问题

### 如何切换默认的 LLM 提供程序？

编辑 `~/.openfang/config.toml`：
```toml
[default_model]
provider = "groq"
model = "llama-3.3-70b-versatile"
api_key_env = "GROQ_API_KEY"
```

### 可以同时使用多个提供程序吗？

可以。每个智能体可以通过其清单中的 `[model]` 部分使用不同的提供程序。内核为每个唯一的提供程序配置创建专用驱动程序。

### 如何添加新通道？

1. 在 `~/.openfang/config.toml` 中的 `[channels]` 下添加通道配置
2. 设置所需的环境变量（令牌、密钥）
3. 重启守护进程

### 如何更新 OpenFang？

```bash
# 从源码
cd openfang && git pull && cargo install --path crates/openfang-cli

# Docker
docker pull ghcr.io/RightNow-AI/openfang:latest
```

### 智能体可以相互通信吗？

可以。智能体可以使用 `agent_send`、`agent_spawn`、`agent_find` 和 `agent_list` 工具进行通信。orchestrator 模板专门设计用于多智能体委托。

### 我的数据会被发送到云端吗？

只有 LLM API 调用会转到提供程序的服务器。所有智能体数据、内存、会话和配置都本地存储在 SQLite（`~/.openfang/data/openfang.db`）中。OFP 有线协议使用 HMAC-SHA256 相互认证进行 P2P 通信。

### 如何备份我的数据？

备份这些文件：
- `~/.openfang/config.toml`（配置）
- `~/.openfang/data/openfang.db`（所有智能体数据、内存、会话）
- `~/.openfang/skills/`（已安装的技能）

### 如何重置所有内容？

```bash
rm -rf ~/.openfang
openfang init  # 重新开始
```

### 我可以在没有互联网连接的情况下运行 OpenFang 吗？

可以，如果你使用本地 LLM 提供程序：
- **Ollama**：`ollama serve` + `ollama pull llama3.2`
- **vLLM**：自托管模型服务器
- **LM Studio**：基于 GUI 的本地模型运行器

在配置中设置提供程序：
```toml
[default_model]
provider = "ollama"
model = "llama3.2"
```

### OpenFang 和 OpenClaw 有什么区别？

| 方面 | OpenFang | OpenClaw |
|--------|----------|----------|
| 语言 | Rust | Python |
| 通道 | 40 | 38 |
| 技能 | 60 | 57 |
| 提供程序 | 20 | 3 |
| 安全 | 16 个系统 | 基于配置 |
| 二进制大小 | ~30 MB | ~200 MB |
| 启动 | <200 ms | ~3 s |

OpenFang 可以导入 OpenClaw 配置：`openfang migrate --from openclaw`

### 如何报告错误或请求功能？

- 错误：在 GitHub 上打开 issue
- 安全：请参阅 [SECURITY.md](../SECURITY.md) 了解负责任的披露
- 功能：打开 GitHub 讨论或 PR

### 系统要求是什么？

| 资源 | 最低 | 推荐 |
|----------|---------|-------------|
| RAM | 128 MB | 512 MB |
| 磁盘 | 50 MB（二进制） | 500 MB（含数据） |
| CPU | 任何 x86_64/ARM64 | 2+ 核心 |
| 操作系统 | Linux、macOS、Windows | 任何 |
| Rust | 1.75+（仅构建） | 最新稳定版 |

### 如何为特定 crate 启用调试日志？

```bash
RUST_LOG=openfang_runtime=debug,openfang_channels=info openfang start
```

### 我可以将 OpenFang 用作库吗？

可以。每个 crate 都可以独立使用：
```toml
[dependencies]
openfang-runtime = { path = "crates/openfang-runtime" }
openfang-memory = { path = "crates/openfang-memory" }
```

`openfang-kernel` crate 将所有内容组装在一起，但你可以使用各个 crate 进行自定义集成。
