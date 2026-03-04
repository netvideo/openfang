# 智能体模板目录

OpenFang 附带 **30 个预构建的智能体模板**，按 4 个性能层级组织。每个模板是一个可立即生成的 `agent.toml` 清单，位于 `agents/` 目录中。模板涵盖软件工程、业务运营、个人生产力和日常任务。

## 快速开始

从 CLI 生成任何模板：

```bash
openfang spawn orchestrator
openfang spawn coder
openfang spawn --template agents/writer/agent.toml
```

通过 REST API 生成：

```bash
# 从内置模板名称生成
curl -X POST http://localhost:4200/api/agents \
  -H "Content-Type: application/json" \
  -d '{"template": "coder"}'

# 带覆盖生成
curl -X POST http://localhost:4200/api/agents \
  -H "Content-Type: application/json" \
  -d '{"template": "writer", "model": "gemini-2.5-flash"}'
```

向运行中的智能体发送消息：

```bash
curl -X POST http://localhost:4200/api/agents/{id}/message \
  -H "Content-Type: application/json" \
  -d '{"content": "为认证模块编写单元测试"}'
```

---

## 模板层级

模板按任务复杂度和使用的 LLM 模型组织为 4 个层级。更高层级使用更强大（也更昂贵）的模型来处理需要深度推理的任务。

### 层级 1 -- 前沿 (DeepSeek)

用于需要最深推理的任务：多智能体编排、系统架构和安全分析。

| 模板 | 提供程序 | 模型 |
|----------|----------|-------|
| orchestrator | deepseek | deepseek-chat |
| architect | deepseek | deepseek-chat |
| security-auditor | deepseek | deepseek-chat |

如果 DeepSeek API 密钥不可用，所有层级 1 智能体将回退到 `groq/llama-3.3-70b-versatile`。

### 层级 2 -- 智能 (Gemini 2.5 Flash)

用于需要强大分析和编码能力的任务：软件工程、数据科学、研究、测试和法律审查。

| 模板 | 提供程序 | 模型 |
|----------|----------|-------|
| coder | gemini | gemini-2.5-flash |
| code-reviewer | gemini | gemini-2.5-flash |
| data-scientist | gemini | gemini-2.5-flash |
| debugger | gemini | gemini-2.5-flash |
| researcher | gemini | gemini-2.5-flash |
| analyst | gemini | gemini-2.5-flash |
| test-engineer | gemini | gemini-2.5-flash |
| legal-assistant | gemini | gemini-2.5-flash |

如果 Gemini API 密钥不可用，所有层级 2 智能体将回退到 `groq/llama-3.3-70b-versatile`。

### 层级 3 -- 平衡 (Groq + Gemini 回退)

用于日常业务和生产力任务：规划、写作、电子邮件、客户支持、销售、招聘和会议。

| 模板 | 提供程序 | 模型 | 回退 |
|----------|----------|-------|----------|
| planner | groq | llama-3.3-70b-versatile | gemini/gemini-2.0-flash |
| writer | groq | llama-3.3-70b-versatile | gemini/gemini-2.0-flash |
| doc-writer | groq | llama-3.3-70b-versatile | gemini/gemini-2.0-flash |
| devops-lead | groq | llama-3.3-70b-versatile | gemini/gemini-2.0-flash |
| assistant | groq | llama-3.3-70b-versatile | gemini/gemini-2.0-flash |
| email-assistant | groq | llama-3.3-70b-versatile | gemini/gemini-2.0-flash |
| social-media | groq | llama-3.3-70b-versatile | gemini/gemini-2.0-flash |
| customer-support | groq | llama-3.3-70b-versatile | gemini/gemini-2.0-flash |
| sales-assistant | groq | llama-3.3-70b-versatile | gemini/gemini-2.0-flash |
| recruiter | groq | llama-3.3-70b-versatile | gemini/gemini-2.0-flash |
| meeting-assistant | groq | llama-3.3-70b-versatile | gemini/gemini-2.0-flash |

### 层级 4 -- 快速 (仅 Groq)

用于轻量级、高速任务：运维监控、翻译、辅导、健康跟踪、预算、旅行和家居自动化。未配置回退模型（`ops` 除外，它使用较小的 8B 模型以提高速度）。

| 模板 | 提供程序 | 模型 |
|----------|----------|-------|
| ops | groq | llama-3.1-8b-instant |
| hello-world | groq | llama-3.3-70b-versatile |
| translator | groq | llama-3.3-70b-versatile |
| tutor | groq | llama-3.3-70b-versatile |
| health-tracker | groq | llama-3.3-70b-versatile |
| personal-finance | groq | llama-3.3-70b-versatile |
| travel-planner | groq | llama-3.3-70b-versatile |
| home-automation | groq | llama-3.3-70b-versatile |

---

## 模板目录

### orchestrator

**层级 1 -- 前沿** | `deepseek/deepseek-chat` | 回退：`groq/llama-3.3-70b-versatile`

> 元智能体，用于分解复杂任务，委托给专业智能体，并综合结果。

编排器是智能体舰队的指挥中心。它分析用户请求，将其分解为子任务，使用 `agent_list` 发现可用的专家，通过 `agent_send` 委派工作，在需要时生成新的智能体，并将所有响应综合成连贯的最终答案。它在执行前解释其委托策略，并避免委托过于简单的任务。

- **标签**：无
- **温度**：0.3
- **最大令牌数**：8192
- **令牌配额**：500,000/小时
- **调度**：每 120 秒连续检查
- **工具**：`agent_send`、`agent_spawn`、`agent_list`、`agent_kill`、`memory_store`、`memory_recall`、`file_read`、`file_write`
- **能力**：`agent_spawn = true`、`agent_message = ["*"]`、`memory_read = ["*"]`、`memory_write = ["*"]`

```bash
openfang spawn orchestrator
# "规划和执行代码库的完整安全审计"
```

---

### architect

**层级 1 -- 前沿** | `deepseek/deepseek-chat` | 回退：`groq/llama-3.3-70b-versatile`

> 系统架构师。设计软件架构，评估权衡，创建技术规范。

遵循关注点分离、性能感知设计、简洁优于聪明，以及为变化设计而不过度工程化的原则设计系统。澄清需求，识别关键组件，定义接口和数据流，评估权衡（延迟、吞吐量、复杂度、可维护性），并记录决策及理由。输出使用清晰的标题、ASCII 图表和结构化推理。

- **标签**：`architecture`、`design`、`planning`
- **温度**：0.3
- **最大令牌数**：8192
- **令牌配额**：200,000/小时
- **工具**：`file_read`、`file_list`、`memory_store`、`memory_recall`、`agent_send`
- **能力**：`agent_message = ["*"]`、`memory_read = ["*"]`、`memory_write = ["self.*", "shared.*"]`

```bash
openfang spawn architect
# "为支付处理系统设计微服务架构"
```

---

### security-auditor

**层级 1 -- 前沿** | `deepseek/deepseek-chat` | 回退：`groq/llama-3.3-70b-versatile`

> 安全专家。审查代码中的漏洞，检查配置，执行威胁建模。

专注于 OWASP Top 10、输入验证、认证缺陷、加密误用、注入攻击（SQL、命令、XSS、SSTI）、不安全的反序列化、密钥管理、依赖项漏洞、竞争条件和权限提升。映射攻击面，从不受信任的输入跟踪数据流，检查信任边界，审查错误处理，并评估加密实现。报告带有严重级别（CRITICAL/HIGH/MEDIUM/LOW/INFO）的发现，格式为：发现、影响、证据、修复。

- **标签**：`security`、`audit`、`vulnerability`
- **温度**：0.2
- **最大令牌数**：4096
- **令牌配额**：150,000/小时
- **调度**：在 `event:agent_spawned`、`event:agent_terminated` 时主动执行
- **工具**：`file_read`、`file_list`、`shell_exec`、`memory_store`、`memory_recall`
- **Shell 访问**：`cargo audit *`、`cargo tree *`、`git log *`
- **能力**：`memory_read = ["*"]`、`memory_write = ["self.*", "shared.*"]`

```bash
openfang spawn security-auditor
# "审计认证模块的漏洞"
```

---

### coder

**层级 2 -- 智能** | `gemini/gemini-2.5-flash` | 回退：`groq/llama-3.3-70b-versatile`

> 专家软件工程师。读取、编写和分析代码。

编写干净、生产质量的代码，采用逐步推理方法。首先读取文件以了解上下文，然后进行精确的更改。始终为生成的代码编写测试。支持 Rust、Python、JavaScript 和其他语言。

- **标签**：`coding`、`implementation`、`rust`、`python`
- **温度**：0.3
- **最大令牌数**：8192
- **令牌配额**：200,000/小时
- **最大并发工具数**：10
- **工具**：`file_read`、`file_write`、`file_list`、`shell_exec`
- **Shell 访问**：`cargo *`、`rustc *`、`git *`、`npm *`、`python *`
- **能力**：`memory_read = ["*"]`、`memory_write = ["self.*"]`

```bash
openfang spawn coder
# "使用令牌桶算法在 Rust 中实现速率限制器"
```

---

### code-reviewer

**层级 2 -- 智能** | `gemini/gemini-2.5-flash` | 回退：`groq/llama-3.3-70b-versatile`

> 高级代码审查员。审查 PR，识别问题，提出符合生产标准的改进建议。

按优先级审查代码：正确性、安全性、性能、可维护性、风格。按文件分组反馈，带有严重级别标签：`[MUST FIX]`、`[SHOULD FIX]`、`[NIT]`、`[PRAISE]`。解释 WHY，而不仅仅是 WHAT。为建议的更改提供具体代码。认可好代码，当有格式化工具存在时避免对风格的过度争论。

- **标签**：`review`、`code-quality`、`best-practices`
- **温度**：0.3
- **最大令牌数**：4096
- **令牌配额**：150,000/小时
- **工具**：`file_read`、`file_list`、`shell_exec`、`memory_store`、`memory_recall`
- **Shell 访问**：`cargo clippy *`、`cargo fmt *`、`git diff *`、`git log *`
- **能力**：`memory_read = ["*"]`、`memory_write = ["self.*", "shared.*"]`

```bash
openfang spawn code-reviewer
# "审查最近 3 次提交的更改，评估生产准备情况"
```

---

### data-scientist

**层级 2 -- 智能** | `gemini/gemini-2.5-flash` | 回退：`groq/llama-3.3-70b-versatile`

> 数据科学家。分析数据集、构建模型、创建可视化、执行统计分析。

遵循结构化方法：理解问题，探索数据（形状、分布、缺失值），使用适当的统计方法进行分析，按需构建预测模型，并清晰地传达发现。工具包包括描述性统计、假设检验（t 检验、卡方、ANOVA）、相关/回归、时间序列、聚类、降维和 A/B 测试设计。

- **标签**：无
- **温度**：0.3
- **最大令牌数**：4096
- **令牌配额**：150,000/小时
- **工具**：`file_read`、`file_write`、`file_list`、`shell_exec`、`memory_store`、`memory_recall`
- **Shell 访问**：`python *`
- **能力**：`memory_read = ["*"]`、`memory_write = ["self.*", "shared.*"]`

```bash
openfang spawn data-scientist
# "分析此 CSV 数据集并识别与流失相关的 top 3 因素"
```

---

### debugger

**层级 2 -- 智能** | `gemini/gemini-2.5-flash` | 回退：`groq/llama-3.3-70b-versatile`

> 专家调试器。跟踪错误、分析堆栈跟踪、执行根本原因分析。

遵循严格的方法：复现、隔离（通过代码/数据进行二分搜索）、识别根本原因（不仅仅是症状）、修复（最小正确的修复）、验证（回归测试）。查找常见模式：差一错误、空值、竞争条件、资源泄漏。检查错误处理路径和最近的更改。以错误报告、根本原因、修复、预防的形式呈现发现。

- **标签**：无
- **温度**：0.2
- **最大令牌数**：4096
- **令牌配额**：150,000/小时
- **工具**：`file_read`、`file_list`、`shell_exec`、`memory_store`、`memory_recall`
- **Shell 访问**：`cargo *`、`git log *`、`git diff *`、`git show *`
- **能力**：`memory_read = ["*"]`、`memory_write = ["self.*", "shared.*"]`

```bash
openfang spawn debugger
# "当名称包含 unicode 时，API 在 POST /api/agents 上返回 500 -- 找到根本原因"
```

---

### researcher

**层级 2 -- 智能** | `gemini/gemini-2.5-flash` | 回退：`groq/llama-3.3-70b-versatile`

> 研究智能体。获取网页内容并综合信息。

获取网页、阅读文档，并将发现综合成清晰、结构化的报告。始终引用来源，将事实与分析分开，并标记不确定性。将研究任务分解为子问题并系统地调查每个问题。

- **标签**：`research`、`analysis`、`web`
- **温度**：0.5
- **最大令牌数**：4096
- **令牌配额**：150,000/小时
- **工具**：`web_fetch`、`file_read`、`file_write`、`file_list`
- **能力**：`network = ["*"]`、`memory_read = ["*"]`、`memory_write = ["self.*", "shared.*"]`

```bash
openfang spawn researcher
# "研究 WebAssembly 组件模型的当前状态并总结关键提案"
```

---

### analyst

**层级 2 -- 智能** | `gemini/gemini-2.5-flash` | 回退：`groq/llama-3.3-70b-versatile`

> 数据分析师。处理数据、生成洞察、创建报告。

分析数据、发现模式、生成洞察并创建结构化报告。展示方法论，使用数字和证据支持结论。首先读取文件以了解数据结构，然后展示带摘要、关键指标、详细分析和建议的发现。

- **标签**：无
- **温度**：0.4
- **最大令牌数**：4096
- **令牌配额**：150,000/小时
- **工具**：`file_read`、`file_write`、`file_list`、`shell_exec`
- **Shell 访问**：`python *`、`cargo *`
- **能力**：`memory_read = ["*"]`、`memory_write = ["self.*", "shared.*"]`

```bash
openfang spawn analyst
# "分析服务器访问日志并按小时和端点报告流量模式"
```

---

### test-engineer

**层级 2 -- 智能** | `gemini/gemini-2.5-flash` | 回退：`groq/llama-3.3-70b-versatile`

> 质量保证工程师。设计测试策略、编写测试、验证正确性。

测试记录行为，而不是实现。偏好快速、确定性的测试。设计单元测试、集成测试、基于属性的测试、边缘情况测试和回归测试。遵循 Arrange-Act-Assert 模式，使用描述性测试名称（`test_X_when_Y_should_Z`）。审查测试覆盖率以识别未测试的路径和缺失的边缘情况。

- **标签**：`testing`、`qa`、`validation`
- **温度**：0.3
- **最大令牌数**：4096
- **令牌配额**：150,000/小时
- **工具**：`file_read`、`file_write`、`file_list`、`shell_exec`、`memory_store`、`memory_recall`
- **Shell 访问**：`cargo test *`、`cargo check *`
- **能力**：`memory_read = ["*"]`、`memory_write = ["self.*", "shared.*"]`

```bash
openfang spawn test-engineer
# "为速率限制器模块编写全面的测试，覆盖边缘情况"
```

---

### legal-assistant

**层级 2 -- 智能** | `gemini/gemini-2.5-flash` | 回退：`groq/llama-3.3-70b-versatile`

> 法律助理，用于合同审查、法律研究、合规检查和文档起草。

系统性地审查合同，涵盖各方、终止条款、付款条件、赔偿、知识产权条款、保密、管辖法律和不可抗力。起草 NDA、服务协议、服务条款、隐私政策和雇佣协议。检查 GDPR、SOC 2、HIPAA、PCI DSS、CCPA/CPRA、ADA 和 OSHA 的合规性。始终包含免责声明，说明输出不构成法律建议。

- **标签**：`legal`、`contracts`、`compliance`、`research`、`review`、`documents`
- **温度**：0.2
- **最大令牌数**：8192
- **令牌配额**：200,000/小时
- **最大并发工具数**：5
- **工具**：`file_read`、`file_write`、`file_list`、`memory_store`、`memory_recall`、`web_fetch`
- **能力**：`network = ["*"]`、`memory_read = ["*"]`、`memory_write = ["self.*", "shared.*"]`

```bash
openfang spawn legal-assistant
# "审查此 NDA 并标记任何单方面或有问题的条款"
```

---

### planner

**层级 3 -- 平衡** | `groq/llama-3.3-70b-versatile` | 回退：`gemini/gemini-2.0-flash`

> 项目规划师。创建项目计划、分解史诗、估算工作量、识别风险和依赖。

遵循结构化方法论：范围（内/外）、分解（史诗到故事到任务）、排序（依赖和关键路径）、估算（S/M/L/XL 带理由）、风险（技术和进度）、里程碑（带验收标准）。估算范围（最佳/可能/最差），首先处理风险最高的部分，并为未知情况预留 20-30% 的缓冲。

- **标签**：无
- **温度**：0.3
- **最大令牌数**：8192
- **令牌配额**：200,000/小时
- **工具**：`file_read`、`file_list`、`memory_store`、`memory_recall`、`agent_send`
- **能力**：`agent_message = ["*"]`、`memory_read = ["*"]`、`memory_write = ["self.*", "shared.*"]`

```bash
openfang spawn planner
# "创建一个在 6 个月内将我们的单体应用迁移到微服务的项目计划"
```

---

### writer

**层级 3 -- 平衡** | `groq/llama-3.3-70b-versatile` | 回退：`gemini/gemini-2.0-flash`

> 内容写手。创建文档、文章和技术写作。

擅长文档、技术写作、博客文章和清晰沟通。使用主动语态简洁写作，使用标题和项目符号构建内容。当被要求时读取现有文件获取上下文，并将输出生成到文件。

- **标签**：无
- **温度**：0.7
- **最大令牌数**：4096
- **令牌配额**：100,000/小时
- **工具**：`file_read`、`file_write`、`file_list`
- **能力**：`memory_read = ["*"]`、`memory_write = ["self.*"]`

```bash
openfang spawn writer
# "写一篇关于基于智能体的架构优势的博客文章"
```

---

### doc-writer

**层级 3 -- 平衡** | `groq/llama-3.3-70b-versatile` | 回退：`gemini/gemini-2.0-flash`

> 技术写作。创建文档、README 文件、API 文档、教程和架构指南。

为读者写作：从 WHY 开始，然后是 WHAT，然后是 HOW。使用渐进式披露（从概述到细节）。创建 README、API 文档、架构文档、教程、参考文档和架构决策记录（ADR）。使用主动语态、短句，并为每个非平凡概念包含代码示例。

- **标签**：无
- **温度**：0.4
- **最大令牌数**：8192
- **令牌配额**：200,000/小时
- **工具**：`file_read`、`file_write`、`file_list`、`memory_store`、`memory_recall`
- **能力**：`memory_read = ["*"]`、`memory_write = ["self.*", "shared.*"]`

```bash
openfang spawn doc-writer
# "为所有 /api/agents 端点编写 API 文档"
```

---

### devops-lead

**层级 3 -- 平衡** | `groq/llama-3.3-70b-versatile` | 回退：`gemini/gemini-2.0-flash`

> DevOps 负责人。管理 CI/CD、基础设施、部署、监控和事件响应。

涵盖 CI/CD 管道设计、容器编排（Docker、Kubernetes）、基础设施即代码（Terraform、Pulumi）、监控和可观测性（Prometheus、Grafana、OpenTelemetry）、事件响应、安全加固和容量规划。设计具有快速反馈循环、不可变工件和自动回滚的管道。

- **标签**：无
- **温度**：0.2
- **最大令牌数**：4096
- **令牌配额**：150,000/小时
- **工具**：`file_read`、`file_write`、`file_list`、`shell_exec`、`memory_store`、`memory_recall`、`agent_send`
- **Shell 访问**：`docker *`、`git *`、`cargo *`、`kubectl *`
- **能力**：`agent_message = ["*"]`、`memory_read = ["*"]`、`memory_write = ["self.*", "shared.*"]`

```bash
openfang spawn devops-lead
# "为我们的 Rust 工作空间设计一个具有 staging 和 production 环境的 CI/CD 管道"
```

---

### assistant

**层级 3 -- 平衡** | `groq/llama-3.3-70b-versatile` | 回退：`gemini/gemini-2.0-flash`

> 通用助手。默认的 OpenFang 智能体，用于日常任务、问题和对话。

多功能默认智能体，涵盖对话智能、任务执行、研究和综合、写作和沟通、问题解决、智能体委托（将专业任务路由到正确的专家）、知识管理和创意头脑风暴。作为用户值得信赖的第一联系人 -- 直接处理大多数任务，并在专家能做得更好时委托给他们。

- **标签**：`general`、`assistant`、`default`、`multipurpose`、`conversation`、`productivity`
- **温度**：0.5
- **最大令牌数**：8192
- **令牌配额**：300,000/小时
- **最大并发工具数**：10
- **工具**：`file_read`、`file_write`、`file_list`、`memory_store`、`memory_recall`、`web_fetch`、`shell_exec`、`agent_send`、`agent_list`
- **Shell 访问**：`python *`、`cargo *`、`git *`、`npm *`
- **能力**：`network = ["*"]`、`agent_message = ["*"]`、`memory_read = ["*"]`、`memory_write = ["self.*", "shared.*"]`

```bash
openfang spawn assistant
# "帮我规划我的一周并起草对这三封电子邮件的回复"
```

---

### email-assistant

**层级 3 -- 平衡** | `groq/llama-3.3-70b-versatile` | 回退：`gemini/gemini-2.0-flash`

> 电子邮件分类、起草、调度和收件箱管理智能体。

通过紧急程度、类别和所需操作快速分类收到的电子邮件。根据收件人和情况起草专业的电子邮件。管理基于电子邮件的调度和后续义务。识别重复出现的电子邮件模式并生成可重用的模板。为长线程和高容量收件箱生成简洁的摘要。

- **标签**：`email`、`communication`、`triage`、`drafting`、`scheduling`、`productivity`
- **温度**：0.4
- **最大令牌数**：8192
- **令牌配额**：150,000/小时
- **最大并发工具数**：5
- **工具**：`file_read`、`file_write`、`file_list`、`memory_store`、`memory_recall`、`web_fetch`
- **能力**：`network = ["*"]`、`memory_read = ["*"]`、`memory_write = ["self.*", "shared.*"]`

```bash
openfang spawn email-assistant
# "分类这 15 封电子邮件并为紧急的草拟回复"
```

---

### social-media

**层级 3 -- 平衡** | `groq/llama-3.3-70b-versatile` | 回退：`gemini/gemini-2.0-flash`

> 社交媒体内容创建、调度和参与策略智能体。

为 Twitter/X、LinkedIn、Instagram、Facebook、TikTok、Reddit、Mastodon、Bluesky 和 Threads 制作平台优化内容。规划内容日历，设计参与策略，分析参与数据，定义品牌声音指南，并优化标签和 SEO。根据平台将语气从专业思想领导力调整到休闲和犀利。

- **标签**：`social-media`、`content`、`marketing`、`engagement`、`scheduling`、`analytics`
- **温度**：0.7
- **最大令牌数**：4096
- **令牌配额**：120,000/小时
- **最大并发工具数**：5
- **工具**：`file_read`、`file_write`、`file_list`、`memory_store`、`memory_recall`、`web_fetch`
- **能力**：`network = ["*"]`、`memory_read = ["*"]`、`memory_write = ["self.*", "shared.*"]`

```bash
openfang spawn social-media
# "创建一周关于我们开源发布的 LinkedIn 帖子"
```

---

### customer-support

**层级 3 -- 平衡** | `groq/llama-3.3-70b-versatile` | 回退：`gemini/gemini-2.0-flash`

> 客户支持智能体，用于工单处理、问题解决和客户沟通。

按类别、严重程度、产品区域和客户层级分类支持工单。遵循系统化的故障排除工作流程进行问题诊断。撰写共情的、以解决方案为导向的客户回复。管理知识库内容和升级交接。监控客户情绪并生成支持指标摘要。

- **标签**：`support`、`customer-service`、`tickets`、`helpdesk`、`communication`、`resolution`
- **温度**：0.3
- **最大令牌数**：4096
- **令牌配额**：200,000/小时
- **最大并发工具数**：5
- **工具**：`file_read`、`file_write`、`file_list`、`memory_store`、`memory_recall`、`web_fetch`
- **能力**：`network = ["*"]`、`memory_read = ["*"]`、`memory_write = ["self.*", "shared.*"]`

```bash
openfang spawn customer-support
# "分类这批支持工单并为前 5 个紧急的草拟回复"
```

---

### sales-assistant

**层级 3 -- 平衡** | `groq/llama-3.3-70b-versatile` | 回退：`gemini/gemini-2.0-flash`

> 销售助理，用于 CRM 更新、外联起草、管道管理和交易跟踪。

使用 AIDA 框架起草个性化的冷门外联电子邮件。管理带有结构化更新的 CRM 数据。分析带有加权价值、有风险的交易和转化率的销售管道。准备带有潜在客户研究的通话前简报。构建竞争性战斗卡并执行输赢分析。

- **标签**：`sales`、`crm`、`outreach`、`pipeline`、`prospecting`、`deals`
- **温度**：0.5
- **最大令牌数**：4096
- **令牌配额**：150,000/小时
- **最大并发工具数**：5
- **工具**：`file_read`、`file_write`、`file_list`、`memory_store`、`memory_recall`、`web_fetch`
- **能力**：`network = ["*"]`、`memory_read = ["*"]`、`memory_write = ["self.*", "shared.*"]`

```bash
openfang spawn sales-assistant
# "为中型市场 SaaS 公司的 CTO 起草一个 3 次接触的外联序列"
```

---

### recruiter

**层级 3 -- 平衡** | `groq/llama-3.3-70b-versatile` | 回退：`gemini/gemini-2.0-flash`

> 招聘智能体，用于简历筛选、候选人外联、职位描述编写和招聘管道管理。

使用结构化匹配评分根据职位要求评估简历。撰写包容性的、可搜索的职位描述。起草个性化的候选人外联序列。准备带有 STAR 格式行为问题的结构化面试指南。跟踪候选人通过招聘管道阶段并生成报告。积极支持包容性招聘实践。

- **标签**：`recruiting`、`hiring`、`resume`、`outreach`、`talent`、`hr`
- **温度**：0.4
- **最大令牌数**：4096
- **令牌配额**：150,000/小时
- **最大并发工具数**：5
- **工具**：`file_read`、`file_write`、`file_list`、`memory_store`、`memory_recall`、`web_fetch`
- **能力**：`network = ["*"]`、`memory_read = ["*"]`、`memory_write = ["self.*", "shared.*"]`

```bash
openfang spawn recruiter
# "根据高级后端工程师职位要求筛选这 10 份简历"
```

---

### meeting-assistant

**层级 3 -- 平衡** | `groq/llama-3.3-70b-versatile` | 回退：`gemini/gemini-2.0-flash`

> 会议记录、行动项、议程准备和后续跟踪智能体。

创建结构化、限时的议程。将原始会议记录或转录转换为干净、结构化的会议记录，包含执行摘要、关键讨论点、决策和行动项。提取每个承诺的所有者、截止日期和优先级。起草后续电子邮件并安排提醒。综合多个相关会议以识别主题和差距。

- **标签**：`meetings`、`notes`、`action-items`、`agenda`、`follow-up`、`productivity`
- **温度**：0.3
- **最大令牌数**：8192
- **令牌配额**：150,000/小时
- **最大并发工具数**：5
- **工具**：`file_read`、`file_write`、`file_list`、`memory_store`、`memory_recall`
- **能力**：`memory_read = ["*"]`、`memory_write = ["self.*", "shared.*"]`

```bash
openfang spawn meeting-assistant
# "处理此会议转录并提取所有带有所有者和截止日期的行动项"
```

---

### ops

**层级 4 -- 快速** | `groq/llama-3.1-8b-instant` | 无回退

> DevOps 智能体。监控系统、运行诊断、管理部署。

监控系统健康状况、运行诊断并帮助部署。精确而谨慎 -- 在运行命令之前解释它的作用。除非明确要求更改，否则偏好只读操作。以结构化格式报告：状态、详细信息、建议的操作。在舰队中使用最小的模型（8B）以在例行运维检查上获得最大速度。

- **标签**：无
- **温度**：0.2
- **最大令牌数**：2048
- **令牌配额**：50,000/小时
- **调度**：每 5 分钟定期执行
- **工具**：`shell_exec`、`file_read`、`file_list`
- **Shell 访问**：`docker *`、`git *`、`cargo *`、`systemctl *`、`ps *`、`df *`、`free *`
- **能力**：`memory_read = ["*"]`、`memory_write = ["self.*"]`

```bash
openfang spawn ops
# "检查磁盘使用情况、内存和运行中的容器"
```

---

### hello-world

**层级 4 -- 快速** | `groq/llama-3.3-70b-versatile` | 无回退

> 一个友好的问候智能体，可以读取文件和获取网页。

最简单的智能体模板 -- 一个具有基本只读能力的最小入门智能体。没有系统提示，没有标签，没有 shell 访问。可用作自定义智能体的起点或用于测试智能体系统是否正常工作。

- **标签**：无
- **温度**：默认
- **最大令牌数**：默认
- **令牌配额**：100,000/小时
- **工具**：`file_read`、`file_list`、`web_fetch`
- **能力**：`memory_read = ["*"]`、`memory_write = ["self.*"]`、`agent_spawn = false`

```bash
openfang spawn hello-world
# "你好！你能做什么？"
```

---

### translator

**层级 4 -- 快速** | `groq/llama-3.3-70b-versatile` | 无回退

> 多语言翻译智能体，用于文档翻译、本地化和跨文化交流。

在 20+ 种主要语言之间进行高保真翻译，保留含义、语气和意图。处理上下文和文化适应、文档格式保留、软件本地化（JSON、YAML、PO/POT、XLIFF）、技术/专业翻译、翻译质量保证（回译、一致性检查）和词汇表管理。标记具有多种翻译选项的模糊短语。

- **标签**：`translation`、`languages`、`localization`、`multilingual`、`communication`、`i18n`
- **温度**：0.3
- **最大令牌数**：8192
- **令牌配额**：200,000/小时
- **最大并发工具数**：5
- **工具**：`file_read`、`file_write`、`file_list`、`memory_store`、`memory_recall`、`web_fetch`
- **能力**：`network = ["*"]`、`memory_read = ["*"]`、`memory_write = ["self.*", "shared.*"]`

```bash
openfang spawn translator
# "将此 README 从英语翻译成日语和西班牙语，保留代码块"
```

---

### tutor

**层级 4 -- 快速** | `groq/llama-3.3-70b-versatile` | 无回退

> 教学和解释智能体，用于学习、辅导和教育内容创建。

使用费曼技巧在学习者水平上解释概念。使用苏格拉底式提问引导发现。跨数学、计算机科学、自然科学、人文科学、社会科学和专业技能进行教学。逐步解决问题，展示推理而不仅仅是解决方案。创建带有间隔重复的结构化学习计划。提供带有详细、建设性反馈的练习题。

- **标签**：`education`、`teaching`、`tutoring`、`learning`、`explanation`、`knowledge`
- **温度**：0.5
- **最大令牌数**：8192
- **令牌配额**：200,000/小时
- **最大并发工具数**：5
- **工具**：`file_read`、`file_write`、`file_list`、`memory_store`、`memory_recall`、`shell_exec`、`web_fetch`
- **Shell 访问**：`python *`
- **能力**：`network = ["*"]`、`memory_read = ["*"]`、`memory_write = ["self.*", "shared.*"]`

```bash
openfang spawn tutor
# "教我二分搜索树的工作原理，从基础开始"
```

---

### health-tracker

**层级 4 -- 快速** | `groq/llama-3.3-70b-versatile` | 无回退

> 健康跟踪智能体，用于健康指标、药物提醒、健身目标和生活习惯。

跟踪体重、血压、心率、睡眠、饮水量、步数、情绪和自定义指标。管理带有剂量、时间和补充日期的药物调度。设置带有渐进训练计划的 SMART 健身目标。记录餐食并估计营养含量。应用基于证据的习惯形成原则。生成定期健康报告。始终包含免责声明，说明它不是医疗专业人员。

- **标签**：`health`、`wellness`、`fitness`、`medication`、`habits`、`tracking`
- **温度**：0.3
- **最大令牌数**：4096
- **令牌配额**：100,000/小时
- **最大并发工具数**：5
- **调度**：每 1 小时定期执行
- **工具**：`file_read`、`file_write`、`file_list`、`memory_store`、`memory_recall`
- **能力**：`memory_read = ["*"]`、`memory_write = ["self.*"]`

```bash
openfang spawn health-tracker
# "记录今天的指标：体重 175 磅，睡眠 7.5 小时，情绪 8/10，8000 步"
```

---

### personal-finance

**层级 4 -- 快速** | `groq/llama-3.3-70b-versatile` | 无回退

> 个人财务智能体，用于预算跟踪、费用分析、储蓄目标和财务规划。

使用 50/30/20、零基预算和信封方法等框架创建详细预算。处理任何格式的费用数据（CSV、手动列表）并分类交易。定义和跟踪带有预计时间线的储蓄目标。分析债务组合并模拟雪崩与雪球还款策略。生成带有净资产、债务收入比和储蓄率的财务健康报告。始终免责声明，说明输出不是财务建议。

- **标签**：`finance`、`budget`、`expenses`、`savings`、`planning`、`money`
- **温度**：0.2
- **最大令牌数**：8192
- **令牌配额**：150,000/小时
- **最大并发工具数**：5
- **工具**：`file_read`、`file_write`、`file_list`、`memory_store`、`memory_recall`、`shell_exec`
- **Shell 访问**：`python *`
- **能力**：`memory_read = ["*"]`、`memory_write = ["self.*", "shared.*"]`

```bash
openfang spawn personal-finance
# "分析这个月的费用 CSV 并告诉我哪里超支了"
```

---

### travel-planner

**层级 4 -- 快速** | `groq/llama-3.3-70b-versatile` | 无回退

> 旅行规划智能体，用于行程创建、预订研究、预算估算和旅行物流。

构建逐日行程，包含预计时间、交通、餐饮推荐和应急计划。提供全面的目的地指南，涵盖最佳访问时间、景点、习俗、安全、美食和签证要求。创建多价格档次的详细旅行预算。按类型、社区和预算推荐住宿。规划交通物流，包括航班、火车和当地交通。生成定制的打包清单。

- **标签**：`travel`、`planning`、`itinerary`、`booking`、`logistics`、`vacation`
- **温度**：0.5
- **最大令牌数**：8192
- **令牌配额**：150,000/小时
- **最大并发工具数**：5
- **工具**：`file_read`、`file_write`、`file_list`、`memory_store`、`memory_recall`、`web_fetch`
- **能力**：`network = ["*"]`、`memory_read = ["*"]`、`memory_write = ["self.*", "shared.*"]`

```bash
openfang spawn travel-planner
# "为 2 人规划一次 10 天的日本之旅，中等预算，文化和美食混合"
```

---

### home-automation

**层级 4 -- 快速** | `groq/llama-3.3-70b-versatile` | 无回退

> 智能家居控制智能体，用于 IoT 设备管理、自动化规则和家庭监控。

管理智能家居设备（灯、恒温器、安全、电器、传感器）。使用事件-条件-操作模式设计自动化工作流。为常见场景配置多设备场景（早晨例行程序、电影之夜、就寝时间、离开模式）。监控能耗并推荐优化。配置家庭安全工作流。解决 IoT 连接问题并桥接不同的生态系统（Home Assistant、HomeKit、SmartThings）。了解 Matter/Thread 协议采用。

- **标签**：`smart-home`、`iot`、`automation`、`devices`、`monitoring`、`home`
- **温度**：0.2
- **最大令牌数**：4096
- **令牌配额**：100,000/小时
- **最大并发工具数**：10
- **工具**：`file_read`、`file_write`、`file_list`、`memory_store`、`memory_recall`、`shell_exec`、`web_fetch`
- **Shell 访问**：`curl *`、`python *`、`ping *`
- **能力**：`network = ["*"]`、`memory_read = ["*"]`、`memory_write = ["self.*", "shared.*"]`

```bash
openfang spawn home-automation
# "创建一个就寝时间自动化：锁门、启动摄像头、调暗灯光、将恒温器设置为 68F"
```

---

## 自定义模板

`agents/custom/` 目录保留给你自己的智能体模板。按照下面的清单格式创建一个新的 `agent.toml` 文件。

### 清单格式

```toml
# 必填字段
name = "my-agent"
version = "0.1.0"
description = "一句话描述这个智能体做什么。"
author = "your-name"
module = "builtin:chat"

# 可选元数据
tags = ["tag1", "tag2"]

# 模型配置（必填）
[model]
provider = "gemini"                  # 提供程序：gemini、deepseek、groq、openai、anthropic 等。
model = "gemini-2.5-flash"           # 模型标识符
api_key_env = "GEMINI_API_KEY"       # 持有 API 密钥的环境变量
max_tokens = 4096                    # 每次响应的最大输出令牌数
temperature = 0.3                    # 创造性（0.0 = 确定性，1.0 = 创造性）
system_prompt = """你的智能体的个性、能力和说明放在这里。
要具体说明智能体应该做什么和不应该做什么。"""

# 可选回退模型（主模型不可用时使用）
[[fallback_models]]
provider = "groq"
model = "llama-3.3-70b-versatile"
api_key_env = "GROQ_API_KEY"

# 可选调度（用于自主/后台智能体）
[schedule]
periodic = { cron = "every 5m" }                                     # 定期执行
# continuous = { check_interval_secs = 120 }                         # 连续循环
# proactive = { conditions = ["event:agent_spawned"] }               # 事件触发

# 资源限制
[resources]
max_llm_tokens_per_hour = 150000    # 每小时令牌预算
max_concurrent_tools = 5            # 最大并行工具执行数

# 能力授予（最小权限原则）
[capabilities]
tools = ["file_read", "file_write", "file_list", "shell_exec",
         "memory_store", "memory_recall", "web_fetch",
         "agent_send", "agent_list", "agent_spawn", "agent_kill"]
network = ["*"]                     # 网络访问模式
memory_read = ["*"]                 # 智能体可以读取的内存命名空间
memory_write = ["self.*"]           # 智能体可以写入的内存命名空间
agent_spawn = true                  # 此智能体可以生成其他智能体吗？
agent_message = ["*"]               # 它可以向哪些智能体发送消息？
shell = ["python *", "cargo *"]     # 允许的 shell 命令模式（白名单）
```

### 可用工具

| 工具 | 说明 |
|------|-------------|
| `file_read` | 读取文件内容 |
| `file_write` | 写入/创建文件 |
| `file_list` | 列出目录内容 |
| `shell_exec` | 执行 shell 命令（受 `shell` 白名单限制） |
| `memory_store` | 将键值数据持久化到内存 |
| `memory_recall` | 从内存检索数据 |
| `web_fetch` | 从 URL 获取内容（SSRF 保护） |
| `agent_send` | 向另一个智能体发送消息 |
| `agent_list` | 列出所有运行中的智能体 |
| `agent_spawn` | 生成新智能体 |
| `agent_kill` | 终止运行中的智能体 |

### 自定义智能体的技巧

1. **从最小开始**。仅授予智能体实际需要的工具和能力。以后总是可以添加更多。
2. **编写清晰的系统提示**。系统提示是模板中最重要的部分。要具体说明智能体的角色、方法论、输出格式和限制。
3. **设置适当的温度**。对精确/分析任务使用 0.2，对平衡任务使用 0.5，对创意任务使用 0.7+。
4. **使用 shell 白名单**。永远不要授予 `shell = ["*"]`。将特定命令模式列入白名单，如 `shell = ["python *", "cargo test *"]`。
5. **设置令牌预算**。使用 `max_llm_tokens_per_hour` 防止失控成本。从 100,000 开始并根据使用情况调整。
6. **添加回退模型**。如果你的主模型有速率限制或可用性问题，添加一个 `[[fallback_models]]` 条目。
7. **使用内存保持连续性**。授予 `memory_store` 和 `memory_recall`，以便智能体可以跨会话持久化上下文。

---

## 生成智能体

### CLI

```bash
# 按模板名称生成
openfang spawn coder

# 使用自定义名称生成
openfang spawn coder --name "backend-coder"

# 从 TOML 文件路径生成
openfang spawn --template agents/custom/my-agent.toml

# 列出运行中的智能体
openfang agents

# 发送消息
openfang message <agent-id> "编写一个函数来解析 TOML 文件"

# 终止智能体
openfang kill <agent-id>
```

### REST API

```bash
# 从模板生成
POST /api/agents
{"template": "coder"}

# 带覆盖生成
POST /api/agents
{"template": "coder", "name": "backend-coder", "model": "deepseek-chat"}

# 发送消息
POST /api/agents/{id}/message
{"content": "实现认证模块"}

# WebSocket（流式）
WS /api/agents/{id}/ws

# 列出智能体
GET /api/agents

# 删除智能体
DELETE /api/agents/{id}
```

### OpenAI 兼容 API

```bash
# 通过 OpenAI 兼容端点使用任何智能体
POST /v1/chat/completions
{
  "model": "openfang:coder",
  "messages": [{"role": "user", "content": "编写一个 Rust HTTP 服务器"}],
  "stream": true
}

# 列出可用模型
GET /v1/models
```

### 编排器委托

编排器智能体可以以编程方式生成和委托给任何其他智能体：

```
用户："构建一个带测试和文档的 REST API"

编排器：
1. agent_send(coder, "实现 REST API 端点")
2. agent_send(test-engineer, "为这些端点编写集成测试")
3. agent_send(doc-writer, "记录 API 端点")
4. 将所有结果综合成最终报告
```

---

## 环境变量

设置以下 API 密钥以启用相应的模型提供程序：

| 变量 | 提供程序 | 用于 |
|----------|----------|---------|
| `DEEPSEEK_API_KEY` | DeepSeek | 层级 1（orchestrator、architect、security-auditor） |
| `GEMINI_API_KEY` | Google Gemini | 层级 2 主要，层级 3 回退 |
| `GROQ_API_KEY` | Groq | 层级 3 主要，层级 1/2 回退，层级 4 |

至少设置 `GROQ_API_KEY` 以启用所有层级 3 和层级 4 智能体。添加 `GEMINI_API_KEY` 用于层级 2 智能体。添加 `DEEPSEEK_API_KEY` 用于层级 1 前沿智能体。
