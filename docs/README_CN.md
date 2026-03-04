# OpenFang 快速入门指南

本指南将引导您完成安装 OpenFang、配置首个 LLM 提供商、生成智能体，并与其进行聊天的完整流程。

## 目录

- [安装](#安装)
- [配置](#配置)
- [生成首个智能体](#生成首个智能体)
- [与智能体聊天](#与智能体聊天)
- [启动守护进程](#启动守护进程)
- [使用 WebChat 界面](#使用-webchat-界面)
- [后续步骤](#后续步骤)

---

## 安装

### 方案一：桌面应用（Windows / macOS / Linux）

从 [最新版本](https://github.com/RightNow-AI/openfang/releases/latest) 下载适用于您平台的安装程序：

| 平台 | 文件 |
|---|---|
| Windows | `.msi` 安装程序 |
| macOS | `.dmg` 磁盘映像 |
| Linux | `.AppImage` 或 `.deb` |

桌面应用包含完整的 OpenFang 系统，具备原生窗口、系统托盘、自动更新和操作系统通知功能。更新会在后台自动安装。

### 方案二：Shell 安装程序（Linux / macOS）

```bash
curl -sSf https://openfang.sh | sh
```

这将下载最新的 CLI 二进制文件并安装到 `~/.openfang/bin/`。

### 方案三：PowerShell 安装程序（Windows）

```powershell
irm https://openfang.sh/install.ps1 | iex
```

下载最新的 CLI 二进制文件，验证其 SHA256 校验和，并将其添加到您的用户 PATH。

### 方案四：Cargo 安装（任何平台）

需要 Rust 1.75+：

```bash
cargo install --git https://github.com/RightNow-AI/openfang openfang-cli
```

或从源码构建：

```bash
git clone https://github.com/RightNow-AI/openfang.git
cd openfang
cargo install --path crates/openfang-cli
```

### 方案五：Docker

```bash
docker pull ghcr.io/RightNow-AI/openfang:latest

docker run -d \
  --name openfang \
  -p 4200:4200 \
  -e ANTHROPIC_API_KEY=$ANTHROPIC_API_KEY \
  -v openfang-data:/data \
  ghcr.io/RightNow-AI/openfang:latest
```

或使用 Docker Compose：

```bash
git clone https://github.com/RightNow-AI/openfang.git
cd openfang
# 在环境变量或 .env 文件中设置您的 API 密钥
docker compose up -d
```

### 验证安装

```bash
openfang --version
```

---

## 配置

### 初始化

运行 init 命令创建 `~/.openfang/` 目录和默认配置文件：

```bash
openfang init
```

这将创建：

```
~/.openfang/
  config.toml    # 主配置文件
  data/          # 数据库和运行时数据
  agents/        # 智能体清单（可选）
```

### 设置 API 密钥

OpenFang 需要至少一个 LLM 提供商的 API 密钥。将其设置为环境变量：

```bash
# Anthropic (Claude)
export ANTHROPIC_API_KEY=sk-ant-...

# 或 OpenAI
export OPENAI_API_KEY=sk-...

# 或 Groq（提供免费套餐）
export GROQ_API_KEY=gsk_...
```

将 export 命令添加到您的 shell 配置文件（`~/.bashrc`、`~/.zshrc` 等）以持久化设置。

### 编辑配置

默认配置使用 Anthropic。要更改提供商，请编辑 `~/.openfang/config.toml`：

```toml
[default_model]
provider = "groq"                      # anthropic、openai、groq、ollama 等
model = "llama-3.3-70b-versatile"      # 提供商的模型标识符
api_key_env = "GROQ_API_KEY"           # 存储 API 密钥的环境变量名

[memory]
decay_rate = 0.05                      # 记忆置信度衰减率

[network]
listen_addr = "127.0.0.1:4200"        # OFP 监听地址
```

### 验证设置

```bash
openfang doctor
```

这将检查配置文件是否存在、API 密钥是否已设置，以及工具链是否可用。

---

## 生成首个智能体

### 使用内置模板

OpenFang 附带 30 个智能体模板。生成 hello-world 智能体：

```bash
openfang agent spawn agents/hello-world/agent.toml
```

输出：

```
Agent spawned successfully!
  ID:   a1b2c3d4-e5f6-...
  Name: hello-world
```

### 使用自定义清单

创建您自己的 `my-agent.toml`：

```toml
name = "my-assistant"
version = "0.1.0"
description = "一个乐于助人的助手"
author = "您"
module = "builtin:chat"

[model]
provider = "groq"
model = "llama-3.3-70b-versatile"

[capabilities]
tools = ["file_read", "file_list", "web_fetch"]
memory_read = ["*"]
memory_write = ["self.*"]
```

然后生成它：

```bash
openfang agent spawn my-agent.toml
```

### 列出运行中的智能体

```bash
openfang agent list
```

输出：

```
ID                                     NAME             STATE      PROVIDER     MODEL
-----------------------------------------------------------------------------------------------
a1b2c3d4-e5f6-...                     hello-world      Running    groq         llama-3.3-70b-versatile
```

---

## 与智能体聊天

使用智能体 ID 启动交互式聊天会话：

```bash
openfang agent chat a1b2c3d4-e5f6-...
```

或使用快速聊天命令（选择第一个可用智能体）：

```bash
openfang chat
```

或按名称指定智能体：

```bash
openfang chat hello-world
```

示例会话：

```
Chat session started (daemon mode). Type 'exit' or Ctrl+C to quit.

you> 你好！你能做什么？

agent> 我是运行在 OpenFang 上的 hello-world 智能体。我可以：
- 从文件系统读取文件
- 列出目录内容
- 获取网页内容

试试让我读取文件或在网上查找内容！

  [tokens: 142 in / 87 out | iterations: 1]

you> 列出当前目录的文件

agent> 当前目录的文件如下：
- Cargo.toml
- Cargo.lock
- README.md
- agents/
- crates/
- docs/
...

you> exit
Chat session ended.
```

---

## 启动守护进程

对于持久化智能体、多用户访问和 WebChat 界面，请启动守护进程：

```bash
openfang start
```

输出：

```
Starting OpenFang daemon...
OpenFang daemon running on http://127.0.0.1:4200
Press Ctrl+C to stop.
```

守护进程提供：
- **REST API** 位于 `http://127.0.0.1:4200/api/`
- **WebSocket** 端点位于 `ws://127.0.0.1:4200/api/agents/{id}/ws`
- **WebChat 界面** 位于 `http://127.0.0.1:4200/`
- **OFP 网络** 在 4200 端口

### 检查状态

```bash
openfang status
```

### 停止守护进程

在运行守护进程的终端中按 `Ctrl+C`，或：

```bash
curl -X POST http://127.0.0.1:4200/api/shutdown
```

---

## 使用 WebChat 界面

启动守护进程后，在浏览器中打开：

```
http://127.0.0.1:4200/
```

嵌入式 WebChat 界面允许您：
- 查看所有运行中的智能体
- 通过 WebSocket 与任何智能体实时聊天
- 查看生成的流式响应
- 查看每条消息的 token 使用量

---

## 后续步骤

现在您已运行 OpenFang：

- **探索智能体模板**：浏览 `agents/` 目录，了解 30 个预置智能体（coder、researcher、writer、ops、analyst、security-auditor 等）。
- **创建自定义智能体**：编写您自己的 `agent.toml` 清单。有关能力和调度的详细信息，请参阅[架构指南](architecture_CN.md)。
- **设置通道**：连接任意 40 个消息平台（Telegram、Discord、Slack、WhatsApp、LINE、Mastodon 等）。请参阅[通信通道适配器](channel-adapters_CN.md)。
- **使用内置技能**：60 个专家知识技能已预装（GitHub、Docker、Kubernetes、安全审计、提示工程等）。请参阅[技能开发](skill-development_CN.md)。
- **构建自定义技能**：使用 Python、WASM 或纯提示技能扩展智能体。请参阅[技能开发](skill-development_CN.md)。
- **使用 API**：76 个 REST/WS/SSE 端点，包括与 OpenAI 兼容的 `/v1/chat/completions`。请参阅[API 参考手册](api-reference_CN.md)。
- **切换 LLM 提供商**：支持 20 个提供商（Anthropic、OpenAI、Gemini、Groq、DeepSeek、xAI、Ollama 等）。支持每个智能体的模型覆盖。
- **设置工作流**：将多个智能体链接在一起。使用 TOML 工作流定义运行 `openfang workflow create`。
- **使用 MCP**：通过模型上下文协议连接到外部工具。在 `config.toml` 的 `[[mcp_servers]]` 下配置。
- **从 OpenClaw 迁移**：运行 `openfang migrate --from openclaw`。请参阅 [MIGRATION_CN.md](../MIGRATION_CN.md)。
- **桌面应用**：运行 `cargo tauri dev` 获取带系统托盘的原生桌面体验。
- **运行诊断**：`openfang doctor` 检查您的整个设置。

### 实用命令参考

```bash
openfang init                          # 初始化 ~/.openfang/
openfang start                         # 启动守护进程
openfang status                        # 检查守护进程状态
openfang doctor                        # 运行诊断检查

openfang agent spawn <manifest.toml>   # 生成智能体
openfang agent list                    # 列出所有智能体
openfang agent chat <id>               # 与智能体聊天
openfang agent kill <id>               # 终止智能体

openfang workflow list                 # 列出工作流
openfang workflow create <file.json>   # 创建工作流
openfang workflow run <id> <input>     # 运行工作流

openfang trigger list                  # 列出事件触发器
openfang trigger create <args>         # 创建触发器
openfang trigger delete <id>           # 删除触发器

openfang skill install <source>        # 安装技能
openfang skill list                    # 列出已安装技能
openfang skill search <query>          # 搜索 FangHub
openfang skill create                  # 脚手架创建新技能

openfang channel list                  # 列出通道状态
openfang channel setup <channel>       # 交互式设置向导

openfang config show                   # 显示当前配置
openfang config edit                   # 在编辑器中打开配置

openfang chat [agent]                  # 快速聊天（别名）
openfang migrate --from openclaw       # 从 OpenClaw 迁移
openfang mcp                           # 启动 MCP 服务器（stdio）
```
