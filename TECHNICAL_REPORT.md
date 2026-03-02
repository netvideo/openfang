# OpenFang Technical Report

## 1. Project Overview

OpenFang is an open-source Agent Operating System written in Rust, comprising 14 crates and approximately 137,000 lines of code. The project compiles to a single ~32MB binary and provides autonomous agents that operate continuously on user-defined schedules (24/7). The system emphasizes security, with 16 distinct security systems implemented, and maintains high code quality with 1,767+ tests and zero Clippy warnings.

The project uses a modern Rust toolchain (Edition 2021, minimum Rust 1.75) and follows the MIT/Apache-2.0 dual licensing model. The workspace configuration uses resolver version 2, enabling careful dependency management across the 14 crates.

## 2. Architecture Overview

### 2.1 Core Components

The OpenFang architecture follows a modular design with 14 specialized crates, each responsible for distinct functionality:

**openfang-kernel** serves as the orchestration layer, managing agent lifecycles, memory systems, permissions, scheduling, and inter-agent communication. Key modules include:

- kernel.rs — Core kernel implementation (OpenFangKernel, DeliveryTracker)
- scheduler.rs — Task scheduling for 24/7 agent operation
- workflow.rs — Workflow orchestration
- metering.rs — Usage tracking and cost management
- capabilities.rs — RBAC and permission management
- auth.rs — Authentication and authorization
- event_bus.rs — Inter-agent communication
- registry.rs — Agent and resource registry
- cron.rs — Cron-based scheduling
- triggers.rs — Event-driven automation
- supervisor.rs — Agent supervision and health monitoring
- background.rs — Background task processing
- pairing.rs — Device pairing for OFP protocol
- heartbeat.rs — Health monitoring
- wizard.rs — Configuration wizards
- config.rs / config_reload.rs — Configuration management
- whatsapp_gateway.rs — WhatsApp gateway integration
- approval.rs — Approval workflows
- auto_reply.rs — Automatic response handling

**openfang-runtime** provides the execution environment for agents, containing 56 source files organized into:

- agent_loop.rs — Core agent execution loop
- llm_driver.rs — LLM integration layer
- drivers/ — Multiple LLM provider implementations (anthropic.rs, openai.rs, gemini.rs, groq.rs, copilot.rs, claude_code.rs, fallback.rs)
- tool_runner.rs — Tool execution orchestration
- sandbox.rs / workspace_sandbox.rs / subprocess_sandbox.rs / docker_sandbox.rs — Isolation environments
- web_search.rs / web_fetch.rs — Web capabilities
- python_runtime.rs — Python script execution
- embedding.rs — Vector embedding generation
- mcp.rs / mcp_server.rs — Model Context Protocol support
- a2a.rs — Agent-to-Agent communication
- browser.rs — Browser automation
- image_gen.rs — Image generation
- tts.rs — Text-to-speech
- context_budget.rs / context_overflow.rs — Token management
- retry.rs — Retry logic
- hooks.rs — Extension hooks
- audit.rs — Audit logging

**openfang-api** exposes 140+ REST/WebSocket/SSE endpoints:

- server.rs — Axum-based HTTP server
- routes.rs — API route definitions
- ws.rs — WebSocket handling
- webchat.rs — Web chat interface
- openai_compat.rs — OpenAI API compatibility layer
- rate_limiter.rs — API rate limiting
- middleware.rs — HTTP middleware
- stream_chunker.rs / stream_dedup.rs — Stream processing
- channel_bridge.rs — Channel integration
- types.rs — API types

**openfang-memory** handles persistent storage:

- session.rs — Session management
- semantic.rs — Semantic memory with vector embeddings
- knowledge.rs — Knowledge graph storage
- structured.rs — Structured data storage
- consolidation.rs — Memory consolidation
- migration.rs — Data migration
- usage.rs — Usage tracking
- substrate.rs — Substrate integration
- lib.rs — Core memory interfaces

**openfang-channels** provides 40 messaging adapters for diverse platforms:

- telegram.rs, slack.rs, discord.rs, whatsapp.rs
- matrix.rs, signal.rs, element.rs
- email.rs, teams.rs, webex.rs
- linkedin.rs, twitter.rs (X), mastodon.rs, bluesky.rs
- reddit.rs, twitch.rs, youtube.rs
- sms.rs (twilio), voice.rs
- webhook.rs — Generic webhook support
- formatter.rs — Message formatting
- router.rs — Channel routing
- bridge.rs — Bridge between protocols

**openfang-skills** bundles 60+ reusable skills that agents can utilize.

**openfang-hands** contains 7 autonomous "Hand" agents:

- researcher/ — Deep research agent with source verification
- browser/ — Web automation
- twitter/ — Social media management
- clip/ — YouTube/video processing
- lead/ — Lead generation
- collector/ — OSINT intelligence gathering
- predictor/ — Forecasting and predictions

Each Hand has configurable settings (research_depth, output_style, source_verification, etc.) and integrates with the knowledge graph and memory systems.

**openfang-types** defines core types, taint tracking for information flow security, and Ed25519 manifest signing.

**openfang-extensions** provides 25 MCP (Model Context Protocol) templates, credential vault, and OAuth2 support.

**openfang-wire** implements the OFP (OpenFang Protocol) P2P communication.

**openfang-cli** — Command-line interface.

**openfang-desktop** — Desktop application built with Tauri 2.0.

**openfang-migrate** — Migration engine for data transitions.

### 2.2 Technology Stack

The project leverages modern Rust ecosystem libraries:

- **Async Runtime**: tokio with full features, tokio-stream
- **HTTP Server**: axum, tower, tower-http
- **WebSocket**: tokio-tungstenite
- **Database**: rusqlite (bundled SQLite)
- **Serialization**: serde, serde_json, toml, rmp-serde
- **WASM**: wasmtime for sandboxing
- **Security**: sha2, hmac, ed25519-dalek, zeroize, aes-gcm, argon2
- **Rate Limiting**: governor
- **CLI**: clap, ratatui
- **Email**: lettre, imap
- **Error Handling**: thiserror, anyhow

Build optimizations: LTO enabled, single codegen unit, stripped binaries, opt-level=3.

## 3. Agent System

### 3.1 Agent Templates

OpenFang ships with 32 pre-built agent templates in the `agents/` directory:

assistant, analyst, architect, coder, customer-support, data-scientist, debugger, devops-lead, doc-writer, email-assistant, health-tracker, hello-world, home-automation, legal-assistant, meeting-assistant, ops, orchestrator, personal-finance, planner, recruiter, researcher, sales-assistant, security-auditor, social-media, test-engineer, translator, travel-planner, tutor, writer, code-reviewer.

Each agent is defined in TOML format with:

- name, version, description, author
- module (builtin:chat, etc.)
- tags for categorization
- model configuration (provider, model, api_key_env, max_tokens, temperature)
- fallback_models for redundancy
- resources (max_llm_tokens_per_hour, max_concurrent_tools)
- capabilities (tools, network, memory, shell permissions)

### 3.2 Agent Configuration Example

The Coder agent demonstrates the configuration pattern:

```toml
name = "coder"
module = "builtin:chat"
[model]
provider = "gemini"
model = "gemini-2.5-flash"
api_key_env = "GEMINI_API_KEY"
max_tokens = 8192
temperature = 0.3
[[fallback_models]]
provider = "groq"
model = "llama-3.3-70b-versatile"
[resources]
max_llm_tokens_per_hour = 200000
max_concurrent_tools = 10
[capabilities]
tools = ["file_read", "file_write", "file_list", "shell_exec", "web_search", "web_fetch", "memory_store", "memory_recall"]
network = ["*"]
memory_read = ["*"]
memory_write = ["self.*"]
shell = ["cargo *", "rustc *", "git *", "npm *", "python *"]
```

### 3.3 Hands (Autonomous Agents)

Hands are autonomous agents capable of independent operation. The Researcher Hand exemplifies the architecture:

- Runs continuously on schedules
- Uses 18 tools: shell_exec, file_read, file_write, file_list, web_fetch, web_search, memory_store, memory_recall, schedule_create/list/delete, knowledge_add_entity/relation/query, event_publish
- Implements 7-phase research methodology: Platform Detection, Question Analysis, Search Strategy, Information Gathering, Cross-Reference, Fact-Check, Report Generation
- Configurable settings: research_depth, output_style, citation_style, source_verification, max_sources, auto_follow_up, language
- Dashboard metrics integration for tracking queries solved, sources cited, reports generated

## 4. LLM Integration

### 4.1 Supported Providers

OpenFang supports 27 LLM providers with 123+ models:

- Anthropic (Claude models)
- Google Gemini
- OpenAI (GPT models)
- Groq
- DeepSeek
- OpenRouter
- Together AI
- Mistral
- Cohere
- AI21
- Meta (Llama via various providers)
- And more

### 4.2 Driver Architecture

The runtime implements a provider-agnostic driver system:

- llm_driver.rs — Core abstraction
- drivers/mod.rs — Provider registry
- drivers/anthropic.rs — Anthropic Claude integration
- drivers/openai.rs — OpenAI GPT integration
- drivers/gemini.rs — Google Gemini integration
- drivers/groq.rs — Groq integration
- drivers/copilot.rs — GitHub Copilot
- drivers/claude_code.rs — Claude Code specific
- drivers/fallback.rs — Fallback chain logic

Features include:

- Automatic fallback between providers
- Provider health monitoring
- Rate limiting per provider
- Token budget management
- Context overflow handling
- Retry with exponential backoff

## 5. Security Systems

OpenFang implements 16 security systems:

1. **WASM Dual-Metered Sandbox** — Resource-constrained execution environment
2. **Merkle Hash-Chain Audit Trail** — Immutable audit logging
3. **Information Flow Taint Tracking** — Data lineage and contamination tracking
4. **Ed25519 Signed Manifests** — Code authenticity verification
5. **SSRF Protection** — Server-Side Request Forgery prevention
6. **Secret Zeroization** — Secure memory clearing
7. **OFP Mutual Authentication** — P2P protocol security
8. **Capability Gates** — RBAC enforcement
9. **Security Headers** — HTTP security headers
10. **Prompt Injection Scanner** — Malicious input detection
11. **Loop Guard** — Infinite loop prevention
12. **Session Repair** — Corrupted session recovery
13. **Path Traversal Prevention** — File system access control
14. **GCRA Rate Limiter** — Generic Cell Rate Algorithm limiting
15. **Content Security Policy** — XSS and injection prevention
16. **Command Sandboxing** — Shell command restriction

## 6. API and Interfaces

### 6.1 REST API

140+ endpoints covering:

- Agent management (CRUD, message sending)
- Budget and metering
- Network status and peers
- A2A (Agent-to-Agent) communication
- Channel management
- Memory and knowledge graph
- Skills and extensions
- Configuration
- Health and diagnostics

### 6.2 WebSocket and SSE

Real-time communication for:

- Agent streaming responses
- Event notifications
- Live dashboard updates

### 6.3 OpenAI Compatibility

OpenFang provides an OpenAI-compatible API layer, enabling integration with existing tools and workflows designed for OpenAI's API.

### 6.4 SDKs

- **JavaScript SDK** — For web integrations
- **Python SDK** — For Python applications and scripting

### 6.5 CLI

Command-line interface built with clap and ratatui for terminal interaction.

### 6.6 Desktop Application

Tauri 2.0-based desktop application in openfang-desktop.

## 7. Channels and Integrations

### 7.1 Messaging Platforms

40 channel adapters support:

- Telegram, Discord, Slack
- WhatsApp, Signal
- Matrix, Element
- Teams, Webex
- Email (SMTP/IMAP)
- SMS (Twilio)
- And 25+ others

### 7.2 Social Media

- Twitter/X, Mastodon, Bluesky
- LinkedIn, Reddit
- Twitch, YouTube

### 7.3 Custom Integrations

- Webhook support for custom integrations
- Bridge capability for protocol translation

## 8. Development Practices

### 8.1 Code Quality

- **Testing**: 1,767+ tests across the workspace
- **Linting**: Zero Clippy warnings enforced
- **Formatting**: cargo fmt required before commits
- **Build**: cargo build --workspace --lib for compilation verification
- **Integration Testing**: Live tests required for new endpoints

### 8.2 Configuration

- Default config location: ~/.openfang/config.toml
- Default API endpoint: http://127.0.0.1:4200
- Environment-based API key configuration

### 8.3 Development Workflow

1. Implement feature
2. cargo build --workspace --lib
3. cargo test --workspace
4. cargo clippy --workspace --all-targets -- -D warnings
5. Run live integration tests
6. Submit PR

## 9. Key Features Summary

- **Agent Operating System**: 24/7 autonomous agents running on schedules
- **Multi-Provider LLM**: 27 providers, 123+ models with automatic fallback
- **40 Channel Adapters**: Comprehensive messaging platform support
- **7 Autonomous Hands**: Pre-built specialized agents
- **60+ Bundled Skills**: Reusable agent capabilities
- **Vector Memory**: Semantic search and knowledge graphs
- **WASM Sandboxing**: Secure tool execution
- **P2P Protocol**: OFP for distributed communication
- **Desktop/App**: Tauri-based desktop application
- **Security-First**: 16 security systems implemented

## 10. Project Structure

```
openfang/
├── agents/                  # 32 agent templates
├── crates/
│   ├── openfang-api/       # REST/WebSocket API (12 files)
│   ├── openfang-channels/  # 40 messaging adapters (47 files)
│   ├── openfang-cli/       # CLI tool
│   ├── openfang-desktop/  # Tauri desktop app
│   ├── openfang-extensions/# MCP templates, OAuth
│   ├── openfang-hands/    # 7 autonomous Hands
│   ├── openfang-kernel/   # Core orchestration (22 files)
│   ├── openfang-memory/   # Storage and memory (9 files)
│   ├── openfang-migrate/ # Migration engine
│   ├── openfang-runtime/  # Agent execution (56 files)
│   ├── openfang-skills/   # 60+ bundled skills
│   ├── openfang-types/    # Core types
│   └── openfang-wire/     # P2P protocol
├── packages/
│   └── whatsapp-gateway/ # WhatsApp integration
├── scripts/               # Install scripts
├── sdk/
│   ├── javascript/        # JS SDK
│   └── python/            # Python SDK
└── docs/                 # Documentation
```

---

*Report generated from OpenFang project analysis. For the latest information, refer to the official GitHub repository.*