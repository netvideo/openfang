# 工作流引擎指南

## 概述

OpenFang 工作流引擎支持多步骤智能体流水线——将任务编排为有序的序列，每一步将工作路由到特定的智能体，上一步的输出作为下一步的输入。工作流让你能够用简单、单一用途的智能体组合出复杂的行为，而无需编写任何 Rust 代码。

当你需要以下功能时，请使用工作流：

- 将多个智能体链接到处理流水线中（例如：先研究，再撰写，然后审核）。
- 将工作分散给多个智能体并行处理并收集结果。
- 根据前面步骤的输出进行条件分支执行。
- 在循环中迭代执行步骤，直到达到质量标准。
- 构建可通过 API 或 CLI 触发的可复现、可审计的多智能体流程。

实现位于 `openfang-kernel/src/workflow.rs`。工作流引擎通过闭包与内核解耦——它从不直接拥有或引用内核，因此可以单独进行测试。

---

## 核心类型

| Rust 类型 | 描述 |
|---|---|
| `WorkflowId(Uuid)` | 工作流定义的唯一标识符。 |
| `WorkflowRunId(Uuid)` | 运行中工作流实例的唯一标识符。 |
| `Workflow` | 一个命名的定义，包含 `WorkflowStep` 条目列表。 |
| `WorkflowStep` | 单个步骤：智能体引用、提示词模板、模式、超时、错误处理。 |
| `WorkflowRun` | 运行中的实例：跟踪状态、步骤结果、最终输出、时间戳。 |
| `WorkflowRunState` | 枚举：`Pending`、`Running`、`Completed`、`Failed`。 |
| `StepResult` | 单个步骤的结果：智能体信息、输出文本、Token 数量、持续时间。 |
| `WorkflowEngine` | 引擎本身：将定义和运行存储在 `Arc<RwLock<HashMap>>` 中。 |

---

## 工作流定义

工作流通过 REST API 以 JSON 格式注册。顶层结构如下：

```json
{
  "name": "my-pipeline",
  "description": "描述工作流的功能",
  "steps": [ ... ]
}
```

对应的 Rust 结构体如下：

```rust
pub struct Workflow {
    pub id: WorkflowId,            // 创建时自动分配
    pub name: String,              // 人类可读的名称
    pub description: String,       // 此工作流的功能描述
    pub steps: Vec<WorkflowStep>,  // 有序的步骤列表
    pub created_at: DateTime<Utc>, // 创建时自动分配
}
```

---

## 步骤配置

`steps` 数组中的每个步骤包含以下字段：

| JSON 字段 | Rust 字段 | 类型 | 默认值 | 描述 |
|---|---|---|---|---|
| `name` | `name` | `String` | `"step"` | 步骤名称，用于日志和显示。 |
| `agent_name` | `agent` | `StepAgent::ByName` | -- | 通过名称引用智能体（第一个匹配的）。与 `agent_id` 互斥。 |
| `agent_id` | `agent` | `StepAgent::ById` | -- | 通过 UUID 引用智能体。与 `agent_name` 互斥。 |
| `prompt` | `prompt_template` | `String` | `"{{input}}"` | 带有变量占位符的提示词模板。 |
| `mode` | `mode` | `StepMode` | `"sequential"` | 执行模式（见下文）。 |
| `timeout_secs` | `timeout_secs` | `u64` | `120` | 步骤超时前的最大时间（秒）。 |
| `error_mode` | `error_mode` | `ErrorMode` | `"fail"` | 如何处理错误（见下文）。 |
| `max_retries` | (在 `ErrorMode::Retry` 内) | `u32` | `3` | 当 `error_mode` 为 `"retry"` 时的重试次数。 |
| `output_var` | `output_var` | `Option<String>` | `null` | 如果设置，将此步骤的输出存储在命名变量中供后续引用。 |
| `condition` | (在 `StepMode::Conditional` 内) | `String` | `""` | 在前一步输出中匹配的子字符串（不区分大小写）。 |
| `max_iterations` | (在 `StepMode::Loop` 内) | `u32` | `5` | 强制终止前的最大循环迭代次数。 |
| `until` | (在 `StepMode::Loop` 内) | `String` | `""` | 在输出中匹配的子字符串以终止循环（不区分大小写）。 |

### 智能体解析

每个步骤必须恰好指定 `agent_name` 或 `agent_id` 中的一个。`StepAgent` 枚举如下：

```rust
pub enum StepAgent {
    ById { id: String },    // 现有智能体的 UUID
    ByName { name: String }, // 名称匹配（第一个具有此名称的智能体）
}
```

如果在执行时无法解析智能体，工作流将以 `"Agent not found for step '<name>'"` 失败。

---

## 步骤模式

`mode` 字段控制步骤在工作流中相对于其他步骤的执行方式。

### 顺序（默认）

```json
{ "mode": "sequential" }
```

步骤在前一步完成后运行。前一步的输出成为此步骤的 `{{input}}`。当省略 `mode` 时，这是默认模式。

### 扇出

```json
{ "mode": "fan_out" }
```

扇出步骤**并行**运行。引擎收集所有连续的 `fan_out` 步骤并使用 `futures::future::join_all` 同时启动它们。所有扇出步骤接收相同的 `{{input}}`——来自扇出组之前最后一步的输出。

如果任何扇出步骤失败或超时，整个工作流立即失败。

### 收集

```json
{ "mode": "collect" }
```

`collect` 步骤收集前面扇出组的所有输出。它不执行智能体——它是一个**纯数据**步骤，用分隔符 `"\n\n---\n\n"` 连接所有累积的输出，并将结果设置为后续步骤的 `{{input}}`。

典型的扇出/收集模式：

```
步骤 1: fan_out  -->  并行运行
步骤 2: fan_out  -->  并行运行
步骤 3: collect  -->  连接步骤 1 和 2 的输出
步骤 4: sequential --> 接收连接后的输出作为 {{input}}
```

### 条件

```json
{ "mode": "conditional", "condition": "ERROR" }
```

仅当前一步的输出**包含** `condition` 子字符串时（通过 `to_lowercase().contains()` 进行不区分大小写的比较），步骤才执行。如果条件未满足，步骤完全跳过，`{{input}}` 不会被修改。

当条件满足时，步骤像顺序步骤一样执行。

### 循环

```json
{ "mode": "loop", "max_iterations": 5, "until": "APPROVED" }
```

步骤最多重复 `max_iterations` 次。每次迭代后，引擎检查输出是否**包含** `until` 子字符串（不区分大小写）。如果找到，循环提前终止。

每次迭代将其输出反馈为下一次迭代的 `{{input}}`。步骤结果使用名称如 `"refine (iter 1)"`、`"refine (iter 2)"` 等记录。

如果 `until` 条件从未满足，循环恰好运行 `max_iterations` 次，并使用最后一次迭代的输出继续到下一步。

---

## 变量替换

提示词模板支持两种变量引用：

### `{{input}}` —— 前一步输出

始终可用。包含紧接前一步的输出（或工作流的初始输入，如果是第一步）。

### `{{variable_name}}` —— 命名变量

当步骤有 `"output_var": "my_var"` 时，其输出存储在变量映射中的 `my_var` 键下。任何后续步骤都可以在其提示词模板中使用 `{{my_var}}` 引用它。

扩展逻辑（来自 `WorkflowEngine::expand_variables`）：

```rust
fn expand_variables(template: &str, input: &str, vars: &HashMap<String, String>) -> String {
    let mut result = template.replace("{{input}}", input);
    for (key, value) in vars {
        result = result.replace(&format!("{{{{{key}}}}}"), value);
    }
    result
}
```

变量在整个工作流运行期间持续存在。后续步骤可以使用相同的 `output_var` 名称覆盖变量。

**示例**：一个三步工作流，其中步骤 3 引用步骤 1 和步骤 2 的输出：

```json
{
  "steps": [
    { "name": "research", "output_var": "research_output", "prompt": "Research: {{input}}" },
    { "name": "outline",  "output_var": "outline_output",  "prompt": "Outline based on: {{input}}" },
    { "name": "combine",  "prompt": "Write article.\nResearch: {{research_output}}\nOutline: {{outline_output}}" }
  ]
}
```

---

## 错误处理

每个步骤都有一个 `error_mode`，用于控制步骤失败或超时时的行为。

### 失败（默认）

```json
{ "error_mode": "fail" }
```

工作流立即中止。运行状态设置为 `Failed`，记录错误消息，并设置 `completed_at`。错误消息格式为 `"Step '<name>' failed: <error>"` 或 `"Step '<name>' timed out after <N>s"`。

### 跳过

```json
{ "error_mode": "skip" }
```

步骤在错误或超时时静默跳过。记录警告，但工作流继续。下一步的 `{{input}}` 保持不变（保留跳过步骤之前的值）。跳过的步骤不记录 `StepResult`。

### 重试

```json
{ "error_mode": "retry", "max_retries": 3 }
```

步骤在初始尝试后最多重试 `max_retries` 次（因此 `max_retries: 3` 表示最多 4 次尝试：1 次初始 + 3 次重试）。每次尝试获得完整的 `timeout_secs` 预算。如果所有尝试都失败，工作流以 `"Step '<name>' failed after <N> retries: <last_error>"` 中止。

### 超时行为

每个步骤执行都包装在 `tokio::time::timeout(Duration::from_secs(step.timeout_secs), ...)` 中。默认超时为 120 秒。超时被视为错误，并根据步骤的 `error_mode` 进行处理。

对于扇出步骤，每个并行步骤都有自己的独立超时。

---

## 示例

### 示例 1：代码审核流水线

一个顺序流水线，分析代码、审核问题并生成摘要。

```json
{
  "name": "code-review-pipeline",
  "description": "分析代码、审核问题并生成摘要报告",
  "steps": [
    {
      "name": "analyze",
      "agent_name": "code-reviewer",
      "prompt": "分析以下代码中的错误、风格问题和安全漏洞：\n\n{{input}}",
      "mode": "sequential",
      "timeout_secs": 180,
      "error_mode": "fail",
      "output_var": "analysis"
    },
    {
      "name": "security-check",
      "agent_name": "security-auditor",
      "prompt": "审核此代码分析中的安全问题。标记任何关键问题：\n\n{{analysis}}",
      "mode": "sequential",
      "timeout_secs": 120,
      "error_mode": "retry",
      "max_retries": 2,
      "output_var": "security_review"
    },
    {
      "name": "summary",
      "agent_name": "writer",
      "prompt": "撰写简洁的代码审核摘要。\n\n代码分析：\n{{analysis}}\n\n安全审核：\n{{security_review}}",
      "mode": "sequential",
      "timeout_secs": 60,
      "error_mode": "fail"
    }
  ]
}
```

### 示例 2：研究并撰写文章

研究主题、创建大纲，然后撰写——包含一个条件性的事实核查步骤。

```json
{
  "name": "research-and-write",
  "description": "研究主题、创建大纲、撰写，并选择性地进行事实核查",
  "steps": [
    {
      "name": "research",
      "agent_name": "researcher",
      "prompt": "彻底研究以下主题。尽可能引用来源：\n\n{{input}}",
      "mode": "sequential",
      "timeout_secs": 300,
      "error_mode": "retry",
      "max_retries": 1,
      "output_var": "research"
    },
    {
      "name": "outline",
      "agent_name": "planner",
      "prompt": "基于此研究创建详细的文章大纲：\n\n{{research}}",
      "mode": "sequential",
      "timeout_secs": 60,
      "output_var": "outline"
    },
    {
      "name": "write",
      "agent_name": "writer",
      "prompt": "撰写完整的文章。\n\n大纲：\n{{outline}}\n\n研究：\n{{research}}",
      "mode": "sequential",
      "timeout_secs": 300,
      "output_var": "article"
    },
    {
      "name": "fact-check",
      "agent_name": "analyst",
      "prompt": "对此文章进行事实核查，并指出任何需要验证的声明：\n\n{{article}}",
      "mode": "conditional",
      "condition": "claim",
      "timeout_secs": 120,
      "error_mode": "skip"
    }
  ]
}
```

只有当文章包含单词 "claim"（不区分大小写）时，事实核查步骤才会运行。如果事实核查智能体失败，工作流将按原样继续使用文章。

### 示例 3：多智能体头脑风暴（扇出 + 收集）

三个智能体并行头脑风暴，然后第四个智能体综合他们的想法。

```json
{
  "name": "brainstorm",
  "description": "3 个智能体并行头脑风暴，然后综合",
  "steps": [
    {
      "name": "creative-ideas",
      "agent_name": "writer",
      "prompt": "为以下内容头脑风暴 5 个创意：{{input}}",
      "mode": "fan_out",
      "timeout_secs": 60,
      "output_var": "creative"
    },
    {
      "name": "technical-ideas",
      "agent_name": "architect",
      "prompt": "为以下内容头脑风暴 5 个技术上可行的创意：{{input}}",
      "mode": "fan_out",
      "timeout_secs": 60,
      "output_var": "technical"
    },
    {
      "name": "business-ideas",
      "agent_name": "analyst",
      "prompt": "为以下内容头脑风暴 5 个具有强大商业潜力的创意：{{input}}",
      "mode": "fan_out",
      "timeout_secs": 60,
      "output_var": "business"
    },
    {
      "name": "gather",
      "agent_name": "planner",
      "prompt": "unused",
      "mode": "collect"
    },
    {
      "name": "synthesize",
      "agent_name": "orchestrator",
      "prompt": "你收到了三个角度的头脑风暴结果。将它们综合成前 5 个可执行的创意，按影响力排序：\n\n{{input}}",
      "mode": "sequential",
      "timeout_secs": 120
    }
  ]
}
```

三个扇出步骤并行运行。`collect` 步骤用 `---` 分隔符连接它们的输出。`synthesize` 步骤接收组合后的输出。

### 示例 4：迭代优化（循环）

智能体优化草稿直到达到质量标准。

```json
{
  "name": "iterative-refinement",
  "description": "优化文档直到获得批准或达到最大迭代次数",
  "steps": [
    {
      "name": "first-draft",
      "agent_name": "writer",
      "prompt": "撰写关于以下内容的第一稿：{{input}}",
      "mode": "sequential",
      "timeout_secs": 120,
      "output_var": "draft"
    },
    {
      "name": "review-and-refine",
      "agent_name": "code-reviewer",
      "prompt": "审核此草稿。如果符合质量标准，在开头回复 APPROVED。否则，提供具体反馈和修订版本：\n\n{{input}}",
      "mode": "loop",
      "max_iterations": 4,
      "until": "APPROVED",
      "timeout_secs": 180,
      "error_mode": "retry",
      "max_retries": 1
    }
  ]
}
```

循环最多运行审核员 4 次。每次迭代接收上一次迭代的输出作为 `{{input}}`。一旦审核员的响应中包含 "APPROVED"，循环就提前终止。

---

## 触发器引擎

触发器引擎（`openfang-kernel/src/triggers.rs`）提供事件驱动的自动化。触发器监听内核的事件总线，并在匹配的事件到达时自动向智能体发送消息。

### 核心类型

| Rust 类型 | 描述 |
|---|---|
| `TriggerId(Uuid)` | 触发器的唯一标识符。 |
| `Trigger` | 一个已注册的触发器：智能体、模式、提示词模板、触发次数、限制。 |
| `TriggerPattern` | 定义匹配哪些事件的枚举。 |
| `TriggerEngine` | 引擎：基于 `DashMap` 的并发存储，带有智能体到触发器的索引。 |

### 触发器定义

```rust
pub struct Trigger {
    pub id: TriggerId,
    pub agent_id: AgentId,         // 哪个智能体接收消息
    pub pattern: TriggerPattern,   // 匹配什么事件
    pub prompt_template: String,   // 带有 {{event}} 占位符的模板
    pub enabled: bool,             // 可以切换开/关
    pub created_at: DateTime<Utc>,
    pub fire_count: u64,           // 已触发多少次
    pub max_fires: u64,            // 0 = 无限制
}
```

### 事件模式

`TriggerPattern` 枚举支持 9 种匹配模式：

| 模式 | JSON | 描述 |
|---|---|---|
| `All` | `"all"` | 匹配每个事件（通配符）。 |
| `Lifecycle` | `"lifecycle"` | 匹配任何生命周期事件（spawned、started、terminated 等）。 |
| `AgentSpawned` | `{"agent_spawned": {"name_pattern": "coder"}}` | 当名称包含 `name_pattern` 的智能体被生成时匹配。使用 `"*"` 表示任何智能体。 |
| `AgentTerminated` | `"agent_terminated"` | 当任何智能体终止或崩溃时匹配。 |
| `System` | `"system"` | 匹配任何系统事件（健康检查、配额警告等）。 |
| `SystemKeyword` | `{"system_keyword": {"keyword": "quota"}}` | 匹配调试表示中包含关键字的系统事件（不区分大小写）。 |
| `MemoryUpdate` | `"memory_update"` | 匹配任何内存变更事件。 |
| `MemoryKeyPattern` | `{"memory_key_pattern": {"key_pattern": "config"}}` | 当键包含 `key_pattern` 时匹配内存更新。使用 `"*"` 表示任何键。 |
| `ContentMatch` | `{"content_match": {"substring": "error"}}` | 当人类可读的描述包含子字符串时匹配任何事件（不区分大小写）。 |

### 模式匹配细节

`matches_pattern` 函数决定每种模式的评估方式：

- **`All`**：始终返回 `true`。
- **`Lifecycle`**：检查 `EventPayload::Lifecycle(_)`。
- **`AgentSpawned`**：检查 `LifecycleEvent::Spawned`，其中 `name.contains(name_pattern)` 或 `name_pattern == "*"`。
- **`AgentTerminated`**：检查 `LifecycleEvent::Terminated` 或 `LifecycleEvent::Crashed`。
- **`System`**：检查 `EventPayload::System(_)`。
- **`SystemKeyword`**：通过 `Debug` trait 格式化系统事件，小写，并检查 `contains(keyword)`。
- **`MemoryUpdate`**：检查 `EventPayload::MemoryUpdate(_)`。
- **`MemoryKeyPattern`**：检查 `delta.key.contains(key_pattern)` 或 `key_pattern == "*"`。
- **`ContentMatch`**：使用 `describe_event()` 函数生成人类可读的字符串，然后检查 `contains(substring)`（不区分大小写）。

### 提示词模板和 `{{event}}`

当触发器触发时，引擎将 `prompt_template` 中的 `{{event}}` 替换为人类可读的事件描述。`describe_event()` 函数生成如下字符串：

- `"Agent 'coder' (id: <uuid>) was spawned"`
- `"Agent <uuid> terminated: shutdown requested"`
- `"Agent <uuid> crashed: out of memory"`
- `"Kernel started"`
- `"Quota warning: agent <uuid>, tokens at 85.0%"`
- `"Health check failed: agent <uuid>, unresponsive for 30s"`
- `"Memory Created on key 'config' for agent <uuid>"`
- `"Tool 'web_search' succeeded (450ms): ..."`

### 最大触发次数和自动禁用

当 `max_fires` 设置为大于 0 的值时，触发器在 `fire_count >= max_fires` 时自动禁用自身（设置 `enabled = false`）。将 `max_fires` 设置为 0 表示触发器无限期触发。

### 触发器用例

**监控智能体健康：**
```json
{
  "agent_id": "<ops-agent-uuid>",
  "pattern": {"content_match": {"substring": "health check failed"}},
  "prompt_template": "ALERT: {{event}}. 调查并报告所有智能体的状态。",
  "max_fires": 0
}
```

**响应新智能体生成：**
```json
{
  "agent_id": "<orchestrator-uuid>",
  "pattern": {"agent_spawned": {"name_pattern": "*"}},
  "prompt_template": "一个新智能体刚刚创建：{{event}}。更新机群名单。",
  "max_fires": 0
}
```

**一次性配额警报：**
```json
{
  "agent_id": "<admin-agent-uuid>",
  "pattern": {"system_keyword": {"keyword": "quota"}},
  "prompt_template": "检测到配额事件：{{event}}。建议采取纠正措施。",
  "max_fires": 1
}
```

---

## API 端点

### 工作流端点

#### `POST /api/workflows` —— 创建工作流

注册新工作流定义。

**请求体：**
```json
{
  "name": "my-pipeline",
  "description": "工作流描述",
  "steps": [
    {
      "name": "step-1",
      "agent_name": "researcher",
      "prompt": "Research: {{input}}",
      "mode": "sequential",
      "timeout_secs": 120,
      "error_mode": "fail",
      "output_var": "research"
    }
  ]
}
```

**响应（201 Created）：**
```json
{ "workflow_id": "<uuid>" }
```

#### `GET /api/workflows` —— 列出所有工作流

返回已注册工作流摘要的数组。

**响应（200 OK）：**
```json
[
  {
    "id": "<uuid>",
    "name": "my-pipeline",
    "description": "工作流描述",
    "steps": 3,
    "created_at": "2026-01-15T10:30:00Z"
  }
]
```

#### `POST /api/workflows/:id/run` —— 执行工作流

启动同步工作流执行。调用会一直阻塞，直到工作流完成或失败。

**请求体：**
```json
{ "input": "第一步的初始输入文本" }
```

**响应（200 OK）：**
```json
{
  "run_id": "<uuid>",
  "output": "最后一步的最终输出",
  "status": "completed"
}
```

**响应（500 Internal Server Error）：**
```json
{ "error": "工作流执行失败" }
```

#### `GET /api/workflows/:id/runs` —— 列出工作流运行

返回所有工作流运行（在当前实现中不按工作流 ID 过滤）。

**响应（200 OK）：**
```json
[
  {
    "id": "<uuid>",
    "workflow_name": "my-pipeline",
    "state": "completed",
    "steps_completed": 3,
    "started_at": "2026-01-15T10:30:00Z",
    "completed_at": "2026-01-15T10:32:15Z"
  }
]
```

### 触发器端点

#### `POST /api/triggers` —— 创建触发器

为智能体注册新的事件触发器。

**请求体：**
```json
{
  "agent_id": "<agent-uuid>",
  "pattern": "lifecycle",
  "prompt_template": "生命周期事件发生：{{event}}",
  "max_fires": 0
}
```

**响应（201 Created）：**
```json
{
  "trigger_id": "<uuid>",
  "agent_id": "<agent-uuid>"
}
```

#### `GET /api/triggers` —— 列出所有触发器

可选按智能体过滤：`GET /api/triggers?agent_id=<uuid>`

**响应（200 OK）：**
```json
[
  {
    "id": "<uuid>",
    "agent_id": "<agent-uuid>",
    "pattern": "lifecycle",
    "prompt_template": "事件：{{event}}",
    "enabled": true,
    "fire_count": 5,
    "max_fires": 0,
    "created_at": "2026-01-15T10:00:00Z"
  }
]
```

#### `PUT /api/triggers/:id` —— 启用/禁用触发器

切换触发器的启用状态。

**请求体：**
```json
{ "enabled": false }
```

**响应（200 OK）：**
```json
{ "status": "updated", "trigger_id": "<uuid>", "enabled": false }
```

#### `DELETE /api/triggers/:id` —— 删除触发器

**响应（200 OK）：**
```json
{ "status": "removed", "trigger_id": "<uuid>" }
```

**响应（404 Not Found）：**
```json
{ "error": "触发器未找到" }
```

---

## CLI 命令

所有工作流和触发器 CLI 命令都需要正在运行的 OpenFang 守护进程。

### 工作流命令

```
openfang workflow list
```
列出所有已注册的工作流及其 ID、名称、步骤数和创建日期。

```
openfang workflow create <file>
```
从 JSON 文件创建工作流。文件应包含与 `POST /api/workflows` 请求体相同的 JSON 结构。

```
openfang workflow run <workflow_id> <input>
```
通过其 UUID 执行工作流，使用给定的输入文本。阻塞直到完成并打印输出。

### 触发器命令

```
openfang trigger list [--agent-id <uuid>]
```
列出所有已注册的触发器。可选按智能体 ID 过滤。

```
openfang trigger create <agent_id> <pattern_json> [--prompt <template>] [--max-fires <n>]
```
为指定智能体创建触发器。`pattern_json` 参数是描述模式的 JSON 字符串。

默认值：
- `--prompt`: `"事件：{{event}}"`
- `--max-fires`: `0`（无限制）

示例：
```bash
# 监视所有生命周期事件
openfang trigger create <agent-id> '"lifecycle"' --prompt "生命周期：{{event}}"

# 监视特定智能体生成
openfang trigger create <agent-id> '{"agent_spawned":{"name_pattern":"coder"}}' --max-fires 1

# 监视包含 "error" 的内容
openfang trigger create <agent-id> '{"content_match":{"substring":"error"}}'
```

```
openfang trigger delete <trigger_id>
```
通过其 UUID 删除触发器。

---

## 执行限制

### 运行清除上限

工作流引擎最多保留 **200** 个工作流运行（`WorkflowEngine::MAX_RETAINED_RUNS`）。当创建新运行后超过此限制时，最旧的**已完成**或**失败**的运行将被清除（按 `started_at` 排序）。处于 `Pending` 或 `Running` 状态的运行永远不会被清除。

### 步骤超时

每个步骤都有可配置的 `timeout_secs`（默认：120 秒）。超时通过 `tokio::time::timeout` 强制执行，每次尝试单独计算——重试模式为每次尝试提供新的超时预算。扇出步骤各自获得自己的独立超时。

### 循环迭代上限

循环步骤受 `max_iterations` 限制（API 中默认：5）。即使 `until` 条件从未满足，引擎也不会执行超过此数量的迭代。

### 每小时 Token 配额

`AgentScheduler`（在 `openfang-kernel/src/scheduler.rs` 中）通过 `UsageTracker` 跟踪每个智能体的 Token 使用量，使用滚动 1 小时窗口。如果智能体超过其 `ResourceQuota.max_llm_tokens_per_hour`，调度器返回 `OpenFangError::QuotaExceeded`。窗口在 3600 秒后自动重置。此配额适用于所有智能体交互，包括工作流调用的那些。

---

## 工作流数据流图

```
                    input
                      |
                      v
              +---------------+
              |   步骤 1      |  mode: sequential
              |   智能体: A    |
              +-------+-------+
                      | output -> {{input}} for step 2
                      |          -> variables["var1"] if output_var set
                      v
              +---------------+
              |   步骤 2      |  mode: fan_out
              |   智能体: B    |---+
              +---------------+   |
              +---------------+   |  并行执行
              |   步骤 3      |   |  (all receive same {{input}})
              |   智能体: C    |---+
              +---------------+   |
                      |           |
                      v           v
              +---------------+
              |   步骤 4      |  mode: collect
              |   (无智能体)   |  用 "---" 连接所有输出
              +-------+-------+
                      | combined output -> {{input}}
                      v
              +---------------+
              |   步骤 5      |  mode: conditional { condition: "issue" }
              |   智能体: D    |  (如果 {{input}} 不包含 "issue" 则跳过)
              +-------+-------+
                      |
                      v
              +---------------+
              |   步骤 6      |  mode: loop { max_iterations: 3, until: "DONE" }
              |   智能体: E    |  重复，将输出反馈为 {{input}}
              +-------+-------+
                      |
                      v
                  final output
```

---

## 内部架构说明

- `WorkflowEngine` 与 `OpenFangKernel` 解耦。`execute_run` 方法接受两个闭包：`agent_resolver`（将 `StepAgent` 解析为 `AgentId` + 名称）和 `send_message`（向智能体发送提示词并返回输出 + Token 数量）。这种设计使引擎可以在没有活动内核的情况下进行测试。
- 所有状态都保存在 `Arc<RwLock<HashMap>>` 中，允许并发读取和串行写入。
- `TriggerEngine` 使用 `DashMap` 进行无锁并发访问，带有 `agent_triggers` 索引用于高效的每个智能体触发器查找。
- 扇出并行使用 `futures::future::join_all`——连续组中的所有扇出步骤同时启动。
- 触发器 `evaluate` 方法在 `DashMap` 上使用 `iter_mut()` 在检查模式时原子递增触发次数，防止竞态条件。
