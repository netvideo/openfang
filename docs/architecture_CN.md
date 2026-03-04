# OpenFang 系统架构

本文档描述 OpenFang 的内部架构，这是一个用 Rust 构建的开源智能体操作系统。涵盖 crate 结构、内核启动序列、智能体生命周期、内存基板、LLM 驱动抽象、基于能力的安全模型、OFP 线协议、安全加固栈、通道和技能系统，以及智能体稳定性子系统。

## 目录

- [Crate 结构](#crate-结构)
- [内核启动序列](#内核启动序列)
- [智能体生命周期](#智能体生命周期)
- [智能体循环稳定性](#智能体循环稳定性)
- [内存基板](#内存基板)
- [LLM 驱动抽象](#llm-驱动抽象)
- [模型目录](#模型目录)
- [基于能力的安全模型](#基于能力的安全模型)
- [安全加固](#安全加固)
- [通道系统](#通道系统)
- [技能系统](#技能系统)
- [MCP 和 A2A 协议](#mcp-和-a2a-协议)
- [线协议 (OFP)](#线协议-ofp)
- [桌面应用程序](#桌面应用程序)
- [子系统图](#子系统图)

---

## Crate 结构

OpenFang 组织为一个包含 14 个 crate 的 Cargo 工作区（13 个代码 crate + xtask）。依赖关系向下流动（下层 crate 不依赖于上层的任何内容）。

```
openfang-cli            CLI 界面、守护进程自动检测、MCP 服务器
    |
openfang-desktop        Tauri 2.0 桌面应用（WebView + 系统托盘）
    |
openfang-api            REST/WS/SSE API 服务器（Axum 0.8），76 个端点
    |
openfang-kernel         内核：组装所有子系统、工作流引擎、RBAC、计量
    |
    +-- openfang-runtime    智能体循环、3 个 LLM 驱动、23 个工具、WASM 沙箱、MCP、A2A
    +-- openfang-channels   40 个通道适配器、桥接、格式化器、速率限制器
    +-- openfang-wire       带 HMAC-SHA256 认证的 OFP 点对点网络
    +-- openfang-migrate    迁移引擎（OpenClaw YAML->TOML）
    +-- openfang-skills     60 个内置技能、FangHub 市场、ClawHub 客户端
    |
openfang-memory         SQLite 内存基板、会话、语义搜索、使用跟踪
    |
openfang-types          共享类型：智能体、能力、事件、内存、消息、工具、配置、
                        污点、清单签名、模型目录、MCP/A2A 配置、Web 配置
```

### Crate 职责

| Crate | 责任 | 关键依赖 |
|-------|------|----------|
| `openfang-types` | 所有 crate 使用的共享类型和常量。无业务逻辑。 | 无 |
| `openfang-memory` | SQLite 基板，内存子系统。会话存储、语义搜索、使用跟踪、token 统计。 | `openfang-types` |
| `openfang-wire` | OFP（OpenFang 协议）网络。带 HMAC-SHA256 认证的点对点消息。 | `openfang-types` |
| `openfang-runtime` | 智能体执行引擎。3 个 LLM 驱动、23 个工具、WASM 沙箱、MCP 客户端、A2A 客户端。 | `openfang-types`, `openfang-memory` |
| `openfang-channels` | 40 个通道适配器。桥接、格式化、速率限制。 | `openfang-types`, `openfang-memory`, `openfang-runtime` |
| `openfang-skills` | 60 个内置技能。FangHub/ClawHub 市场客户端。 | `openfang-types`, `openfang-runtime` |
| `openfang-migrate` | 迁移引擎。OpenClaw YAML 到 OpenFang TOML。 | `openfang-types`, `openfang-memory` |
| `openfang-kernel` | 内核。组装所有子系统。工作流引擎。RBAC。计量。 | 所有其他 crate |
| `openfang-api` | REST/WS/SSE API 服务器。76 个端点。 | `openfang-kernel` |
| `openfang-desktop` | Tauri 2.0 桌面应用。WebView + 系统托盘。 | `openfang-api` |
| `openfang-cli` | CLI 界面。守护进程自动检测。MCP 服务器。 | `openfang-api` |

## 内核启动序列

当 OpenFang 启动时，内核经历一系列阶段来初始化所有子系统。

```
Phase 1: 配置加载
- 读取 ~/.openfang/config.toml
- 使用 serde 反序列化到 Config 结构
- 验证（所有必填字段存在，网络地址可解析）
- 如果验证失败则应用默认补丁并记录警告

Phase 2: 内存基板初始化
- 初始化 SQLite 连接池
- 加载模式迁移
- 初始化嵌入模型（如果配置了语义搜索）
- 预热连接池

Phase 3: 智能体运行时初始化
- 注册 3 个 LLM 驱动（Anthropic、OpenAI、Ollama）
- 注册 23 个工具
- 初始化 WASM 沙箱（如果启用）
- 加载技能清单
- 初始化 MCP 客户端
- 初始化 A2A 客户端

Phase 4: 通道适配器初始化
- 初始化每个已配置通道的适配器
- 设置桥接
- 启动速率限制器
- 启动格式化器

Phase 5: 工作流引擎初始化
- 加载工作流定义
- 初始化触发器
- 启动调度器

Phase 6: API 服务器启动
- 绑定到配置的地址
- 启动 HTTP 服务器
- 启动 WebSocket 服务器
- 启动 SSE 服务器

Phase 7: 守护进程模式（如果启用）
- Fork 到后台
- 写入 PID 文件
- 设置信号处理程序
```

## 智能体生命周期

智能体经历一个定义明确的生命周期，从生成到终止。

```
1. 已定义 (DEFINED)
   - 智能体清单已加载
   - 配置已验证
   - 资源已分配
   - 转换: generate() -> PENDING

2. 待处理 (PENDING)
   - 等待调度
   - 排队等待执行
   - 转换: schedule() -> RUNNING

3. 运行中 (RUNNING)
   - 智能体循环已启动
   - 处理消息
   - 执行工具调用
   - 转换: pause() -> PAUSED
   - 转换: terminate() -> TERMINATING

4. 已暂停 (PAUSED)
   - 智能体循环已暂停
   - 状态已保留
   - 转换: resume() -> RUNNING
   - 转换: terminate() -> TERMINATING

5. 终止中 (TERMINATING)
   - 正在清理资源
   - 保存最终状态
   - 写入内存
   - 转换: cleanup() -> TERMINATED

6. 已终止 (TERMINATED)
   - 智能体已停止
   - 资源已释放
   - 最终状态已持久化
   - 终端状态

7. 错误 (ERROR)
   - 生命周期中发生错误
   - 可以从某些错误状态恢复
   - 转换: recover() -> PENDING
   - 转换: terminate() -> TERMINATING
```

## 智能体循环稳定性

智能体循环包括多个稳定性机制，以防止失控执行。

```
1. Token 预算
   - 每个智能体有最大输入/输出 token 限制
   - 达到限制时循环终止
   - 可配置: input_token_limit, output_token_limit

2. 迭代限制
   - 最大工具调用/响应迭代次数
   - 防止无限循环
   - 可配置: max_iterations

3. 时间限制
   - 智能体执行的最长时间
   - 超时后硬停止
   - 可配置: max_execution_time

4. 工具配额
   - 每种工具类型的使用限制
   - 防止工具滥用
   - 可配置: tool_quotas

5. 内存限制
   - 智能体内存使用的上限
   - 防止内存泄漏
   - 可配置: memory_limit

6. 回退机制
   - 达到限制时的优雅降级
   - 将状态保存到内存
   - 允许稍后恢复
```

## 内存基板

OpenFang 使用 SQLite 作为内存基板，提供持久化、结构化的存储。

```
架构:
- SQLite 数据库文件: ~/.openfang/data/openfang.db
- 连接池用于并发访问
- WAL 模式用于高性能
- 自动迁移

表:
1. sessions
   - id: UUID 主键
   - agent_id: 智能体 UUID
   - created_at: 时间戳
   - updated_at: 时间戳
   - metadata: JSON 对象

2. messages
   - id: UUID 主键
   - session_id: 会话 UUID
   - role: 枚举 (user, assistant, system)
   - content: 文本
   - tokens_in: 整数
   - tokens_out: 整数
   - created_at: 时间戳

3. memories
   - id: UUID 主键
   - agent_id: 智能体 UUID
   - key: 字符串
   - value: 文本
   - confidence: 浮点数 (0.0-1.0)
   - created_at: 时间戳
   - updated_at: 时间戳

4. usage_stats
   - id: UUID 主键
   - agent_id: 智能体 UUID
   - provider: 字符串
   - model: 字符串
   - tokens_in: 整数
   - tokens_out: 整数
   - cost: 浮点数
   - timestamp: 时间戳

语义搜索 (可选):
- 向量嵌入存储
- 余弦相似度搜索
- 可配置的嵌入模型
```

## LLM 驱动抽象

OpenFang 通过通用接口支持多个 LLM 提供商。

```
驱动架构:
- 通用 trait: LLMDriver
- 特定实现: AnthropicDriver, OpenAIDriver, OllamaDriver
- 驱动注册表用于查找
- 每个驱动处理提供商特定的:
  - 请求格式
  - 响应解析
  - 认证
  - 错误处理
  - 工具调用转换

通用接口:
trait LLMDriver {
    fn generate(&self, request: GenerationRequest) -> Result<GenerationResponse, DriverError>;
    fn stream(&self, request: GenerationRequest) -> Result<Stream<Token>, DriverError>;
    fn validate_config(&self, config: &ModelConfig) -> Result<(), ConfigError>;
}

驱动注册:
- 启动时注册驱动
- 按提供商名称查找
- 支持自定义驱动
```

## 模型目录

集中式模型定义和别名系统。

```
目的:
- 标准化模型标识符
- 提供商之间的抽象
- 版本管理
- 能力发现
- 成本估算

结构:
- YAML 文件: models/catalog.yaml
- 每个条目定义:
  - id: 唯一标识符
  - name: 人类可读的名称
  - provider: 提供商 ID
  - capabilities: 能力列表 (tools, vision, json)
  - cost: 每 1K token 的输入/输出成本
  - aliases: 替代名称列表
- 自动加载和验证
- 运行时访问

别名系统:
- 将通用名称映射到具体模型
- 示例: "gpt-4" -> "gpt-4-0125-preview"
- 允许提供商特定的别名
- 用户可配置的别名覆盖
```

## 基于能力的安全模型

细粒度、显式的权限系统。

```
原则:
- 默认拒绝
- 显式优于隐式
- 最小权限
- 能力必须被授予，不能假设

能力类型:
1. 工具能力
   - 每个工具的显式权限
   - 参数限制
   - 速率限制

2. 内存能力
   - 读取范围 (哪些键)
   - 写入范围 (哪些键)
   - 置信度阈值

3. 网络能力
   - 出站连接
   - 域限制
   - 协议限制

4. 文件能力
   - 读/写/执行
   - 路径限制
   - 大小限制

在清单中声明:
[capabilities]
tools = ["file_read", "file_list"]
tool_params = { file_read = { max_size = 1000000 } }
memory_read = ["user.*", "session.*"]
memory_write = ["self.*"]
network = ["https"]
network_domains = ["api.github.com"]

在运行时强制执行:
- 内核在每次工具调用前检查能力
- 内存访问根据能力进行过滤
- 网络请求验证域白名单
- 违反能力会导致错误，可能终止智能体
```

## 安全加固

纵深防御安全架构。

```
层 1: 输入验证
- 严格的模式验证
- 类型安全（Rust 的类型系统）
- 边界检查
- 消毒处理

层 2: 认证
- 用户认证（密码、密钥）
- 智能体认证（令牌、签名）
- API 密钥验证
- MCP 服务器认证

层 3: 授权
- 基于角色的访问控制（RBAC）
- 能力系统
- 资源级权限
- 审计日志

层 4: 隔离
- WASM 沙箱
- 进程隔离
- 网络命名空间
- 文件系统命名空间

层 5: 加密
- 传输层 TLS
- 静态数据加密
- 密钥管理
- 安全随机数生成

层 6: 监控
- 日志记录
- 审计追踪
- 异常检测
- 入侵检测

纵深防御:
- 每层都提供备份保护
- 多层的组合提供强大的安全性
- 一层失败不会危及整个系统
```

## 通道系统

用于多平台通信的 40 个通道适配器。

```
架构:
- 每个通道的适配器 trait
- 通用接口用于消息收发
- 桥接系统连接通道
- 格式化引擎用于内容转换
- 速率限制器防止滥用

通用接口:
trait ChannelAdapter {
    fn send(&self, message: Message) -> Result<(), ChannelError>;
    fn receive(&self) -> Result<Stream<Message>, ChannelError>;
    fn setup(&self, config: &ChannelConfig) -> Result<(), SetupError>;
}

支持的通道:
- 消息平台: Telegram, Discord, Slack, WhatsApp, LINE, Signal, WeChat
- 社交媒体: Mastodon, Twitter/X, LinkedIn, Facebook, Instagram
- 协作工具: Microsoft Teams, Zoom, Google Meet, Jitsi
- 邮件: SMTP, IMAP, SendGrid, Mailgun
- Web: WebSocket, SSE, Webhook, HTTP/REST
- 语音: Twilio, Vonage, Amazon Polly, Google Speech
- 游戏: Steam, Discord, Twitch, OBS
- 自定义: WebSocket, gRPC, MQTT, AMQP

桥接:
- 连接多个通道
- 跨平台消息转发
- 内容转换
- 身份映射
```

## 技能系统

用于扩展智能体能力的 60 个内置技能。

```
架构:
- 技能 trait 定义接口
- 技能清单用于元数据
- 技能注册表用于发现
- 技能加载器用于安装
- 技能市场 (FangHub) 用于分发

技能 trait:
trait Skill {
    fn execute(&self, input: SkillInput) -> Result<SkillOutput, SkillError>;
    fn metadata(&self) -> SkillMetadata;
}

技能清单:
[skill]
name = "github"
version = "1.0.0"
description = "GitHub 仓库操作"
author = "OpenFang Team"
type = "builtin"

[capabilities]
tools = ["github_repo_list", "github_issue_create", "github_pr_merge"]

技能类型:
- 内置: 随 OpenFang 一起提供
- 自定义: 用户开发的技能
- 市场: 来自 FangHub/ClawHub
- WASM: WebAssembly 打包的技能
- Python: Python 编写的技能
- 提示: 纯提示技能

内置技能类别:
- 开发: Git, Docker, Kubernetes, GitHub, GitLab
- 运维: AWS, Azure, GCP, Terraform, Ansible
- 安全: 漏洞扫描、渗透测试、合规检查
- 数据: SQL, NoSQL, 数据清洗、ETL
- 通信: 邮件、Slack、Discord、Telegram
- 媒体: 图像处理、视频编辑、音频转换
- 办公: PDF、文档、电子表格、演示文稿

技能市场:
- FangHub: OpenFang 官方市场
- ClawHub: 社区市场
- 私有注册表: 企业内部使用
```

## MCP 和 A2A 协议

用于外部工具连接和智能体间通信的协议。

```
MCP（模型上下文协议）:
- 标准化外部工具集成
- 服务器-客户端架构
- JSON-RPC 2.0 传输
- 能力协商

MCP 服务器:
- 向客户端暴露工具
- 处理工具调用
- 管理资源访问
- 提供提示模板

MCP 客户端（在 OpenFang 中）:
- 连接到 MCP 服务器
- 发现可用工具
- 执行工具调用
- 管理会话状态

配置:
[[mcp_servers]]
name = "filesystem"
command = "npx"
args = ["-y", "@modelcontextprotocol/server-filesystem", "/path/to/allowed/dir"]

A2A（智能体到智能体协议）:
- 智能体间通信标准
- 点对点消息传递
- 能力发现和广告
- 任务委托和协作

A2A 参与者:
- 客户端智能体：发起请求
- 远程智能体：处理请求
- 任务：工作单元
- 工件：可交付成果

A2A 工作流:
1. 能力发现：智能体广告能力
2. 任务发送：客户端发送任务
3. 任务处理：远程智能体处理
4. 工件返回：结果交付
5. 状态更新：进度通信

协议栈:
- 传输：HTTP/2，WebSocket
- 序列化：JSON，Protocol Buffers
- 安全：TLS 1.3，OAuth 2.0
- 发现：DNS-SD，mDNS
```

## 线协议 (OFP)

OpenFang 点对点网络协议。

```
概述:
- 自定义线协议
- 点对点消息传递
- HMAC-SHA256 认证
- 加密传输

协议结构:
```
[Header]
- Magic: 4 bytes (0x4F465031 = "OFP1")
- Version: 1 byte
- Message Type: 1 byte
- Flags: 2 bytes
- Payload Length: 4 bytes
- Timestamp: 8 bytes
- Nonce: 8 bytes

[Authentication]
- HMAC-SHA256: 32 bytes

[Payload]
- Encrypted message data
```

消息类型:
- 0x01: HELLO - 初始握手
- 0x02: HELLO_ACK - 握手确认
- 0x03: PING - 连接检查
- 0x04: PONG - 连接响应
- 0x05: MESSAGE - 应用消息
- 0x06: ACK - 消息确认
- 0x07: ERROR - 错误报告
- 0x08: BYE - 连接关闭

握手过程:
1. 发起者发送 HELLO（带支持的版本和密钥指纹）
2. 响应者验证并发送 HELLO_ACK（带选定的版本和密钥指纹）
3. 双方派生会话密钥
4. 后续消息使用会话密钥加密

加密:
- 密钥交换: X25519
- 对称加密: AES-256-GCM
- 认证: HMAC-SHA256
- 前向保密: 每次握手生成临时密钥

网络安全:
- 防止重放攻击（时间戳和 nonce 检查）
- 消息认证（HMAC 验证）
- 序列号防止消息丢失/重复
- 连接超时和心跳检测
```

## 桌面应用程序

Tauri 2.0 原生桌面应用程序。

```
概述:
- 使用 Tauri 2.0 构建
- WebView 前端
- 系统托盘集成
- 原生通知
- 自动更新

架构:
```
[前端]
- 框架: React/Vue/Svelte (可配置)
- UI 组件: 自定义设计系统
- 状态管理: Redux/Vuex/Pinia
- API 客户端: 生成的 HTTP 客户端

[Tauri 后端]
- Rust 核心
- 命令处理程序
- 事件系统
- 系统托盘管理
- 窗口管理
- 通知管理

[系统托盘]
- 图标: 动态状态指示器
- 菜单: 快速操作、状态、退出
- 气球提示: 重要通知
- 左键/右键单击处理

[自动更新]
- 更新服务器: 可配置端点
- 签名验证: Ed25519 签名
- 后台下载
- 无缝安装
- 回滚支持
```

功能:
- 完整的 WebChat UI
- 系统托盘快速访问
- 原生通知
- 键盘快捷键
- 多窗口支持
- 离线模式
- 主题（浅色/深色/系统）
- 可访问性支持

构建:
```bash
# 开发
cargo tauri dev

# 构建
cargo tauri build

# 构建特定平台
cargo tauri build --target x86_64-pc-windows-msvc
cargo tauri build --target x86_64-apple-darwin
cargo tauri build --target x86_64-unknown-linux-gnu
```

配置:
```toml
[desktop]
window_width = 1200
window_height = 800
min_window_width = 800
min_window_height = 600
enable_tray = true
start_minimized = false
auto_launch = false
theme = "system"
```
```

## 子系统图

```
┌─────────────────────────────────────────────────────────────────────┐
│                         OpenFang 架构概览                            │
└─────────────────────────────────────────────────────────────────────┘

┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐
│   openfang-cli  │  │ openfang-desktop│  │   openfang-api  │
│   (CLI 界面)    │  │   (桌面应用)    │  │   (API 服务器)  │
└────────┬────────┘  └────────┬────────┘  └────────┬────────┘
         │                  │                  │
         └──────────────────┼──────────────────┘
                            │
                    ┌───────┴───────┐
                    │ openfang-kernel│
                    │    (内核)      │
                    └───────┬───────┘
                            │
        ┌───────────────────┼───────────────────┐
        │                   │                   │
┌───────┴───────┐  ┌───────┴───────┐  ┌───────┴───────┐
│openfang-runtime│  │openfang-channels│  │ openfang-memory │
│  (运行时)       │  │   (通道)       │  │   (内存)       │
└───────┬───────┘  └───────┬───────┘  └───────┬───────┘
        │                   │                   │
┌───────┴───────┐  ┌───────┴───────┐  ┌───────┴───────┐
│ openfang-skills│  │ openfang-wire │  │openfang-types │
│   (技能)       │  │   (网络)       │  │   (类型)       │
└───────────────┘  └───────────────┘  └───────────────┘
```

**数据流图：**

```
用户输入
    │
    ▼
┌─────────────────┐
│   通道适配器    │ ◄── 40 个通道（Telegram、Discord、Slack 等）
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│   智能体运行时  │ ◄── 3 个 LLM 驱动、23 个工具、WASM 沙箱
│   （智能体循环）│
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│   内存基板      │ ◄── SQLite、会话存储、语义搜索
└────────┬────────┘
         │
         ▼
    响应输出
```

**安全架构：**

```
┌─────────────────────────────────────────────────────┐
│                    安全层                            │
├─────────────────────────────────────────────────────┤
│  1. 输入验证  │  模式验证、类型安全、边界检查        │
├───────────────┼──────────────────────────────────────┤
│  2. 认证      │  用户认证、智能体认证、API 密钥       │
├───────────────┼──────────────────────────────────────┤
│  3. 授权      │  RBAC、能力系统、资源级权限           │
├───────────────┼──────────────────────────────────────┤
│  4. 隔离      │  WASM 沙箱、进程隔离、网络命名空间      │
├───────────────┼──────────────────────────────────────┤
│  5. 加密      │  TLS、静态加密、密钥管理               │
├───────────────┼──────────────────────────────────────┤
│  6. 监控      │  日志记录、审计追踪、异常检测          │
└───────────────┴──────────────────────────────────────┘
```

**组件交互：**

```
CLI 命令 ────────┐
                │
桌面应用 ────────┼──────► API 服务器 ◄────── WebChat UI
                │           │
Docker/API ─────┘           │
                            ▼
                      ┌─────────────┐
                      │    内核      │
                      └──────┬──────┘
                             │
        ┌────────────────────┼────────────────────┐
        │                    │                    │
        ▼                    ▼                    ▼
   ┌─────────┐        ┌─────────┐        ┌─────────┐
   │ 运行时  │        │  通道   │        │  内存   │
   │ 智能体  │◄──────►│ 适配器  │◄──────►│ 基板   │
   └────┬────┘        └────┬────┘        └────┬────┘
        │                  │                  │
        ▼                  ▼                  ▼
   ┌─────────┐        ┌─────────┐        ┌─────────┐
   │  技能   │        │  网络   │        │  持久化 │
   │ 市场   │        │  OFP   │        │ SQLite  │
   └─────────┘        └─────────┘        └─────────┘
```
