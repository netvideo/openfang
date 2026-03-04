# 变更日志

本文档记录 OpenFang 的所有显著变更。

格式基于 [Keep a Changelog](https://keepachangelog.com/en/1.1.0/)，本项目遵循 [语义化版本](https://semver.org/spec/v2.0.0.html)。

## [0.1.0] - 2026-02-24

### 新增

#### 核心平台
- 15 crate Rust 工作空间: types, memory, runtime, kernel, api, channels, wire, cli, migrate, skills, hands, extensions, desktop, xtask
- 代理生命周期管理：spawn, list, kill, clone, 模式切换 (Full/Assist/Observe)
- SQLite 支持的内存底层，包含结构化 KV、语义召回、向量嵌入
- 41 内置工具 (文件系统、网页、shell、调度、协作、图像分析、智能体间、TTS、媒体)
- WASM 沙箱，具备双重计量（燃料 + epoch 中断）
e- 工作流引擎，支持流水线、扇出并行、条件步骤、循环和变量扩展
- 可视化工作流构建器，带拖放画布和 TOML 导出
- 触发系统，包含事件模式匹配、内容过滤器和点火限制
- 事件总线，具备发布/订阅和相关 ID
- 7 Hands 包，用于自主代理操作

#### LLM 支持
- 3 原生 LLM 驱动: Anthropic, Google Gemini, OpenAI-compatible
- 27 提供商: Anthropic, Gemini, OpenAI, Groq, OpenRouter, DeepSeek, Together, Mistral, Fireworks, Cohere, Perplexity, xAI, AI21, Cerebras, SambaNova, Hugging Face, Replicate, Ollama, vLLM, LM Studio，等等
- 模型目录，包含 130+ 内置模型，23个别名，层级分类
- 智能模型路由，具备任务复杂度评分
- 自动故障转移驱动，在提供商之间实现自动故障转移
- 成本估算和计量引擎，具备按模型定价
- 全驱动范围内的流式支持（SSE）
e- 基于令牌/4 的上下文窗口跟踪

#### 令牌管理与上下文
- 基于令牌的会话压缩（字符/4 启发式，70% 上下文容量触发）
- 循环内紧急修剪，70%/90% 阈值，摘要注入
- 工具配置文件过滤（默认41 工具到4-10聊天代理，节省 15-20K 令牌）
- 上下文预算分配，用于系统提示、工具、历史、响应
- MAX_TOOL_RESULT_CHARS 从50K降低到15K防止工具结果膨胀
- 每小时默认令牌配额从100K提高到1M

#### 安全性
- 基于能力的访问控制，具备权限升级预防
- 所有文件工具中的路径遍历保护
- SSRF 保护，阻止私有 IP 和云元数据端点
- 代理清单的 Ed25519 签名
- Merkle 哈希链审计跟踪，具备防篡改检测
- 信息流污点跟踪
- OFP 相互认证，HMAC-SHA256
- 中间件安全头（CSP、X-Frame-Options、HSTS）
e- GCRA 速率限制器，具备成本感知令牌桶
- 所有 API 密钥字段上的密钥归零化
- 子进程环境隔离
- 健康端点修订（公开最小，认证完整）
e- 循环守卫，具备基于 SHA256 的检测和断路器阈值
e- 会话修复（验证并修复孤立工具结果、空消息）

#### 渠道
- 40 渠道适配器：Telegram、Discord、Slack、WhatsApp、Signal、Matrix、Email、Teams、Mattermost、Google Chat、Webex、Feishu/Lark、LINE、Viber、Facebook Messenger、Mastodon、Bluesky、Redit、LinkedIn、Twitch、IRC、XMPP等等
e- 统一桥，具备代理路由、命令处理、消息分割
e- 每渠道用户过滤和RBAC实施
e- 优雅关闭、指数退避、所有适配器上密钥归零化
e
#### API
- 100+ REST/WS/SSE API 端点（axum 0.8）
e- WebSocket 实时流，每个代理连接
- OpenAI-compatible `/v1/chat/completions` API（流式 SSE + 非流式）
e- WebChat 嵌入式 UI，Alpine.js
- Google A2A 协议支持（智能体卡片、任务发送/获取/取消）
e- Prometheus `/api/metrics` 端点用于监控
- 多会话管理：列出、创建、切换、标签会话每个代理
- 使用分析：摘要、按模型、每日分解
- 无需重启配置热重载

#### 桌面应用
- Tauri 2.0 原生桌面应用
- 系统托盘，具备状态和快速操作
- 单实例强制
- 关闭时最小化到托盘
- 更新的CSP，用于媒体、帧和 blob 源

#### 会话管理
- 基于LLM的会话压缩，具备令牌感知触发器
- 每代理多会话，具备命名标签
- 通过API和UI会话切换
- 跨渠道规范会话
- 扩展聊天命令：`/new`、`/compact`、`/model`、`/stop`、`/usage`、`/think`

#### 图像支持
- `ContentBlock::Image`，具备base64内联数据
- 媒体类型验证（仅png、jpeg、gif、webp）
e- 5MB 大小限制执行
- 映射到所有3个原生LLM驱动

#### 使用跟踪
- 每响应成本估算，具备模型感知定价
- 在WebSocket响应和WebChat UI中使用页脚
- 使用事件持久化到SQLite
- 配额执行，具备每小时窗口

#### 互操作性
- OpenClaw迁移引擎（YAML/JSON5到TOML）
e- MCP客户端（JSON-RPC 2.0 over stdio/SSE，工具命名空间）
- MCP服务器（通过MCP协议暴露OpenFang工具）
e- A2A协议客户端和服务器
- 工具名称兼容映射（21 OpenClaw工具名称）
e
#### 基础架构
- 多阶段Dockerfile（debian:bookworm-slim运行时）
- docker-compose.yml，具备卷持久化
- GitHub Actions CI（检查、测试、clippy、格式）
e- GitHub Actions发布（多平台、GHCR推送、SHA256校验和）
e- 跨平台安装脚本（curl/irm一键安装程序）
e- systemd服务文件用于Linux部署

#### 多用户
- RBAC，具备Owner/Admin/User/Viewer角色
- 渠道身份解析
- 每用户授权检查
- 设备配对和审批系统

#### 生产就绪性
- 1731+测试跨越15个crate，0失败
- 跨平台支持（Linux、macOS、Windows）
e- 优雅关闭，信号处理（SIGINT/SIGTERM在Unix，Ctrl+C在Windows）
- 守护进程PID文件，带过期进程检测
- 释放配置文件，LTO、单codegen单元、符号剥离
- Prometheus指标用于监控
- 无需重启配置热重载

[0.1.0]:https://github.com/RightNow-AI/openfang/releases/tag/v0.1.0
