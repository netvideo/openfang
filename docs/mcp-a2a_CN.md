# MCP 与 A2A 集成指南

OpenFang 实现了 **模型上下文协议（MCP）** 和 **代理间（A2A）** 协议，支持与外部工具、IDE 和其他代理框架进行深度互操作。

---

## 目录

- [第一部分：MCP（模型上下文协议）](#第一部分mcp模型上下文协议)
  - [概述](#mcp-概述)
  - [MCP 客户端 -- 连接外部服务器](#mcp-客户端)
  - [MCP 服务器 -- 通过 MCP 暴露 OpenFang](#mcp-服务器)
  - [配置示例](#mcp-配置示例)
  - [API 端点](#mcp-api-端点)
- [第二部分：A2A（代理间协议）](#第二部分a2a代理间协议)
  - [概述](#a2a-概述)
  - [代理卡片](#代理卡片)
  - [A2A 服务器](#a2a-服务器)
  - [A2A 客户端](#a2a-客户端)
  - [任务生命周期](#任务生命周期)
  - [API 端点](#a2a-api-端点)
  - [配置](#a2a-配置)
- [安全](#安全)

---

## 第一部分：MCP（模型上下文协议）

### MCP 概述

模型上下文协议（MCP）是一种基于 JSON-RPC 2.0 的协议，它标准化了 LLM 应用程序发现和调用工具的方式。OpenFang 在双向支持 MCP：

- **作为客户端**：OpenFang 连接到外部 MCP 服务器（GitHub、文件系统、数据库、Puppeteer 等），并将其工具提供给所有代理使用。
- **作为服务器**：OpenFang 将其自身的代理暴露为 MCP 工具，因此像 Cursor、VS Code 和 Claude Desktop 这样的 IDE 可以直接调用 OpenFang 代理。

OpenFang 实现的 MCP 协议版本为 `2024-11-05`。

**源文件：**
- 客户端：`crates/openfang-runtime/src/mcp.rs`
- 服务器处理器：`crates/openfang-runtime/src/mcp_server.rs`
- CLI 服务器：`crates/openfang-cli/src/mcp.rs`
- 配置类型：`crates/openfang-types/src/config.rs`（`McpServerConfigEntry`、`McpTransportEntry`）

---

### MCP 客户端

MCP 客户端（`openfang-runtime` 中的 `McpConnection`）允许 OpenFang 连接到任何兼容 MCP 的服务器，并使用其工具就像它们是内置的一样。

#### 配置

MCP 服务器在 `config.toml` 中使用 `[[mcp_servers]]` 数组进行配置：

```toml
[[mcp_servers]]
name = "github"
timeout_secs = 30
env = ["GITHUB_PERSONAL_ACCESS_TOKEN"]

[mcp_servers.transport]
type = "stdio"
command = "npx"
args = ["-y", "@modelcontextprotocol/server-github"]
```

每个条目映射到一个 `McpServerConfigEntry` 结构：

| 字段 | 类型 | 默认值 | 描述 |
|------|------|--------|------|
| `name` | `String` | 必需 | 显示名称，用于工具命名空间 |
| `transport` | `McpTransportEntry` | 必需 | 连接方式（stdio 或 SSE） |
| `timeout_secs` | `u64` | `30` | JSON-RPC 请求超时 |
| `env` | `Vec<String>` | `[]` | 传递给子进程的环境变量 |

#### 传输类型

OpenFang 支持两种 MCP 传输，由 `McpTransport` 定义：

**Stdio** -- 生成子进程并通过 stdin/stdout 进行通信，使用换行分隔的 JSON-RPC：

```toml
[mcp_servers.transport]
type = "stdio"
command = "npx"
args = ["-y", "@modelcontextprotocol/server-github"]
```

**SSE** -- 连接到远程 HTTP 端点并通过 POST 发送 JSON-RPC：

```toml
[mcp_servers.transport]
type = "sse"
url = "https://mcp.example.com/api"
```

#### 工具命名空间

从 MCP 服务器发现的所有工具都使用 `mcp_{server}_{tool}` 模式进行命名，以防止与内置工具或其他服务器的工具发生冲突。名称规范化为小写，连字符替换为下划线。

示例：
- 服务器 `github`，工具 `create_issue` 变为 `mcp_github_create_issue`
- 服务器 `my-server`，工具 `do_thing` 变为 `mcp_my_server_do_thing`

辅助函数（从 `openfang_runtime::mcp` 导出）：
- `format_mcp_tool_name(server, tool)` -- 构建命名名称
- `is_mcp_tool(name)` -- 检查工具名称是否以 `mcp_` 开头
- `extract_mcp_server(tool_name)` -- 从命名工具中提取服务器名称

#### 内核启动时自动连接

当内核启动（`start_background_agents()`）时，它会检查 `config.mcp_servers`。如果配置了任何服务器，它会生成一个后台任务调用 `connect_mcp_servers()`。此方法：

1. 遍历配置中的每个 `McpServerConfigEntry`
2. 将配置级 `McpTransportEntry` 转换为运行时 `McpTransport`
3. 调用 `McpConnection::connect()`：
   - 生成子进程（stdio）或创建 HTTP 客户端（SSE）
   - 发送带有客户端信息的 `initialize` 握手
   - 发送 `notifications/initialized` 通知
   - 调用 `tools/list` 发现所有可用工具
   - 使用 `mcp_{server}_{tool}` 为每个工具命名
4. 将发现的 `ToolDefinition` 条目缓存到 `kernel.mcp_tools`
5. 将活动的 `McpConnection` 存储到 `kernel.mcp_connections`

连接后，内核记录可用的 MCP 工具总数。

#### 工具发现和列表

MCP 工具通过 `available_tools()` 合并到代理的可用工具集中：

```
内置工具 (23) + 技能工具 + MCP 工具 = 完整工具列表
```

当代理在其循环期间调用 MCP 工具时，工具运行器识别 `mcp_` 前缀，找到适当的 `McpConnection`，剥离命名空间前缀，并将 `tools/call` 请求转发到外部 MCP 服务器。

#### 连接生命周期

`McpConnection` 结构管理连接的生命周期：

```rust
pub struct McpConnection {
    config: McpServerConfig,
    tools: Vec<ToolDefinition>,
    transport: McpTransportHandle,  // Stdio 或 SSE
    next_id: u64,                   // JSON-RPC 请求计数器
}
```

当连接被丢弃时，stdio 子进程通过 `Drop` 自动终止：

```rust
impl Drop for McpConnection {
    fn drop(&mut self) {
        if let McpTransportHandle::Stdio { ref mut child, .. } = self.transport {
            let _ = child.start_kill();
        }
    }
}
```

---

### MCP 服务器

OpenFang 也可以作为 MCP 服务器，将其代理暴露为可由外部 MCP 客户端调用的工具。

#### 工作原理

每个 OpenFang 代理都成为一个名为 `openfang_agent_{name}` 的 MCP 工具（连字符替换为下划线）。该工具接受单个 `message` 字符串参数并返回代理的响应。

例如，名为 `code-reviewer` 的代理成为 MCP 工具 `openfang_agent_code_reviewer`。

#### CLI: `openfang mcp`

运行 MCP 服务器的主要方式是使用 `openfang mcp` 命令，它启动一个基于 stdio 的 MCP 服务器：

```bash
openfang mcp
```

此命令：
1. 检查 OpenFang 守护进程是否正在运行（通过 `find_daemon()`）
2. 如果找到，通过其 HTTP API 将所有工具调用代理到守护进程
3. 如果没有守护进程运行，则启动一个进程内内核作为回退
4. 从 stdin 读取 Content-Length 分帧的 JSON-RPC 消息
5. 将 Content-Length 分帧的 JSON-RPC 响应写入 stdout

MCP 服务器使用 `McpBackend`，支持两种模式：
- `McpBackend::Daemon` -- 通过 HTTP 将请求转发到正在运行的 OpenFang 守护进程
- `McpBackend::InProcess` -- 在没有守护进程时启动完整内核

#### HTTP MCP 端点

OpenFang 还在 `POST /mcp` 上通过 HTTP 暴露 MCP 端点。与仅暴露代理的 stdio 服务器不同，HTTP 端点暴露完整的工具集（内置 + 技能 + MCP 工具）并通过内核的 `execute_tool()` 管道执行工具。这意味着 HTTP MCP 端点支持：

- 所有 23 个内置工具（file_read、web_fetch 等）
- 所有已安装的技能工具
- 所有已连接的 MCP 服务器工具

#### 支持的 JSON-RPC 方法

| 方法 | 描述 |
|------|------|
| `initialize` | 握手；返回服务器功能和信息 |
| `notifications/initialized` | 客户端确认；无响应 |
| `tools/list` | 返回所有可用工具及其名称、描述和输入模式 |
| `tools/call` | 执行工具并返回结果 |

未知方法收到 `-32601`（方法未找到）错误。

#### 协议详情

**消息分帧**（stdio 模式）：

```
Content-Length: 123\r\n
\r\n
{"jsonrpc":"2.0","id":1,"method":"initialize","params":{}}
```

消息限制为 10 MB（`MAX_MCP_MESSAGE_SIZE`）。超大消息会被清空并拒绝。

**初始化握手：**

```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "method": "initialize",
  "params": {
    "protocolVersion": "2024-11-05",
    "capabilities": {},
    "clientInfo": { "name": "cursor", "version": "1.0" }
  }
}
```

响应：

```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "result": {
    "protocolVersion": "2024-11-05",
    "capabilities": { "tools": {} },
    "serverInfo": { "name": "openfang", "version": "0.1.0" }
  }
}
```

**工具调用：**

```json
{
  "jsonrpc": "2.0",
  "id": 3,
  "method": "tools/call",
  "params": {
    "name": "openfang_agent_code_reviewer",
    "arguments": {
      "message": "Review this Python function for security issues..."
    }
  }
}
```

响应：

```json
{
  "jsonrpc": "2.0",
  "id": 3,
  "result": {
    "content": [{
      "type": "text",
      "text": "I found 3 potential security issues..."
    }]
  }
}
```

#### 从 IDE 连接

**Cursor / VS Code（使用 MCP 扩展）：**

将以下内容添加到 MCP 配置文件（例如 `.cursor/mcp.json` 或 VS Code MCP 设置）：

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

**Claude Desktop：**

添加到 `claude_desktop_config.json`：

```json
{
  "mcpServers": {
    "openfang": {
      "command": "openfang",
      "args": ["mcp"],
      "env": {}
    }
  }
}
```

配置后，所有 OpenFang 代理都会显示为 IDE 中的工具。例如，您可以要求 Claude Desktop "使用 openfang code-reviewer 代理审查此文件"。

---

### MCP 配置示例

#### GitHub 服务器（文件 + 议题 + PR 工具）

```toml
[[mcp_servers]]
name = "github"
timeout_secs = 30
env = ["GITHUB_PERSONAL_ACCESS_TOKEN"]

[mcp_servers.transport]
type = "stdio"
command = "npx"
args = ["-y", "@modelcontextprotocol/server-github"]
```

#### 文件系统服务器

```toml
[[mcp_servers]]
name = "filesystem"
timeout_secs = 10
env = []

[mcp_servers.transport]
type = "stdio"
command = "npx"
args = ["-y", "@modelcontextprotocol/server-filesystem", "/home/user/projects"]
```

#### PostgreSQL 服务器

```toml
[[mcp_servers]]
name = "postgres"
timeout_secs = 30
env = ["DATABASE_URL"]

[mcp_servers.transport]
type = "stdio"
command = "npx"
args = ["-y", "@modelcontextprotocol/server-postgres"]
```

#### Puppeteer（浏览器自动化）

```toml
[[mcp_servers]]
name = "puppeteer"
timeout_secs = 60

[mcp_servers.transport]
type = "stdio"
command = "npx"
args = ["-y", "@modelcontextprotocol/server-puppeteer"]
```

#### 远程 SSE 服务器

```toml
[[mcp_servers]]
name = "remote-tools"
timeout_secs = 30

[mcp_servers.transport]
type = "sse"
url = "https://tools.example.com/mcp"
```

#### 多个服务器

```toml
[[mcp_servers]]
name = "github"
env = ["GITHUB_PERSONAL_ACCESS_TOKEN"]
[mcp_servers.transport]
type = "stdio"
command = "npx"
args = ["-y", "@modelcontextprotocol/server-github"]

[[mcp_servers]]
name = "filesystem"
[mcp_servers.transport]
type = "stdio"
command = "npx"
args = ["-y", "@modelcontextprotocol/server-filesystem", "/home/user/projects"]

[[mcp_servers]]
name = "postgres"
env = ["DATABASE_URL"]
[mcp_servers.transport]
type = "stdio"
command = "npx"
args = ["-y", "@modelcontextprotocol/server-postgres"]
```

---

### MCP API 端点

| 方法 | 路径 | 描述 |
|------|------|------|
| `GET` | `/api/mcp/servers` | 列出已配置和已连接的 MCP 服务器及其工具 |
| `POST` | `/mcp` | 通过 HTTP 处理 MCP JSON-RPC 请求（完整工具执行） |

**GET /api/mcp/servers** 响应：

```json
{
  "configured": [
    {
      "name": "github",
      "transport": { "type": "stdio", "command": "npx", "args": [...] },
      "timeout_secs": 30,
      "env": ["GITHUB_PERSONAL_ACCESS_TOKEN"]
    }
  ],
  "connected": [
    {
      "name": "github",
      "tools_count": 12,
      "tools": [
        { "name": "mcp_github_create_issue", "description": "[MCP:github] Create a GitHub issue" },
        { "name": "mcp_github_search_repos", "description": "[MCP:github] Search repositories" }
      ],
      "connected": true
    }
  ]
}
```

---

## 第二部分：A2A（代理间协议）

### A2A 概述

代理间（A2A）协议最初由 Google 提出，支持跨框架代理互操作性。它允许使用不同框架构建的代理发现彼此的能力并交换任务。

OpenFang 在双向实现 A2A：

- **作为服务器**：发布描述每个代理能力的代理卡片，接受任务提交，并跟踪任务生命周期。
- **作为客户端**：在启动时发现外部 A2A 代理，向它们发送任务，并轮询结果。

**源文件：**
- 协议类型和逻辑：`crates/openfang-runtime/src/a2a.rs`
- API 路由：`crates/openfang-api/src/routes.rs`
- 配置类型：`crates/openfang-types/src/config.rs`（`A2aConfig`、`ExternalAgent`）

---

### 代理卡片

代理卡片是一个 JSON 文档，描述代理的身份、能力和支持的交互模式。根据 A2A 规范，它在众所周知的路径 `/.well-known/agent.json` 处提供。

`AgentCard` 结构：

```rust
pub struct AgentCard {
    pub name: String,
    pub description: String,
    pub url: String,                         // 端点 URL（例如 "http://host/a2a"）
    pub version: String,                     // 协议版本
    pub capabilities: AgentCapabilities,
    pub skills: Vec<AgentSkill>,             // A2A 技能描述符
    pub default_input_modes: Vec<String>,    // 例如 ["text"]
    pub default_output_modes: Vec<String>,   // 例如 ["text"]
}
```

**AgentCapabilities：**

```rust
pub struct AgentCapabilities {
    pub streaming: bool,                 // true -- OpenFang 支持流式传输
    pub push_notifications: bool,        // false -- 当前未实现
    pub state_transition_history: bool,  // true -- 任务状态历史可用
}
```

**AgentSkill**（与 OpenFang 技能不同 -- 这些是 A2A 能力描述符）：

```rust
pub struct AgentSkill {
    pub id: String,           // 匹配 OpenFang 工具名称
    pub name: String,         // 人类可读（下划线替换为空格）
    pub description: String,
    pub tags: Vec<String>,
    pub examples: Vec<String>,
}
```

代理卡片通过 `build_agent_card()` 从 OpenFang 代理清单构建。代理能力列表中的每个工具都成为一个 A2A 技能描述符。示例卡片：

```json
{
  "name": "code-reviewer",
  "description": "Reviews code for bugs, security issues, and style",
  "url": "http://127.0.0.1:50051/a2a",
  "version": "0.1.0",
  "capabilities": {
    "streaming": true,
    "pushNotifications": false,
    "stateTransitionHistory": true
  },
  "skills": [
    {
      "id": "file_read",
      "name": "file read",
      "description": "Can use the file_read tool",
      "tags": ["tool"],
      "examples": []
    }
  ],
  "defaultInputModes": ["text"],
  "defaultOutputModes": ["text"]
}
```

---

### A2A 服务器

OpenFang 通过 REST API 提供 A2A 请求。服务器端实现包括：

1. **代理卡片发布** 在 `/.well-known/agent.json`
2. **代理列表** 在 `/a2a/agents`
3. **任务提交和跟踪** 通过 `A2aTaskStore`

#### A2aTaskStore

`A2aTaskStore` 是一个内存中的、有界的存储，用于跟踪 A2A 任务生命周期：

```rust
pub struct A2aTaskStore {
    tasks: Mutex<HashMap<String, A2aTask>>,
    max_tasks: usize,  // 默认：1000
}
```

关键属性：
- **有界**：当存储达到 `max_tasks` 时，它会逐出最旧的已完成/失败/已取消任务（FIFO）
- **线程安全**：使用 `Mutex<HashMap>` 进行并发访问
- **内核字段**：存储为 `kernel.a2a_task_store`

`A2aTaskStore` 的方法：
- `insert(task)` -- 添加新任务，如果达到容量则逐出旧任务
- `get(task_id)` -- 通过 ID 检索任务
- `update_status(task_id, status)` -- 更改任务状态
- `complete(task_id, response, artifacts)` -- 标记为已完成并附带响应
- `fail(task_id, error_message)` -- 标记为失败并附带错误
- `cancel(task_id)` -- 标记为已取消

#### 任务提交流程

当调用 `POST /a2a/tasks/send` 时：

1. 从 A2A 请求格式中提取消息文本（带有 "text" 类型的部件）
2. 找到目标代理（当前使用第一个注册的代理）
3. 创建一个状态为 `Working` 的 `A2aTask` 并插入任务存储
4. 通过 `kernel.send_message()` 将消息发送给代理
5. 成功时：用代理的响应完成任务
6. 失败时：用错误消息使任务失败
7. 返回最终任务状态

---

### A2A 客户端

`A2aClient` 结构发现并与外部 A2A 代理交互：

```rust
pub struct A2aClient {
    client: reqwest::Client,  // 30 秒超时
}
```

**方法：**

- `discover(url)` -- 获取 `{url}/.well-known/agent.json` 并解析代理卡片
- `send_task(url, message, session_id)` -- 发送 JSON-RPC 任务提交
- `get_task(url, task_id)` -- 轮询任务状态

#### 启动时自动发现

当内核启动且 A2A 启用并配置了外部代理时，它会生成一个后台任务调用 `discover_external_agents()`。此函数：

1. 创建一个 `A2aClient`
2. 遍历每个配置的 `ExternalAgent`
3. 从 `{url}/.well-known/agent.json` 获取每个代理的卡片
4. 记录成功的发现（名称、URL、技能计数）
5. 将发现的 `(name, AgentCard)` 对存储在 `kernel.a2a_external_agents` 中

失败的发现记录为警告，但不会阻止启动。

#### 向外部代理发送任务

```rust
let client = A2aClient::new();
let task = client.send_task(
    "https://other-agent.example.com/a2a",
    "Analyze this dataset for anomalies",
    Some("session-123"),
).await?;
println!("Task {}: {:?}", task.id, task.status);
```

客户端发送 JSON-RPC 请求：

```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "method": "tasks/send",
  "params": {
    "message": {
      "role": "user",
      "parts": [{ "type": "text", "text": "Analyze this dataset..." }]
    },
    "sessionId": "session-123"
  }
}
```

---

### 任务生命周期

`A2aTask` 跟踪跨代理交互的完整生命周期：

```rust
pub struct A2aTask {
    pub id: String,
    pub session_id: Option<String>,
    pub status: A2aTaskStatus,
    pub messages: Vec<A2aMessage>,
    pub artifacts: Vec<A2aArtifact>,
}
```

#### 任务状态

| 状态 | 描述 |
|------|------|
| `Submitted` | 任务已接收但尚未开始 |
| `Working` | 代理正在积极处理任务 |
| `InputRequired` | 代理需要调用者提供更多信息 |
| `Completed` | 任务成功完成 |
| `Cancelled` | 任务被调用者取消 |
| `Failed` | 任务遇到错误 |

#### 消息格式

消息使用具有类型化内容部件的 A2A 特定格式：

```rust
pub struct A2aMessage {
    pub role: String,          // "user" 或 "agent"
    pub parts: Vec<A2aPart>,
}

pub enum A2aPart {
    Text { text: String },
    File { name: String, mime_type: String, data: String },  // base64
    Data { mime_type: String, data: serde_json::Value },
}
```

#### 产物

任务可以产生产物（文件、结构化数据）以及消息：

```rust
pub struct A2aArtifact {
    pub name: String,
    pub parts: Vec<A2aPart>,
}
```

---

### A2A API 端点

| 方法 | 路径 | 认证 | 描述 |
|------|------|------|------|
| `GET` | `/.well-known/agent.json` | 公开 | 主代理的代理卡片 |
| `GET` | `/a2a/agents` | 公开 | 列出所有代理卡片 |
| `POST` | `/a2a/tasks/send` | 公开 | 向代理提交任务 |
| `GET` | `/a2a/tasks/{id}` | 公开 | 获取任务状态和消息 |
| `POST` | `/a2a/tasks/{id}/cancel` | 公开 | 取消正在运行的任务 |

#### GET /.well-known/agent.json

返回第一个注册代理的代理卡片。如果没有生成代理，则返回占位卡片。

#### GET /a2a/agents

将所有注册代理列为代理卡片：

```json
{
  "agents": [
    {
      "name": "code-reviewer",
      "description": "Reviews code for bugs and security issues",
      "url": "http://127.0.0.1:50051/a2a",
      "version": "0.1.0",
      "capabilities": { "streaming": true, "pushNotifications": false, "stateTransitionHistory": true },
      "skills": [...],
      "defaultInputModes": ["text"],
      "defaultOutputModes": ["text"]
    }
  ],
  "total": 1
}
```

#### POST /a2a/tasks/send

提交任务。请求体遵循 JSON-RPC 2.0 格式：

```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "method": "tasks/send",
  "params": {
    "message": {
      "role": "user",
      "parts": [{ "type": "text", "text": "Review this code for security issues" }]
    },
    "sessionId": "optional-session-id"
  }
}
```

响应（已完成任务）：

```json
{
  "id": "550e8400-e29b-41d4-a716-446655440000",
  "sessionId": "optional-session-id",
  "status": "completed",
  "messages": [
    {
      "role": "user",
      "parts": [{ "type": "text", "text": "Review this code for security issues" }]
    },
    {
      "role": "agent",
      "parts": [{ "type": "text", "text": "I found 2 potential issues..." }]
    }
  ],
  "artifacts": []
}
```

#### GET /a2a/tasks/{id}

轮询任务状态。如果任务未找到或已被逐出，则返回 `404`。

#### POST /a2a/tasks/{id}/cancel

取消正在运行的任务。将其状态设置为 `Cancelled`。如果任务未找到，则返回 `404`。

---

### A2A 配置

A2A 在 `config.toml` 中的 `[a2a]` 部分进行配置：

```toml
[a2a]
enabled = true
listen_path = "/a2a"

[[a2a.external_agents]]
name = "research-agent"
url = "https://research.example.com"

[[a2a.external_agents]]
name = "data-analyst"
url = "https://data.example.com"
```

`A2aConfig` 结构：

| 字段 | 类型 | 默认值 | 描述 |
|------|------|--------|------|
| `enabled` | `bool` | `false` | A2A 端点是否激活 |
| `listen_path` | `String` | `"/a2a"` | A2A 端点的基础路径 |
| `external_agents` | `Vec<ExternalAgent>` | `[]` | 启动时发现的外部代理 |

每个 `ExternalAgent`：

| 字段 | 类型 | 描述 |
|------|------|------|
| `name` | `String` | 此外部代理的显示名称 |
| `url` | `String` | 发布代理卡片的基础 URL |

如果 `a2a` 为 `None`（配置中不存在），则所有 A2A 功能都被禁用。A2A 端点始终在路由器中注册，但发现和任务存储功能需要 `enabled = true`。

---

## 安全

### MCP 安全

**子进程沙箱**：Stdio MCP 服务器使用 `env_clear()` 运行 -- 子进程环境被完全清除。只有显式列入白名单的环境变量（`env` 字段中列出）加上 `PATH` 被传递。这可以防止将机密泄露给不受信任的 MCP 服务器进程。

**路径遍历防护**：对 stdio MCP 服务器的命令路径进行验证，以拒绝 `..` 序列。

**SSRF 防护**：SSE 传输 URL 会针对已知元数据端点（169.254.169.254、metadata.google）进行检查，以防止 SSRF 攻击。

**请求超时**：所有 MCP 请求都有可配置的超时（默认 30 秒），以防止连接挂起。

**消息大小限制**：stdio MCP 服务器强制执行 10 MB 的最大消息大小，以防止内存耗尽攻击。超大消息会被清空并拒绝。

### A2A 安全

**速率限制**：A2A 端点通过与其他所有 API 端点相同的 GCRA 速率限制器。

**API 认证**：当内核配置中设置了 `api_key` 时，所有 API 端点（包括 A2A）都需要 `Authorization: Bearer <key>` 标头。例外是 `/.well-known/agent.json` 和健康端点，它们通常是公开的。

**任务存储边界**：`A2aTaskStore` 是有界的（默认 1000 个任务），对已完成/失败/已取消任务进行 FIFO 逐出，防止任务累积导致的内存耗尽。

**外部代理发现**：`A2aClient` 使用 30 秒超时并发送 `User-Agent: OpenFang/0.1 A2A` 标头。失败的发现会被记录但不会阻止内核启动。

### 内核级保护

MCP 和 A2A 工具执行都流经与其他所有工具调用相同的安全管道：
- 基于能力的访问控制（代理仅获得授权的工具）
- 工具结果截断（50K 字符硬上限）
- 通用 60 秒工具执行超时
- 循环守卫检测（阻止重复工具调用模式）
- 工具间数据流污点跟踪
