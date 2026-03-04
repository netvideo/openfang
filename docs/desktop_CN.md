# OpenFang 桌面应用程序

OpenFang 桌面应用程序是一个使用 [Tauri 2.0](https://v2.tauri.app/) 构建的原生桌面封装器，它将整个 OpenFang 代理操作系统打包成一个可安装的单一应用程序。用户无需运行 CLI 守护进程并打开浏览器，而是获得一个原生窗口，具有系统托盘集成、操作系统通知和单实例强制执行功能 -- 所有这些都由与无头部署相同的内核和 API 服务器提供支持。

**包：** `openfang-desktop`
**标识符：** `ai.openfang.desktop`
**产品名称：** OpenFang

---

## 架构

桌面应用程序遵循简单的嵌入式服务器模式：

```
+-------------------------------------------+
|  Tauri 2.0 进程                           |
|                                           |
|  +-----------+    +--------------------+  |
|  |  主       |    | 后台线程           |  |
|  |  线程     |    | ("openfang-server")|  |
|  |           |    |                    |  |
|  | WebView   |    | tokio 运行时       |  |
|  | 窗口      |--->| axum API 服务器    |  |
|  | (主)      |    | 通道桥接           |  |
|  |           |    | 后台代理           |  |
|  | 系统      |    |                    |  |
|  | 托盘      |    | OpenFang 内核      |  |
|  +-----------+    +--------------------+  |
|       |                    |              |
|       |   http://127.0.0.1:{port}        |
|       +------------------------------------
+-------------------------------------------+
```

### 启动序列

1. **追踪初始化** -- 使用 `RUST_LOG` 环境变量配置 `tracing_subscriber`，默认为 `openfang=info,tauri=info`。
2. **内核启动** -- `OpenFangKernel::boot(None)` 加载默认配置（来自 `config.toml` 或默认值），包装在 `Arc` 中。调用 `set_self_handle()` 以启用自引用内核操作。
3. **端口绑定** -- 一个 `std::net::TcpListener` 在主线程上绑定到 `127.0.0.1:0`，这让操作系统分配一个随机空闲端口。这确保在创建任何窗口之前就知道端口号。
4. **服务器线程** -- 生成一个名为 `"openfang-server"` 的专用操作系统线程。它创建自己的 `tokio::runtime::Builder::new_multi_thread()` 运行时并运行：
   - `kernel.start_background_agents()` -- 心跳监控、自主代理等。
   - `run_embedded_server()` -- 通过 `openfang_api::server::build_router()` 构建 axum 路由器，将 `std::net::TcpListener` 转换为 `tokio::net::TcpListener`，并使用优雅关闭提供服务。
5. **Tauri 应用程序** -- 使用插件、托管状态、IPC 命令、系统托盘和一个指向 `http://127.0.0.1:{port}` 的 WebView 窗口组装 Tauri 构建器。
6. **事件循环** -- Tauri 运行其原生事件循环。退出时，调用 `server_handle.shutdown()` 以停止嵌入式服务器和内核。

### ServerHandle

`ServerHandle` 结构（在 `src/server.rs` 中定义）管理嵌入式服务器生命周期：

```rust
pub struct ServerHandle {
    pub port: u16,
    pub kernel: Arc<OpenFangKernel>,
    shutdown_tx: watch::Sender<bool>,
    server_thread: Option<std::thread::JoinHandle<()>>,
}
```

- **`port`** -- 嵌入式服务器监听的端口。
- **`kernel`** -- 内核的共享引用，也用于 Tauri 应用程序进行 IPC 命令和通知。
- **`shutdown_tx`** -- 一个 `tokio::sync::watch` 通道。发送 `true` 会触发 axum 服务器的优雅关闭。
- **`server_thread`** -- 后台线程的 Join 句柄。`shutdown()` 会 join 它以确保干净终止。

调用 `shutdown()` 会发送关闭信号，join 后台线程，并调用 `kernel.shutdown()`。`Drop` 实现会尽力发送关闭信号，但不会阻塞在线程 join 上。

### 优雅关闭

axum 服务器使用 `with_graceful_shutdown()` 连接到观察通道：

```rust
let server = axum::serve(listener, app.into_make_service_with_connect_info::<SocketAddr>())
    .with_graceful_shutdown(async move {
        let _ = shutdown_rx.wait_for(|v| *v).await;
    });
```

服务器关闭后，通过 `bridge.stop().await` 停止通道桥接（Telegram、Slack 等）。

---

## 功能

### 系统托盘

系统托盘（在 `src/tray.rs` 中定义）无需打开主窗口即可提供快速访问：

| 菜单项 | 行为 |
|--------|------|
| **显示窗口** | 在主 WebView 窗口上调用 `show()`、`unminimize()` 和 `set_focus()` |
| **在浏览器中打开** | 从托管的 `PortState` 读取端口并在默认浏览器中打开 `http://127.0.0.1:{port}` |
| **代理：N 个运行中** | 禁用（仅信息）-- 显示当前代理计数 |
| **状态：运行中（运行时间）** | 禁用（仅信息）-- 以人类可读格式显示运行时间 |
| **登录时启动** | 复选框 -- 通过 `tauri-plugin-autostart` 切换操作系统级自动启动 |
| **检查更新...** | 检查更新、下载、安装并在可用时重新启动。显示进度/成功/失败通知 |
| **打开配置目录** | 在 OS 文件管理器中打开 `~/.openfang/` |
| **退出 OpenFang** | 记录退出事件并调用 `app.exit(0)` |

托盘提示文字为 **"OpenFang Agent OS"**。

**左键单击托盘图标** 显示主窗口（与"显示窗口"菜单项相同）。这通过 `on_tray_icon_event` 监听 `MouseButton::Left` 和 `MouseButtonState::Up` 实现。

### 单实例强制执行

在桌面平台上，`tauri-plugin-single-instance` 防止同时运行多个 OpenFang 副本。当第二个实例尝试启动时，现有实例的主窗口将被显示、取消最小化并获得焦点：

```rust
#[cfg(desktop)]
{
    builder = builder.plugin(tauri_plugin_single_instance::init(
        |app, _args, _cwd| {
            if let Some(w) = app.get_webview_window("main") {
                let _ = w.show();
                let _ = w.unminimize();
                let _ = w.set_focus();
            }
        },
    ));
}
```

### 关闭时隐藏到托盘

关闭窗口不会退出应用程序。相反，窗口被隐藏并抑制关闭事件：

```rust
.on_window_event(|window, event| {
    #[cfg(desktop)]
    if let tauri::WindowEvent::CloseRequested { api, .. } = event {
        let _ = window.hide();
        api.prevent_close();
    }
})
```

要实际退出，请使用系统托盘菜单中的 **"退出 OpenFang"** 选项。

### 原生操作系统通知

应用程序订阅内核的事件总线，并使用 `tauri-plugin-notification` 将关键事件转发为原生桌面通知：

| 事件 | 通知标题 | 正文 |
|------|----------|------|
| `LifecycleEvent::Crashed` | "代理崩溃" | `代理 {id} 崩溃：{error}` |
| `LifecycleEvent::Spawned` | "代理已启动" | `代理 "{name}" 现在正在运行` |
| `SystemEvent::HealthCheckFailed` | "健康检查失败" | `代理 {id} 无响应 {secs} 秒` |

所有其他事件都被静默跳过。通知监听器作为通过 `tauri::async_runtime::spawn` 生成的异步任务运行，并优雅地处理广播延迟（记录警告并继续）。

---

## IPC 命令

注册了十一个 Tauri IPC 命令，可通过 WebView 前端使用 `invoke()` 调用：

### `get_port`

返回嵌入式服务器正在监听的端口号（`u16`）。

```typescript
// 前端使用
const port: number = await invoke("get_port");
```

### `get_status`

返回带有运行时状态的 JSON 对象：

```json
{
  "status": "running",
  "port": 8042,
  "agents": 5,
  "uptime_secs": 3600
}
```

- `agents` -- 来自 `kernel.registry.list()` 的注册代理计数。
- `uptime_secs` -- 自内核状态初始化以来的秒数（通过启动时的 `Instant::now()`）。

### `get_agent_count`

返回注册代理的数量（`usize`）作为简单整数。

```typescript
const count: number = await invoke("get_agent_count");
```

### `import_agent_toml`

打开 `.toml` 文件的原生文件选择器。将选定文件验证为 `AgentManifest`，将其复制到 `~/.openfang/agents/{name}/agent.toml`，并生成代理。成功时返回代理名称。

### `import_skill_file`

打开技能文件（`.md`、`.toml`、`.py`、`.js`、`.wasm`）的原生文件选择器。将文件复制到 `~/.openfang/skills/` 并触发技能注册表的热重载。

### `get_autostart` / `set_autostart`

检查或切换 OpenFang 是否在操作系统登录时启动。使用 `tauri-plugin-autostart`（macOS 上使用 launchd，Windows 上使用注册表，Linux 上使用 systemd）。

### `check_for_updates`

检查可用更新而不安装。返回 `UpdateInfo` 对象：

```json
{ "available": true, "version": "0.2.0", "body": "发布说明..." }
```

### `install_update`

下载并安装最新更新，然后重新启动应用程序。成功时此命令不返回（应用程序重新启动）。失败时返回错误字符串。

```typescript
await invoke("install_update"); // 如果更新成功，应用程序将重新启动
```

### `open_config_dir` / `open_logs_dir`

在 OS 文件管理器中打开 `~/.openfang/` 或 `~/.openfang/logs/`。

---

## 窗口配置

主窗口在 `setup` 闭包中程序化创建（不是通过 `tauri.conf.json`，它声明一个空的 `windows: []` 数组）：

| 属性 | 值 |
|------|-----|
| 窗口标签 | `"main"` |
| 标题 | `"OpenFang"` |
| URL | `http://127.0.0.1:{port}`（外部） |
| 内部大小 | 1280 x 800 |
| 最小内部大小 | 800 x 600 |
| 位置 | 居中 |

窗口使用 `WebviewUrl::External(...)` 而不是捆绑的前端，因为 WebView 渲染的是 axum 提供的 UI。

### 自动更新器

应用程序在启动后 10 秒检查更新。如果有可用更新，它会自动下载、安装并重新启动应用程序。用户还可以通过系统托盘手动触发检查。

**流程：**
1. 启动检查（10秒延迟） → `check_for_update()` → 如果可用 → 通知用户 → `download_and_install_update()` → 应用程序重新启动
2. 托盘"检查更新" → 相同流程，如果安装失败则显示失败通知

**配置**（在 `tauri.conf.json` 中）：
- `plugins.updater.pubkey` — Ed25519 公钥（必须与签名私钥匹配）
- `plugins.updater.endpoints` — `latest.json` 的 URL（托管在 GitHub Releases 上）
- `plugins.updater.windows.installMode` — `"passive"`（无完整 UI 安装）

**签名：** 每个发布包都使用 `TAURI_SIGNING_PRIVATE_KEY`（GitHub Secret）签名。`tauri-action` 生成包含每个平台下载 URL 和签名的 `latest.json`。

有关密钥生成和设置说明，请参阅 [生产检查清单](production-checklist_CN.md)。

### CSP

`tauri.conf.json` 配置内容安全策略，允许连接到本地嵌入式服务器：

```
default-src 'self' http://127.0.0.1:* ws://127.0.0.1:*;
img-src 'self' data: http://127.0.0.1:*;
style-src 'self' 'unsafe-inline';
script-src 'self' 'unsafe-inline'
```

这允许 WebView 从 localhost API 服务器加载内容，同时阻止外部资源加载。axum API 服务器提供额外的安全标头中间件。

---

## 构建

### 前提条件

- **Rust**（稳定工具链）
- **Tauri CLI v2**：`cargo install tauri-cli --version "^2"`
- **平台特定依赖**：
  - **Windows**：WebView2（包含在 Windows 10/11 中）、Visual Studio 构建工具
  - **macOS**：Xcode 命令行工具
  - **Linux**：`libwebkit2gtk-4.1-dev`、`libappindicator3-dev`、`librsvg2-dev`、`libssl-dev`、`build-essential`

### 开发

```bash
cd crates/openfang-desktop
cargo tauri dev
```

这会启动具有热重载支持的应用程序。控制台窗口在调试构建中可见以显示追踪输出。

### 生产构建

```bash
cd crates/openfang-desktop
cargo tauri build
```

这生成平台特定的安装程序：
- **Windows**：`.msi` 和 `.exe`（NSIS）安装程序
- **macOS**：`.dmg` 和 `.app` 包
- **Linux**：`.deb`、`.rpm` 和 `.AppImage`

发布二进制文件通过以下方式在 Windows 上抑制控制台窗口：

```rust
#![cfg_attr(not(debug_assertions), windows_subsystem = "windows")]
```

### 包配置

来自 `tauri.conf.json`：

```json
{
  "bundle": {
    "active": true,
    "targets": "all",
    "icon": [
      "icons/icon.png",
      "icons/32x32.png",
      "icons/128x128.png",
      "icons/128x128@2x.png"
    ]
  }
}
```

`"targets": "all"` 设置为当前平台生成每种可用的包格式。图标以多种分辨率提供，加上 Windows 的 `icon.ico`。

---

## 插件

| 插件 | 版本 | 用途 |
|------|------|------|
| `tauri-plugin-notification` | 2 | 用于内核事件和更新进度的原生操作系统通知 |
| `tauri-plugin-shell` | 2 | 从 WebView 访问 Shell/进程 |
| `tauri-plugin-dialog` | 2 | 用于代理/技能导入的原生文件选择器 |
| `tauri-plugin-single-instance` | 2 | 防止多个实例（仅限桌面） |
| `tauri-plugin-autostart` | 2 | 在操作系统登录时启动（仅限桌面） |
| `tauri-plugin-updater` | 2 | 来自 GitHub Releases 的签名自动更新（仅限桌面） |
| `tauri-plugin-global-shortcut` | 2 | Ctrl+Shift+O/N/C 快捷键（仅限桌面） |

### 能力

默认能力集（在 `capabilities/default.json` 中定义）授予：

```json
{
  "identifier": "default",
  "windows": ["main"],
  "permissions": [
    "core:default",
    "notification:default",
    "shell:default",
    "dialog:default",
    "global-shortcut:allow-register",
    "global-shortcut:allow-unregister",
    "global-shortcut:allow-is-registered",
    "autostart:default",
    "updater:default"
  ]
}
```

只有 `"main"` 窗口接收这些权限。

---

## 移动就绪

代码库包含用于移动平台支持的条件编译守卫：

- **入口点**：`run()` 函数带有 `#[cfg_attr(mobile, tauri::mobile_entry_point)]` 注解，允许 Tauri 将其用作移动入口点。
- **仅限桌面的功能**：系统托盘设置、单实例强制执行和关闭时隐藏到托盘都在 `#[cfg(desktop)]` 后面，因此它们在移动目标上编译时会被排除。
- **移动目标**：iOS 和 Android 构建在结构上由 Tauri 2.0 框架支持，尽管内核和 API 服务器仍会在设备上以进程内启动。

---

## 文件结构

```
crates/openfang-desktop/
  build.rs                 # tauri_build::build()
  Cargo.toml               # 包依赖和元数据
  tauri.conf.json           # Tauri 应用程序配置
  capabilities/
    default.json            # 主窗口的权限授予
  gen/
    schemas/                # 自动生成的 Tauri 模式
  icons/
    icon.png                # 源图标 (327 KB)
    icon.ico                # Windows 图标
    32x32.png               # 小图标
    128x128.png             # 标准图标
    128x128@2x.png          # HiDPI 图标
  src/
    main.rs                 # 二进制入口点（调用 lib::run()）
    lib.rs                  # Tauri 应用程序构建器、状态类型、事件监听器
    commands.rs             # IPC 命令处理器（get_port、get_status、get_agent_count）
    server.rs               # ServerHandle、内核启动、嵌入式 axum 服务器
    tray.rs                 # 系统托盘菜单和事件处理器
```

---

## 环境变量

| 变量 | 效果 |
|------|------|
| `RUST_LOG` | 控制追踪详细程度。如果未设置，默认为 `openfang=info,tauri=info`。 |

所有其他 OpenFang 环境变量（API 密钥、配置）照常适用，因为桌面应用程序启动的内核与无头守护进程相同。
