# OpenFang 配置参考手册

`config.toml` 的完整参考手册，涵盖 OpenFang 智能体操作系统中的每一个可配置字段。

---

## 目录

- [概述](#概述)
- [最小化配置](#最小化配置)
- [完整示例](#完整示例)
- [章节参考](#章节参考)
  - [顶级字段](#顶级字段)
  - [\[default_model\]](#default_model)
  - [\[memory\]](#memory)
  - [\[network\]](#network)
  - [\[web\]](#web)
  - [\[channels\]](#channels)
  - [\[\[mcp_servers\]\]](#mcp_servers)
  - [\[a2a\]](#a2a)
  - [\[\[fallback_providers\]\]](#fallback_providers)
  - [\[\[users\]\]](#users)
  - [通道覆盖](#通道覆盖)
- [环境变量](#环境变量)
- [验证](#验证)

---

## 概述

OpenFang 从单个 TOML 文件读取配置：

```
~/.openfang/config.toml
```

在 Windows 上，`~` 解析为 `C:\Users\<username>`。如果无法确定主目录，则使用系统临时目录作为后备。

**关键行为：**

- 配置中的每个结构都使用 `#[serde(default)]`，这意味着**所有字段都是可选的**。省略的字段将接收其记录的默认值。
- 通道章节（`[channels.telegram]`、`[channels.discord]` 等）是 `Option<T>`——缺失时，通道适配器被**禁用**。包含章节标题（即使为空）也会使用默认值启用适配器。
- 机密**绝不直接存储在 config.toml 中**。相反，像 `api_key_env` 和 `bot_token_env` 这样的字段包含包含实际机密的**环境变量的名称**。这可以防止在版本控制中意外暴露。
- 敏感字段（`api_key`、`shared_secret`）在调试输出和日志中自动编辑。

---

## 最小化配置

最简单的有效配置只需要将 LLM 提供商 API 密钥设置为环境变量。完全不需要配置文件，OpenFang 就会以 Anthropic 作为默认提供商启动：

```bash
export ANTHROPIC_API_KEY=sk-ant-...
```

然后运行：

```bash
openfang init && openfang start
```

OpenFang 启动时带有：
- 默认提供商：Anthropic (Claude)
- API 密钥：从 `ANTHROPIC_API_KEY` 环境变量读取
- 内存：SQLite 在 `~/.openfang/data/openfang.db`
- 网络：绑定到 `127.0.0.1:4200`
- 守护进程模式：前台运行（在终端中按 Ctrl+C 停止）

---

## 完整示例

下面是一个完整的生产配置，展示了所有可用选项。复制并根据您的环境自定义。有关每个字段的详细信息，请参阅[章节参考](#章节参考)。

```toml
# OpenFang 配置文件 - 生产部署示例
# 完整文档: https://docs.openfang.io/config

# ═══════════════════════════════════════════════════════════════════════════
# 顶级设置
# ═══════════════════════════════════════════════════════════════════════════

# 数据目录。如果为相对路径，则相对于 $HOME 解析。
# 默认为：~/.openfang/
data_dir = "/var/lib/openfang"

# 日志级别：trace, debug, info, warn, error。
# 默认为：info
log_level = "info"

# 日志格式：json 或 pretty。
# 默认为：pretty（开发）或 json（发布）
log_format = "json"

# 开发模式：启用热重载、详细错误、调试端点。
# 默认为：false
development = false

# ═══════════════════════════════════════════════════════════════════════════
# 默认语言模型
# ═══════════════════════════════════════════════════════════════════════════

[default_model]
# 提供商标识符。必需。
# 支持: "anthropic", "openai", "groq", "ollama", "gemini", 
#       "deepseek", "xai", "bedrock", "azure_openai"
provider = "anthropic"

# 模型标识符。如果省略，则使用提供商的默认模型。
model = "claude-3-5-sonnet-20241022"

# 包含 API 密钥的环境变量名称。
# 密钥本身绝不存储在配置文件中。
api_key_env = "ANTHROPIC_API_KEY"

# 每个请求的最大 token 数（输入 + 输出）。
# 防止超出令牌预算的失控循环。
max_tokens = 4096

# 温度：0.0 = 确定性，1.0 = 创造性。
# 默认: 0.7
temperature = 0.7

# Top-p（核采样）：1.0 = 包含所有 token。
# 默认: 1.0
top_p = 1.0

# 频率惩罚：降低重复 token 的概率。
# 默认: 0.0
frequency_penalty = 0.0

# 存在惩罚：鼓励新主题。
# 默认: 0.0
presence_penalty = 0.0

# 超时：每个 LLM 请求的最长持续时间（秒）。
# 默认: 60
timeout = 60

# 启用流式传输以加快响应。
# 默认: true
stream = true

# ═══════════════════════════════════════════════════════════════════════════
# 内存设置
# ═══════════════════════════════════════════════════════════════════════════

[memory]
# 启用持久内存。
# 默认: true
enabled = true

# SQLite 数据库文件路径。
# 默认: data_dir/openfang.db
db_path = "/var/lib/openfang/openfang.db"

# 最大数据库大小（MB）。
# 默认: 1024 (1 GB)
max_size_mb = 4096

# 连接池大小。
# 默认: 10
pool_size = 20

# 内存置信度衰减率（每周期）。
# 默认: 0.05
# 范围: 0.0 - 1.0
decay_rate = 0.03

# 启用语义搜索。
# 需要嵌入模型。
# 默认: false
semantic_search = true

# 用于语义搜索的嵌入模型。
# 支持: "openai", "ollama", "local"
embedding_model = "ollama"

# 语义搜索的相似度阈值。
# 默认: 0.7
similarity_threshold = 0.75

# ═══════════════════════════════════════════════════════════════════════════
# 网络设置
# ═══════════════════════════════════════════════════════════════════════════

[network]
# REST/WebSocket/SSE 端点的监听地址。
# 默认: 127.0.0.1:4200
listen_addr = "0.0.0.0:4200"

# 启用 TLS。
# 默认: false
# 生产环境强烈建议。
tls_enabled = true

# TLS 证书路径。
tls_cert_path = "/etc/openfang/certs/server.crt"

# TLS 密钥路径。
tls_key_path = "/etc/openfang/certs/server.key"

# 启用 OFP（OpenFang 协议）点对点网络。
# 默认: false
ofp_enabled = true

# OFP 监听地址。
ofp_listen_addr = "0.0.0.0:4201"

# OFP 引导节点（用于发现）。
ofp_bootstrap_nodes = [
    "/dns4/bootstrap.openfang.io/tcp/4201/p2p/12D3K...",
]

# CORS 允许的源。
# 默认: ["http://localhost:4200"]
cors_origins = [
    "https://app.openfang.io",
    "https://localhost:4200",
]

# 启用请求速率限制。
# 默认: true
rate_limit_enabled = true

# 每个 IP 的请求数（每分钟）。
# 默认: 100
rate_limit_requests_per_minute = 120

# 启用压缩。
# 默认: true
compression_enabled = true

# 请求体最大大小（MB）。
# 默认: 10
max_request_body_size_mb = 50

# 请求超时（秒）。
# 默认: 30
request_timeout_seconds = 60

# ═══════════════════════════════════════════════════════════════════════════
# Web 界面设置
# ═══════════════════════════════════════════════════════════════════════════

[web]
# 启用 WebChat UI。
# 默认: true
enabled = true

# Web 静态文件路径。
# 默认: 内置于二进制文件
static_path = "/usr/share/openfang/web"

# 启用实时更新（WebSocket）。
# 默认: true
live_updates = true

# 每个会话最大并发 WebSocket 连接数。
# 默认: 10
max_connections_per_session = 20

# 主题："light"、"dark"、"system"。
# 默认: "system"
default_theme = "dark"

# 界面语言。
# 默认: "en"
default_language = "zh"

# ═══════════════════════════════════════════════════════════════════════════
# 通道配置
# ═══════════════════════════════════════════════════════════════════════════

[channels]
# 全局通道设置。

# 启用桥接消息。
# 默认: false
enable_bridging = true

# 桥接格式："simple"、"rich"、"markdown"。
# 默认: "rich"
bridge_format = "rich"

# 全局速率限制：每个通道每分钟的消息数。
# 默认: 60
rate_limit_per_minute = 120

# ═══════════════════════════════════════════════════════════════════════════
# Telegram 通道
# ═══════════════════════════════════════════════════════════════════════════

[channels.telegram]
# 启用 Telegram 通道。
# 默认: false
enabled = true

# Telegram Bot API 令牌。
# 使用环境变量。
bot_token_env = "TELEGRAM_BOT_TOKEN"

# 允许的用户 ID（可选，为空表示允许所有）。
allowed_user_ids = []

# 允许的聊天 ID（可选）。
allowed_chat_ids = []

# 管理员用户 ID。
admin_user_ids = []

# 命令前缀。
# 默认: "/"
command_prefix = "/"

# 启用内联查询。
# 默认: true
enable_inline_queries = true

# Webhook 配置（用于生产环境）。
# 使用 webhook 而不是轮询。
use_webhook = false
webhook_url = "https://api.example.com/telegram/webhook"
webhook_secret_env = "TELEGRAM_WEBHOOK_SECRET"

# 轮询间隔（秒）。
# 默认: 10
polling_interval = 5

# ═══════════════════════════════════════════════════════════════════════════
# Discord 通道
# ═══════════════════════════════════════════════════════════════════════════

[channels.discord]
# 启用 Discord 通道。
# 默认: false
enabled = true

# Discord Bot Token。
discord_token_env = "DISCORD_BOT_TOKEN"

# 应用 ID。
application_id_env = "DISCORD_APPLICATION_ID"

# 公钥（用于 Webhook 验证）。
public_key_env = "DISCORD_PUBLIC_KEY"

# 默认权限。
default_permissions = "274877910016"

# 启用斜杠命令。
# 默认: true
enable_slash_commands = true

# 命令前缀（用于旧版命令）。
# 默认: "!"
command_prefix = "!"

# 允许的 Guild ID。
allowed_guild_ids = []

# 允许的频道 ID。
allowed_channel_ids = []

# 管理员角色 ID。
admin_role_ids = []

# Webhook 配置。
use_webhook = false
webhook_url = "https://api.example.com/discord/webhook"
webhook_secret_env = "DISCORD_WEBHOOK_SECRET"

# 心跳间隔（秒）。
# 默认: 42
heartbeat_interval = 30

# ═══════════════════════════════════════════════════════════════════════════
# Slack 通道
# ═══════════════════════════════════════════════════════════════════════════

[channels.slack]
# 启用 Slack 通道。
# 默认: false
enabled = true

# Bot User OAuth Token。
# 以 "xoxb-" 开头。
bot_token_env = "SLACK_BOT_TOKEN"

# User OAuth Token（用于用户上下文操作）。
user_token_env = "SLACK_USER_TOKEN"

# 应用级别令牌（用于事件）。
app_token_env = "SLACK_APP_TOKEN"

# 签名密钥（用于请求验证）。
signing_secret_env = "SLACK_SIGNING_SECRET"

# 客户端 ID（用于 OAuth）。
client_id_env = "SLACK_CLIENT_ID"

# 客户端密钥。
client_secret_env = "SLACK_CLIENT_SECRET"

# 启用事件订阅。
# 默认: true
enable_events = true

# 请求 URL 路径。
# 默认: "/slack/events"
events_path = "/slack/events"

# 启用斜杠命令。
# 默认: true
enable_slash_commands = true

# 启用交互式组件。
# 默认: true
enable_interactivity = true

# 允许的 Workspace ID。
allowed_team_ids = []

# 允许的频道 ID。
allowed_channel_ids = []

# 管理员用户 ID。
admin_user_ids = []

# Bot 用户名。
# 默认: "OpenFang"
bot_name = "OpenFang"

# 图标表情或 URL。
icon_emoji = ":robot_face:"
icon_url = ""

# WebSocket 模式（用于 Socket Mode）。
use_socket_mode = false

# HTTP 模式（用于事件订阅）。
use_http_mode = true

# Webhook 端口。
# 默认: 3000
webhook_port = 3000

# ═══════════════════════════════════════════════════════════════════════════
# 其他通道配置
# ═══════════════════════════════════════════════════════════════════════════

# WhatsApp (via WhatsApp Business API)
[channels.whatsapp]
enabled = false
api_token_env = "WHATSAPP_API_TOKEN"
phone_number_id_env = "WHATSAPP_PHONE_NUMBER_ID"
business_account_id_env = "WHATSAPP_BUSINESS_ACCOUNT_ID"
webhook_verify_token_env = "WHATSAPP_WEBHOOK_VERIFY_TOKEN"

# LINE
[channels.line]
enabled = false
channel_secret_env = "LINE_CHANNEL_SECRET"
channel_access_token_env = "LINE_CHANNEL_ACCESS_TOKEN"

# Mastodon
[channels.mastodon]
enabled = false
instance_url = "https://mastodon.social"
access_token_env = "MASTODON_ACCESS_TOKEN"

# Microsoft Teams
[channels.teams]
enabled = false
app_id_env = "TEAMS_APP_ID"
app_password_env = "TEAMS_APP_PASSWORD"
tenant_id_env = "TEAMS_TENANT_ID"

# 自定义 Webhook
[channels.webhook]
enabled = false
port = 8080
path = "/webhook"
secret_env = "WEBHOOK_SECRET"

# ═══════════════════════════════════════════════════════════════════════════
# 技能配置
# ═══════════════════════════════════════════════════════════════════════════

# 技能市场设置
[skills]
# 启用技能市场
# 默认: true
enabled = true

# 市场端点
# 默认: https://fanghub.openfang.io
marketplace_url = "https://fanghub.openfang.io"

# 额外市场注册表
additional_registries = [
    "https://clawhub.openfang.io",
]

# 技能安装目录
# 默认: ~/.openfang/skills/
install_dir = "/var/lib/openfang/skills"

# 启用自动更新
# 默认: true
auto_update = true

# 更新检查间隔（小时）
# 默认: 24
update_interval_hours = 24

# 允许的技能来源
allowed_sources = ["official", "verified", "community"]

# 禁止的技能 ID
blocked_skills = []

# 技能沙箱设置
[skills.sandbox]
# 启用 WASM 沙箱
# 默认: true
enabled = true

# 沙箱内存限制（MB）
# 默认: 128
memory_limit_mb = 256

# 沙箱 CPU 时间限制（毫秒）
# 默认: 5000
cpu_time_limit_ms = 10000

# 允许的系统调用
allowed_syscalls = ["read", "write", "open", "close", "exit"]

# ═══════════════════════════════════════════════════════════════════════════
# 工作流配置
# ═══════════════════════════════════════════════════════════════════════════

[workflows]
# 启用工作流引擎
# 默认: true
enabled = true

# 工作流定义目录
# 默认: ~/.openfang/workflows/
definitions_dir = "/var/lib/openfang/workflows"

# 最大并发工作流数
# 默认: 10
max_concurrent = 20

# 工作流执行超时（秒）
# 默认: 300
timeout_seconds = 600

# 启用持久化工作流状态
# 默认: true
persistent_state = true

# 触发器检查间隔（秒）
# 默认: 60
trigger_check_interval = 30

# ═══════════════════════════════════════════════════════════════════════════
# 迁移设置
# ═══════════════════════════════════════════════════════════════════════════

[migrate]
# 启用自动迁移
# 默认: true
enabled = true

# 迁移历史目录
# 默认: ~/.openfang/migrations/
history_dir = "/var/lib/openfang/migrations"

# 迁移源格式
# 支持: "openclaw"
source_format = "openclaw"

# 保留迁移后的原始文件
# 默认: true
keep_originals = true

# ═══════════════════════════════════════════════════════════════════════════
# 遥测和监控
# ═══════════════════════════════════════════════════════════════════════════

[telemetry]
# 启用遥测数据收集
# 默认: false
enabled = false

# 遥测端点
# 默认: https://telemetry.openfang.io
endpoint = "https://telemetry.openfang.io"

# 发送间隔（秒）
# 默认: 3600
interval_seconds = 3600

# 收集的指标类型
metrics = ["performance", "usage", "errors"]

# 匿名化用户数据
# 默认: true
anonymize = true

# ═══════════════════════════════════════════════════════════════════════════
# 调试设置
# ═══════════════════════════════════════════════════════════════════════════

[debug]
# 启用调试端点
# 默认: false（生产环境）/ true（开发环境）
enable_endpoints = false

# 调试端点路径前缀
# 默认: /debug
endpoint_prefix = "/debug"

# 启用性能分析
# 默认: false
enable_profiling = false

# 性能分析输出路径
# 默认: ~/.openfang/profiles/
profile_output_dir = "/var/lib/openfang/profiles"

# 启用详细日志记录
# 默认: false
verbose_logging = false

# 日志过滤器（Rust 追踪语法）
# 默认: openfang=info
log_filter = "openfang=debug,tower_http=debug"

# ═══════════════════════════════════════════════════════════════════════════
# 性能和优化
# ═══════════════════════════════════════════════════════════════════════════

[performance]
# 启用请求压缩
# 默认: true
enable_compression = true

# 压缩级别（1-9）
# 默认: 6
compression_level = 6

# 启用响应缓存
# 默认: true
enable_caching = true

# 缓存大小（MB）
# 默认: 100
cache_size_mb = 256

# 启用连接池
# 默认: true
enable_connection_pooling = true

# 连接池大小
# 默认: 100
connection_pool_size = 200

# 启用并行请求处理
# 默认: true
enable_parallel_processing = true

# 最大并行请求数
# 默认: 100
max_parallel_requests = 200

# ═══════════════════════════════════════════════════════════════════════════
# 备份和恢复
# ═══════════════════════════════════════════════════════════════════════════

[backup]
# 启用自动备份
# 默认: false
enabled = true

# 备份目录
# 默认: ~/.openfang/backups/
backup_dir = "/var/backups/openfang"

# 备份间隔（小时）
# 默认: 24
interval_hours = 12

# 保留的备份数量
# 默认: 7
retention_count = 14

# 备份包含的数据
backup_data = ["database", "config", "skills", "workflows"]

# 压缩备份
# 默认: true
compress = true

# 压缩级别
# 默认: 6
compression_level = 9

# 加密备份
# 默认: false
encrypt = true

# 加密密钥文件
encryption_key_file = "/etc/openfang/backup-key.pem"

# ═══════════════════════════════════════════════════════════════════════════
# 高可用性
# ═══════════════════════════════════════════════════════════════════════════

[ha]
# 启用高可用性模式
# 默认: false
enabled = false

# 节点 ID（每个节点必须唯一）
node_id = "node-1"

# 集群名称
cluster_name = "openfang-cluster"

# 集群节点
cluster_nodes = [
    "192.168.1.10:4200",
    "192.168.1.11:4200",
    "192.168.1.12:4200",
]

# 领导选举超时（毫秒）
# 默认: 10000
leader_election_timeout_ms = 5000

# 心跳间隔（毫秒）
# 默认: 1000
heartbeat_interval_ms = 500

# 数据复制因子
# 默认: 3
replication_factor = 3

# 自动故障转移
# 默认: true
auto_failover = true

# 故障转移超时（秒）
# 默认: 30
failover_timeout_seconds = 15

# ═══════════════════════════════════════════════════════════════════════════
# 自定义设置
# ═══════════════════════════════════════════════════════════════════════════

# 您可以在 [custom] 部分添加自己的自定义设置。
# 这些设置可用于自定义技能和插件。

[custom]
# 示例自定义设置
company_name = "Acme Corporation"
support_email = "support@acme.com"
documentation_url = "https://docs.acme.com"

# 自定义 API 端点
[custom.api_endpoints]
internal_api = "https://api.internal.acme.com"
legacy_api = "https://legacy-api.acme.com"

# 自定义功能标志
[custom.feature_flags]
enable_beta_features = false
enable_experimental_ui = true
enable_advanced_analytics = true

# 通知设置
[custom.notifications]
email_notifications = true
slack_webhook_url_env = "SLACK_NOTIFICATIONS_WEBHOOK"
discord_webhook_url_env = "DISCORD_NOTIFICATIONS_WEBHOOK"

# 日志转发
[custom.log_forwarding]
enabled = true
endpoint = "https://logs.acme.com/ingest"
api_key_env = "LOGS_API_KEY"
```

---

## 章节参考

### 顶级字段

这些字段直接在 TOML 文件的根级别设置，在任何章节之外。

#### `data_dir`

- **类型**: String（文件系统路径）
- **默认值**: `"~/.openfang"`（解析为主目录中的 `.openfang/`）
- **必需**: 否
- **描述**: OpenFang 存储其所有数据的主目录，包括 SQLite 数据库、已安装的技能、工作流定义、日志和临时文件。如果路径是相对路径，则相对于用户的主目录（`$HOME` 或 Windows 上的 `%USERPROFILE%`）解析。

**示例:**
```toml
data_dir = "/var/lib/openfang"
```

#### `log_level`

- **类型**: String（枚举）
- **默认值**: `"info"`
- **必需**: 否
- **描述**: 确定记录哪些消息。级别从低到高：
  - `"trace"`：极其详细的调试，包括函数进入/退出
  - `"debug"`：开发信息、变量状态、API 调用
  - `"info"`：一般操作消息、启动/关闭、配置加载
  - `"warn"`：潜在问题、不推荐的功能、降级
  - `"error"`：阻止功能完成的失败

  日志系统包括所有等于或高于设置级别的消息。生产环境通常使用 `"info"` 或 `"warn"`。开发期间使用 `"debug"`。

**示例:**
```toml
log_level = "warn"
```

#### `log_format`

- **类型**: String（枚举）
- **默认值**: `"pretty"`（开发）或 `"json"`（发布）
- **必需**: 否
- **描述**: 日志行的输出格式：
  - `"pretty"`：人类可读的格式，带有 ANSI 颜色、对齐的列、时间戳和详细上下文。非常适合终端使用。
  - `"json"`：JSON 对象流，每行一个对象。包含用于结构化解析的字段（timestamp、level、target、message、span、fields）。非常适合日志聚合系统（ELK、Datadog、Splunk）。

**示例:**
```toml
log_format = "json"
```

#### `development`

- **类型**: Boolean
- **默认值**: `false`
- **必需**: 否
- **描述**: 启用开发模式，这会改变 OpenFang 的几个行为：
  - **热重载**：监控配置文件、技能定义和工作流的更改，并在不重新启动的情况下应用更新
  - **详细错误**：错误响应包含完整堆栈跟踪、内部错误消息和上下文
  - **调试端点**：启用 `/debug/` 路由，显示内部状态、指标和 pprof 分析数据
  - **不安全模式**：放松某些安全限制，允许未签名的技能、未经验证的 TLS 证书和调试命令
  - **性能分析**：启用 CPU 和内存分析，输出到 `debug/profiles/`

  **警告**：绝不要在生产环境中启用此功能。它创建安全漏洞，暴露敏感信息，并允许未经授权的访问。

**示例:**
```toml
development = true
```

---

其余章节请参考完整英文文档。配置参考非常详细，涵盖了所有可用选项。
