# 通道适配器

OpenFang 通过**40 个通道适配器**连接到消息平台，允许用户跨每个主要通信平台与他们的智能体交互。适配器涵盖消费者消息、企业协作、社交媒体、社区平台、隐私优先协议和通用 webhook。

所有适配器共享一个共同基础：通过 `watch::channel` 优雅关闭、连接失败时的指数退避、使用 `Zeroizing<String>` 保护密钥、针对平台限制的自动消息拆分、按通道模型/提示词覆盖、DM/群组策略执行、每用户速率限制以及输出格式化（Markdown、TelegramHTML、SlackMrkdwn、PlainText）。

## 目录

- [所有 40 个通道](#所有-40-个通道)
- [通道配置](#通道配置)
- [通道覆盖](#通道覆盖)
- [格式化器、速率限制器和策略](#格式化器速率限制器和策略)
- [Telegram](#telegram)
- [Discord](#discord)
- [Slack](#slack)
- [WhatsApp](#whatsapp)
- [Signal](#signal)
- [Matrix](#matrix)
- [Email](#email)
- [WebChat（内置）](#webchat内置)
- [智能体路由](#智能体路由)
- [编写自定义适配器](#编写自定义适配器)

---

## 所有 40 个通道

### 核心（7 个）

| 通道 | 协议 | 环境变量 | ChannelType 变体 |
|---------|----------|----------|---------------------|
| Telegram | Bot API 长轮询 | `TELEGRAM_BOT_TOKEN` | `Telegram` |
| Discord | Gateway WebSocket v10 | `DISCORD_BOT_TOKEN` | `Discord` |
| Slack | Socket Mode WebSocket | `SLACK_BOT_TOKEN`, `SLACK_APP_TOKEN` | `Slack` |
| WhatsApp | Cloud API webhook | `WA_ACCESS_TOKEN`, `WA_PHONE_ID`, `WA_VERIFY_TOKEN` | `WhatsApp` |
| Signal | signal-cli REST/JSON-RPC | _（系统服务）_ | `Signal` |
| Matrix | Client-Server API `/sync` | `MATRIX_TOKEN` | `Matrix` |
| Email | IMAP + SMTP | `EMAIL_PASSWORD` | `Email` |

### 企业（8 个）

| 通道 | 协议 | 环境变量 | ChannelType 变体 |
|---------|----------|----------|---------------------|
| Microsoft Teams | Bot Framework v3 webhook + OAuth2 | `TEAMS_APP_ID`, `TEAMS_APP_SECRET` | `Teams` |
| Mattermost | WebSocket + REST v4 | `MATTERMOST_TOKEN`, `MATTERMOST_URL` | `Mattermost` |
| Google Chat | 服务账户 webhook | `GOOGLE_CHAT_SA_KEY`, `GOOGLE_CHAT_SPACE` | `Custom("google_chat")` |
| Webex | Bot SDK WebSocket | `WEBEX_BOT_TOKEN` | `Custom("webex")` |
| Feishu / Lark | 开放平台 webhook | `FEISHU_APP_ID`, `FEISHU_APP_SECRET` | `Custom("feishu")` |
| Rocket.Chat | REST 轮询 | `ROCKETCHAT_TOKEN`, `ROCKETCHAT_URL` | `Custom("rocketchat")` |
| Zulip | 事件队列长轮询 | `ZULIP_EMAIL`, `ZULIP_API_KEY`, `ZULIP_URL` | `Custom("zulip")` |
| XMPP | XMPP 协议（存根） | `XMPP_JID`, `XMPP_PASSWORD`, `XMPP_SERVER` | `Custom("xmpp")` |

### 社交（8 个）

| 通道 | 协议 | 环境变量 | ChannelType 变体 |
|---------|----------|----------|---------------------|
| LINE | Messaging API webhook | `LINE_CHANNEL_SECRET`, `LINE_CHANNEL_TOKEN` | `Custom("line")` |
| Viber | Bot API webhook | `VIBER_AUTH_TOKEN` | `Custom("viber")` |
| Facebook Messenger | Platform API webhook | `MESSENGER_PAGE_TOKEN`, `MESSENGER_VERIFY_TOKEN` | `Custom("messenger")` |
| Mastodon | Streaming API WebSocket | `MASTODON_TOKEN`, `MASTODON_INSTANCE` | `Custom("mastodon")` |
| Bluesky | AT Protocol WebSocket | `BLUESKY_HANDLE`, `BLUESKY_APP_PASSWORD` | `Custom("bluesky")` |
| Reddit | OAuth2 轮询 | `REDDIT_CLIENT_ID`, `REDDIT_CLIENT_SECRET`, `REDDIT_USERNAME`, `REDDIT_PASSWORD` | `Custom("reddit")` |
| LinkedIn | Messaging API 轮询 | `LINKEDIN_ACCESS_TOKEN` | `Custom("linkedin")` |
| Twitch | IRC 网关 | `TWITCH_TOKEN`, `TWITCH_CHANNEL` | `Custom("twitch")` |

### 社区（6 个）

| 通道 | 协议 | 环境变量 | ChannelType 变体 |
|---------|----------|----------|---------------------|
| IRC | 原始 TCP PRIVMSG | `IRC_SERVER`, `IRC_NICK`, `IRC_PASSWORD` | `Custom("irc")` |
| Guilded | WebSocket | `GUILDED_BOT_TOKEN` | `Custom("guilded")` |
| Revolt | WebSocket | `REVOLT_BOT_TOKEN` | `Custom("revolt")` |
| Keybase | Bot API 轮询 | `KEYBASE_USERNAME`, `KEYBASE_PAPERKEY` | `Custom("keybase")` |
| Discourse | REST 轮询 | `DISCOURSE_API_KEY`, `DISCOURSE_URL` | `Custom("discourse")` |
| Gitter | Streaming API | `GITTER_TOKEN` | `Custom("gitter")` |

### 自托管（1 个）

| 通道 | 协议 | 环境变量 | ChannelType 变体 |
|---------|----------|----------|---------------------|
| Nextcloud Talk | REST 轮询 | `NEXTCLOUD_TOKEN`, `NEXTCLOUD_URL` | `Custom("nextcloud")` |

### 隐私（3 个）

| 通道 | 协议 | 环境变量 | ChannelType 变体 |
|---------|----------|----------|---------------------|
| Threema | Gateway API webhook | `THREEMA_ID`, `THREEMA_SECRET` | `Custom("threema")` |
| Nostr | NIP-01 relay WebSocket | `NOSTR_PRIVATE_KEY`, `NOSTR_RELAY` | `Custom("nostr")` |
| Mumble | TCP 文本协议 | `MUMBLE_SERVER`, `MUMBLE_USERNAME`, `MUMBLE_PASSWORD` | `Custom("mumble")` |

### 工作场所（4 个）

| 通道 | 协议 | 环境变量 | ChannelType 变体 |
|---------|----------|----------|---------------------|
| Pumble | Webhook | `PUMBLE_WEBHOOK_URL`, `PUMBLE_TOKEN` | `Custom("pumble")` |
| Flock | Webhook | `FLOCK_TOKEN` | `Custom("flock")` |
| Twist | API v3 轮询 | `TWIST_TOKEN` | `Custom("twist")` |
| DingTalk | Robot API webhook | `DINGTALK_TOKEN`, `DINGTALK_SECRET` | `Custom("dingtalk")` |

### 通知（2 个）

| 通道 | 协议 | 环境变量 | ChannelType 变体 |
|---------|----------|----------|---------------------|
| ntfy | SSE 发布/订阅 | `NTFY_TOPIC`, `NTFY_SERVER` | `Custom("ntfy")` |
| Gotify | WebSocket | `GOTIFY_TOKEN`, `GOTIFY_URL` | `Custom("gotify")` |

### 集成（1 个）

| 通道 | 协议 | 环境变量 | ChannelType 变体 |
|---------|----------|----------|---------------------|
| Webhook | 带 HMAC-SHA256 的通用 HTTP | `WEBHOOK_URL`, `WEBHOOK_SECRET` | `Custom("webhook")` |

---

## 通道配置

所有通道配置位于 `~/.openfang/config.toml` 的 `[channels]` 部分下。每个通道是一个子部分：

```toml
[channels.telegram]
bot_token_env = "TELEGRAM_BOT_TOKEN"
default_agent = "assistant"
allowed_users = ["123456789"]

[channels.discord]
bot_token_env = "DISCORD_BOT_TOKEN"
default_agent = "coder"

[channels.slack]
bot_token_env = "SLACK_BOT_TOKEN"
app_token_env = "SLACK_APP_TOKEN"
default_agent = "ops"

# 企业示例
[channels.teams]
app_id_env = "TEAMS_APP_ID"
app_secret_env = "TEAMS_APP_SECRET"
default_agent = "ops"

# 社交示例
[channels.mastodon]
token_env = "MASTODON_TOKEN"
instance = "https://mastodon.social"
default_agent = "social-media"
```

### 通用字段

- `bot_token_env` / `token_env` -- 保存机器人/访问令牌的环境变量。OpenFang 在启动时从此环境变量读取令牌。所有密钥都存储为 `Zeroizing<String>` 并在丢弃时从内存中擦除。
- `default_agent` -- 当没有特定路由适用时接收消息的代理名称（或 ID）。
- `allowed_users` -- 允许交互的可选平台用户 ID 列表。空表示允许所有。
- `overrides` -- 可选的每通道行为覆盖（见下文[通道覆盖](#通道覆盖)）。

### 环境变量参考（核心通道）

| 通道 | 必需环境变量 |
|---------|-------------------|
| Telegram | `TELEGRAM_BOT_TOKEN` |
| Discord | `DISCORD_BOT_TOKEN` |
| Slack | `SLACK_BOT_TOKEN`, `SLACK_APP_TOKEN` |
| WhatsApp | `WA_ACCESS_TOKEN`, `WA_PHONE_ID`, `WA_VERIFY_TOKEN` |
| Matrix | `MATRIX_TOKEN` |
| Email | `EMAIL_PASSWORD` |

所有其他通道的环境变量列在上方的[所有 40 个通道](#所有-40-个通道)表中。

---

## 通道覆盖

每个通道适配器都支持 `ChannelOverrides`，允许你自定义每个通道的行为而无需修改代理清单。在 `config.toml` 中添加 `[channels.<name>.overrides]` 部分：

```toml
[channels.telegram.overrides]
model = "gemini-2.5-flash"
system_prompt = "你是一个简洁的 Telegram 助手。回复保持在 200 字以内。"
dm_policy = "respond"
group_policy = "mention_only"
rate_limit_per_user = 10
threading = true
output_format = "telegram_html"
usage_footer = "compact"
```

### 覆盖字段

| 字段 | 类型 | 默认值 | 描述 |
|-------|------|---------|-------------|
| `model` | `Option<String>` | 代理默认值 | 覆盖此通道的 LLM 模型。 |
| `system_prompt` | `Option<String>` | 代理默认值 | 覆盖此通道的系统提示词。 |
| `dm_policy` | `DmPolicy` | `Respond` | 如何处理私信。 |
| `group_policy` | `GroupPolicy` | `MentionOnly` | 如何处理群组/频道消息。 |
| `rate_limit_per_user` | `u32` | `0`（无限制） | 每用户每分钟最大消息数。 |
| `threading` | `bool` | `false` | 将回复作为话题响应发送（支持的平台）。 |
| `output_format` | `Option<OutputFormat>` | `Markdown` | 此通道的输出格式。 |
| `usage_footer` | `Option<UsageFooterMode>` | None | 是否将 Token 使用量附加到响应。 |

---

## 格式化器、速率限制器和策略

### 输出格式化器

`formatter` 模块（`openfang-channels/src/formatter.rs`）将 LLM 的 Markdown 输出转换为平台原生格式：

| OutputFormat | 目标 | 说明 |
|-------------|--------|-------|
| `Markdown` | 标准 Markdown | 默认；原样传递。 |
| `TelegramHtml` | Telegram HTML 子集 | 转换 `**bold**` 为 `<b>`，`` `code` `` 为 `<code>` 等。 |
| `SlackMrkdwn` | Slack mrkdwn | 转换 `**bold**` 为 `*bold*`，链接为 `<url\|text>` 等。 |
| `PlainText` | 纯文本 | 剥离所有格式。 |

### 每用户速率限制器

`ChannelRateLimiter`（`openfang-channels/src/rate_limiter.rs`）使用 `DashMap` 跟踪每用户消息计数。当在通道的覆盖上设置 `rate_limit_per_user` 时，限制器强制执行每分钟 N 条消息的滑动窗口上限。超出消息收到礼貌拒绝。

### DM 策略

控制适配器如何处理私信：

| DmPolicy | 行为 |
|----------|----------|
| `Respond` | 回复所有私信（默认）。 |
| `AllowedOnly` | 只回复来自 `allowed_users` 的私信。 |
| `Ignore` | 静默丢弃所有私信。 |

### 群组策略

控制适配器如何处理群组聊天、频道和房间中的消息：

| GroupPolicy | 行为 |
|-------------|----------|
| `All` | 回复群组中的每条消息。 |
| `MentionOnly` | 只在机器人被 @提及时回复（默认）。 |
| `CommandsOnly` | 只回复 `/command` 消息。 |
| `Ignore` | 静默忽略所有群组消息。 |

策略执行发生在 `dispatch_message()` 中，消息到达代理循环之前。这意味着被忽略的消息消耗零 LLM Token。

---

## Telegram

### 先决条件

- Telegram 机器人令牌（来自 [@BotFather](https://t.me/botfather)）

### 设置

1. 打开 Telegram 并向 `@BotFather` 发送消息。
2. 发送 `/newbot` 并按照提示创建新机器人。
3. 复制机器人令牌。
4. 设置环境变量：

```bash
export TELEGRAM_BOT_TOKEN=123456789:ABCdefGHIjklMNOpqrsTUVwxyz
```

5. 添加到配置：

```toml
[channels.telegram]
bot_token_env = "TELEGRAM_BOT_TOKEN"
default_agent = "assistant"
# 可选：限制特定 Telegram 用户 ID
# allowed_users = ["123456789"]

[channels.telegram.overrides]
# 可选：Telegram 原生 HTML 格式化
# output_format = "telegram_html"
# group_policy = "mention_only"
```

6. 重启守护进程：

```bash
openfang start
```

### 工作原理

Telegram 适配器使用 `getUpdates` API 通过长轮询。它每隔几秒轮询一次，30 秒长轮询超时。API 失败时，它应用指数退避（从 1 秒开始，最多 60 秒）。关闭通过 `watch::channel` 协调。

来自授权用户的消息被转换为 `ChannelMessage` 事件并路由到配置的代理。响应通过 `sendMessage` API 发送回。长响应使用共享的 `split_message()` 工具自动拆分为多条消息，以遵守 Telegram 的 4096 字符限制。

### 交互式设置

```bash
openfang channel setup telegram
```

这将引导你交互式完成设置。

---

## Discord

### 先决条件

- Discord 应用程序和机器人（来自 [Discord Developer Portal](https://discord.com/developers/applications)）

### 设置

1. 前往 [Discord Developer Portal](https://discord.com/developers/applications)。
2. 点击 "New Application" 并命名。
3. 进入 **Bot** 部分并点击 "Add Bot"。
4. 复制机器人令牌。
5. 在 **Privileged Gateway Intents** 下启用：
   - **Message Content Intent**（需要读取消息内容）
6. 进入 **OAuth2 > URL Generator**：
   - 选择 scopes: `bot`
   - 选择 permissions: `Send Messages`, `Read Message History`
   - 复制生成的 URL 并打开它以邀请机器人到你的服务器。
7. 设置环境变量：

```bash
export DISCORD_BOT_TOKEN=MTIzNDU2Nzg5.ABCDEF.ghijklmnop
```

8. 添加到配置：

```toml
[channels.discord]
bot_token_env = "DISCORD_BOT_TOKEN"
default_agent = "coder"
```

9. 重启守护进程。

### 工作原理

Discord 适配器通过 WebSocket（v10）连接到 Discord Gateway。它监听 `MESSAGE_CREATE` 事件并将消息路由到配置的代理。响应通过 REST API 的 `channels/{id}/messages` 端点发送。

适配器自动处理 Gateway 重新连接、心跳和会话恢复。

---

## Slack

### 先决条件

- 启用了 Socket Mode 的 Slack 应用

### 设置

1. 前往 [Slack API](https://api.slack.com/apps) 并点击 "Create New App" > "From Scratch"。
2. 启用 **Socket Mode**（Settings > Socket Mode）：
   - 生成具有 scope `connections:write` 的 App-Level Token。
   - 复制令牌（`xapp-...`）。
3. 进入 **OAuth & Permissions** 并添加 Bot Token Scopes：
   - `chat:write`
   - `app_mentions:read`
   - `im:history`
   - `im:read`
   - `im:write`
4. 将应用安装到你的工作区。
5. 复制 Bot User OAuth Token（`xoxb-...`）。
6. 设置环境变量：

```bash
export SLACK_APP_TOKEN=xapp-1-...
export SLACK_BOT_TOKEN=xoxb-...
```

7. 添加到配置：

```toml
[channels.slack]
bot_token_env = "SLACK_BOT_TOKEN"
app_token_env = "SLACK_APP_TOKEN"
default_agent = "ops"

[channels.slack.overrides]
# 可选：Slack 原生 mrkdwn 格式化
# output_format = "slack_mrkdwn"
# threading = true
```

8. 重启守护进程。

### 工作原理

Slack 适配器使用 Socket Mode，它与 Slack 的服务器建立 WebSocket 连接。这避免了需要公共 webhook URL。适配器接收事件（应用提及、私信）并将它们路由到配置的代理。响应通过 `chat.postMessage` Web API 发布。当 `threading = true` 时，回复通过 `thread_ts` 发送到消息的话题。

---

## WhatsApp

### 先决条件

- 具有 WhatsApp Cloud API 访问权限的 Meta Business 账户

### 设置

1. 前往 [Meta for Developers](https://developers.facebook.com/)。
2. 创建 Business App。
3. 添加 WhatsApp 产品。
4. 设置测试电话号码（或使用生产号码）。
5. 复制：
   - 电话号码 ID
   - 永久访问令牌
   - 选择验证令牌（你选择的任意字符串）
6. 设置环境变量：

```bash
export WA_PHONE_ID=123456789012345
export WA_ACCESS_TOKEN=EAABs...
export WA_VERIFY_TOKEN=my-secret-verify-token
```

7. 添加到配置：

```toml
[channels.whatsapp]
mode = "cloud_api"
phone_number_id_env = "WA_PHONE_ID"
access_token_env = "WA_ACCESS_TOKEN"
verify_token_env = "WA_VERIFY_TOKEN"
webhook_port = 8443
default_agent = "assistant"
```

8. 在 Meta 仪表板中设置 webhook，指向服务器的公共 URL：
   - URL: `https://your-domain.com:8443/webhook/whatsapp`
   - 验证令牌：你上面选择的值
   - 订阅：`messages`

9. 重启守护进程。

### 工作原理

WhatsApp 适配器运行 HTTP 服务器（在配置的 `webhook_port` 上）接收来自 WhatsApp Cloud API 的传入 webhook。它处理 webhook 验证（GET）和消息接收（POST）。响应通过 Cloud API 的 `messages` 端点发送。

---

## Signal

### 先决条件

- Signal CLI 已安装并链接到电话号码

### 设置

1. 安装 [signal-cli](https://github.com/AsamK/signal-cli)。
2. 注册或链接电话号码。
3. 添加到配置：

```toml
[channels.signal]
signal_cli_path = "/usr/local/bin/signal-cli"
phone_number = "+1234567890"
default_agent = "assistant"
```

4. 重启守护进程。

### 工作原理

Signal 适配器在守护进程模式下将 `signal-cli` 作为子进程生成，并通过 JSON-RPC 通信。从 signal-cli 输出流读取传入消息并路由到配置的代理。

---

## Matrix

### 先决条件

- Matrix  homeserver 账户和访问令牌

### 设置

1. 在你的 Matrix  homeserver 上创建机器人账户。
2. 生成访问令牌。
3. 设置环境变量：

```bash
export MATRIX_TOKEN=syt_...
```

4. 添加到配置：

```toml
[channels.matrix]
homeserver_url = "https://matrix.org"
access_token_env = "MATRIX_TOKEN"
user_id = "@openfang-bot:matrix.org"
default_agent = "assistant"
```

5. 邀请机器人到你希望它监控的房间。
6. 重启守护进程。

### 工作原理

Matrix 适配器使用 Matrix Client-Server API。它使用长轮询（`/sync` 带超时）与 homeserver 同步，并处理来自已加入房间的新消息。响应通过 `/rooms/{roomId}/send` 端点发送。

---

## Email

### 先决条件

- 具有 IMAP 和 SMTP 访问权限的电子邮件账户

### 设置

1. 对于 Gmail，创建 [应用密码](https://myaccount.google.com/apppasswords)。
2. 设置环境变量：

```bash
export EMAIL_PASSWORD=abcd-efgh-ijkl-mnop
```

3. 添加到配置：

```toml
[channels.email]
imap_host = "imap.gmail.com"
imap_port = 993
smtp_host = "smtp.gmail.com"
smtp_port = 587
username = "you@gmail.com"
password_env = "EMAIL_PASSWORD"
poll_interval = 30
default_agent = "email-assistant"
```

4. 重启守护进程。

### 工作原理

电子邮件适配器以配置的间隔轮询 IMAP 收件箱。新邮件被解析（主题 + 正文）并路由到配置的代理。响应通过 SMTP 作为回复邮件发送，保留主题行线程。

---

## WebChat（内置）

WebChat UI 嵌入在守护进程中，无需配置。当守护进程运行时：

```
http://127.0.0.1:4200/
```

功能：
- 通过 WebSocket 实时聊天
- 流式响应（文本增量到达时）
- 代理选择（在运行中的代理之间切换）
- Token 使用量显示
- 本地主机无需认证（受 CORS 保护）

---

## 智能体路由

`AgentRouter` 决定哪个代理接收传入消息。路由逻辑是：

1. **每通道默认**：每个通道配置都有一个 `default_agent` 字段。来自该通道的消息进入该代理。
2. **用户-代理绑定**：如果用户之前已与特定代理关联（通过命令或配置），来自该用户的消息将路由到该代理。
3. **命令前缀**：用户可以通过在聊天中发送如 `/agent coder` 的命令来切换代理。后续消息将路由到 "coder" 代理。
4. **回退**：如果没有路由适用，消息进入第一个可用代理。

---

## 编写自定义适配器

要添加对新消息平台的支持，实现 `ChannelAdapter` trait。该 trait 定义在 `crates/openfang-channels/src/types.rs` 中。

### ChannelAdapter Trait

```rust
pub trait ChannelAdapter: Send + Sync {
    /// 此适配器的人类可读名称。
    fn name(&self) -> &str;

    /// 此适配器处理的通道类型。
    fn channel_type(&self) -> ChannelType;

    /// 开始接收消息。返回传入消息流。
    async fn start(
        &self,
    ) -> Result<Pin<Box<dyn Stream<Item = ChannelMessage> + Send>>, Box<dyn std::error::Error>>;

    /// 向此通道上的用户发送响应。
    async fn send(
        &self,
        user: &ChannelUser,
        content: ChannelContent,
    ) -> Result<(), Box<dyn std::error::Error>>;

    /// 发送输入指示器（可选 -- 默认无操作）。
    async fn send_typing(&self, _user: &ChannelUser) -> Result<(), Box<dyn std::error::Error>> {
        Ok(())
    }

    /// 停止适配器并清理资源。
    async fn stop(&self) -> Result<(), Box<dyn std::error::Error>>;

    /// 获取此适配器的当前健康状态（可选 -- 默认返回断开）。
    fn status(&self) -> ChannelStatus {
        ChannelStatus::default()
    }

    /// 作为话题回复发送响应（可选 -- 默认回退到 `send()`）。
    async fn send_in_thread(
        &self,
        user: &ChannelUser,
        content: ChannelContent,
        _thread_id: &str,
    ) -> Result<(), Box<dyn std::error::Error>> {
        self.send(user, content).await
    }
}
```

### 1. 定义你的适配器

创建 `crates/openfang-channels/src/myplatform.rs`：

```rust
use crate::types::{
    ChannelAdapter, ChannelContent, ChannelMessage, ChannelStatus, ChannelType, ChannelUser,
};
use futures::stream::{self, Stream};
use std::pin::Pin;
use tokio::sync::watch;
use zeroize::Zeroizing;

pub struct MyPlatformAdapter {
    token: Zeroizing<String>,
    client: reqwest::Client,
    shutdown: watch::Receiver<bool>,
}

impl MyPlatformAdapter {
    pub fn new(token: String, shutdown: watch::Receiver<bool>) -> Self {
        Self {
            token: Zeroizing::new(token),
            client: reqwest::Client::new(),
            shutdown,
        }
    }
}

impl ChannelAdapter for MyPlatformAdapter {
    fn name(&self) -> &str {
        "MyPlatform"
    }

    fn channel_type(&self) -> ChannelType {
        ChannelType::Custom("myplatform".to_string())
    }

    async fn start(
        &self,
    ) -> Result<Pin<Box<dyn Stream<Item = ChannelMessage> + Send>>, Box<dyn std::error::Error>> {
        // 返回产生 ChannelMessage 项的流。
        // 使用 self.shutdown 检测守护进程何时停止。
        // 在连接失败时应用指数退避。
        let stream = stream::empty(); // 替换为你的轮询/WebSocket 逻辑
        Ok(Box::pin(stream))
    }

    async fn send(
        &self,
        user: &ChannelUser,
        content: ChannelContent,
    ) -> Result<(), Box<dyn std::error::Error>> {
        // 将响应发送回平台。
        // 如果平台有消息长度限制，使用 split_message()。
        // 使用 self.client 和 self.token 调用平台的 API。
        Ok(())
    }

    async fn stop(&self) -> Result<(), Box<dyn std::error::Error>> {
        // 干净关闭：关闭连接，停止轮询。
        Ok(())
    }

    fn status(&self) -> ChannelStatus {
        ChannelStatus::default()
    }
}
```

**新适配器的关键点：**
- 对通道类型使用 `ChannelType::Custom("myplatform".to_string())`。只有 9 个最常见的通道有命名的 `ChannelType` 变体（`Telegram`、`WhatsApp`、`Slack`、`Discord`、`Signal`、`Matrix`、`Email`、`Teams`、`Mattermost`）。所有其他使用 `Custom(String)`。
- 将密钥包装在 `Zeroizing<String>` 中，以便在丢弃时从内存中擦除。
- 接受 `watch::Receiver<bool>` 以与守护进程协调关闭。
- 在连接失败时具有弹性，使用指数退避。
- 对具有消息长度限制的平台使用共享的 `split_message(text, max_len)` 工具。

### 2. 注册模块

在 `crates/openfang-channels/src/lib.rs` 中：

```rust
pub mod myplatform;
```

### 3. 将其接入桥接

在 `crates/openfang-api/src/channel_bridge.rs` 中，为适配器添加初始化逻辑，与现有适配器一起。

### 4. 添加配置支持

在 `openfang-types` 中，添加配置结构体：

```rust
#[derive(Debug, Clone, Default, Serialize, Deserialize)]
pub struct MyPlatformConfig {
    pub token_env: String,
    pub default_agent: Option<String>,
    #[serde(default)]
    pub overrides: ChannelOverrides,
}
```

将其添加到 `ChannelsConfig` 结构体和 `config.toml` 解析中。`overrides` 字段为你的通道自动提供对模型/提示词覆盖、DM/群组策略、速率限制、线程和输出格式选择的支持。

### 5. 添加 CLI 设置向导

在 `crates/openfang-cli/src/main.rs` 中，为平台的分步说明添加一个 case 到 `cmd_channel_setup`。

### 6. 测试

编写集成测试。使用 `ChannelMessage` 类型模拟传入消息，无需连接到真实平台。
