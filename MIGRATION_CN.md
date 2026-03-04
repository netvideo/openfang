# 迁移到OpenFang

本指南介绍从其他框架迁移到OpenFang的流程。迁移引擎处理配置转换、智能体导入、内存传输、渠道重新配置和技能扫描。

## 目录

- [快速迁移](#快速迁移)
- [什么被迁移](#什么被迁移)
- [手动迁移步骤](#手动迁移步骤)
- [配置格式差异](#配置格式差异)
- [工具名称映射](#工具名称映射)
- [提供商映射](#提供商映射)
- [功能比较](#功能比较)

---

## 快速迁移

运行单个命令以迁移整个OpenFang工作空间：

```bash
openfang migrate --from openclaw
```
e这将自动检测您在`~/.openclaw/`的OpenClaw工作空间并将所有内容导入到`~/.openfang/`。

### 选项
```bash
# 指定自定义源目录
openfang migrate --from openclaw --source-dir /path/to/openclaw/workspace
# 试运行--查看将进行哪些更改而不进行实际修改
openfang migrate --from openclaw --dry-run
```
e### 迁移报告
成功迁移后，`migration_report.md`文件将保存到`~/.openfang/`，其中总结所有导入、跳过或需要手动关注的内容。
### 其他框架
LangChain和AutoGPT迁移支持已计划：
e```bash
openfang migrate --from langchain   # Coming soon
openfang migrate --from autogpt    # Coming soon
```
e---
e## 什么被迁移e
| 项目 | 源（OpenClaw） | 目标（OpenFang） | 状态 |
|------|-------------------|------------------------|--------|
| **配置** | `~/.openclaw/config.yaml` | `~/.openfang/config.toml` | 完全自动化 |
| **智能体** | `~/.openclaw/agents/*/agent.yaml` | `~/.openfang/agents/*/agent.toml` | 完全自动化 |
| **内存** | `~/.openclaw/agents/*/MEMORY.md` | `~/.openfang/agents/*/imported_memory.md` | 完全自动化 |
| **渠道** | `~/.openclaw/messaging/*.yaml` | `~/.openfang/channels_import.toml` | 自动化（手动合并） |
| **技能** | `~/.openclaw/skills/` | 扫描并报告 | 手动重新安装 |
| **会话** | `~/.openclaw/agents/*/sessions/` | 未迁移 | 建议重新开始 |
e**渠道导入说明**
e渠道配置（Telegram、Discord、Slack）导出到`channels_import.toml`文件。您必须手动将`[channels]`部分合并到您的`~/.openfang/config.toml`。
**技能说明**
OpenClaw技能（Node.js）在迁移报告中被检测和列出，但不会自动转换。迁移后，使用以下命令重新安装技能：
e```bash
openfang skill install <skill-name-or-path>
```
eOpenFang在安装过程中自动检测OpenClaw格式的技能并进行转换。e---e## 手动迁移步骤
e如果您喜欢手动迁移（或需要处理边缘情况），请按照以下步骤操作：
e### 1. 初始化OpenFange
e```bash
openfang init
```
e这将创建`~/.openfang/`并包含默认`config.toml`。e### 2. 转换您的配置
e将您的`config.yaml`翻译成`config.toml`：e**OpenClaw** (`~/.openclaw/config.yaml`)：
```yaml
provider: anthropic
model: claude-sonnet-4-20250514
api_key_env: ANTHROPIC_API_KEY
temperature: 0.7
memory:
  decay_rate: 0.05
```
e**OpenFang** (`~/.openfang/config.toml`)：
toml
[default_model]
provider = "anthropic"
model = "claude-sonnet-4-20250514"
api_key_env = "ANTHROPIC_API_KEY"

[memory]
decay_rate = 0.05

[network]
listen_addr = "127.0.0.1:4200"
```
e### 3. 转换智能体清单e将每个`agent.yaml`翻译成`agent.toml`：e**OpenClaw** (`~/.openclaw/agents/coder/agent.yaml`)：
```yaml
name: coder
description: A coding assistant
provider: anthropic
model: claude-sonnet-4-20250514
tools:
  - read_file
  - write_file
  - execute_command
tags:
  - coding
  - dev
```
e**OpenFang** (`~/.openfang/agents/coder/agent.toml`)：
toml
name = "coder"
version = "0.1.0"
description = "A coding assistant"
author = "openfang"
module = "builtin:chat"
tags = ["coding", "dev"]

[model]
provider = "anthropic"
model = "claude-sonnet-4-20250514"

[capabilities]
tools = ["file_read", "file_write", "shell_exec"]
memory_read = ["*"]
memory_write = ["self.*"]
```
e### 4. 转换渠道配置e**OpenClaw** (`~/.openclaw/messaging/telegram.yaml`)：
type: telegram
bot_token_env: TELEGRAM_BOT_TOKEN
default_agent: coder
allowed_users:
  - "123456789"
```
e**OpenFang** (添加到`~/.openfang/config.toml`)：
toml
[channels.telegram]
bot_token_env = "TELEGRAM_BOT_TOKEN"
default_agent = "coder"
allowed_users = ["123456789"]
```
e### 5. 导入内存e从 OpenClaw 智能体复制任何`MEMORY.md`文件到 OpenFang 智能体目录：
e```bash
cp ~/.openclaw/agents/coder/MEMORY.md ~/.openfang/agents/coder/imported_memory.md
```e内核将在首次启动时摄取这些。e---e## 配置格式差异e| 方面 | OpenClaw | OpenFang |
|--------|----------|----------|
| 格式 | YAML | TOML |
| 配置位置 | `~/.openclaw/config.yaml` | `~/.openfang/config.toml` |
| 智能体定义 | `agent.yaml` | `agent.toml` |
| 渠道配置 | 每个渠道的单独文件 | 统一在`config.toml`中 |
| 工具权限 | 隐式（工具列表） | 基于能力（工具、内存、网络、shell、智能体生成） |
| 模型配置 | 扁平（顶层字段） | 嵌套（`[model]`部分） |
| 智能体模块 | 隐式 | 显式（`module = "builtin:chat"` / `"wasm:..."` / `"python:..."`） |
| 调度 | 不支持 | 内置（`[schedule]`部分：反应、连续、定期、主动）
e| 资源配额 | 不支持 | 内置（`[resources]`部分：每小时令牌、内存、CPU时间）
e| 网络 | 不支持 | OFP协议（`[network]`部分）
e## 工具名称映射e工具在 OpenClaw 和 OpenFang 之间被重命名以保持一致性。迁移引擎自动处理此问题。

| OpenClaw 工具 | OpenFang 工具 | 说明 |
|---------------|---------------|-------|
| `read_file` | `file_read` | 名词优先命名 |
| `write_file` | `file_write` | |
| `list_files` | `file_list` | |
| `execute_command` | `shell_exec` | 能力门控 |
| `web_search` | `web_search` | 未改变 |
| `fetch_url` | `web_fetch` | |
| `browser_navigate` | `browser_navigate` | 未改变 |
| `memory_search` | `memory_recall` | |
| `memory_recall` | `memory_recall` | |
| `memory_save` | `memory_store` | |
| `memory_store` | `memory_store` | |
| `sessions_send` | `agent_send` | |
| `agent_message` | `agent_send` | |
| `agents_list` | `agent_list` | |
| `agent_list` | `agent_list` | |

### OpenFang 中的新工具
这些工具没有 OpenClaw 等效项：
e| 工具 | 说明 |
|------|-------------|
| `agent_spawn` | 从智能体内生成新智能体 |
| `agent_kill` | 终止另一智能体 |
| `agent_find` | 按名称、标签或说明搜索智能体 |
| `memory_store` | 在共享内存中存储键值数据 |
| `memory_recall` | 从共享内存中召回键值数据 |
| `task_post` | 将任务发布到共享任务板 |
| `task_claim` | 声明可用任务 |
| `task_complete` | 将任务标记为完成 |
| `task_list` | 按状态列出任务 |
| `event_publish` | 将自定义事件发布到事件总线 |
| `schedule_create` | 创建计划作业 |
| `schedule_list` | 列出计划作业 |
| `schedule_delete` | 删除计划作业 |
| `image_analyze` | 分析图像 |
| `location_get` | 获取位置信息 |

### 令牌配额n| OpenClaw 配置文件 | 对应 OpenFang 工具 |
|------------------|----------------|
| `minimal` | `file_read`, `file_list` |
| `coding` | `file_read`, `file_write`, `file_list`, `shell_exec`, `web_fetch` |
| `messaging` | `agent_send`, `agent_list`, `memory_store`, `memory_recall` |
| `research` | `web_fetch`, `web_search`, `file_read`, `file_write` |
| `full` | 所有10个核心工具 |
---
e## 提供商映射
| OpenClaw 名称 | OpenFang 名称 | API 密钥环境变量 |
|---------------|---------------|-----------------|
| `anthropic` | `anthropic` | `ANTHROPIC_API_KEY` |
| `claude` | `anthropic` | `ANTHROPIC_API_KEY` |
| `openai` | `openai` | `OPENAI_API_KEY` |
| `gpt` | `openai` | `OPENAI_API_KEY` |
| `groq` | `groq` | `GROQ_API_KEY` |
| `ollama` | `ollama` | （无需密钥） |
| `openrouter` | `openrouter` | `OPENROUTER_API_KEY` |
| `deepseek` | `deepseek` | `DEEPSEEK_API_KEY` |
| `together` | `together` | `TOGETHER_API_KEY` |
| `mistral` | `mistral` | `MISTRAL_API_KEY` |
| `fireworks` | `fireworks` | `FIREWORKS_API_KEY` |
| `cohere` | `cohere` | `COHERE_API_KEY` |
| `perplexity` | `perplexity` | `PERPLEXITY_API_KEY` |
| `xai` | `xai` | `XAI_API_KEY` |
| `ai21` | `ai21` | `AI21_API_KEY` |
| `cerebras` | `cerebras` | `CEREBRAS_API_KEY` |
| `sambanova` | `sambanova` | `SAMBANOVA_API_KEY` |
| `hugging face` | `huggingface` | `HUGGINGFACE_API_KEY` |
| `replicate` | `replicate` | `REPLICATE_API_KEY` |

### OpenFang 中的新提供商
| 提供商 | 说明 |
|---------|-------------|
| `vllm` | 自托管 vLLM 推理服务器 |
| `lmstudio` | LM Studio 本地模型 |
---
e## 功能比较
| 功能 | OpenClaw | OpenFang |
|---------|----------|----------|
| **语言** | Node.js / TypeScript | Rust |
| **配置格式** | YAML | TOML |
| **智能体清单** | YAML | TOML |
| **多智能体** | 基本（消息传递） | 一流（spawn、kill、查找、工作流、触发器） |
| **智能体调度** | 手动 | 内置（反应、连续、定期、主动） |
| **内存** | Markdown 文件 | SQLite + KV 存储 + 语义搜索 + 知识图谱 |
| **会话管理** | JSONL 文件 | SQLite，上下文窗口跟踪 |
| **LLM提供商** | ~5 | 20 |
| **模型目录** | 手动配置 | 内置，130+ |
| **安全性** | 基于配置 | 基于能力 |
| **WASM 沙箱** | Docker | Wasmtime 双重计量 |
| **网络** | 无 | OFP 协议 |
| **API** | 基本 REST | REST + WebSocket + SSE |
| **WebChat** | 无 | 嵌入式 |
| **CLI** | 基本 | 14+ 子命令 |
| **技能** | 57，Node.js | 60，多运行时 |
| **测试** | 0 | 1731+，15个crate |
---
e## 令牌配额
| OpenClaw | OpenFang |
|----------|----------|
| 速率限制 | 无 | GCRA + 成本感知令牌桶 |
| 上下文限制 | 无 | 70%触发器 |
| 每智能体预算 | 无 | 每智能体配额 |
| 使用报告 | 无 | 每个响应使用页脚 |
---
e## 安全
| OpenClaw | OpenFang |
|----------|----------|
| 访问控制 | 配置 | 能力 |
| 沙箱 | Docker | WASM |
| 签名 | 无 | Ed25519 |
| 审计 | 无 | Merkle链 |
| 认证 | 无 | API密钥 |
| 会话 | 无 | 多 |
| 隔离 | 无 | 子进程 |
---
e## 总结
本迁移指南涵盖：
e- 快速迁移
- 迁移内容
- 手动步骤
- 配置差异
- 工具名称映射
- 提供商映射
- 功能比较
- 故障排除
e请仔细遵循本指南以确保成功迁移。有关任何问题，请参考[OpenFang文档](https://github.com/RightNow-AI/openfang)或联系支持团队。
