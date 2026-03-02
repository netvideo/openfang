# OpenFang 技术报告

## 1. 项目概述

OpenFang 是一个开源的智能体操作系统，使用 Rust 语言编写，由 14 个 crate 组成，约 137,000 行代码。项目编译成单个约 32MB 的二进制文件，提供可全天候 (24/7) 在用户定义的计划上运行的自主智能体。

项目采用现代 Rust 工具链（Edition 2021，最低要求 Rust 1.75），使用 MIT/Apache-2.0 双许可证模式。工作区配置使用 resolver 版本 2，确保跨 14 个 crate 的依赖管理。

## 2. 架构概述

### 2.1 核心组件

OpenFang 架构采用模块化设计，包含 14 个专门的 crate，每个负责不同功能：

**openfang-kernel** 作为编排层，管理智能体生命周期、内存系统、权限、调度以及智能体间通信。关键模块包括：

- kernel.rs — 核心内核实现（OpenFangKernel、DeliveryTracker）
- scheduler.rs — 用于 24/7 智能体操作的任务调度
- workflow.rs — 工作流编排
- metering.rs — 使用跟踪和成本管理
- capabilities.rs — RBAC 和权限管理
- auth.rs — 认证和授权
- event_bus.rs — 智能体间通信
- registry.rs — 智能体和资源注册表
- cron.rs — 基于 Cron 的调度
- triggers.rs — 事件驱动自动化
- supervisor.rs — 智能体监督和健康状况监控
- background.rs — 后台任务处理
- pairing.rs — OFP 协议的设备配对
- heartbeat.rs — 健康状况监控
- wizard.rs — 配置向导
- config.rs / config_reload.rs — 配置管理
- whatsapp_gateway.rs — WhatsApp 网关集成
- approval.rs — 审批工作流
- auto_reply.rs — 自动回复处理

**openfang-runtime** 为智能体提供执行环境，包含 56 个源文件：

- agent_loop.rs — 核心智能体执行循环
- llm_driver.rs — LLM 集成层
- drivers/ — 多个 LLM 提供商实现（anthropic.rs、openai.rs、gemini.rs、groq.rs、copilot.rs、claude_code.rs、fallback.rs）
- tool_runner.rs — 工具执行编排
- sandbox.rs / workspace_sandbox.rs / subprocess_sandbox.rs / docker_sandbox.rs — 隔离环境
- web_search.rs / web_fetch.rs — Web 功能
- python_runtime.rs — Python 脚本执行
- embedding.rs — 向量嵌入生成
- mcp.rs / mcp_server.rs — 模型上下文协议支持
- a2a.rs — 智能体间通信
- browser.rs — 浏览器自动化
- image_gen.rs — 图像生成
- tts.rs — 文本转语音
- context_budget.rs / context_overflow.rs — 令牌管理
- retry.rs — 重试逻辑
- hooks.rs — 扩展钩子
- audit.rs — 审计日志

**openfang-api** 暴露 140+ REST/WebSocket/SSE 端点：

- server.rs — 基于 Axum 的 HTTP 服务器
- routes.rs — API 路由定义
- ws.rs — WebSocket 处理
- webchat.rs — Web 聊天界面
- openai_compat.rs — OpenAI API 兼容层
- rate_limiter.rs — API 速率限制
- middleware.rs — HTTP 中间件
- stream_chunker.rs / stream_dedup.rs — 流处理
- channel_bridge.rs — 通道集成
- types.rs — API 类型

**openfang-memory** 处理持久化存储：

- session.rs — 会话管理
- semantic.rs — 带向量嵌入的语义内存
- knowledge.rs — 知识图谱存储
- structured.rs — 结构化数据存储
- consolidation.rs — 内存整合
- migration.rs — 数据迁移
- usage.rs — 使用跟踪
- substrate.rs — 底层集成
- lib.rs — 核心内存接口

**openfang-channels** 为不同平台提供 40 个消息适配器：

- telegram.rs, slack.rs, discord.rs, whatsapp.rs
- matrix.rs, signal.rs, element.rs
- email.rs, teams.rs, webex.rs
- linkedin.rs, twitter.rs (X), mastodon.rs, bluesky.rs
- reddit.rs, twitch.rs, youtube.rs
- sms.rs (twilio), voice.rs
- webhook.rs — 通用 webhook 支持
- formatter.rs — 消息格式化
- router.rs — 通道路由
- bridge.rs — 协议间桥接

**openfang-skills** 捆绑 60+ 可重用技能供智能体使用。

**openfang-hands** 包含 7 个自主 "Hand" 智能体：

- researcher/ — 具有源验证功能的深度研究智能体
- browser/ — Web 自动化
- twitter/ — 社交媒体管理
- clip/ — YouTube/视频处理
- lead/ — 潜在客户生成
- collector/ — OSINT 情报收集
- predictor/ — 预测

每个 Hand 都有可配置的设置（research_depth、output_style、source_verification 等）并与知识图谱和内存系统集成。

**openfang-types** 定义核心类型、信息流安全的污点跟踪以及 Ed25519 清单签名。

**openfang-extensions** 提供 25 个 MCP（模型上下文协议）模板、凭证库和 OAuth2 支持。

**openfang-wire** 实现 OFP（OpenFang 协议）P2P 通信。

**openfang-cli** — 命令行界面。

**openfang-desktop** — 使用 Tauri 2.0 构建的桌面应用程序。

**openfang-migrate** — 用于数据转换的迁移引擎。

### 2.2 技术栈

项目利用现代 Rust 生态系统库：

- **异步运行时**: tokio 全功能，tokio-stream
- **HTTP 服务器**: axum, tower, tower-http
- **WebSocket**: tokio-tungstenite
- **数据库**: rusqlite (捆绑 SQLite)
- **序列化**: serde, serde_json, toml, rmp-serde
- **WASM**: wasmtime 用于沙箱化
- **安全**: sha2, hmac, ed25519-dalek, zeroize, aes-gcm, argon2
- **速率限制**: governor
- **CLI**: clap, ratatui
- **电子邮件**: lettre, imap
- **错误处理**: thiserror, anyhow

构建优化: 启用 LTO，单 codegen 单元，剥离二进制文件，opt-level=3。

## 3. 智能体系统

### 3.1 智能体模板

OpenFang 在 `agents/` 目录中附带 32 个预构建的智能体模板：

assistant, analyst, architect, coder, customer-support, data-scientist, debugger, devops-lead, doc-writer, email-assistant, health-tracker, hello-world, home-automation, legal-assistant, meeting-assistant, ops, orchestrator, personal-finance, planner, recruiter, researcher, sales-assistant, security-auditor, social-media, test-engineer, translator, travel-planner, tutor, writer, code-reviewer。

每个智能体都以 TOML 格式定义，包含：

- name, version, description, author
- module (builtin:chat 等)
- 用于分类的 tags
- 模型配置 (provider, model, api_key_env, max_tokens, temperature)
- 用于冗余的 fallback_models
- resources (max_llm_tokens_per_hour, max_concurrent_tools)
- capabilities (tools, network, memory, shell 权限)

### 3.2 智能体配置示例

Coder 智能体展示了配置模式：

```toml
name = "coder"
module = "builtin:chat"
[model]
provider = "gemini"
model = "gemini-2.5-flash"
api_key_env = "GEMINI_API_KEY"
max_tokens = 8192
temperature = 0.3
[[fallback_models]]
provider = "groq"
model = "llama-3.3-70b-versatile"
[resources]
max_llm_tokens_per_hour = 200000
max_concurrent_tools = 10
[capabilities]
tools = ["file_read", "file_write", "file_list", "shell_exec", "web_search", "web_fetch", "memory_store", "memory_recall"]
network = ["*"]
memory_read = ["*"]
memory_write = ["self.*"]
shell = ["cargo *", "rustc *", "git *", "npm *", "python *"]
```

### 3.3 Hands (自主智能体)

Hands 是能够实现独立操作的自主智能体。Researcher Hand 体现了架构：

- 按计划连续运行
- 使用 18 个工具：shell_exec, file_read, file_write, file_list, web_fetch, web_search, memory_store, memory_recall, schedule_create/list/delete, knowledge_add_entity/relation/query, event_publish
- 实现 7 阶段研究方法：平台检测、问题分析、搜索策略、信息收集、交叉引用、事实核查、报告生成
- 可配置设置：research_depth, output_style, citation_style, source_verification, max_sources, auto_follow_up, language
- 仪表板指标集成，用于跟踪已解决的问题、引用的来源、生成的报告

## 4. LLM 集成

### 4.1 支持的提供商

OpenFang 支持 27 个 LLM 提供商，有 123+ 个模型：

- Anthropic (Claude 模型)
- Google Gemini
- OpenAI (GPT 模型)
- Groq
- DeepSeek
- OpenRouter
- Together AI
- Mistral
- Cohere
- AI21
- Meta (通过各个提供商的 Llama)
- 等等

### 4.2 驱动程序架构

运行时实现了与提供商无关的驱动程序系统：

- llm_driver.rs — 核心抽象
- drivers/mod.rs — 提供商注册表
- drivers/anthropic.rs — Anthropic Claude 集成
- drivers/openai.rs — OpenAI GPT 集成
- drivers/gemini.rs — Google Gemini 集成
- drivers/groq.rs — Groq 集成
- drivers/copilot.rs — GitHub Copilot
- drivers/claude_code.rs — Claude Code 特定功能
- drivers/fallback.rs — 回退链逻辑

功能包括：

- 提供商之间的自动回退
- 提供商健康监控
- 每个提供商的速率限制
- 令牌预算管理
- 上下文溢出处理
- 带指数退避的重试

## 5. 安全系统

OpenFang 实现了 16 个安全系统：

1. **WASM 双计量沙箱** — 资源受限的执行环境
2. **Merkle 哈希链审计追踪** — 不可变的审计日志记录
3. **信息流污点跟踪** — 数据血缘和污染跟踪
4. **Ed25519 签名清单** — 代码真实性验证
5. **SSRF 防护** — 服务器端请求伪造防护
6. **密钥归零** — 安全内存清除
7. **OFP 双向认证** — P2P 协议安全
8. **能力门控** — RBAC 实施
9. **安全头部** — HTTP 安全头部
10. **提示注入扫描器** — 恶意输入检测
11. **循环守卫** — 无限循环防护
12. **会话修复** — 损坏的会话恢复
13. **路径遍历防护** — 文件系统访问控制
14. **GCRA 速率限制器** — 通用单元速率算法限制
15. **内容安全策略** — XSS 和注入防护
16. **命令沙箱化** — Shell 命令限制

## 6. API 和接口

### 6.1 REST API

140+ 个端点涵盖：

- 智能体管理 (CRUD、消息发送)
- 预算和计量
- 网络状态和对等节点
- A2A (智能体对智能体) 通信
- 通道管理
- 内存和知识图谱
- 技能和扩展
- 配置
- 健康和诊断

### 6.2 WebSocket 和 SSE

实时通信用于：

- 智能体流式响应
- 事件通知
- 实时仪表板更新

### 6.3 OpenAI 兼容性

OpenFang 提供 OpenAI 兼容的 API 层，支持与为 OpenAI API 设计的现有工具和工作流集成。

### 6.4 SDK

- **JavaScript SDK** — 用于 Web 集成
- **Python SDK** — 用于 Python 应用程序和脚本

### 6.5 CLI

使用 clap 和 ratatui 构建的命令行界面，用于终端交互。

### 6.6 桌面应用程序

openfang-desktop 中基于 Tauri 2.0 的桌面应用程序。

## 7. 通道和集成

### 7.1 消息平台

40 个通道适配器支持：

- Telegram、Discord、Slack
- WhatsApp、Signal
- Matrix、Element
- Teams、Webex
- 电子邮件 (SMTP/IMAP)
- SMS (Twilio)
- 以及 25+ 其他

### 7.2 社交媒体

- Twitter/X、Mastodon、Bluesky
- LinkedIn、Reddit
- Twitch、YouTube

### 7.3 自定义集成

- Webhook 支持自定义集成
- 协议翻译的桥接能力

## 8. 开发实践

### 8.1 代码质量

- **测试**: 工作区中 1,767+ 个测试
- **Linting**: 强制执行零 Clippy 警告
- **格式化**: 提交前需要 cargo fmt
- **构建**: cargo build --workspace --lib 用于编译验证
- **集成测试**: 新端点需要实时测试

### 8.2 配置

- 默认配置位置: ~/.openfang/config.toml
- 默认 API 端点: http://127.0.0.1:4200
- 基于环境的 API 密钥配置

### 8.3 开发工作流

1. 实现功能
2. cargo build --workspace --lib
3. cargo test --workspace
4. cargo clippy --workspace --all-targets -- -D warnings
5. 运行实时集成测试
6. 提交 PR

## 9. 关键特性总结

- **智能体操作系统**: 按计划 (24/7) 运行的全天候智能体
- **多提供商 LLM**: 27 个提供商，123+ 个模型，自动回退
- **40 个通道适配器**: 全面的消息平台支持
- **7 个自主 Hands**: 预构建的专用智能体
- **60+ 捆绑技能**: 可重用的智能体能力
- **向量内存**: 语义搜索和知识图谱
- **WASM 沙箱化**: 安全工具执行
- **P2P 协议**: 用于分布式通信的 OFP
- **桌面/应用**: 基于 Tauri 的桌面应用
- **安全第一**: 实施 16 个安全系统

## 10. 项目结构

```
openfang/
├── agents/                  # 32 个智能体模板
├── crates/
│   ├── openfang-api/       # REST/WebSocket API (12 个文件)
│   ├── openfang-channels/  # 40 个消息适配器 (47 个文件)
│   ├── openfang-cli/       # CLI 工具
│   ├── openfang-desktop/  # Tauri 桌面应用
│   ├── openfang-extensions/# MCP 模板，OAuth
│   ├── openfang-hands/    # 7 个自主 Hands
│   ├── openfang-kernel/   # 核心编排 (22 个文件)
│   ├── openfang-memory/   # 存储和内存 (9 个文件)
│   ├── openfang-migrate/ # 迁移引擎
│   ├── openfang-runtime/  # 智能体执行 (56 个文件)
│   ├── openfang-skills/   # 60+ 捆绑技能
│   ├── openfang-types/    # 核心类型
│   └── openfang-wire/     # P2P 协议
├── packages/
│   └── whatsapp-gateway/ # WhatsApp 集成
├── scripts/               # 安装脚本
├── sdk/
│   ├── javascript/        # JS SDK
│   └── python/            # Python SDK
└── docs/                 # 文档
```

---

*本文档是 OpenFang 项目的技术报告中文版。更多信息请参阅项目源代码和英文文档。