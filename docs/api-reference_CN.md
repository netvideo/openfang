# API 参考

OpenFang 在守护进程运行时暴露 REST API、WebSocket 端点和 SSE 流。默认监听地址为 `http://127.0.0.1:4200`。

所有响应都包含安全标头（CSP、X-Frame-Options、X-Content-Type-Options、HSTS），并受到 GCRA 成本感知速率限制器的保护，具有每 IP 令牌桶跟踪和自动过时条目清理。OpenFang 实现了 16 个安全系统，包括 Merkle 审计跟踪、污点跟踪、WASM 双计量、Ed25519 清单签名、SSRF 防护、子进程沙箱和密钥零化。

---

## 目录

- [认证](#认证)
- [代理端点](#代理端点)
- [工作流端点](#工作流端点)
- [触发器端点](#触发器端点)
- [内存端点](#内存端点)
- [通道端点](#通道端点)
- [模板端点](#模板端点)
- [系统端点](#系统端点)
- [模型目录端点](#模型目录端点)
- [提供商配置端点](#提供商配置端点)
- [技能与市场端点](#技能与市场端点)
- [ClawHub 端点](#clawhub-端点)
- [MCP 与 A2A 协议端点](#mcp-与-a2a-协议端点)
- [审计与安全端点](#审计与安全端点)
- [使用与分析端点](#使用与分析端点)
- [迁移端点](#迁移端点)
- [会话管理端点](#会话管理端点)
- [WebSocket 协议](#websocket-协议)
- [SSE 流](#sse-流)
- [OpenAI 兼容 API](#openai-兼容-api)
- [错误响应](#错误响应)

---

## 认证

当在 `config.toml` 中配置 API 密钥时，所有端点（除了 `/api/health` 和 `/`）都需要 Bearer 令牌：

```
Authorization: Bearer <your-api-key>
```

### 设置 API 密钥

添加到 `~/.openfang/config.toml`：

```toml
api_key = "your-secret-api-key"
```

### 无认证

如果 `api_key` 为空或未设置，API 无需认证即可访问。在此模式下 CORS 仅限于 localhost 来源。

### 公开端点（无需认证）

- `GET /api/health`
- `GET /` (WebChat UI)

---

## 代理端点

### GET /api/agents

列出所有正在运行的代理。

**响应** `200 OK`：

```json
[
  {
    "id": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
    "name": "hello-world",
    "state": "Running",
    "created_at": "2025-01-15T10:30:00Z",
    "model_provider": "groq",
    "model_name": "llama-3.3-70b-versatile"
  }
]
```

### GET /api/agents/{id}

返回单个代理的详细信息。

**响应** `200 OK`：

```json
{
  "id": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
  "name": "hello-world",
  "state": "Running",
  "created_at": "2025-01-15T10:30:00Z",
  "session_id": "s1b2c3d4-...",
  "model": {
    "provider": "groq",
    "model": "llama-3.3-70b-versatile"
  },
  "capabilities": {
    "tools": ["file_read", "file_list", "web_fetch"],
    "network": []
  },
  "description": "A friendly greeting agent",
  "tags": []
}
```

### POST /api/agents

从 TOML 清单生成新代理。

**请求体** (JSON)：

```json
{
  "manifest_toml": "name = \"my-agent\"\nversion = \"0.1.0\"\ndescription = \"Test agent\"\nauthor = \"me\"\nmodule = \"builtin:chat\"\n\n[model]\nprovider = \"groq\"\nmodel = \"llama-3.3-70b-versatile\"\n\n[capabilities]\ntools = [\"file_read\", \"web_fetch\"]\nmemory_read = [\"*\"]\nmemory_write = [\"self.*\"]\n"
}
```

**响应** `201 Created`：

```json
{
  "agent_id": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
  "name": "my-agent"
}
```
