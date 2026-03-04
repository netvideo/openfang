# OpenFang 安全架构

本文档为 OpenFang 智能体操作系统中的每个安全系统提供全面的技术参考。所有结构体名称、函数签名、常量值和算法描述均直接来自源代码。

---

## 目录

1.  [安全概述](#1-安全概述)
2.  [基于能力的安全](#2-基于能力的安全)
3.  [WASM 双重计量](#3-wasm-双重计量)
4.  [Merkle 哈希链审计追踪](#4-merkle-哈希链审计追踪)
5.  [信息流污点追踪](#5-信息流污点追踪)
6.  [Ed25519 清单签名](#6-ed25519-清单签名)
7.  [SSRF 防护](#7-ssrf-防护)
8.  [密钥清零](#8-密钥清零)
9.  [OFP 双向认证](#9-ofp-双向认证)
10. [安全响应头](#10-安全响应头)
11. [GCRA 速率限制器](#11-gcra-速率限制器)
12. [路径遍历防护](#12-路径遍历防护)
13. [子进程沙箱](#13-子进程沙箱)
14. [提示词注入扫描器](#14-提示词注入扫描器)
15. [循环守卫](#15-循环守卫)
16. [会话修复](#16-会话修复)
17. [健康端点脱敏](#17-健康端点脱敏)
18. [安全配置](#18-安全配置)
19. [安全依赖](#19-安全依赖)

---

## 1. 安全概述

OpenFang 实现了**纵深防御**安全。没有任何单一机制被信任为唯一的保护者；相反，16 个独立系统形成重叠层，任何一层的故障都会被其他层捕获。

| # | 系统 | 包 | 防护对象 |
|---|---|---|---|
| 1 | 基于能力的安全 | `openfang-types` | 智能体的未授权操作 |
| 2 | WASM 双重计量 | `openfang-runtime` | 无限循环、CPU 拒绝服务 |
| 3 | Merkle 审计追踪 | `openfang-runtime` | 被篡改的审计日志 |
| 4 | 污点追踪 | `openfang-types` | 提示词注入、数据外泄 |
| 5 | Ed25519 清单签名 | `openfang-types` | 供应链攻击 |
| 6 | SSRF 防护 | `openfang-runtime` | 服务器端请求伪造 |
| 7 | 密钥清零 | `openfang-runtime`, `openfang-channels` | 内存取证、密钥泄露 |
| 8 | OFP 双向认证 | `openfang-wire` | 未授权的对等连接 |
| 9 | 安全响应头 | `openfang-api` | XSS、点击劫持、MIME 嗅探 |
| 10 | GCRA 速率限制器 | `openfang-api` | API 滥用、拒绝服务 |
| 11 | 路径遍历防护 | `openfang-runtime` | 目录遍历攻击 |
| 12 | 子进程沙箱 | `openfang-runtime` | 通过子进程泄露密钥 |
| 13 | 提示词注入扫描器 | `openfang-skills` | 恶意技能提示词 |
| 14 | 循环守卫 | `openfang-runtime` | 卡住的智能体工具循环 |
| 15 | 会话修复 | `openfang-runtime` | 损坏的 LLM 对话历史 |
| 16 | 健康端点脱敏 | `openfang-api` | 信息泄露 |

---

## 2. 基于能力的安全

**来源：** `openfang-types/src/capability.rs`

OpenFang 使用基于能力的安全。智能体只能执行被显式授予权限的操作。能力在智能体创建后不可变，并在内核级别强制执行。

### 2.1 能力变体

`Capability` 枚举定义了每种权限类型：

```rust
pub enum Capability {
    // 文件系统
    FileRead(String),       // 通配符模式，例如 "/data/*"
    FileWrite(String),

    // 网络
    NetConnect(String),     // 主机:端口模式，例如 "*.openai.com:443"
    NetListen(u16),

    // 工具
    ToolInvoke(String),     // 特定工具 ID
    ToolAll,                // 所有工具（危险）

    // LLM
    LlmQuery(String),
    LlmMaxTokens(u64),

    // 智能体交互
    AgentSpawn,
    AgentMessage(String),
    AgentKill(String),

    // 内存
    MemoryRead(String),
    MemoryWrite(String),

    // Shell
    ShellExec(String),
    EnvRead(String),

    // OFP 线协议
    OfpDiscover,
    OfpConnect(String),
    OfpAdvertise,

    // 经济
    EconSpend(f64),
    EconEarn,
    EconTransfer(String),
}
```

### 2.2 模式匹配

`capability_matches(granted, required)` 函数实现类似 glob 的匹配：

- **完全匹配：** `"api.openai.com:443"` 匹配 `"api.openai.com:443"`
- **完全通配：** `"*"` 匹配任何内容
- **前缀通配：** `"*.openai.com:443"` 匹配 `"api.openai.com:443"`
- **后缀通配：** `"api.*"` 匹配 `"api.openai.com"`
- **中间通配：** `"api.*.com"` 匹配 `"api.openai.com"`
- **ToolAll 特殊情况：** `ToolAll` 授予任何 `ToolInvoke(_)`
- **数值边界：** `LlmMaxTokens(10000)` 授予 `LlmMaxTokens(5000)`（已授予 >= 需要）

### 2.3 强制执行点

在 WASM 沙箱中，每次主机调用在执行**之前**由 `host_functions.rs` 中的 `check_capability()` 检查：

```rust
fn check_capability(
    capabilities: &[Capability],
    required: &Capability,
) -> Result<(), serde_json::Value> {
    for granted in capabilities {
        if capability_matches(granted, required) {
            return Ok(());
        }
    }
    Err(json!({"error": format!("Capability denied: {required:?}")}))
}
```

如果没有授予的能力与所需能力匹配，操作立即返回 JSON 错误——工具永远不会被调用。

### 2.4 能力继承

当智能体生成子智能体时，`validate_capability_inheritance()` 确保子智能体的能力是父智能体的**子集**。这防止了权限提升：

```rust
pub fn validate_capability_inheritance(
    parent_caps: &[Capability],
    child_caps: &[Capability],
) -> Result<(), String> {
    for child_cap in child_caps {
        let is_covered = parent_caps
            .iter()
            .any(|parent_cap| capability_matches(parent_cap, child_cap));
        if !is_covered {
            return Err(format!(
                "权限提升被拒绝：子智能体请求 {:?} \
                 但父智能体没有匹配的授权",
                child_cap
            ));
        }
    }
    Ok(())
}
```

`host_functions.rs` 中的 `host_agent_spawn()` 函数调用
`kernel.spawn_agent_checked(manifest_toml, Some(&state.agent_id), &state.capabilities)`
在创建子智能体之前调用此验证。

---

## 3. WASM 双重计量

**来源：** `openfang-runtime/src/sandbox.rs`

不受信任的 WASM 模块在 Wasmtime 沙箱中运行，同时运行**两个独立的**计量机制。

### 3.1 Fuel 计量（确定性）

Fuel 计量计算 WASM 指令。引擎为执行的每条指令扣除 fuel。当预算耗尽时，执行以 `Trap::OutOfFuel` 陷阱终止。

```rust
// SandboxConfig 默认值
pub fuel_limit: u64,  // 默认：1_000_000

// 执行时应用
if config.fuel_limit > 0 {
    store.set_fuel(config.fuel_limit)?;
}
```

执行后，报告消耗的 fuel：

```rust
let fuel_remaining = store.get_fuel().unwrap_or(0);
let fuel_consumed = config.fuel_limit.saturating_sub(fuel_remaining);
```

### 3.2 Epoch 中断（墙钟时间）

一个 watchdog 线程睡眠配置的超时时间，然后递增引擎 epoch。当 epoch 超过存储的截止时间时，执行以 `Trap::Interrupt` 陷阱终止。

```rust
store.set_epoch_deadline(1);
let engine_clone = engine.clone();
let timeout = config.timeout_secs.unwrap_or(30);
let _watchdog = std::thread::spawn(move || {
    std::thread::sleep(std::time::Duration::from_secs(timeout));
    engine_clone.increment_epoch();
});
```

### 3.3 为什么两者都需要？

| 属性 | Fuel | Epoch |
|----------|------|-------|
| **指标** | 指令计数 | 墙钟时间 |
| **精度** | 确定性、可复现 | 非确定性 |
| **捕获** | CPU 密集型循环 | 主机调用阻塞、I/O 等待 |
| **绕过** | 可能在主机调用中浪费时间 | 可能廉价地忙循环 |

它们共同形成完整的防御：fuel 捕获计算密集型循环，而 epoch 捕获主机调用滥用或环境减速。

### 3.4 SandboxConfig

```rust
pub struct SandboxConfig {
    pub fuel_limit: u64,           // 默认：1_000_000
    pub max_memory_bytes: usize,   // 默认：16 MB
    pub capabilities: Vec<Capability>,
    pub timeout_secs: Option<u64>, // 默认：30 秒
}
```

### 3.5 错误类型

```rust
pub enum SandboxError {
    Compilation(String),
    Instantiation(String),
    Execution(String),
    FuelExhausted,         // Trap::OutOfFuel
    AbiError(String),
}
```

---

## 4. Merkle 哈希链审计追踪

**来源：** `openfang-runtime/src/audit.rs`

每个安全关键操作都被附加到防篡改的 Merkle 哈希链，类似于区块链。每个条目包含其自身内容的 SHA-256 哈希与前一个条目哈希的连接。

### 4.1 可审计操作

```rust
pub enum AuditAction {
    ToolInvoke,
    CapabilityCheck,
    AgentSpawn,
    AgentKill,
    AgentMessage,
    MemoryAccess,
    FileAccess,
    NetworkAccess,
    ShellExec,
    AuthAttempt,
    WireConnect,
    ConfigChange,
}
```

### 4.2 条目结构

```rust
pub struct AuditEntry {
    pub seq: u64,          // 单调递增的序列号
    pub timestamp: String, // ISO-8601
    pub agent_id: String,
    pub action: AuditAction,
    pub detail: String,    // 例如工具名称、文件路径
    pub outcome: String,   // "ok"、"denied"、错误消息
    pub prev_hash: String, // 前一个条目的 SHA-256（或 64 个零）
    pub hash: String,      // 此条目 + prev_hash 的 SHA-256
}
```

### 4.3 哈希计算

每个条目的哈希从其所有字段与前一个条目哈希的连接计算：

```rust
fn compute_entry_hash(
    seq: u64, timestamp: &str, agent_id: &str,
    action: &AuditAction, detail: &str,
    outcome: &str, prev_hash: &str,
) -> String {
    let mut hasher = Sha256::new();
    hasher.update(seq.to_string().as_bytes());
    hasher.update(timestamp.as_bytes());
    hasher.update(agent_id.as_bytes());
    hasher.update(action.to_string().as_bytes());
    hasher.update(detail.as_bytes());
    hasher.update(outcome.as_bytes());
    hasher.update(prev_hash.as_bytes());
    hex::encode(hasher.finalize())
}
```

### 4.4 链完整性验证

`AuditLog::verify_integrity()` 遍历整个链并重新计算每个哈希。如果任何条目被篡改，重新计算的哈希将与存储的哈希不匹配，或者 `prev_hash` 链接将被破坏：

```rust
pub fn verify_integrity(&self) -> Result<(), String> {
    let entries = self.entries.lock().unwrap_or_else(|e| e.into_inner());
    let mut expected_prev = "0".repeat(64);  // 创世哨兵

    for entry in entries.iter() {
        if entry.prev_hash != expected_prev {
            return Err(format!(
                "链在 seq {} 处断裂：期望 prev_hash {} 但找到 {}",
                entry.seq, expected_prev, entry.prev_hash
            ));
        }
        let recomputed = compute_entry_hash(/* ... */);
        if recomputed != entry.hash {
            return Err(format!(
                "哈希在 seq {} 处不匹配：期望 {} 但找到 {}",
                entry.seq, recomputed, entry.hash
            ));
        }
        expected_prev = entry.hash.clone();
    }
    Ok(())
}
```

### 4.5 线程安全

`AuditLog` 使用 `Mutex<Vec<AuditEntry>>` 和 `Mutex<String>` 存储最新哈希。两个锁都使用 `unwrap_or_else(|e| e.into_inner())` 从中毒的互斥锁中恢复，确保即使在 panic 后审计日志仍然可用。

### 4.6 API

| 方法 | 描述 |
|--------|-------------|
| `AuditLog::new()` | 使用创世哨兵（`"0" * 64`）创建空日志 |
| `record(agent_id, action, detail, outcome)` | 追加条目，返回其哈希 |
| `verify_integrity()` | 验证整个链 |
| `tip_hash()` | 返回最近条目的哈希 |
| `len()` / `is_empty()` | 条目计数 |
| `recent(n)` | 返回最近的 `n` 个条目（克隆） |

---

## 5. 信息流污点追踪

**来源：** `openfang-types/src/taint.rs`

OpenFang 实现了基于格的污点传播模型，防止污点值在没有显式降级的情况下流入敏感接收器。这防护提示词注入、数据外泄和混淆副手攻击。

### 5.1 污点标签

```rust
pub enum TaintLabel {
    ExternalNetwork,  // 来自外部网络请求的数据
    UserInput,        // 直接用户输入
    Pii,              // 个人身份信息
    Secret,           // API 密钥、令牌、密码
    UntrustedAgent,   // 来自沙箱/不受信任智能体的数据
}
```

### 5.2 污点值

```rust
pub struct TaintedValue {
    pub value: String,              // 有效载荷
    pub labels: HashSet<TaintLabel>, // 附加的污点标签
    pub source: String,             // 人类可读的来源
}
```

关键方法：

| 方法 | 描述 |
|--------|-------------|
| `TaintedValue::new(value, labels, source)` | 使用标签创建 |
| `TaintedValue::clean(value, source)` | 创建无标签（无污点） |
| `merge_taint(&mut self, other)` | 标签的并集（用于连接） |
| `check_sink(&self, sink)` | 检查值是否可以流向接收器 |
| `declassify(&mut self, label)` | 移除特定标签（显式安全决策） |
| `is_tainted(&self) -> bool` | 如果有任何标签则返回 true |

### 5.3 污点接收器

`TaintSink` 定义哪些标签被**阻止**到达它：

| 接收器 | 阻止的标签 | 原理 |
|------|---------------|-----------|
| `TaintSink::shell_exec()` | `ExternalNetwork`, `UntrustedAgent`, `UserInput` | 防止命令注入 |
| `TaintSink::net_fetch()` | `Secret`, `Pii` | 防止数据外泄 |
| `TaintSink::agent_message()` | `Secret` | 防止向其他智能体泄露密钥 |

### 5.4 违规处理

当 `check_sink()` 发现被阻止的标签时，它返回 `TaintViolation`：

```rust
pub struct TaintViolation {
    pub label: TaintLabel,    // 违规标签
    pub sink_name: String,    // "shell_exec", "net_fetch" 等
    pub source: String,       // 污点值的来源
}
```

显示：`污点违规：来自源 'env_var' 的标签 'Secret' 不允许到达接收器 'net_fetch'`

### 5.5 降级

降级是**显式安全决策**。调用者断言值已被清理：

```rust
tainted.declassify(&TaintLabel::ExternalNetwork);
tainted.declassify(&TaintLabel::UserInput);
// 降级后，值可以流向 shell_exec
assert!(tainted.check_sink(&TaintSink::shell_exec()).is_ok());
```

### 5.6 污点传播

当两个值组合时（连接、插值），结果必须携带两组标签的并集：

```rust
let mut combined = TaintedValue::new(/* ... */);
combined.merge_taint(&other_value);
// combined.labels 现在是两者的并集
```

---

## 6. Ed25519 清单签名

**来源：** `openfang-types/src/manifest_signing.rs`

智能体清单定义智能体的能力、工具和配置。被入侵的清单可能授予提升的权限。此模块提供基于 Ed25519 的加密签名。

### 6.1 签名方案

1. 计算清单内容的 SHA-256（原始 TOML 文本）。
2. 使用 Ed25519 签名哈希（通过 `ed25519-dalek`）。
3. 将签名、公钥和内容哈希打包到 `SignedManifest` 信封中。

### 6.2 SignedManifest 结构

```rust
pub struct SignedManifest {
    pub manifest: String,           // 原始 TOML 内容
    pub content_hash: String,       // 清单的十六进制 SHA-256
    pub signature: Vec<u8>,         // Ed25519 签名（64 字节）
    pub signer_public_key: Vec<u8>, // Ed25519 公钥（32 字节）
    pub signer_id: String,          // 人类可读的签名者 ID
}
```

### 6.3 签名

```rust
let signing_key = SigningKey::generate(&mut OsRng);
let signed = SignedManifest::sign(manifest_toml, &signing_key, "admin@org.com");
```

内部：

```rust
pub fn sign(manifest: impl Into<String>, signing_key: &SigningKey, signer_id: impl Into<String>) -> Self {
    let manifest = manifest.into();
    let content_hash = hash_manifest(&manifest);  // SHA-256
    let signature = signing_key.sign(content_hash.as_bytes());
    let verifying_key = signing_key.verifying_key();
    Self {
        manifest,
        content_hash,
        signature: signature.to_bytes().to_vec(),
        signer_public_key: verifying_key.to_bytes().to_vec(),
        signer_id: signer_id.into(),
    }
}
```

### 6.4 验证

两阶段验证：

1. **哈希检查：** 重新计算 `manifest` 的 SHA-256 并与 `content_hash` 比较。
2. **签名检查：** 使用 `signer_public_key` 验证 `content_hash` 上的 Ed25519 签名。

```rust
pub fn verify(&self) -> Result<(), String> {
    let recomputed = hash_manifest(&self.manifest);
    if recomputed != self.content_hash {
        return Err("content hash mismatch: ...".into());
    }
    let verifying_key = VerifyingKey::from_bytes(&pk_bytes)?;
    let signature = Signature::from_bytes(&sig_bytes);
    verifying_key.verify(self.content_hash.as_bytes(), &signature)
        .map_err(|e| format!("signature verification failed: {}", e))
}
```

### 6.5 篡改检测

- 修改签名后的清单内容会导致**内容哈希不匹配**。
- 用不同的密钥替换公钥会导致**签名验证失败**。
- 两种攻击都会被 `verify()` 捕获。

---

## 7. SSRF 防护

**来源：** `openfang-runtime/src/host_functions.rs`

`host_net_fetch` 函数（WASM 主机调用网络请求）包含全面的服务器端请求伪造防护。

### 7.1 协议验证

只允许 `http://` 和 `https://` 协议。其他所有协议（`file://`、`gopher://`、`ftp://`）立即被阻止：

```rust
if !url.starts_with("http://") && !url.starts_with("https://") {
    return Err(json!({"error": "只允许 http:// 和 https:// URL"}));
}
```

### 7.2 主机名黑名单

在 DNS 解析之前，阻止以下主机名：

- `localhost`
- `metadata.google.internal`
- `metadata.aws.internal`
- `instance-data`
- `169.254.169.254`（AWS/GCP 元数据端点）

### 7.3 DNS 解析检查

主机名黑名单之后，函数将主机名解析为 IP 地址并检查**每个解析的 IP** 是否在私有范围内。这挫败了 DNS 重新绑定攻击：

```rust
let socket_addr = format!("{hostname}:{port}");
if let Ok(addrs) = socket_addr.to_socket_addrs() {
    for addr in addrs {
        let ip = addr.ip();
        if ip.is_loopback() || ip.is_unspecified() || is_private_ip(&ip) {
            return Err(json!({"error": format!(
                "SSRF 阻止：{hostname} 解析到私有 IP {ip}"
            )}));
        }
    }
}
```

### 7.4 私有 IP 检测

`is_private_ip()` 函数涵盖：

**IPv4：**
- `10.0.0.0/8` -- RFC 1918
- `172.16.0.0/12` -- RFC 1918
- `192.168.0.0/16` -- RFC 1918
- `169.254.0.0/16` -- 链路本地（AWS 元数据）

**IPv6：**
- `fc00::/7` -- 唯一本地地址
- `fe80::/10` -- 链路本地

```rust
fn is_private_ip(ip: &std::net::IpAddr) -> bool {
    match ip {
        IpAddr::V4(v4) => {
            let octets = v4.octets();
            matches!(
                octets,
                [10, ..] | [172, 16..=31, ..] | [192, 168, ..] | [169, 254, ..]
            )
        }
        IpAddr::V6(v6) => {
            let segments = v6.segments();
            (segments[0] & 0xfe00) == 0xfc00 || (segments[0] & 0xffc0) == 0xfe80
        }
    }
}
```

### 7.5 主机提取

`extract_host_from_url()` 解析 URL 以提取 `host:port` 用于 SSRF 检查和能力匹配：

```
https://api.openai.com/v1/chat  ->  api.openai.com:443
http://localhost:8080/api       ->  localhost:8080
http://example.com              ->  example.com:80
```

---

## 8. 密钥清零

**来源：** 所有 LLM 驱动模块、通道适配器和网页搜索模块。

OpenFang 在每个保存密钥材料的字段上使用 `zeroize` 包的 `Zeroizing<String>`。当值被丢弃时，其内存被零覆盖，防止密钥在内存中 lingering。

### 8.1 工作原理

`Zeroizing<T>` 是来自 `zeroize` 包的智能指针包装器。它实现 `Deref<Target=T>` 以透明使用，`Drop` 以自动清零：

```rust
// 在 Drop 时，内部 String 的缓冲区被零覆盖
let key = Zeroizing::new("sk-secret-key".to_string());
// 通过 Deref 透明使用 key
client.post(url).header("authorization", format!("Bearer {}", &*key));
// 当 key 超出作用域时，内存被清零
```

### 8.2 使用清零的字段

**LLM 驱动**（`openfang-runtime/src/drivers/`）：

| 驱动 | 字段 |
|--------|-------|
| `AnthropicDriver` | `api_key: Zeroizing<String>` |
| `GeminiDriver` | `api_key: Zeroizing<String>` |
| `OpenAiCompatDriver` | `api_key: Zeroizing<String>` |

**通道适配器**（`openfang-channels/src/`）：

| 适配器 | 字段 |
|---------|----------|
| `DiscordAdapter` | `token: Zeroizing<String>` |
| `EmailAdapter` | `password: Zeroizing<String>` |
| `BlueskyAdapter` | `app_password: Zeroizing<String>` |
| `DingTalkAdapter` | `access_token: Zeroizing<String>`, `secret: Zeroizing<String>` |
| `FeishuAdapter` | `app_secret: Zeroizing<String>` |
| `FlockAdapter` | `bot_token: Zeroizing<String>` |
| `GitterAdapter` | `token: Zeroizing<String>` |
| `GotifyAdapter` | `app_token: Zeroizing<String>`, `client_token: Zeroizing<String>` |

**网页搜索**（`openfang-runtime/src/web_search.rs`）：

```rust
fn resolve_api_key(env_var: &str) -> Option<Zeroizing<String>> {
    std::env::var(env_var).ok().filter(|k| !k.is_empty()).map(Zeroizing::new)
}
```

**嵌入**（`openfang-runtime/src/embedding.rs`）：

| 结构体 | 字段 |
|--------|-------|
| `EmbeddingClient` | `api_key: Zeroizing<String>` |

### 8.3 为什么重要

没有清零，密钥在使用后直到操作系统回收页面之前一直保留在内存中。具有核心转储、交换文件或内存取证工具访问权限的攻击者可以恢复 API 密钥。`Zeroizing<String>` 确保密钥在不再需要时被覆盖。

---

## 9. OFP 双向认证

**来源：** `openfang-wire/src/peer.rs`

OpenFang 线协议（OFP）使用基于 HMAC-SHA256 的 nonce 双向认证，通过 TCP 连接。

### 9.1 预共享密钥要求

没有 `shared_secret` 时 OFP 拒绝启动：

```rust
if config.shared_secret.is_empty() {
    return Err(WireError::HandshakeFailed(
        "OFP 需要 shared_secret。在 config.toml 中设置 [network] shared_secret".into(),
    ));
}
```

### 9.2 HMAC 函数

```rust
type HmacSha256 = Hmac<Sha256>;

fn hmac_sign(secret: &str, data: &[u8]) -> String {
    let mut mac = HmacSha256::new_from_slice(secret.as_bytes())
        .expect("HMAC 接受任何密钥大小");
    mac.update(data);
    hex::encode(mac.finalize().into_bytes())
}

fn hmac_verify(secret: &str, data: &[u8], signature: &str) -> bool {
    let expected = hmac_sign(secret, data);
    subtle::ConstantTimeEq::ct_eq(expected.as_bytes(), signature.as_bytes()).into()
}
```

**恒定时间比较**（`subtle::ConstantTimeEq`）防止时序侧信道攻击。

### 9.3 握手协议

**发起者（客户端）：**

1. 生成随机 UUID nonce。
2. 计算 `auth_data = nonce + node_id`。
3. 计算 `auth_hmac = hmac_sign(shared_secret, auth_data)`。
4. 发送 `Handshake { node_id, node_name, protocol_version, agents, nonce, auth_hmac }`。

**响应者（服务器）：**

1. 接收 `Handshake` 消息。
2. 验证传入 HMAC：`hmac_verify(shared_secret, nonce + node_id, auth_hmac)`。
3. 如果验证失败，返回错误代码 403。
4. 为确认生成新的 UUID nonce。
5. 计算 `ack_auth_data = ack_nonce + self.node_id`。
6. 计算 `ack_hmac = hmac_sign(shared_secret, ack_auth_data)`。
7. 发送 `HandshakeAck { node_id, node_name, protocol_version, agents, nonce: ack_nonce, auth_hmac: ack_hmac }`。

**发起者（验证）：**

1. 接收 `HandshakeAck`。
2. 验证：`hmac_verify(shared_secret, ack_nonce + node_id, ack_hmac)`。
3. 如果验证失败，返回 `WireError::HandshakeFailed`。

### 9.4 安全属性

| 属性 | 实现方式 |
|----------|-------------------|
| **双向认证** | 双方证明知道共享密钥 |
| **重放防护** | 每次握手随机 UUID nonce |
| **时序攻击抗性** | `subtle::ConstantTimeEq` 用于 HMAC 比较 |
| **强制密钥** | 没有 `shared_secret` 时 OFP 拒绝启动 |
| **消息大小限制** | `MAX_MESSAGE_SIZE = 16 MB` 防止内存拒绝服务 |
| **协议版本检查** | `PROTOCOL_VERSION` 不匹配返回 `WireError::VersionMismatch` |


---

## 10. 安全响应头

**来源：** `openfang-api/src/middleware.rs`

`security_headers` 中间件应用于**所有** API 响应：

```rust
pub async fn security_headers(request: Request<Body>, next: Next) -> Response<Body> {
    let mut response = next.run(request).await;
    let headers = response.headers_mut();
    headers.insert("x-content-type-options", "nosniff".parse().unwrap());
    headers.insert("x-frame-options", "DENY".parse().unwrap());
    headers.insert("x-xss-protection", "1; mode=block".parse().unwrap());
    headers.insert("content-security-policy", /* CSP 策略 */);
    headers.insert("referrer-policy", "strict-origin-when-cross-origin".parse().unwrap());
    headers.insert("cache-control", "no-store, no-cache, must-revalidate".parse().unwrap());
    response
}
```

| 响应头 | 值 | 防护对象 |
|--------|-------|------------------|
| `X-Content-Type-Options` | `nosniff` | MIME 类型嗅探攻击 |
| `X-Frame-Options` | `DENY` | 通过 iframe 的点击劫持 |
| `X-XSS-Protection` | `1; mode=block` | 反射型 XSS（旧浏览器） |
| `Content-Security-Policy` | 见下文 | XSS、代码注入、数据外泄 |
| `Referrer-Policy` | `strict-origin-when-cross-origin` | Referrer 泄露 |
| `Cache-Control` | `no-store, no-cache, must-revalidate` | 敏感数据缓存 |

### 10.1 CSP 细分

| 指令 | 值 | 目的 |
|-----------|-------|---------|
| `default-src` | `'self'` | 默认拒绝所有外部资源 |
| `script-src` | `'self' 'unsafe-inline' 'unsafe-eval' cdn.jsdelivr.net` | 允许来自自身和 CDN 的脚本 |
| `style-src` | `'self' 'unsafe-inline' cdn.jsdelivr.net fonts.googleapis.com` | 允许来自自身、CDN、Google Fonts 的样式 |
| `img-src` | `'self' data:` | 允许来自自身和数据 URI 的图片 |
| `connect-src` | `'self' ws: wss:` | 允许 WebSocket 连接 |
| `font-src` | `'self' cdn.jsdelivr.net fonts.gstatic.com` | 允许来自 CDN 的字体 |
| `object-src` | `'none'` | 阻止所有插件（Flash、Java 等） |
| `base-uri` | `'self'` | 防止 base 标签劫持 |
| `form-action` | `'self'` | 限制表单提交目标 |

---

## 11. GCRA 速率限制器

**来源：** `openfang-api/src/rate_limiter.rs`

OpenFang 使用通用单元速率算法（GCRA）通过 `governor` 包实现按成本感知的 API 速率限制。

### 11.1 算法

GCRA 是一种漏桶变体，为每个密钥跟踪单个"虚拟调度时间"（TAT -- 理论到达时间）。每个请求消耗与其成本成比例的 Token 数量。桶以恒定速率重新填充。

**预算：** 每个 IP 地址每分钟 500 Token。

```rust
pub fn create_rate_limiter() -> Arc<KeyedRateLimiter> {
    Arc::new(RateLimiter::keyed(Quota::per_minute(NonZeroU32::new(500).unwrap())))
}
```

### 11.2 操作成本

每个 API 操作都有可配置的 Token 成本：

```rust
pub fn operation_cost(method: &str, path: &str) -> NonZeroU32 {
    match (method, path) {
        (_, "/api/health")                            => 1,
        ("GET", "/api/status")                        => 1,
        ("GET", "/api/version")                       => 1,
        ("GET", "/api/tools")                         => 1,
        ("GET", "/api/agents")                        => 2,
        ("GET", "/api/skills")                        => 2,
        ("GET", "/api/peers")                         => 2,
        ("GET", "/api/config")                        => 2,
        ("GET", "/api/usage")                         => 3,
        ("GET", p) if p.starts_with("/api/audit")     => 5,
        ("GET", p) if p.starts_with("/api/marketplace")=> 10,
        ("POST", "/api/agents")                       => 50,
        ("POST", p) if p.contains("/message")         => 30,
        ("POST", p) if p.contains("/run")             => 100,
        ("POST", "/api/skills/install")               => 50,
        ("POST", "/api/skills/uninstall")             => 10,
        ("POST", "/api/migrate")                      => 100,
        ("PUT", p) if p.contains("/update")           => 10,
        _                                             => 5,
    }
}
```

成本层次是有意设计的：只读健康检查成本 1 Token，而工作流运行等昂贵操作成本 100，意味着客户端每分钟可以执行 500 次健康检查但只能执行 5 次工作流运行。

### 11.3 中间件

```rust
pub async fn gcra_rate_limit(
    State(limiter): State<Arc<KeyedRateLimiter>>,
    request: Request<Body>,
    next: Next,
) -> Response<Body> {
    let ip = /* 从 ConnectInfo 提取，默认 127.0.0.1 */;
    let cost = operation_cost(&method, &path);

    if limiter.check_key_n(&ip, cost).is_err() {
        tracing::warn!(ip, cost, path, "GCRA 速率限制超出");
        return Response::builder()
            .status(StatusCode::TOO_MANY_REQUESTS)
            .header("retry-after", "60")
            .body(/* JSON 错误 */)
            .unwrap_or_default();
    }
    next.run(request).await
}
```

### 11.4 速率限制器类型

```rust
pub type KeyedRateLimiter = RateLimiter<IpAddr, DashMapStateStore<IpAddr>, DefaultClock>;
```

`DashMapStateStore` 提供并发的每 IP 状态，自动清理过期条目。

---

## 12. 路径遍历防护

**来源：** `openfang-runtime/src/host_functions.rs`

两个函数提供针对目录遍历的纵深防御。

### 12.1 safe_resolve_path（用于读取）

用于目标文件必须存在的 `fs_read` 和 `fs_list` 操作：

```rust
fn safe_resolve_path(path: &str) -> Result<std::path::PathBuf, serde_json::Value> {
    let p = Path::new(path);

    // 阶段 1：拒绝任何包含 ".." 组件的路径
    for component in p.components() {
        if matches!(component, Component::ParentDir) {
            return Err(json!({"error": "路径遍历被拒绝：禁止 '..' 组件"}));
        }
    }

    // 阶段 2：规范化以解析符号链接和标准化
    std::fs::canonicalize(p)
        .map_err(|e| json!({"error": format!("无法解析路径: {e}")}))
}
```

### 12.2 safe_resolve_parent（用于写入）

用于目标文件可能尚不存在的 `fs_write` 操作：

```rust
fn safe_resolve_parent(path: &str) -> Result<std::path::PathBuf, serde_json::Value> {
    let p = Path::new(path);

    // 阶段 1：拒绝任何组件中的 ".."
    for component in p.components() {
        if matches!(component, Component::ParentDir) {
            return Err(json!({"error": "路径遍历被拒绝：禁止 '..' 组件"}));
        }
    }

    // 阶段 2：规范化父目录
    let parent = p.parent().filter(|par| !par.as_os_str().is_empty())
        .ok_or_else(|| json!({"error": "无效路径：没有父目录"}))?;
    let canonical_parent = std::fs::canonicalize(parent)?;

    // 阶段 3：对文件名进行双重检查
    let file_name = p.file_name()
        .ok_or_else(|| json!({"error": "无效路径：没有文件名"}))?;
    if file_name.to_string_lossy().contains("..") {
        return Err(json!({"error": "文件名中的路径遍历被拒绝"}));
    }

    Ok(canonical_parent.join(file_name))
}
```

### 12.3 执行顺序

1. **能力检查**首先使用原始路径运行。
2. **路径遍历检查**其次运行。
3. 只有两者都通过时**操作**才运行。

此顺序确保即使能力配置错误，具有宽泛模式如 `"*"`，路径遍历仍被阻止。

---

## 13. 子进程沙箱

**来源：** `openfang-runtime/src/subprocess_sandbox.rs`

当运行时生成子进程（例如用于 shell 工具或技能执行）时，继承的环境必须被剥离以防止密钥的意外泄露。

### 13.1 环境清理

```rust
pub fn sandbox_command(cmd: &mut tokio::process::Command, allowed_env_vars: &[String]) {
    cmd.env_clear();  // 移除所有继承的环境变量

    // 重新添加平台无关的安全变量
    for var in SAFE_ENV_VARS {
        if let Ok(val) = std::env::var(var) {
            cmd.env(var, val);
        }
    }

    // 重新添加 Windows 特定的安全变量（在 Windows 上）
    #[cfg(windows)]
    for var in SAFE_ENV_VARS_WINDOWS { /* ... */ }

    // 重新添加调用者指定的允许变量
    for var in allowed_env_vars { /* ... */ }
}
```

### 13.2 安全环境变量

**所有平台：**

```rust
pub const SAFE_ENV_VARS: &[&str] = &[
    "PATH", "HOME", "TMPDIR", "TMP", "TEMP", "LANG", "LC_ALL", "TERM",
];
```

**仅 Windows：**

```rust
pub const SAFE_ENV_VARS_WINDOWS: &[&str] = &[
    "USERPROFILE", "SYSTEMROOT", "APPDATA", "LOCALAPPDATA",
    "COMSPEC", "WINDIR", "PATHEXT",
];
```

不在这些列表中且不在 `allowed_env_vars` 中的变量**永远不会**传递给子进程。这意味着 `OPENAI_API_KEY`、`GEMINI_API_KEY`、数据库凭证和所有其他密钥都被剥离。

### 13.3 可执行路径验证

```rust
pub fn validate_executable_path(path: &str) -> Result<(), String> {
    let p = Path::new(path);
    for component in p.components() {
        if let std::path::Component::ParentDir = component {
            return Err(format!(
                "可执行路径 '{}' 包含不允许的 '..' 组件",
                path
            ));
        }
    }
    Ok(())
}
```

这防止智能体通过构造的路径如 `../../bin/dangerous` 逃离其工作目录。

### 13.4 Shell 注入防护

`host_shell_exec` 函数使用 `Command::new(command).args(&args)`，它**不**调用 shell。每个参数直接传递给进程，防止通过元字符如 `;`、`|`、`&&` 进行 shell 注入。

---

## 14. 提示词注入扫描器

**来源：** `openfang-skills/src/verify.rs`

`SkillVerifier` 提供两个扫描函数：用于技能清单的 `security_scan()` 和用于技能提示词文本（SKILL.md 正文）的 `scan_prompt_content()`。

### 14.1 清单安全扫描

`SkillVerifier::security_scan(manifest)` 检查技能的声明需求：

| 检查 | 严重级别 | 触发条件 |
|-------|----------|---------|
| Node.js 运行时 | 警告 | `runtime_type == SkillRuntime::Node` |
| Shell 执行能力 | 严重 | 能力包含 `shellexec` 或 `shell_exec` |
| 无限制网络 | 警告 | 能力包含 `netconnect(*)` |
| Shell 工具 | 严重 | 工具是 `shell_exec` 或 `bash` |
| 文件系统写入工具 | 警告 | 工具是 `file_write` 或 `file_delete` |
| 工具过多 | 信息 | 需要超过 10 个工具 |

### 14.2 提示词注入扫描

`SkillVerifier::scan_prompt_content(content)` 检测技能提示词文本中的常见攻击模式：

**严重 -- 提示词覆盖尝试：**

```
"ignore previous instructions", "ignore all previous",
"disregard previous", "forget your instructions",
"you are now", "new instructions:", "system prompt override",
"ignore the above", "do not follow", "override system"
```

**警告 -- 数据外泄模式：**

```
"send to http", "send to https", "post to http", "post to https",
"exfiltrate", "forward all", "send all data",
"base64 encode and send", "upload to"
```

**警告 -- Shell 命令引用：**

```
"rm -rf", "chmod ", "sudo "
```

**信息 -- 长度过长：**

超过 50,000 字节的内容触发关于潜在 LLM 性能退化的信息级别警告。

### 14.3 SHA256 校验和验证

```rust
pub fn verify_checksum(data: &[u8], expected_sha256: &str) -> bool {
    let actual = Self::sha256_hex(data);
    actual == expected_sha256.to_lowercase()
}
```

从 ClawHub 安装的技能会针对已知 SHA256 哈希验证其内容，以检测下载期间的篡改。

### 14.4 警告结构

```rust
pub struct SkillWarning {
    pub severity: WarningSeverity,  // Info, Warning, Critical
    pub message: String,
}
```

---

## 15. 循环守卫

**来源：** `openfang-runtime/src/loop_guard.rs`

`LoopGuard` 跟踪单个智能体循环执行中的工具调用，检测智能体是否卡住反复调用同一工具。

### 15.1 配置

```rust
pub struct LoopGuardConfig {
    pub warn_threshold: u32,         // 默认：3
    pub block_threshold: u32,        // 默认：5
    pub global_circuit_breaker: u32, // 默认：30
}
```

### 15.2 检测算法

1. 对于每次工具调用，计算 `tool_name + "|" + serialized_params` 的 SHA-256。
2. 在 `HashMap<String, u32>` 中递增该哈希的计数。
3. 递增 `total_calls`。
4. 返回分级裁决：

```rust
pub fn check(&mut self, tool_name: &str, params: &serde_json::Value) -> LoopGuardVerdict {
    self.total_calls += 1;

    // 全局熔断器
    if self.total_calls > self.config.global_circuit_breaker {
        return LoopGuardVerdict::CircuitBreak(/* ... */);
    }

    let hash = Self::compute_hash(tool_name, params);
    let count = self.call_counts.entry(hash).or_insert(0);
    *count += 1;

    if *count >= self.config.block_threshold {
        LoopGuardVerdict::Block(/* ... */)
    } else if *count >= self.config.warn_threshold {
        LoopGuardVerdict::Warn(/* ... */)
    } else {
        LoopGuardVerdict::Allow
    }
}
```

### 15.3 裁决类型

| 裁决 | 含义 | 操作 |
|---------|---------|--------|
| `Allow` | 正常操作 | 运行工具 |
| `Warn(msg)` | 相同调用重复 >= 3 次 | 运行，附加警告到结果 |
| `Block(msg)` | 相同调用重复 >= 5 次 | 跳过执行，返回错误 |
| `CircuitBreak(msg)` | > 30 次总工具调用 | 终止整个智能体循环 |

### 15.4 哈希计算

```rust
fn compute_hash(tool_name: &str, params: &serde_json::Value) -> String {
    let mut hasher = Sha256::new();
    hasher.update(tool_name.as_bytes());
    hasher.update(b"|");
    let params_str = serde_json::to_string(params).unwrap_or_default();
    hasher.update(params_str.as_bytes());
    hex::encode(hasher.finalize())
}
```

注意：`serde_json::to_string` 产生确定性输出（对象键排序），确保语义相同的参数产生相同的哈希。

### 15.5 关键属性

具有**不同参数**的调用被分别跟踪。用 10 个不同查询调用 `web_search` 的智能体不会触发守卫，但调用 `web_search({"query": "test"})` 5 次的智能体会被阻止。

---

## 16. 会话修复

**来源：** `openfang-runtime/src/session_repair.rs`

在将消息历史发送到 LLM 之前，此模块验证并修复会导致 API 错误的常见结构问题。

### 16.1 三阶段修复

```rust
pub fn validate_and_repair(messages: &[Message]) -> Vec<Message>
```

**阶段 1 -- 收集 ToolUse ID：**

扫描所有消息中的 `ContentBlock::ToolUse { id, .. }` 块并将其 ID 收集到 `HashSet<String>` 中。

**阶段 2 -- 过滤孤儿和空值：**

- **孤儿 ToolResults：** `tool_use_id` 不在 ToolUse ID 集中的 `ContentBlock::ToolResult { tool_use_id, .. }` 块被删除。
- **空消息：** 空文本或没有内容块的消息被删除。

**阶段 3 -- 合并连续同角色消息：**

Anthropic API 需要严格的角色交替（user、assistant、user、assistant...）。如果两个连续消息具有相同角色，它们被合并为具有组合内容块的单条消息。

### 16.2 为什么需要每次修复

| 问题 | 原因 | 无修复的效果 |
|-------|-------|----------------------|
| 孤儿 ToolResult | 压缩或截断移除了 ToolUse | API 错误："tool_use_id not found" |
| 空消息 | 取消生成、空用户提交 | API 错误：空内容 |
| 连续同角色 | 手动历史编辑、会话修复本身 | API 错误：角色交替违规 |

### 16.3 内容合并

合并连续同角色消息时，两者都转换为块格式并连接：

```rust
fn merge_content(dst: &mut MessageContent, src: MessageContent) {
    let dst_blocks = content_to_blocks(std::mem::replace(dst, MessageContent::Text(String::new())));
    let src_blocks = content_to_blocks(src);
    let mut combined = dst_blocks;
    combined.extend(src_blocks);
    *dst = MessageContent::Blocks(combined);
}
```

---

## 17. 健康端点脱敏

**来源：** `openfang-api/src/routes.rs`

OpenFang 提供两个具有不同信息级别的健康端点。

### 17.1 公共端点：`GET /api/health`

**无需认证。** 仅返回活性信息：

```json
{
    "status": "ok",
    "version": "0.1.0"
}
```

此端点不暴露智能体数量、数据库详情、配置警告、正常运行时间或任何内部系统信息。适用于负载均衡器健康检查。

### 17.2 详情端点：`GET /api/health/detail`

**需要认证。** 返回完整诊断：

```json
{
    "status": "ok",
    "version": "0.1.0",
    "uptime_seconds": 3600,
    "panic_count": 0,
    "restart_count": 2,
    "agent_count": 15,
    "database": "connected",
    "config_warnings": []
}
```

### 17.3 本地主机回退

当未配置 API 密钥时，`auth` 中间件将所有非健康端点限制为环回地址：

```rust
if api_key.is_empty() {
    let is_loopback = request.extensions()
        .get::<ConnectInfo<SocketAddr>>()
        .map(|ci| ci.0.ip().is_loopback())
        .unwrap_or(false);
    if !is_loopback {
        return Response::builder()
            .status(StatusCode::FORBIDDEN)
            .body(/* "未配置 API 密钥。远程访问被拒绝。" */)
            ...;
    }
}
```

---

## 18. 安全配置

### 18.1 config.toml 参考

```toml
# API 认证
api_key = "your-secret-api-key"  # 空 = 仅本地主机模式

# OFP 线协议
[network]
shared_secret = "your-pre-shared-key"  # OFP 必需

# WASM 沙箱
[sandbox]
fuel_limit = 1000000       # 每次执行的 CPU 指令预算
timeout_secs = 30          # 每次执行的墙钟超时
max_memory_bytes = 16777216 # 16 MB 最大 WASM 内存

# 速率限制
# 每 IP 每分钟 500 Token（当前不能通过 config.toml 配置）

# 网页搜索 SSRF 防护
[web]
# SSRF 防护始终开启且不能禁用
```

### 18.2 密钥的环境变量

| 变量 | 使用者 |
|----------|---------|
| `OPENAI_API_KEY` | OpenAI-compat 驱动 |
| `ANTHROPIC_API_KEY` | Anthropic 驱动 |
| `GEMINI_API_KEY` 或 `GOOGLE_API_KEY` | Gemini 驱动 |
| `DEEPSEEK_API_KEY` | DeepSeek 提供商 |
| `GROQ_API_KEY` | Groq 提供商 |
| `BRAVE_API_KEY` | Brave 网页搜索 |
| `TAVILY_API_KEY` | Tavily 网页搜索 |
| `PERPLEXITY_API_KEY` | Perplexity 网页搜索 |

所有环境变量 API 密钥在加载到驱动结构体时都被包装在 `Zeroizing<String>` 中。

### 18.3 能力声明（智能体清单）

能力在智能体的 TOML 清单中声明：

```toml
[agent]
name = "my-agent"

[[capabilities]]
type = "FileRead"
value = "/data/*"

[[capabilities]]
type = "NetConnect"
value = "*.openai.com:443"

[[capabilities]]
type = "ToolInvoke"
value = "web_search"

[[capabilities]]
type = "LlmMaxTokens"
value = 4096
```

### 18.4 循环守卫调优

默认 `LoopGuardConfig` 值：

| 参数 | 默认值 | 描述 |
|-----------|---------|-------------|
| `warn_threshold` | 3 | 相同调用前警告的相同调用次数 |
| `block_threshold` | 5 | 阻止前相同调用次数 |
| `global_circuit_breaker` | 30 | 熔断前总调用次数 |

### 18.5 子进程沙箱允许列表

要将特定环境变量传递给子进程：

```rust
sandbox_command(&mut cmd, &["MY_CUSTOM_VAR".to_string()]);
```

只有 `allowed_env_vars` 中明确列出的变量（加上安全默认值）才会被继承。

---

## 19. 安全依赖

| 包 | 目的 |
|-------|---------|
| `sha2` | SHA-256 哈希（审计追踪、循环守卫、SSRF、校验和） |
| `hmac` | 用于 OFP 认证的 HMAC-SHA256 |
| `hex` | 哈希和签名的十六进制编码/解码 |
| `subtle` | 用于 HMAC 验证的恒定时间比较（`ConstantTimeEq`） |
| `ed25519-dalek` | 用于清单签名的 Ed25519 签名/验证 |
| `rand` | 密钥生成的加密 RNG（`OsRng`） |
| `zeroize` | 用于自动密钥内存擦除的 `Zeroizing<T>` 包装器 |
| `governor` | GCRA 速率限制算法 |
| `wasmtime` | 具有 fuel + epoch 计量的 WASM 沙箱 |
| `uuid` | 用于 OFP 握手的 nonce 生成 |
| `chrono` | 审计条目的 ISO-8601 时间戳 |
| `reqwest` | HTTP 客户端（在 SSRF 防护的 `host_net_fetch` 内部使用） |

### 19.1 为什么选择这些特定包

- **sha2/hmac：** RustCrypto 项目的一部分，经过审计，Rust 生产环境中广泛使用。
- **ed25519-dalek：** Rust 中事实上的标准 Ed25519 库，经过广泛审计。
- **subtle：** 提供恒定时间操作以防止时序侧信道。
- **zeroize：** RustCrypto 清零密钥的官方方法；与 `Drop` 集成。
- **governor：** 经过实战检验的 GCRA 实现，具有基于 `DashMap` 的并发状态。

---

## 威胁模型总结

| 威胁 | 缓解方式 |
|--------|-------------|
| 智能体请求未授权文件访问 | 基于能力的安全（第 2 节） |
| 智能体生成具有提升权限的子智能体 | 能力继承验证（第 2.4 节） |
| WASM 技能运行无限循环 | 双重计量：fuel + epoch（第 3 节） |
| 攻击者篡改审计日志 | Merkle 哈希链（第 4 节） |
| 通过外部数据的提示词注入 | 污点追踪（第 5 节） |
| 通过 LLM 的数据外泄 | 污点接收器阻止 Secret/PII 到 net_fetch（第 5.3 节） |
| 被篡改的智能体清单 | Ed25519 签名（第 6 节） |
| 到云元数据的 SSRF | 私有 IP + 主机名阻止 + DNS 检查（第 7 节） |
| 从内存转储恢复 API 密钥 | Zeroizing<String>（第 8 节） |
| 未授权的对等连接 | HMAC-SHA256 双向认证（第 9 节） |
| API 上的 XSS / 点击劫持 | 安全响应头（第 10 节） |
| API 暴力破解 / 拒绝服务 | GCRA 速率限制器（第 11 节） |
| 通过 `../` 的路径遍历 | safe_resolve_path / safe_resolve_parent（第 12 节） |
| 向子进程泄露密钥 | env_clear() + 允许列表（第 13 节） |
| 来自 ClawHub 的恶意技能 | 提示词注入扫描器 + SHA256 校验和（第 14 节） |
| 智能体卡在工具循环中 | 具有分级响应的 LoopGuard（第 15 节） |
| 损坏的 LLM 会话历史 | 会话修复（第 16 节） |
| 来自健康端点的信息泄露 | 脱敏公共端点（第 17 节） |
| HMAC 验证的时序攻击 | subtle::ConstantTimeEq（第 9.2 节） |
| 通过元字符的 Shell 注入 | Command::new（无 shell）+ env_clear（第 13.4 节） |
| SSRF 绕过的 DNS 重新绑定 | 解析的 IP 检查，不是主机名检查（第 7.3 节） |
