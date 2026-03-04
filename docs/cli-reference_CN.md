# OpenFang CLI 参考手册

`openfang` 命令行工具的完整参考文档，用于管理 OpenFang 智能体操作系统。

## 概述

`openfang` 二进制文件是管理 OpenFang 智能体操作系统的主要接口。它支持两种运行模式：

- **守护进程模式** -- 当守护进程正在运行时（`openfang start`），CLI 命令通过 HTTP 与之通信。这是生产环境推荐使用的模式。
- **进程内模式** -- 当未检测到守护进程时，支持此模式的命令将启动一个临时的进程内内核。此模式下运行的智能体不会被持久化，进程退出时将会丢失。

不带子命令直接运行 `openfang` 将启动使用 ratatui 构建的交互式 TUI（终端用户界面），在终端中提供完整的仪表板体验。

## 安装

### 从源码安装（cargo）

```bash
cargo install --path crates/openfang-cli
```

### 从工作空间构建

```bash
cargo build --release -p openfang-cli
# 二进制文件位置：target/release/openfang（Windows 上为 openfang.exe）
```

### Docker

```bash
docker run -it openfang/openfang:latest
```

### Shell 安装脚本

```bash
curl -fsSL https://get.openfang.ai | sh
```

## 全局选项

以下选项适用于所有命令。

| 选项 | 说明 |
|---|---|
| `--config <PATH>` | 自定义配置文件路径。覆盖默认的 `~/.openfang/config.toml`。 |
| `--help` | 打印任何命令或子命令的帮助信息。 |
| `--version` | 打印 `openfang` 二进制文件的版本。 |

**环境变量：**

| 变量 | 说明 |
|---|---|
| `RUST_LOG` | 控制日志详细程度（例如 `info`、`debug`、`openfang_kernel=trace`）。 |
| `OPENFANG_AGENTS_DIR` | 覆盖智能体模板目录。 |
| `EDITOR` / `VISUAL` | `openfang config edit` 使用的编辑器。默认回退到 `notepad`（Windows）或 `vi`（Unix）。 |

---

## 命令参考

### openfang（无子命令）

启动交互式 TUI 仪表板。

```
openfang [--config <PATH>]
```

TUI 提供全屏终端界面，包含智能体、聊天、工作流、通道、技能、设置等面板。追踪输出被重定向到 `~/.openfang/tui.log` 以避免损坏终端显示。

按 `Ctrl+C` 退出。第二次按 `Ctrl+C` 强制终止进程。

---

### openfang init

初始化 OpenFang 工作空间。创建 `~/.openfang/` 目录及其子目录（`data/`、`agents/`）和默认的 `config.toml`。

```
openfang init [--quick]
```

**选项：**

| 选项 | 说明 |
|---|---|
| `--quick` | 跳过交互式提示。自动检测最佳可用的 LLM 提供程序并立即写入配置。适用于 CI/脚本环境。 |

**行为：**

- 不带 `--quick`：启动交互式 5 步引导向导（ratatui TUI），引导完成提供程序选择、API 密钥配置，并可选择启动守护进程。
- 带 `--quick`：按以下优先级顺序通过检查环境变量自动检测提供程序：Groq、Gemini、DeepSeek、Anthropic、OpenAI、OpenRouter。如果未找到，则回退到 Groq。
- 文件权限限制为仅所有者可访问（Unix 上文件为 `0600`，目录为 `0700`）。

**示例：**

```bash
# 交互式设置
openfang init

# 非交互式（CI/脚本）
export GROQ_API_KEY="gsk_..."
openfang init --quick
```

---

### openfang start

启动 OpenFang 守护进程（内核 + API 服务器）。

```
openfang start [--config <PATH>]
```

**行为：**

- 检查是否已有守护进程在运行；如果是，则退出并报错。
- 启动 OpenFang 内核（加载配置、初始化 SQLite 数据库、加载智能体、连接 MCP 服务器、启动后台任务）。
- 在 `config.toml` 中指定的地址启动 HTTP API 服务器（默认：`127.0.0.1:4200`）。
- 将 `daemon.json` 写入 `~/.openfang/` 以便其他 CLI 命令可以发现正在运行的守护进程。
- 阻塞直到被 `Ctrl+C` 中断。

**输出：**

```
  OpenFang Agent OS v0.1.0

  Starting daemon...

  [ok] Kernel booted (groq/llama-3.3-70b-versatile)
  [ok] 50 models available
  [ok] 3 agent(s) loaded

  API:        http://127.0.0.1:4200
  Dashboard:  http://127.0.0.1:4200/
  Provider:   groq
  Model:      llama-3.3-70b-versatile

  hint: Open the dashboard in your browser, or run `openfang chat`
  hint: Press Ctrl+C to stop the daemon
```

**示例：**

```bash
# 使用默认配置启动
openfang start

# 使用自定义配置启动
openfang start --config /path/to/config.toml
```

---

### openfang status

显示当前内核/守护进程状态。

```
openfang status [--json]
```

**选项：**

| 选项 | 说明 |
|---|---|
| `--json` | 输出机器可读的 JSON 格式，便于脚本处理。 |

**行为：**

- 如果守护进程正在运行：查询 `GET /api/status` 并显示智能体数量、提供程序、模型、运行时间、API URL 和活动智能体列表。
- 如果没有守护进程正在运行：启动进程内内核并显示持久化状态。显示守护进程未运行的警告。

**示例：**

```bash
openfang status

openfang status --json | jq '.agent_count'
```

---

### openfang doctor

对 OpenFang 安装运行诊断检查。

```
openfang doctor [--json] [--repair]
```

**选项：**

| 选项 | 说明 |
|---|---|
| `--json` | 以 JSON 格式输出结果，便于脚本处理。 |
| `--repair` | 尝试自动修复问题（创建缺失的目录、配置，移除过期文件）。在每次修复前会提示确认。 |

**执行的检查：**

1. **OpenFang 目录** -- `~/.openfang/` 是否存在
2. **.env 文件** -- 是否存在且具有正确的权限（Unix 上为 0600）
3. **Config TOML 语法** -- `config.toml` 是否能无错误地解析
4. **守护进程状态** -- 守护进程是否正在运行
5. **端口 4200 可用性** -- 如果守护进程未运行，检查端口是否空闲
6. **过期 daemon.json** -- 崩溃的守护进程遗留的 `daemon.json`
7. **数据库文件** -- SQLite 魔数验证
8. **磁盘空间** -- 如果可用空间少于 100MB 则发出警告（仅 Unix）
9. **智能体清单** -- 验证 `~/.openfang/agents/` 中的所有 `.toml` 文件
10. **LLM 提供程序密钥** -- 检查 10 个提供程序的环境变量（Groq、OpenRouter、Anthropic、OpenAI、DeepSeek、Gemini、Google、Together、Mistral、Fireworks），执行实时验证（检测 401/403）
11. **通道令牌** -- Telegram、Discord、Slack 令牌的格式验证
12. **配置一致性** -- 检查配置中的 `api_key_env` 引用是否与实际环境变量匹配
13. **Rust 工具链** -- `rustc --version`

**示例：**

```bash
openfang doctor

openfang doctor --repair

openfang doctor --json
```

---

### openfang dashboard

在默认浏览器中打开 Web 仪表板。

```
openfang dashboard
```

**行为：**

- 需要正在运行的守护进程。
- 在系统浏览器中打开守护进程 URL（例如 `http://127.0.0.1:4200/`）。
- 将 URL 复制到系统剪贴板（Windows 使用 PowerShell，macOS 使用 `pbcopy`，Linux 使用 `xclip`/`xsel`）。

**示例：**

```bash
openfang dashboard
```

---

### openfang completion

生成 Shell 补全脚本。

```
openfang completion <SHELL>
```

**参数：**

| 参数 | 说明 |
|---|---|
| `<SHELL>` | 目标 Shell。可选值：`bash`、`zsh`、`fish`、`elvish`、`powershell`。 |

**示例：**

```bash
# Bash
openfang completion bash > ~/.bash_completion.d/openfang

# Zsh
openfang completion zsh > "${fpath[1]}/_openfang"

# Fish
openfang completion fish > ~/.config/fish/completions/openfang.fish

# PowerShell
openfang completion powershell > openfang.ps1
```

---

## 智能体命令

### openfang agent new

从内置模板生成智能体。

```
openfang agent new [<TEMPLATE>]
```

**参数：**

| 参数 | 说明 |
|---|---|
| `<TEMPLATE>` | 模板名称（例如 `coder`、`assistant`、`researcher`）。如果省略，显示列出所有可用模板的交互式选择器。 |

**行为：**

- 从以下位置发现模板：仓库的 `agents/` 目录（开发版本）、`~/.openfang/agents/`（已安装），以及 `OPENFANG_AGENTS_DIR`（环境变量覆盖）。
- 每个模板是一个包含 `agent.toml` 清单文件的目录。
- 守护进程模式：发送 `POST /api/agents` 并携带清单。智能体是持久化的。
- 独立模式：启动进程内内核。智能体是临时的。

**示例：**

```bash
# 交互式选择器
openfang agent new

# 按名称生成
openfang agent new coder

# 生成 assistant 模板
openfang agent new assistant
```

---

### openfang agent spawn

从自定义清单文件生成智能体。

```
openfang agent spawn <MANIFEST>
```

**参数：**

| 参数 | 说明 |
|---|---|
| `<MANIFEST>` | 智能体清单 TOML 文件的路径。 |

**行为：**

- 读取并解析 TOML 清单文件。
- 守护进程模式：将原始 TOML 发送到 `POST /api/agents`。
- 独立模式：启动进程内内核并在本地生成智能体。

**示例：**

```bash
openfang agent spawn ./my-agent/agent.toml
```

---

### openfang agent list

列出所有正在运行的智能体。

```
openfang agent list [--json]
```

**选项：**

| 选项 | 说明 |
|---|---|
| `--json` | 以 JSON 数组格式输出，便于脚本处理。 |

**输出列：** ID、NAME、STATE、PROVIDER、MODEL（守护进程模式）或 ID、NAME、STATE、CREATED（进程内模式）。

**示例：**

```bash
openfang agent list

openfang agent list --json | jq '.[].name'
```

---

### openfang agent chat

启动与特定智能体的交互式聊天会话。

```
openfang agent chat <AGENT_ID>
```

**参数：**

| 参数 | 说明 |
|---|---|
| `<AGENT_ID>` | 智能体 UUID。通过 `openfang agent list` 获取。 |

**行为：**

- 打开 REPL 风格的聊天循环。
- 在 `you>` 提示符处输入消息。
- 智能体响应显示在 `agent>` 提示符后，后跟令牌使用情况和迭代计数。
- 输入 `exit`、`quit` 或按 `Ctrl+C` 结束会话。

**示例：**

```bash
openfang agent chat a1b2c3d4-e5f6-7890-abcd-ef1234567890
```

---

### openfang agent kill

终止正在运行的智能体。

```
openfang agent kill <AGENT_ID>
```

**参数：**

| 参数 | 说明 |
|---|---|
| `<AGENT_ID>` | 要终止的智能体 UUID。 |

**示例：**

```bash
openfang agent kill a1b2c3d4-e5f6-7890-abcd-ef1234567890
```

---

## 工作流命令

所有工作流命令都需要正在运行的守护进程。

### openfang workflow list

列出所有已注册的工作流。

```
openfang workflow list
```

**输出列：** ID、NAME、STEPS、CREATED。

---

### openfang workflow create

从 JSON 定义文件创建工作流。

```
openfang workflow create <FILE>
```

**参数：**

| 参数 | 说明 |
|---|---|
| `<FILE>` | 描述工作流步骤的 JSON 文件路径。 |

**示例：**

```bash
openfang workflow create ./my-workflow.json
```

---

### openfang workflow run

按 ID 执行工作流。

```
openfang workflow run <WORKFLOW_ID> <INPUT>
```

**参数：**

| 参数 | 说明 |
|---|---|
| `<WORKFLOW_ID>` | 工作流 UUID。通过 `openfang workflow list` 获取。 |
| `<INPUT>` | 传递给工作流的输入文本。 |

**示例：**

```bash
openfang workflow run abc123 "分析此代码的安全问题"
```

---

## 触发器命令

所有触发器命令都需要正在运行的守护进程。

### openfang trigger list

列出所有事件触发器。

```
openfang trigger list [--agent-id <ID>]
```

**选项：**

| 选项 | 说明 |
|---|---|
| `--agent-id <ID>` | 按所属智能体的 UUID 过滤触发器。 |

**输出列：** TRIGGER ID、AGENT ID、ENABLED、FIRES、PATTERN。

---

### openfang trigger create

为智能体创建事件触发器。

```
openfang trigger create <AGENT_ID> <PATTERN_JSON> [--prompt <TEMPLATE>] [--max-fires <N>]
```

**参数：**

| 参数 | 说明 |
|---|---|
| `<AGENT_ID>` | 拥有该触发器的智能体 UUID。 |
| `<PATTERN_JSON>` | 触发器模式，JSON 字符串格式。 |

**选项：**

| 选项 | 默认值 | 说明 |
|---|---|---|
| `--prompt <TEMPLATE>` | `"Event: {{event}}"` | 提示模板。使用 `{{event}}` 作为事件数据的占位符。 |
| `--max-fires <N>` | `0`（无限制） | 触发器将触发的最大次数。 |

**模式示例：**

```bash
# 在任何生命周期事件上触发
openfang trigger create <AGENT_ID> '{"lifecycle":{}}'

# 当特定智能体生成时触发
openfang trigger create <AGENT_ID> '{"agent_spawned":{"name_pattern":"*"}}'

# 在智能体终止时触发
openfang trigger create <AGENT_ID> '{"agent_terminated":{}}'

# 在所有事件上触发（限制为 10 次）
openfang trigger create <AGENT_ID> '{"all":{}}' --max-fires 10
```

---

### openfang trigger delete

按 ID 删除触发器。

```
openfang trigger delete <TRIGGER_ID>
```

**参数：**

| 参数 | 说明 |
|---|---|
| `<TRIGGER_ID>` | 要删除的触发器 UUID。 |

---

## 技能命令

### openfang skill list

列出所有已安装的技能。

```
openfang skill list
```

**输出列：** NAME、VERSION、TOOLS、DESCRIPTION。

从 `~/.openfang/skills/` 和编译到二进制文件中的捆绑技能加载技能。

---

### openfang skill install

从本地目录、git URL 或 FangHub 市场安装技能。

```
openfang skill install <SOURCE>
```

**参数：**

| 参数 | 说明 |
|---|---|
| `<SOURCE>` | 技能名称（FangHub）、本地目录路径或 git URL。 |

**行为：**

- **本地目录：** 在目录中查找 `skill.toml`。如果未找到，检查 OpenClaw 格式的技能（带 YAML 前置内容的 SKILL.md）并自动转换。
- **远程（FangHub）：** 从 FangHub 市场获取并安装。技能通过 SHA256 验证和提示词注入扫描。

**示例：**

```bash
# 从本地目录安装
openfang skill install ./my-skill/

# 从 FangHub 安装
openfang skill install web-search

# 安装 OpenClaw 格式技能
openfang skill install ./openclaw-skill/
```

---

### openfang skill remove

移除已安装的技能。

```
openfang skill remove <NAME>
```

**参数：**

| 参数 | 说明 |
|---|---|
| `<NAME>` | 要移除的技能名称。 |

**示例：**

```bash
openfang skill remove web-search
```

---

### openfang skill search

在 FangHub 市场中搜索技能。

```
openfang skill search <QUERY>
```

**参数：**

| 参数 | 说明 |
|---|---|
| `<QUERY>` | 搜索查询字符串。 |

**示例：**

```bash
openfang skill search "docker kubernetes"
```

---

### openfang skill create

交互式地创建新的技能项目脚手架。

```
openfang skill create
```

**行为：**

提示输入：
- 技能名称
- 描述
- 运行时（`python`、`node` 或 `wasm`；默认为 `python`）

在 `~/.openfang/skills/<name>/` 下创建目录，包含：
- `skill.toml` -- 清单文件
- `src/main.py`（或 `src/index.js`）-- 带有样板代码的入口点

**示例：**

```bash
openfang skill create
# 技能名称：my-tool
# 描述：一个自定义分析工具
# 运行时（python/node/wasm）[python]：python
```

---

## 通道命令

### openfang channel list

列出已配置的通道及其状态。

```
openfang channel list
```

**输出列：** CHANNEL、ENV VAR、STATUS。

检查 `config.toml` 中的通道配置节和环境变量中的所需令牌。状态为以下之一：`Ready`、`Missing env`、`Not configured`。

**检查的通道：** webchat、telegram、discord、slack、whatsapp、signal、matrix、email。

---

### openfang channel setup

通道集成的交互式设置向导。

```
openfang channel setup [<CHANNEL>]
```

**参数：**

| 参数 | 说明 |
|---|---|
| `<CHANNEL>` | 通道名称。如果省略，显示交互式选择器。 |

**支持的通道：** `telegram`、`discord`、`slack`、`whatsapp`、`email`、`signal`、`matrix`。

每个向导：
1. 显示获取凭据的分步说明。
2. 提示输入令牌/凭据。
3. 将令牌保存到 `~/.openfang/.env`，权限设置为仅所有者可访问。
4. 将通道配置块追加到 `config.toml`（提示确认）。
5. 如果有守护进程正在运行，警告需要重启。

**示例：**

```bash
# 交互式选择器
openfang channel setup

# 直接设置
openfang channel setup telegram
openfang channel setup discord
openfang channel setup slack
```

---

### openfang channel test

通过已配置的通道发送测试消息。

```
openfang channel test <CHANNEL>
```

**参数：**

| 参数 | 说明 |
|---|---|
| `<CHANNEL>` | 要测试的通道名称。 |

需要正在运行的守护进程。发送 `POST /api/channels/<channel>/test`。

**示例：**

```bash
openfang channel test telegram
```

---

### openfang channel enable

启用通道集成。

```
openfang channel enable <CHANNEL>
```

**参数：**

| 参数 | 说明 |
|---|---|
| `<CHANNEL>` | 要启用的通道名称。 |

守护进程模式：发送 `POST /api/channels/<channel>/enable`。无守护进程：打印一条说明，表示更改将在下次启动时生效。

---

### openfang channel disable

禁用通道而不删除其配置。

```
openfang channel disable <CHANNEL>
```

**参数：**

| 参数 | 说明 |
|---|---|
| `<CHANNEL>` | 要禁用的通道名称。 |

守护进程模式：发送 `POST /api/channels/<channel>/disable`。无守护进程：打印一条说明，要求编辑 `config.toml`。

---

## 配置命令

### openfang config show

显示当前配置文件。

```
openfang config show
```

打印 `~/.openfang/config.toml` 的内容，并以文件路径作为标题注释。

---

### openfang config edit

在编辑器中打开配置文件。

```
openfang config edit
```

使用 `$EDITOR`，然后是 `$VISUAL`，默认回退到 `notepad`（Windows）或 `vi`（Unix）。

---

### openfang config get

通过点分键路径获取单个配置值。

```
openfang config get <KEY>
```

**参数：**

| 参数 | 说明 |
|---|---|
| `<KEY>` | 进入 TOML 结构的点分键路径。 |

**示例：**

```bash
openfang config get default_model.provider
# groq

openfang config get api_listen
# 127.0.0.1:4200

openfang config get memory.decay_rate
# 0.05
```

---

### openfang config set

通过点分键路径设置配置值。

```
openfang config set <KEY> <VALUE>
```

**参数：**

| 参数 | 说明 |
|---|---|
| `<KEY>` | 点分键路径。 |
| `<VALUE>` | 新值。类型根据现有值推断（整数、浮点数、布尔值或字符串）。 |

**警告：** 此命令会重新序列化 TOML 文件，这将删除所有注释。

**示例：**

```bash
openfang config set default_model.provider anthropic
openfang config set default_model.model claude-sonnet-4-20250514
openfang config set api_listen "0.0.0.0:4200"
```

---

### openfang config set-key

将 LLM 提供程序 API 密钥保存到 `~/.openfang/.env`。

```
openfang config set-key <PROVIDER>
```

**参数：**

| 参数 | 说明 |
|---|---|
| `<PROVIDER>` | 提供程序名称（例如 `groq`、`anthropic`、`openai`、`gemini`、`deepseek`、`openrouter`、`together`、`mistral`、`fireworks`、`perplexity`、`cohere`、`xai`、`brave`、`tavily`）。 |

**行为：**

- 交互式提示输入 API 密钥。
- 保存到 `~/.openfang/.env`，格式为 `<PROVIDER_NAME>_API_KEY=<value>`。
- 对提供程序的 API 执行实时验证测试。
- Unix 上文件权限限制为仅所有者可访问。

**示例：**

```bash
openfang config set-key groq
# 粘贴你的 groq API 密钥：gsk_...
# [ok] 已将 GROQ_API_KEY 保存到 ~/.openfang/.env
# 正在测试密钥... OK
```

---

### openfang config delete-key

从 `~/.openfang/.env` 移除 API 密钥。

```
openfang config delete-key <PROVIDER>
```

**参数：**

| 参数 | 说明 |
|---|---|
| `<PROVIDER>` | 提供程序名称。 |

**示例：**

```bash
openfang config delete-key openai
```

---

### openfang config test-key

使用存储的 API 密钥测试提供程序连接。

```
openfang config test-key <PROVIDER>
```

**参数：**

| 参数 | 说明 |
|---|---|
| `<PROVIDER>` | 提供程序名称。 |

**行为：**

- 从环境（从 `~/.openfang/.env` 加载）读取 API 密钥。
- 访问提供程序的 models/health 端点。
- 报告 `OK`（密钥被接受）或 `FAILED (401/403)`（密钥被拒绝）。
- 失败时以代码 1 退出。

**示例：**

```bash
openfang config test-key groq
# 正在测试 groq (GROQ_API_KEY)... OK
```

---

## 快速聊天

### openfang chat

启动聊天会话的快速别名。

```
openfang chat [<AGENT>]
```

**参数：**

| 参数 | 说明 |
|---|---|
| `<AGENT>` | 可选的智能体名称或 UUID。 |

**行为：**

- **守护进程模式：** 在运行中的智能体中按名称或 ID 查找智能体。如果未提供智能体名称，使用第一个可用的智能体。如果没有智能体存在，建议执行 `openfang agent new`。
- **独立模式（无守护进程）：** 启动进程内内核并从模板自动生成智能体。搜索与给定名称匹配的智能体，然后回退到 `assistant`，再回退到第一个可用模板。

这是开始聊天的最简单方式 -- 无论是否有守护进程都可以工作。

**示例：**

```bash
# 与默认智能体聊天
openfang chat

# 与特定智能体按名称聊天
openfang chat coder

# 与特定智能体按 UUID 聊天
openfang chat a1b2c3d4-e5f6-7890-abcd-ef1234567890
```

---

## 迁移

### openfang migrate

从另一个智能体框架迁移配置和智能体。

```
openfang migrate --from <FRAMEWORK> [--source-dir <PATH>] [--dry-run]
```

**选项：**

| 选项 | 说明 |
|---|---|
| `--from <FRAMEWORK>` | 源框架。可选值：`openclaw`、`langchain`、`autogpt`。 |
| `--source-dir <PATH>` | 源工作空间路径。如果未设置则自动检测（例如 `~/.openclaw`、`~/.langchain`、`~/Auto-GPT`）。 |
| `--dry-run` | 显示将要导入的内容而不进行实际更改。 |

**行为：**

- 将源框架中的智能体配置、YAML 清单和设置转换为 OpenFang 格式。
- 将导入的数据保存到 `~/.openfang/`。
- 写入 `migration_report.md`，总结已导入的内容。

**示例：**

```bash
# 从 OpenClaw 预览迁移
openfang migrate --from openclaw --dry-run

# 从 OpenClaw 迁移（自动检测源）
openfang migrate --from openclaw

# 从 LangChain 迁移，指定源目录
openfang migrate --from langchain --source-dir /home/user/.langchain

# 从 AutoGPT 迁移
openfang migrate --from autogpt
```

---

## MCP 服务器

### openfang mcp

通过 stdio 启动 MCP（模型上下文协议）服务器。

```
openfang mcp
```

**行为：**

- 通过带有 Content-Length 帧的 stdin/stdout 上的 JSON-RPC 2.0 将运行中的 OpenFang 智能体公开为 MCP 工具。
- 每个智能体成为一个可调用的工具，命名为 `openfang_agent_<name>`（连字符替换为下划线）。
- 如果可用则通过 HTTP 连接到正在运行的守护进程；否则启动进程内内核。
- 协议版本：`2024-11-05`。
- 最大消息大小：10MB（安全限制）。

**支持的 MCP 方法：**

| 方法 | 说明 |
|---|---|
| `initialize` | 返回服务器能力和信息。 |
| `tools/list` | 列出所有可用的智能体工具。 |
| `tools/call` | 向智能体发送消息并返回响应。 |

**工具输入模式：**

每个智能体工具接受单个 `message`（字符串）参数。

**与 Claude Desktop / 其他 MCP 客户端集成：**

添加到你的 MCP 客户端配置：

```json
{
  "mcpServers": {
    "openfang": {
      "command": "openfang",
      "args": ["mcp"]
    }
  }
}
```

---

## 守护进程自动检测

CLI 使用两步机制检测正在运行的守护进程：

1. **读取 `daemon.json`：** 启动时，守护进程将包含监听地址（例如 `127.0.0.1:4200`）的 `~/.openfang/daemon.json` 写入磁盘。CLI 读取此文件以了解守护进程的位置。

2. **健康检查：** CLI 发送 `GET http://<listen_addr>/api/health`，超时时间为 2 秒。如果健康检查成功，则认为守护进程正在运行，CLI 使用 HTTP 与其通信。

如果任一步骤失败（没有 `daemon.json`、文件过期、健康检查超时），对于支持的命令，CLI 将回退到进程内模式。需要守护进程的命令（工作流、触发器、通道测试/启用/禁用、仪表板）将退出并报错并显示有用的消息。

**守护进程生命周期：**

```
openfang start          # 启动守护进程，写入 daemon.json
                         # 其他 CLI 实例检测到 daemon.json
openfang status         # 通过 HTTP 连接到守护进程
Ctrl+C                  # 守护进程关闭，移除 daemon.json

openfang doctor --repair  # 清理崩溃遗留的过期 daemon.json
```

---

## 环境文件

OpenFang 在每次 CLI 调用时将 `~/.openfang/.env` 加载到进程环境中。系统环境变量优先于 `.env` 值。

`.env` 文件存储 API 密钥和密钥：

```bash
GROQ_API_KEY=gsk_...
ANTHROPIC_API_KEY=sk-ant-...
GEMINI_API_KEY=AIza...
TELEGRAM_BOT_TOKEN=123456:ABC-DEF...
```

使用 `config set-key` / `config delete-key` 命令管理密钥，而不是直接编辑文件，因为这些命令强制执行正确的权限。

---

## 退出代码

| 代码 | 含义 |
|---|---|
| `0` | 成功。 |
| `1` | 一般错误（无效参数、操作失败、缺少守护进程、解析错误、生成失败）。 |
| `130` | 被第二个 `Ctrl+C` 中断（强制退出）。 |

---

## 示例

### 首次设置

```bash
# 1. 设置你的 API 密钥
export GROQ_API_KEY="gsk_your_key_here"

# 2. 初始化 OpenFang
openfang init --quick

# 3. 启动守护进程
openfang start
```

### 日常使用

```bash
# 快速聊天（需要时自动生成智能体）
openfang chat

# 与特定智能体聊天
openfang chat coder

# 检查运行状态
openfang status

# 打开 Web 仪表板
openfang dashboard
```

### 智能体管理

```bash
# 从模板生成
openfang agent new assistant

# 从自定义清单生成
openfang agent spawn ./agents/custom-agent/agent.toml

# 列出运行中的智能体
openfang agent list

# 通过 UUID 与智能体聊天
openfang agent chat <UUID>

# 终止智能体
openfang agent kill <UUID>
```

### 工作流自动化

```bash
# 创建工作流
openfang workflow create ./review-pipeline.json

# 列出工作流
openfang workflow list

# 运行工作流
openfang workflow run <WORKFLOW_ID> "审查最新的 PR"
```

### 事件触发器

```bash
# 创建一个在智能体生成时触发的触发器
openfang trigger create <AGENT_ID> '{"agent_spawned":{"name_pattern":"*"}}' \
  --prompt "新智能体已生成：{{event}}" \
  --max-fires 100

# 列出所有触发器
openfang trigger list

# 列出特定智能体的触发器
openfang trigger list --agent-id <AGENT_ID>

# 删除触发器
openfang trigger delete <TRIGGER_ID>
```

### 技能管理

```bash
# 搜索 FangHub
openfang skill search "code review"

# 安装技能
openfang skill install code-reviewer

# 列出已安装技能
openfang skill list

# 创建新技能
openfang skill create

# 移除技能
openfang skill remove code-reviewer
```

### 通道设置

```bash
# 交互式通道选择器
openfang channel setup

# 直接通道设置
openfang channel setup telegram

# 检查通道状态
openfang channel list

# 测试通道
openfang channel test telegram

# 启用/禁用通道
openfang channel enable discord
openfang channel disable slack
```

### 配置

```bash
# 查看配置
openfang config show

# 获取特定值
openfang config get default_model.provider

# 更改提供程序
openfang config set default_model.provider anthropic
openfang config set default_model.model claude-sonnet-4-20250514
openfang config set default_model.api_key_env ANTHROPIC_API_KEY

# 管理 API 密钥
openfang config set-key anthropic
openfang config test-key anthropic
openfang config delete-key openai

# 在编辑器中打开
openfang config edit
```

### 从其他框架迁移

```bash
# 预览迁移
openfang migrate --from openclaw --dry-run

# 执行迁移
openfang migrate --from openclaw

# 从 LangChain 迁移
openfang migrate --from langchain --source-dir ~/.langchain
```

### MCP 集成

```bash
# 为 Claude Desktop 或其他 MCP 客户端启动 MCP 服务器
openfang mcp
```

### 诊断

```bash
# 运行所有诊断检查
openfang doctor

# 自动修复问题
openfang doctor --repair

# 机器可读的诊断
openfang doctor --json
```

### Shell 补全

```bash
# 为 shell 生成并安装补全脚本
openfang completion bash >> ~/.bashrc
openfang completion zsh > "${fpath[1]}/_openfang"
openfang completion fish > ~/.config/fish/completions/openfang.fish
```

---

## 支持的 LLM 提供程序

`openfang config set-key` 和 `openfang doctor` 识别以下提供程序：

| 提供程序 | 环境变量 | 默认模型 |
|---|---|---|
| Groq | `GROQ_API_KEY` | `llama-3.3-70b-versatile` |
| Gemini | `GEMINI_API_KEY` 或 `GOOGLE_API_KEY` | `gemini-2.5-flash` |
| DeepSeek | `DEEPSEEK_API_KEY` | `deepseek-chat` |
| Anthropic | `ANTHROPIC_API_KEY` | `claude-sonnet-4-20250514` |
| OpenAI | `OPENAI_API_KEY` | `gpt-4o` |
| OpenRouter | `OPENROUTER_API_KEY` | `openrouter/auto` |
| Together | `TOGETHER_API_KEY` | -- |
| Mistral | `MISTRAL_API_KEY` | -- |
| Fireworks | `FIREWORKS_API_KEY` | -- |
| Perplexity | `PERPLEXITY_API_KEY` | -- |
| Cohere | `COHERE_API_KEY` | -- |
| xAI | `XAI_API_KEY` | -- |

额外的搜索/获取提供程序密钥：`BRAVE_API_KEY`、`TAVILY_API_KEY`。
