# OpenFang — 中文使用指南

## 项目简介

OpenFang 是一个开源的智能体操作系统，使用 Rust 语言编写。它编译成单个约 32MB 的二进制文件，提供可全天候 (24/7) 在用户定义的计划上运行的自主智能体。

---

## 核心特性

### 🤖 自主智能体
- 全天候 (24/7) 在计划上运行的智能体
- 无需持续监督
- 可并行执行多个任务

### 🧠 多 LLM 支持
- **27+ 个 LLM 提供商** (OpenAI、Anthropic、Google、Groq 等)
- **123+ 个模型**可用
- 自动回退系统

### 📡 广泛的消息通道
- **40+ 个消息适配器**
- Telegram、Discord、Slack、WhatsApp、Signal
- 电子邮件 (SMTP/IMAP)、SMS
- Matrix、Teams、Webex 等

### 🛠️ 工具与能力
- **60+ 个捆绑技能**
- 7 个自主 "Hand" 智能体
- 多种编程语言支持
- 文件系统、Web 搜索、数据分析

### 🔒 安全第一
- **16 个安全系统**实施
- WASM 双计量沙箱
- 信息流转污点跟踪
- Ed25519 签名清单
- Merkle 哈希链审计追踪

---

## 快速开始

### 先决条件

- **Rust 1.75+** (通过 [rustup](https://rustup.rs/) 安装)
- **Git**
- 支持的 LLM API 密钥 (Anthropic、OpenAI、Groq 等)

### 安装

```bash
# 克隆仓库
git clone https://github.com/RightNow-AI/openfang.git
cd openfang

# 构建项目
cargo build --release

# 运行安装脚本
./scripts/install.sh
```

### 配置

创建配置文件：`~/.openfang/config.toml`

```toml
[api]
host = "127.0.0.1"
port = 4200

[llm]
provider = "groq"
model = "llama-3.3-70b-versatile"
api_key_env = "GROQ_API_KEY"

[memory]
database = "~/.openfang/memory.db"

[security]
sandbox_enabled = true
audit_logging = true
```

### 环境变量

```bash
export GROQ_API_KEY="gsk_..."
export ANTHROPIC_API_KEY="sk-ant-..."
export OPENAI_API_KEY="sk-..."
```

---

## 基本用法

### 启动守护进程

```bash
openfang start
```

### 创建智能体

```bash
openfang agent create coder --template coding
```

### 发送消息

```bash
openfang message --agent coder "请帮我写一个快速排序"
```

### 列出智能体

```bash
openfang agent list
```

---

## 开发指南

### 构建和测试

```bash
# 构建整个工作区
cargo build --workspace

# 运行所有测试
cargo test --workspace

# 检查 Clippy 警告
cargo clippy --workspace --all-targets -- -D warnings

# 格式化代码
cargo fmt --all
```

### 添加新智能体模板

1. 在 `agents/` 目录下创建新目录
2. 添加 `agent.toml` 配置文件
3. 定义模型配置、能力、工具权限

### 添加新工具

1. 在 `crates/openfang-runtime/src/` 中实现工具
2. 在 `tool_runner.rs` 中注册
3. 添加测试

---

## 架构概览

### 核心组件

- **openfang-kernel** — 编排层，管理智能体生命周期、内存、权限、调度
- **openfang-runtime** — 执行环境，包含56个源文件
- **openfang-api** — 140+ REST/WebSocket/SSE 端点
- **openfang-memory** — 持久化存储、向量内存
- **openfang-channels** — 40个消息适配器
- **openfang-skills** — 60+ 捆绑技能
- **openfang-hands** — 7个自主 Hands
- **openfang-types** — 核心类型、污点跟踪
- **openfang-extensions** — MCP模板、OAuth2
- **openfang-wire** — OFP P2P协议
- **openfang-cli** — 命令行界面
- **openfang-desktop** — Tauri桌面应用
- **openfang-migrate** — 迁移引擎

### 技术栈

- **异步运行时**: tokio (全功能)
- **HTTP服务器**: axum, tower, tower-http
- **WebSocket**: tokio-tungstenite
- **数据库**: rusqlite (捆绑SQLite)
- **序列化**: serde, serde_json, toml
- **WASM**: wasmtime
- **安全**: sha2, hmac, ed25519-dalek, zeroize
- **速率限制**: governor
- **CLI**: clap, ratatui
- **邮件**: lettre, imap

---

## 许可证

OpenFang 使用 MIT 和 Apache-2.0 双重许可证。

```
Copyright (c) 2024 OpenFang Authors

Licensed under either of:
- Apache License, Version 2.0
- MIT License
```

---

## 社区与支持

- GitHub: https://github.com/RightNow-AI/openfang
- 问题报告: https://github.com/RightNow-AI/openfang/issues
- 文档: 见 `docs/` 目录

---

*本文档是 OpenFang 项目的中文版快速入门指南。更多信息请参阅完整的英文文档。