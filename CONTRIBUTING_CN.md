# 向 OpenFang 贡献代码 - 中文版

感谢您对向 OpenFang 贡献代码的兴趣。本指南涵盖了您入门所需的一切，从设置开发环境到提交 Pull Request。

## 目录

- [开发环境](#开发环境)
- [构建和测试](#构建和测试)
- [代码风格](#代码风格)
- [架构概览](#架构概览)
- [如何添加新的智能体模板](#如何添加新的智能体模板)
- [如何添加新的通道适配器](#如何添加新的通道适配器)
- [如何添加新的工具](#如何添加新的工具)
- [Pull Request 流程](#pull-request-流程)
- [行为准则](#行为准则)

---

## 开发环境

### 先决条件

- **Rust 1.75+** (通过 [rustup](https://rustup.rs/) 安装)
- **Git**
- **Python 3.8+** (可选，用于 Python 运行时和技能)
- 支持的 LLM API 密钥 (Anthropic、OpenAI、Groq 等)，用于端到端测试

### 克隆和构建

```bash
# 克隆仓库
git clone https://github.com/RightNow-AI/openfang.git
cd openfang

# 构建项目
cargo build
```

首次构建需要几分钟，因为它需要编译 SQLite (捆绑) 和 Wasmtime。后续构建是增量的。

### 环境变量

要运行需要真实 LLM 的集成测试，请至少设置一个提供商密钥：

```bash
export GROQ_API_KEY="gsk_..."          # 推荐用于快速免费测试
export ANTHROPIC_API_KEY="sk-ant-..."  # 用于 Anthropic 特定测试
```

需要真实 LLM 密钥的测试在没有环境变量时会优雅地跳过。

---

## 构建和测试

### 构建整个工作区

```bash
cargo build --workspace
```

### 运行所有测试

```bash
cargo test --workspace
```

测试套件目前包含 1,744+ 个测试。所有测试在合并前必须通过。

### 运行单个 crate 的测试

```bash
cargo test -p openfang-kernel
cargo test -p openfang-runtime
cargo test -p openfang-memory
```

### 检查 Clippy 警告

```bash
cargo clippy --workspace --all-targets -- -D warnings
```

CI 流水线强制执行零 Clippy 警告。

### 格式化代码

```bash
cargo fmt --all
```

提交前始终运行 `cargo fmt`。CI 将拒绝未格式化的代码。

### 运行 Doctor 检查

构建后，验证您的本地设置：

```bash
cargo run -- doctor
```

---

## 代码风格

### Rust 习惯用法

- 尽可能使用 `?` 运算符
- 优先使用 `Result` 而不是 panic
- 使用 `thiserror` 定义错误类型
- 使用 `anyhow` 进行快速错误传播
- 遵循标准 Rust 命名规范

### 文档

- 所有公共 API 必须记录
- 使用 `///` 用于文档注释
- 为复杂函数包含示例
- 记录不变量和安全性考虑

### 测试

- 为新功能编写测试
- 对错误情况使用单元测试
- 对公共 API 使用集成测试
- 目标是测试中的高覆盖率

---

## 架构概览

### 核心组件

#### openfang-kernel (编排层)

- 管理智能体生命周期、内存、权限
- 处理调度和智能体间通信
- 实现工作流编排

#### openfang-runtime (执行环境)

- 提供智能体执行上下文
- 实现 LLM 驱动程序（多个提供商）
- 管理工具执行和沙箱
- 处理 MCP 和 A2A 协议

#### openfang-api (API 层)

- 通过 REST/WebSocket/SSE 暴露 140+ 端点
- 实现 OpenAI 兼容层
- 处理速率限制和中间件
- 提供仪表板界面

#### openfang-memory (存储层)

- 管理持久存储
- 实现语义内存（向量嵌入）
- 处理知识图谱

#### openfang-channels (集成层)

- 为 40 个消息平台提供适配器
- 处理消息路由和桥接

#### openfang-hands (自主层)

- 实现 7 个专门的自主智能体
- 每个 Hand 都有可配置的行为
- 与知识图谱集成

### 数据流

1. 智能体在 Kernel 中注册
2. Runtime 执行智能体循环
3. 工具在 Sandbox 中运行
4. 内存持久化到存储
5. 通过 Channels 进行通信
6. API 暴露功能

---

## 如何添加新的智能体模板

1. 在 `agents/` 目录下创建新目录
2. 创建 `agent.toml` 文件：

```toml
name = "my-agent"
version = "0.1.0"
description = "我的自定义智能体"
author = "your-name"
module = "builtin:chat"
tags = ["custom", "utility"]

[model]
provider = "openai"
model = "gpt-4"
api_key_env = "OPENAI_API_KEY"
max_tokens = 4096
temperature = 0.7

[capabilities]
tools = ["file_read", "file_write", "web_search"]
network = ["*"]
```

3. 可选：添加 `icon.png` 用于 UI 显示
4. 测试智能体：
```bash
cargo run -- agent create my-agent --template my-agent
```

---

## 如何添加新的通道适配器

1. 在 `crates/openfang-channels/src/` 中创建新文件
2. 实现 `ChannelAdapter` trait：

```rust
use crate::types::{ChannelAdapter, Message, ChannelConfig};
use async_trait::async_trait;

pub struct MyChannel {
    config: ChannelConfig,
}

#[async_trait]
impl ChannelAdapter for MyChannel {
    async fn connect(&mut self) -> Result<(), ChannelError> {
        // 连接逻辑
        Ok(())
    }
    
    async fn send(&self, message: Message) -> Result<(), ChannelError> {
        // 发送逻辑
        Ok(())
    }
    
    async fn receive(&self) -> Result<Message, ChannelError> {
        // 接收逻辑
        todo!()
    }
}
```

3. 在 `lib.rs` 中注册
4. 添加单元测试
5. 更新文档

---

## 如何添加新的工具

1. 在 `crates/openfang-runtime/src/` 中创建新文件
2. 定义工具函数：

```rust
use serde_json::Value;

pub async fn my_tool(args: Value) -> Result<Value, ToolError> {
    // 验证参数
    let input = args.get("input")
        .and_then(|v| v.as_str())
        .ok_or(ToolError::MissingArgument("input"))?;
    
    // 执行工具逻辑
    let result = process_input(input).await?;
    
    // 返回结果
    Ok(json!({
        "result": result,
        "status": "success"
    }))
}
```

3. 在 `tool_runner.rs` 中注册
4. 添加测试
5. 更新能力文档

---

## Pull Request 流程

1. **Fork 仓库** 或创建功能分支
2. **实现更改** 并遵循代码风格
3. **运行检查**:
   ```bash
   cargo fmt --all
   cargo clippy --workspace --all-targets -- -D warnings
   cargo test --workspace
   ```
4. **提交更改** 并附带清晰的消息
5. **推送分支** 到您的 fork
6. **创建 PR** 到主仓库

### PR 审查清单

- [ ] 代码编译无错误
- [ ] 所有测试通过
- [ ] 零 Clippy 警告
- [ ] 代码已格式化
- [ ] 文档已更新
- [ ] 包含测试
- [ ] 提交消息清晰

---

## 行为准则

### 我们的承诺

为了营造一个开放和友好的环境，我们作为贡献者和维护者承诺：让参与我们的项目和社区成为每个人无骚扰的体验，无论年龄、体型、残疾、种族、性别认同和表达、经验水平、国籍、个人外貌、种族、宗教或性取向和性别认同。

### 我们的标准

有助于创建积极环境的行为示例包括：

- 使用友好和包容的语言
- 尊重不同的观点和经验
- 优雅地接受建设性批评
- 专注于对社区最有利的事情
- 对其他社区成员表示同理心

不可接受的行为示例包括：

- 使用性暗示的语言或图像以及不受欢迎的性关注或挑逗
- 恶搞、侮辱性/贬损性评论以及个人或政治攻击
- 公共或私人骚扰
- 未经明确许可发布他人的私人信息，如物理或电子地址
- 在专业环境中可合理认为不适当的其他行为

### 我们的责任

项目维护者负责阐明可接受行为的标准，并应对任何不可接受行为的实例采取适当和公正的纠正措施。

项目维护者有权利和责任删除、编辑或拒绝与本行为准则不一致的评论、提交、代码、wiki 编辑、问题和其它贡献，或暂时或永久禁止任何贡献者从事他们认为不适当、威胁、冒犯或有害的其他行为。

### 范围

本行为准则适用于项目空间和公共空间，当个人代表项目或其社区时。代表项目或社区的示例包括使用官方项目电子邮件地址、通过官方社交媒体帐户发布或在在线或离线活动中担任指定代表。项目维护者可进一步定义和澄清项目的代表。

### 执行

可通过 contact@example.com 联系项目团队报告滥用、骚扰或其他不可接受的行为。所有投诉都将被审查和调查，并将导致被认为对情况必要的适当回应。项目团队有义务对事件报告者保密。具体执行政策的进一步细节可能单独发布。

不真诚遵循或执行行为准则的项目维护者可能面临由项目领导其他成员确定的临时或永久性影响。

### 归属

本行为准则改编自 [贡献者公约](https://www.contributor-covenant.org/)，版本 1.4，可在 https://www.contributor-covenant.org/version/1/4/code-of-conduct.html 获取。

---

## 获取帮助

### 社区

- **GitHub 讨论**: 一般问题和讨论
- **GitHub Issues**: 错误报告和功能请求
- **Discord**: 实时聊天和社区支持

### 文档

- **用户指南**: 在 `docs/user-guide/` 中
- **API 参考**: 在 `docs/api/` 中
- **开发者文档**: 在 `docs/developer/` 中

### 直接支持

- **电子邮件**: support@example.com
- **商务咨询**: business@example.com

---

## 许可证

OpenFang 使用 MIT 和 Apache-2.0 双重许可证。

```
版权 (c) 2024 OpenFang 作者

根据以下任一许可证授权：
- Apache License, Version 2.0
- MIT License
```

---

*本文档是 OpenFang 项目贡献指南的中文版。有关最新信息，请参阅 GitHub 仓库。  文档是 OpenFang 项目技术报告的中文版。更多信息请参阅项目源代码和英文文档。