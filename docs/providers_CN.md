# LLM 提供商指南

OpenFang 附带一个全面的模型目录，涵盖**3 个原生 LLM 驱动**、**20 个提供商**、**51 个内置模型**和**23 个别名**。每个提供商使用三个经过实战检验的驱动之一：原生 **Anthropic** 驱动、原生 **Gemini** 驱动或通用 **OpenAI 兼容**驱动。本指南是配置、选择和管理 OpenFang 中 LLM 提供商的单一事实来源。

---

## 目录

1. [快速设置](#快速设置)
2. [提供商参考](#提供商参考)
3. [模型目录](#模型目录)
4. [模型别名](#模型别名)
5. [每代理模型覆盖](#每代理模型覆盖)
6. [模型路由](#模型路由)
7. [成本跟踪](#成本跟踪)
8. [回退提供商](#回退提供商)
9. [API 端点](#api-端点)
10. [通道命令](#通道命令)

---

## 快速设置

从零到运行的最快路径：

```bash
# 选择一个提供商 —— 设置其环境变量 —— 完成。
export GEMINI_API_KEY="your-key"        # 提供免费套餐
# 或
export GROQ_API_KEY="your-key"          # 提供免费套餐
# 或
export ANTHROPIC_API_KEY="your-key"
# 或
export OPENAI_API_KEY="your-key"
```

OpenFang 在启动时自动检测配置了哪些 API 密钥。任何模型其提供商已认证的都会立即可用。本地提供商（Ollama、vLLM、LM Studio）根本不需要密钥。

对于 Gemini，`GEMINI_API_KEY` 或 `GOOGLE_API_KEY` 都可以工作。

---

## 提供商参考

### 1. Anthropic

| | |
|---|---|
| **显示名称** | Anthropic |
| **驱动** | 原生 Anthropic（Messages API） |
| **环境变量** | `ANTHROPIC_API_KEY` |
| **基础 URL** | `https://api.anthropic.com` |
| **需要密钥** | 是 |
| **免费套餐** | 否 |
| **认证** | `x-api-key` 响应头 |
| **模型** | 3 |

**可用模型：**
- `claude-opus-4-20250514`（前沿）
- `claude-sonnet-4-20250514`（智能）
- `claude-haiku-4-5-20251001`（快速）

**设置：**
1. 在 [console.anthropic.com](https://console.anthropic.com) 注册
2. 在 Settings > API Keys 下创建 API 密钥
3. `export ANTHROPIC_API_KEY="sk-ant-..."`

---

### 2. OpenAI

| | |
|---|---|
| **显示名称** | OpenAI |
| **驱动** | OpenAI 兼容 |
| **环境变量** | `OPENAI_API_KEY` |
| **基础 URL** | `https://api.openai.com/v1` |
| **需要密钥** | 是 |
| **免费套餐** | 否 |
| **认证** | `Authorization: Bearer` 响应头 |
| **模型** | 6 |

**可用模型：**
- `gpt-4.1`（前沿）
- `gpt-4o`（智能）
- `o3-mini`（智能）
- `gpt-4.1-mini`（平衡）
- `gpt-4o-mini`（快速）
- `gpt-4.1-nano`（快速）

**设置：**
1. 在 [platform.openai.com](https://platform.openai.com) 注册
2. 在 API Keys 下创建 API 密钥
3. `export OPENAI_API_KEY="sk-..."`

---

### 3. Google Gemini

| | |
|---|---|
| **显示名称** | Google Gemini |
| **驱动** | 原生 Gemini（generateContent API） |
| **环境变量** | `GEMINI_API_KEY`（或 `GOOGLE_API_KEY`） |
| **基础 URL** | `https://generativelanguage.googleapis.com` |
| **需要密钥** | 是 |
| **免费套餐** | 是（慷慨的免费套餐） |
| **认证** | `x-goog-api-key` 响应头 |
| **模型** | 3 |

**可用模型：**
- `gemini-2.5-pro`（前沿）
- `gemini-2.5-flash`（智能）
- `gemini-2.0-flash`（快速）

**设置：**
1. 前往 [aistudio.google.com](https://aistudio.google.com)
2. 获取 API 密钥（包含免费套餐）
3. `export GEMINI_API_KEY="AIza..."` 或 `export GOOGLE_API_KEY="AIza..."`

**注意：** Gemini 驱动是完全原生实现。它不与 OpenAI 兼容。模型放在 URL 路径中，系统提示词通过 `systemInstruction`，工具通过 `functionDeclarations`，流式通过 `streamGenerateContent?alt=sse`。

---

### 4. DeepSeek

| | |
|---|---|
| **显示名称** | DeepSeek |
| **驱动** | OpenAI 兼容 |
| **环境变量** | `DEEPSEEK_API_KEY` |
| **基础 URL** | `https://api.deepseek.com/v1` |
| **需要密钥** | 是 |
| **免费套餐** | 否 |
| **认证** | `Authorization: Bearer` 响应头 |
| **模型** | 2 |

**可用模型：**
- `deepseek-chat`（智能）-- DeepSeek V3
- `deepseek-reasoner`（智能）-- DeepSeek R1，不支持工具

**设置：**
1. 在 [platform.deepseek.com](https://platform.deepseek.com) 注册
2. 创建 API 密钥
3. `export DEEPSEEK_API_KEY="sk-..."`

---

### 5. Groq

| | |
|---|---|
| **显示名称** | Groq |
| **驱动** | OpenAI 兼容 |
| **环境变量** | `GROQ_API_KEY` |
| **基础 URL** | `https://api.groq.com/openai/v1` |
| **需要密钥** | 是 |
| **免费套餐** | 是（速率限制） |
| **认证** | `Authorization: Bearer` 响应头 |
| **模型** | 4 |

**可用模型：**
- `llama-3.3-70b-versatile`（平衡）
- `mixtral-8x7b-32768`（平衡）
- `llama-3.1-8b-instant`（快速）
- `gemma2-9b-it`（快速）

**设置：**
1. 在 [console.groq.com](https://console.groq.com) 注册
2. 创建 API 密钥
3. `export GROQ_API_KEY="gsk_..."`

**注意：** Groq 在定制 LPU 硬件上运行开源模型。极快的推理。免费套餐有速率限制但非常可用。

---

### 6. OpenRouter

| | |
|---|---|
| **显示名称** | OpenRouter |
| **驱动** | OpenAI 兼容 |
| **环境变量** | `OPENROUTER_API_KEY` |
| **基础 URL** | `https://openrouter.ai/api/v1` |
| **需要密钥** | 是 |
| **免费套餐** | 是（某些模型有限额度） |
| **认证** | `Authorization: Bearer` 响应头 |
| **模型** | 3 |

**可用模型：**
- `openrouter/auto`（智能）-- 自动选择最佳模型
- `openrouter/optimus`（平衡）-- 成本优化
- `openrouter/nitro`（快速）-- 速度优化

**设置：**
1. 在 [openrouter.ai](https://openrouter.ai) 注册
2. 在 Keys 下创建 API 密钥
3. `export OPENROUTER_API_KEY="sk-or-..."`

**注意：** OpenRouter 是来自许多提供商的 200+ 模型的统一网关。三个内置条目是 OpenRouter 的智能路由端点。你也可以通过直接指定完整的 OpenRouter 模型路径来使用他们目录中的任何模型。

---

### 7. Mistral AI

| | |
|---|---|
| **显示名称** | Mistral AI |
| **驱动** | OpenAI 兼容 |
| **环境变量** | `MISTRAL_API_KEY` |
| **基础 URL** | `https://api.mistral.ai/v1` |
| **需要密钥** | 是 |
| **免费套餐** | 否 |
| **认证** | `Authorization: Bearer` 响应头 |
| **模型** | 3 |

**可用模型：**
- `mistral-large-latest`（智能）
- `codestral-latest`（智能）
- `mistral-small-latest`（快速）

**设置：**
1. 在 [console.mistral.ai](https://console.mistral.ai) 注册
2. 创建 API 密钥
3. `export MISTRAL_API_KEY="..."`

---

### 8. Together AI

| | |
|---|---|
| **显示名称** | Together AI |
| **驱动** | OpenAI 兼容 |
| **环境变量** | `TOGETHER_API_KEY` |
| **基础 URL** | `https://api.together.xyz/v1` |
| **需要密钥** | 是 |
| **免费套餐** | 是（注册时有限额度） |
| **认证** | `Authorization: Bearer` 响应头 |
| **模型** | 3 |

**可用模型：**
- `meta-llama/Meta-Llama-3.1-405B-Instruct-Turbo`（前沿）
- `Qwen/Qwen2.5-72B-Instruct-Turbo`（智能）
- `mistralai/Mixtral-8x22B-Instruct-v0.1`（平衡）

**设置：**
1. 在 [api.together.ai](https://api.together.ai) 注册
2. 创建 API 密钥
3. `export TOGETHER_API_KEY="..."`

---

### 9. Fireworks AI

| | |
|---|---|
| **显示名称** | Fireworks AI |
| **驱动** | OpenAI 兼容 |
| **环境变量** | `FIREWORKS_API_KEY` |
| **基础 URL** | `https://api.fireworks.ai/inference/v1` |
| **需要密钥** | 是 |
| **免费套餐** | 是（注册时有限额度） |
| **认证** | `Authorization: Bearer` 响应头 |
| **模型** | 2 |

**可用模型：**
- `accounts/fireworks/models/llama-v3p1-405b-instruct`（前沿）
- `accounts/fireworks/models/mixtral-8x22b-instruct`（平衡）

**设置：**
1. 在 [fireworks.ai](https://fireworks.ai) 注册
2. 创建 API 密钥
3. `export FIREWORKS_API_KEY="..."`

---

### 10. Ollama

| | |
|---|---|
| **显示名称** | Ollama |
| **驱动** | OpenAI 兼容 |
| **环境变量** | `OLLAMA_API_KEY`（不需要） |
| **基础 URL** | `http://localhost:11434/v1` |
| **需要密钥** | **否** |
| **免费套餐** | 免费（本地） |
| **认证** | 无（本地） |
| **模型** | 3 个内置 + 自动发现 |

**可用模型（内置）：**
- `llama3.2`（本地）
- `mistral:latest`（本地）
- `phi3`（本地）

**设置：**
1. 从 [ollama.com](https://ollama.com) 安装 Ollama
2. 拉取模型：`ollama pull llama3.2`
3. 启动服务器：`ollama serve`
4. 不需要环境变量 -- Ollama 始终可用

**注意：** OpenFang 自动发现来自运行中 Ollama 实例的模型，并将它们合并到目录中，具有 `Local` 层和零成本。你拉取的任何模型都会立即可用。

---

### 11. vLLM

| | |
|---|---|
| **显示名称** | vLLM |
| **驱动** | OpenAI 兼容 |
| **环境变量** | `VLLM_API_KEY`（不需要） |
| **基础 URL** | `http://localhost:8000/v1` |
| **需要密钥** | **否** |
| **免费套餐** | 免费（自托管） |
| **认证** | 无（本地） |
| **模型** | 1 个内置 + 自动发现 |

**可用模型（内置）：**
- `vllm-local`（本地）

**设置：**
1. 安装 vLLM：`pip install vllm`
2. 启动服务器：`python -m vllm.entrypoints.openai.api_server --model <model-name>`
3. 不需要环境变量

---

### 12. LM Studio

| | |
|---|---|
| **显示名称** | LM Studio |
| **驱动** | OpenAI 兼容 |
| **环境变量** | `LMSTUDIO_API_KEY`（不需要） |
| **基础 URL** | `http://localhost:1234/v1` |
| **需要密钥** | **否** |
| **免费套餐** | 免费（本地） |
| **认证** | 无（本地） |
| **模型** | 1 个内置 + 自动发现 |

**可用模型（内置）：**
- `lmstudio-local`（本地）

**设置：**
1. 从 [lmstudio.ai](https://lmstudio.ai) 下载 LM Studio
2. 从内置模型浏览器下载模型
3. 从 "Local Server" 选项卡启动本地服务器
4. 不需要环境变量


---

### 13. Perplexity AI

| | |
|---|---|
| **显示名称** | Perplexity AI |
| **驱动** | OpenAI 兼容 |
| **环境变量** | `PERPLEXITY_API_KEY` |
| **基础 URL** | `https://api.perplexity.ai` |
| **需要密钥** | 是 |
| **免费套餐** | 否 |
| **认证** | `Authorization: Bearer` 响应头 |
| **模型** | 2 |

**可用模型：**
- `sonar-pro`（智能）-- 在线搜索增强
- `sonar`（平衡）-- 在线搜索增强

**设置：**
1. 在 [perplexity.ai](https://www.perplexity.ai) 注册
2. 转到 API 设置并生成密钥
3. `export PERPLEXITY_API_KEY="pplx-..."`

**注意：** Perplexity 模型具有内置网页搜索。它们不支持工具使用。

---

### 14. Cohere

| | |
|---|---|
| **显示名称** | Cohere |
| **驱动** | OpenAI 兼容 |
| **环境变量** | `COHERE_API_KEY` |
| **基础 URL** | `https://api.cohere.com/v2` |
| **需要密钥** | 是 |
| **免费套餐** | 是（速率限制试用） |
| **认证** | `Authorization: Bearer` 响应头 |
| **模型** | 2 |

**可用模型：**
- `command-r-plus`（智能）
- `command-r`（平衡）

**设置：**
1. 在 [dashboard.cohere.com](https://dashboard.cohere.com) 注册
2. 创建 API 密钥
3. `export COHERE_API_KEY="..."`

---

### 15. AI21 Labs

| | |
|---|---|
| **显示名称** | AI21 Labs |
| **驱动** | OpenAI 兼容 |
| **环境变量** | `AI21_API_KEY` |
| **基础 URL** | `https://api.ai21.com/studio/v1` |
| **需要密钥** | 是 |
| **免费套餐** | 是（有限额度） |
| **认证** | `Authorization: Bearer` 响应头 |
| **模型** | 1 |

**可用模型：**
- `jamba-1.5-large`（智能）

**设置：**
1. 在 [studio.ai21.com](https://studio.ai21.com) 注册
2. 创建 API 密钥
3. `export AI21_API_KEY="..."`

---

### 16. Cerebras

| | |
|---|---|
| **显示名称** | Cerebras |
| **驱动** | OpenAI 兼容 |
| **环境变量** | `CEREBRAS_API_KEY` |
| **基础 URL** | `https://api.cerebras.ai/v1` |
| **需要密钥** | 是 |
| **免费套餐** | 是（慷慨的免费套餐） |
| **认证** | `Authorization: Bearer` 响应头 |
| **模型** | 2 |

**可用模型：**
- `cerebras/llama3.3-70b`（平衡）
- `cerebras/llama3.1-8b`（快速）

**设置：**
1. 在 [cloud.cerebras.ai](https://cloud.cerebras.ai) 注册
2. 创建 API 密钥
3. `export CEREBRAS_API_KEY="..."`

**注意：** Cerebras 在晶圆级芯片上运行推理。超快且超便宜（70B 模型输入输出均为 $0.06/M Token）。

---

### 17. SambaNova

| | |
|---|---|
| **显示名称** | SambaNova |
| **驱动** | OpenAI 兼容 |
| **环境变量** | `SAMBANOVA_API_KEY` |
| **基础 URL** | `https://api.sambanova.ai/v1` |
| **需要密钥** | 是 |
| **免费套餐** | 是（有限额度） |
| **认证** | `Authorization: Bearer` 响应头 |
| **模型** | 1 |

**可用模型：**
- `sambanova/llama-3.3-70b`（平衡）

**设置：**
1. 在 [cloud.sambanova.ai](https://cloud.sambanova.ai) 注册
2. 创建 API 密钥
3. `export SAMBANOVA_API_KEY="..."`

---

### 18. Hugging Face

| | |
|---|---|
| **显示名称** | Hugging Face |
| **驱动** | OpenAI 兼容 |
| **环境变量** | `HF_API_KEY` |
| **基础 URL** | `https://api-inference.huggingface.co/v1` |
| **需要密钥** | 是 |
| **免费套餐** | 是（速率限制） |
| **认证** | `Authorization: Bearer` 响应头 |
| **模型** | 1 |

**可用模型：**
- `hf/meta-llama/Llama-3.3-70B-Instruct`（平衡）

**设置：**
1. 在 [huggingface.co](https://huggingface.co) 注册
2. 在 Settings > Access Tokens 下创建令牌
3. `export HF_API_KEY="hf_..."`

---

### 19. xAI

| | |
|---|---|
| **显示名称** | xAI |
| **驱动** | OpenAI 兼容 |
| **环境变量** | `XAI_API_KEY` |
| **基础 URL** | `https://api.x.ai/v1` |
| **需要密钥** | 是 |
| **免费套餐** | 是（有限免费额度） |
| **认证** | `Authorization: Bearer` 响应头 |
| **模型** | 2 |

**可用模型：**
- `grok-2`（智能）-- 支持视觉
- `grok-2-mini`（快速）

**设置：**
1. 在 [console.x.ai](https://console.x.ai) 注册
2. 创建 API 密钥
3. `export XAI_API_KEY="xai-..."`

---

### 20. Replicate

| | |
|---|---|
| **显示名称** | Replicate |
| **驱动** | OpenAI 兼容 |
| **环境变量** | `REPLICATE_API_TOKEN` |
| **基础 URL** | `https://api.replicate.com/v1` |
| **需要密钥** | 是 |
| **免费套餐** | 否 |
| **认证** | `Authorization: Bearer` 响应头 |
| **模型** | 1 |

**可用模型：**
- `replicate/meta-llama-3.3-70b-instruct`（平衡）

**设置：**
1. 在 [replicate.com](https://replicate.com) 注册
2. 转到 Account > API Tokens
3. `export REPLICATE_API_TOKEN="r8_..."`


---

## 模型目录

所有 51 个内置模型的完整目录，按提供商排序。价格为每百万 Token。

| # | 模型 ID | 显示名称 | 提供商 | 层 | 上下文窗口 | 最大输出 | 输入 $/M | 输出 $/M | 工具 | 视觉 |
|---|----------|-------------|----------|------|---------------|------------|-----------|------------|-------|--------|
| 1 | `claude-opus-4-20250514` | Claude Opus 4 | anthropic | 前沿 | 200,000 | 32,000 | $15.00 | $75.00 | 是 | 是 |
| 2 | `claude-sonnet-4-20250514` | Claude Sonnet 4 | anthropic | 智能 | 200,000 | 64,000 | $3.00 | $15.00 | 是 | 是 |
| 3 | `claude-haiku-4-5-20251001` | Claude Haiku 4.5 | anthropic | 快速 | 200,000 | 8,192 | $0.25 | $1.25 | 是 | 是 |
| 4 | `gpt-4.1` | GPT-4.1 | openai | 前沿 | 1,047,576 | 32,768 | $2.00 | $8.00 | 是 | 是 |
| 5 | `gpt-4o` | GPT-4o | openai | 智能 | 128,000 | 16,384 | $2.50 | $10.00 | 是 | 是 |
| 6 | `o3-mini` | o3-mini | openai | 智能 | 200,000 | 100,000 | $1.10 | $4.40 | 是 | 否 |
| 7 | `gpt-4.1-mini` | GPT-4.1 Mini | openai | 平衡 | 1,047,576 | 32,768 | $0.40 | $1.60 | 是 | 是 |
| 8 | `gpt-4o-mini` | GPT-4o Mini | openai | 快速 | 128,000 | 16,384 | $0.15 | $0.60 | 是 | 是 |
| 9 | `gpt-4.1-nano` | GPT-4.1 Nano | openai | 快速 | 1,047,576 | 32,768 | $0.10 | $0.40 | 是 | 否 |
| 10 | `gemini-2.5-pro` | Gemini 2.5 Pro | gemini | 前沿 | 1,048,576 | 65,536 | $1.25 | $10.00 | 是 | 是 |
| 11 | `gemini-2.5-flash` | Gemini 2.5 Flash | gemini | 智能 | 1,048,576 | 65,536 | $0.15 | $0.60 | 是 | 是 |
| 12 | `gemini-2.0-flash` | Gemini 2.0 Flash | gemini | 快速 | 1,048,576 | 8,192 | $0.10 | $0.40 | 是 | 是 |
| 13 | `deepseek-chat` | DeepSeek V3 | deepseek | 智能 | 64,000 | 8,192 | $0.27 | $1.10 | 是 | 否 |
| 14 | `deepseek-reasoner` | DeepSeek R1 | deepseek | 智能 | 64,000 | 8,192 | $0.55 | $2.19 | 否 | 否 |
| 15 | `llama-3.3-70b-versatile` | Llama 3.3 70B | groq | 平衡 | 128,000 | 32,768 | $0.059 | $0.079 | 是 | 否 |
| 16 | `mixtral-8x7b-32768` | Mixtral 8x7B | groq | 平衡 | 32,768 | 4,096 | $0.024 | $0.024 | 是 | 否 |
| 17 | `llama-3.1-8b-instant` | Llama 3.1 8B | groq | 快速 | 128,000 | 8,192 | $0.05 | $0.08 | 是 | 否 |
| 18 | `gemma2-9b-it` | Gemma 2 9B | groq | 快速 | 8,192 | 4,096 | $0.02 | $0.02 | 否 | 否 |
| 19 | `openrouter/auto` | OpenRouter Auto | openrouter | 智能 | 200,000 | 32,000 | $1.00 | $3.00 | 是 | 是 |
| 20 | `openrouter/optimus` | OpenRouter Optimus | openrouter | 平衡 | 200,000 | 32,000 | $0.50 | $1.50 | 是 | 否 |
| 21 | `openrouter/nitro` | OpenRouter Nitro | openrouter | 快速 | 128,000 | 16,000 | $0.20 | $0.60 | 是 | 否 |
| 22 | `mistral-large-latest` | Mistral Large | mistral | 智能 | 128,000 | 8,192 | $2.00 | $6.00 | 是 | 否 |
| 23 | `codestral-latest` | Codestral | mistral | 智能 | 32,000 | 8,192 | $0.30 | $0.90 | 是 | 否 |
| 24 | `mistral-small-latest` | Mistral Small | mistral | 快速 | 128,000 | 8,192 | $0.10 | $0.30 | 是 | 否 |
| 25 | `meta-llama/Meta-Llama-3.1-405B-Instruct-Turbo` | Llama 3.1 405B (Together) | together | 前沿 | 130,000 | 4,096 | $3.50 | $3.50 | 是 | 否 |
| 26 | `Qwen/Qwen2.5-72B-Instruct-Turbo` | Qwen 2.5 72B (Together) | together | 智能 | 32,768 | 4,096 | $0.20 | $0.60 | 是 | 否 |
| 27 | `mistralai/Mixtral-8x22B-Instruct-v0.1` | Mixtral 8x22B (Together) | together | 平衡 | 65,536 | 4,096 | $0.60 | $0.60 | 是 | 否 |
| 28 | `accounts/fireworks/models/llama-v3p1-405b-instruct` | Llama 3.1 405B (Fireworks) | fireworks | 前沿 | 131,072 | 16,384 | $3.00 | $3.00 | 是 | 否 |
| 29 | `accounts/fireworks/models/mixtral-8x22b-instruct` | Mixtral 8x22B (Fireworks) | fireworks | 平衡 | 65,536 | 4,096 | $0.90 | $0.90 | 是 | 否 |
| 30 | `llama3.2` | Llama 3.2 (Ollama) | ollama | 本地 | 128,000 | 4,096 | $0.00 | $0.00 | 是 | 否 |
| 31 | `mistral:latest` | Mistral (Ollama) | ollama | 本地 | 32,768 | 4,096 | $0.00 | $0.00 | 是 | 否 |
| 32 | `phi3` | Phi-3 (Ollama) | ollama | 本地 | 128,000 | 4,096 | $0.00 | $0.00 | 否 | 否 |
| 33 | `vllm-local` | vLLM 本地模型 | vllm | 本地 | 32,768 | 4,096 | $0.00 | $0.00 | 是 | 否 |
| 34 | `lmstudio-local` | LM Studio 本地模型 | lmstudio | 本地 | 32,768 | 4,096 | $0.00 | $0.00 | 是 | 否 |
| 35 | `sonar-pro` | Sonar Pro | perplexity | 智能 | 200,000 | 8,192 | $3.00 | $15.00 | 否 | 否 |
| 36 | `sonar` | Sonar | perplexity | 平衡 | 128,000 | 8,192 | $1.00 | $5.00 | 否 | 否 |
| 37 | `command-r-plus` | Command R+ | cohere | 智能 | 128,000 | 4,096 | $2.50 | $10.00 | 是 | 否 |
| 38 | `command-r` | Command R | cohere | 平衡 | 128,000 | 4,096 | $0.15 | $0.60 | 是 | 否 |
| 39 | `jamba-1.5-large` | Jamba 1.5 Large | ai21 | 智能 | 256,000 | 4,096 | $2.00 | $8.00 | 是 | 否 |
| 40 | `cerebras/llama3.3-70b` | Llama 3.3 70B (Cerebras) | cerebras | 平衡 | 128,000 | 8,192 | $0.06 | $0.06 | 是 | 否 |
| 41 | `cerebras/llama3.1-8b` | Llama 3.1 8B (Cerebras) | cerebras | 快速 | 128,000 | 8,192 | $0.01 | $0.01 | 是 | 否 |
| 42 | `sambanova/llama-3.3-70b` | Llama 3.3 70B (SambaNova) | sambanova | 平衡 | 128,000 | 8,192 | $0.06 | $0.06 | 是 | 否 |
| 43 | `grok-2` | Grok 2 | xai | 智能 | 131,072 | 32,768 | $2.00 | $10.00 | 是 | 是 |
| 44 | `grok-2-mini` | Grok 2 Mini | xai | 快速 | 131,072 | 32,768 | $0.30 | $0.50 | 是 | 否 |
| 45 | `hf/meta-llama/Llama-3.3-70B-Instruct` | Llama 3.3 70B (HF) | huggingface | 平衡 | 128,000 | 4,096 | $0.30 | $0.30 | 否 | 否 |
| 46 | `replicate/meta-llama-3.3-70b-instruct` | Llama 3.3 70B (Replicate) | replicate | 平衡 | 128,000 | 4,096 | $0.40 | $0.40 | 否 | 否 |

**模型层：**

| 层 | 描述 | 典型用途 |
|------|------------|------------|
| **前沿** | 最强大、成本最高 | 编排、架构、安全审计 |
| **智能** | 强推理、中等成本 | 编码、代码审查、研究、分析 |
| **平衡** | 良好的成本/质量权衡 | 规划、写作、DevOps、日常任务 |
| **快速** | 最便宜的云推理 | 运维、翻译、简单问答、健康检查 |
| **本地** | 自托管、零成本 | 隐私优先、离线、开发 |

**注意：**
- 本地提供商（Ollama、vLLM、LM Studio）在运行时自动发现模型。你下载并提供服务的任何模型都将以 `本地` 层和零成本合并到目录中。
- 上面的 46 个条目是内置模型。目录中引用的 51 个总数包括因安装而异的运行时自动发现模型。

---

## 模型别名

所有 23 个别名都解析为规范模型 ID。别名不区分大小写。

| 别名 | 解析为 |
|-------|------------|
| `sonnet` | `claude-sonnet-4-20250514` |
| `claude-sonnet` | `claude-sonnet-4-20250514` |
| `haiku` | `claude-haiku-4-5-20251001` |
| `claude-haiku` | `claude-haiku-4-5-20251001` |
| `opus` | `claude-opus-4-20250514` |
| `claude-opus` | `claude-opus-4-20250514` |
| `gpt4` | `gpt-4o` |
| `gpt4o` | `gpt-4o` |
| `gpt4-mini` | `gpt-4o-mini` |
| `flash` | `gemini-2.5-flash` |
| `gemini-flash` | `gemini-2.5-flash` |
| `gemini-pro` | `gemini-2.5-pro` |
| `deepseek` | `deepseek-chat` |
| `llama` | `llama-3.3-70b-versatile` |
| `llama-70b` | `llama-3.3-70b-versatile` |
| `mixtral` | `mixtral-8x7b-32768` |
| `mistral` | `mistral-large-latest` |
| `codestral` | `codestral-latest` |
| `grok` | `grok-2` |
| `grok-mini` | `grok-2-mini` |
| `sonar` | `sonar-pro` |
| `jamba` | `jamba-1.5-large` |
| `command-r` | `command-r-plus` |

你可以在需要模型 ID 的任何地方使用别名：在配置文件中、REST API 调用、聊天命令和模型路由配置中。

---

## 每代理模型覆盖

`config.toml` 中的每个代理都可以指定自己的模型，覆盖全局默认值：

```toml
# 全局默认模型
[agents.defaults]
model = "claude-sonnet-4-20250514"

# 每代理覆盖：使用别名或完整模型 ID
[[agents]]
name = "orchestrator"
model = "opus"                      # claude-opus-4-20250514 的别名

[[agents]]
name = "ops"
model = "llama-3.3-70b-versatile"   # 简单运维的廉价 Groq 模型

[[agents]]
name = "coder"
model = "gemini-2.5-flash"          # 快速 + 廉价 + 1M 上下文

[[agents]]
name = "researcher"
model = "sonar-pro"                 # 具有内置网页搜索的 Perplexity

# 你也可以在代理清单 TOML 中固定模型
[[agents]]
name = "production-bot"
pinned_model = "claude-sonnet-4-20250514"  # 从不自动路由
```

当 `pinned_model` 设置在代理清单上时，该代理始终使用指定的模型，无论路由配置如何。这在**稳定模式**（`KernelMode::Stable`）中使用，其中模型被冻结以确保生产可靠性。

---

## 模型路由

OpenFang 可以自动选择能够处理每个查询的最便宜模型。这是通过代理的 `ModelRoutingConfig` 按代理配置的。

### 工作原理

1. **ModelRouter** 基于启发式为每个传入的 `CompletionRequest` 打分
2. 分数映射到 **TaskComplexity** 层：`Simple`、`Medium` 或 `Complex`
3. 每层都有预配置的模型

### 评分启发式

| 信号 | 权重 | 逻辑 |
|--------|--------|-------|
| 总消息长度 | 每 ~4 字符 1 分 | 粗略 Token 代理 |
| 工具可用性 | 每个定义的工具 +20 | 工具意味着多步工作 |
| 代码标记 | 每个找到的标记 +30 | 反引号、`fn`、`def`、`class`、`import`、`function`、`async`、`await`、`struct`、`impl`、`return` |
| 对话深度 | 每个 > 10 的消息 +15 | 深上下文 = 更难推理 |
| 系统提示词长度 | 每 10 字符 > 500 的 +1 | 长系统提示词意味着复杂任务 |

### 阈值

| 复杂度 | 分数范围 | 默认模型 |
|-----------|-------------|---------------|
| 简单 | score < 100 | `claude-haiku-4-5-20251001` |
| 中等 | 100 <= score < 500 | `claude-sonnet-4-20250514` |
| 复杂 | score >= 500 | `claude-sonnet-4-20250514` |

### 配置

```toml
# 在代理清单或 config.toml 中
[routing]
simple_model = "claude-haiku-4-5-20251001"
medium_model = "gemini-2.5-flash"
complex_model = "claude-sonnet-4-20250514"
simple_threshold = 100
complex_threshold = 500
```

路由器还与模型目录集成：
- **`validate_models()`** 检查所有配置的模型 ID 是否存在于目录中
- **`resolve_aliases()`** 将别名扩展为规范 ID（例如，`"sonnet"` 变为 `"claude-sonnet-4-20250514"`）

---

## 成本跟踪

OpenFang 跟踪每次 LLM 调用的成本，并可以强制执行每代理支出配额。

### 每响应成本估算

每次 LLM 调用后，成本计算为：

```
cost = (input_tokens / 1,000,000) * input_rate + (output_tokens / 1,000,000) * output_rate
```

`MeteringEngine` 首先检查**模型目录**获取确切价格。如果找不到模型，则回退到模式匹配启发式。

### 成本费率（每百万 Token）

| 模型模式 | 输入 $/M | 输出 $/M |
|--------------|-----------|------------|
| `*haiku*` | $0.25 | $1.25 |
| `*sonnet*` | $3.00 | $15.00 |
| `*opus*` | $15.00 | $75.00 |
| `gpt-4o-mini` | $0.15 | $0.60 |
| `gpt-4o` | $2.50 | $10.00 |
| `gpt-4.1-nano` | $0.10 | $0.40 |
| `gpt-4.1-mini` | $0.40 | $1.60 |
| `gpt-4.1` | $2.00 | $8.00 |
| `o3-mini` | $1.10 | $4.40 |
| `gemini-2.5-pro` | $1.25 | $10.00 |
| `gemini-2.5-flash` | $0.15 | $0.60 |
| `gemini-2.0-flash` | $0.10 | $0.40 |
| `deepseek-reasoner` / `deepseek-r1` | $0.55 | $2.19 |
| `*deepseek*` | $0.27 | $1.10 |
| `*cerebras*` | $0.06 | $0.06 |
| `*sambanova*` | $0.06 | $0.06 |
| `*replicate*` | $0.40 | $0.40 |
| `*llama*` / `*mixtral*` | $0.05 | $0.10 |
| `*qwen*` | $0.20 | $0.60 |
| `mistral-large*` | $2.00 | $6.00 |
| `*mistral*`（其他） | $0.10 | $0.30 |
| `command-r-plus` | $2.50 | $10.00 |
| `command-r` | $0.15 | $0.60 |
| `sonar-pro` | $3.00 | $15.00 |
| `*sonar*`（其他） | $1.00 | $5.00 |
| `grok-2-mini` / `grok-mini` | $0.30 | $0.50 |
| `*grok*`（其他） | $2.00 | $10.00 |
| `*jamba*` | $2.00 | $8.00 |
| 默认（未知） | $1.00 | $3.00 |

### 配额强制执行

每次 LLM 调用都会检查配额。如果代理超出其每小时限制，调用将以 `QuotaExceeded` 错误被拒绝。

```toml
# config.toml 中的每代理配额
[[agents]]
name = "chatbot"
[agents.resources]
max_cost_per_hour_usd = 5.00   # 限制为 $5/小时
```

启用使用量页脚时，将成本信息附加到每个响应：

```
> 成本：$0.0042 | Token：1,200 输入 / 340 输出 | 模型：claude-sonnet-4-20250514
```

---

## 回退提供商

`FallbackDriver` 将多个 LLM 驱动包装在链中。如果主驱动失败，自动尝试链中的下一个驱动。

### 行为

- 成功时：立即返回
- **速率限制 / 过载**错误（`429`、`529`）：冒泡给重试逻辑（**不**故障转移，因为主应在退避后重试）
- **所有其他错误**：记录警告并尝试链中的下一个驱动
- 如果所有驱动都失败：返回最后一个错误

### 配置

回退链在你的代理清单或 `config.toml` 中配置。当代理处于**稳定模式**（`KernelMode::Stable`）或配置多个提供商以确保可靠性时，自动使用 `FallbackDriver`。

```toml
# 示例：主 Anthropic，回退到 Gemini，然后 Groq
[[agents]]
name = "production-bot"
model = "claude-sonnet-4-20250514"
fallback_models = ["gemini-2.5-flash", "llama-3.3-70b-versatile"]
```

回退驱动创建链：`AnthropicDriver -> GeminiDriver -> OpenAIDriver(Groq)`。

---

## API 端点

### 列出所有模型

```
GET /api/models
```

返回具有元数据、定价和功能标志的完整模型目录。

**响应：**
```json
[
  {
    "id": "claude-sonnet-4-20250514",
    "display_name": "Claude Sonnet 4",
    "provider": "anthropic",
    "tier": "智能",
    "context_window": 200000,
    "max_output_tokens": 64000,
    "input_cost_per_m": 3.0,
    "output_cost_per_m": 15.0,
    "supports_tools": true,
    "supports_vision": true,
    "supports_streaming": true,
    "aliases": ["sonnet", "claude-sonnet"]
  }
]
```

### 获取特定模型

```
GET /api/models/{id}
```

返回单个模型条目。支持规范 ID 和别名。

```
GET /api/models/sonnet
GET /api/models/claude-sonnet-4-20250514
```

### 列出别名

```
GET /api/models/aliases
```

返回所有别名到规范 ID 映射的映射。

**响应：**
```json
{
  "sonnet": "claude-sonnet-4-20250514",
  "haiku": "claude-haiku-4-5-20251001",
  "flash": "gemini-2.5-flash",
  "grok": "grok-2"
}
```

### 列出提供商

```
GET /api/providers
```

返回所有 20 个提供商及其认证状态和模型计数。

**响应：**
```json
[
  {
    "id": "anthropic",
    "display_name": "Anthropic",
    "api_key_env": "ANTHROPIC_API_KEY",
    "base_url": "https://api.anthropic.com",
    "key_required": true,
    "auth_status": "已配置",
    "model_count": 3
  },
  {
    "id": "ollama",
    "display_name": "Ollama",
    "api_key_env": "OLLAMA_API_KEY",
    "base_url": "http://localhost:11434/v1",
    "key_required": false,
    "auth_status": "不需要",
    "model_count": 5
  }
]
```

认证状态值：`已配置`、`缺失`、`不需要`。

### 设置提供商 API 密钥

```
POST /api/providers/{name}/key
Content-Type: application/json

{ "api_key": "sk-..." }
```

在运行时配置提供商的 API 密钥（存储为 `Zeroizing<String>`，在丢弃时从内存中擦除）。

### 移除提供商 API 密钥

```
DELETE /api/providers/{name}/key
```

移除提供商配置的 API 密钥。

### 测试提供商连接

```
POST /api/providers/{name}/test
```

发送最小测试请求以验证提供商是否可访问且 API 密钥有效。

---

## 通道命令

任何通道中都有两个聊天命令可用于检查模型和提供商：

### `/models`

列出所有可用模型及其层、提供商和上下文窗口。只显示来自已配置认证（或不需要）提供商的模型。

```
/models
```

示例输出：
```
可用模型 (12)：

前沿:
  claude-opus-4-20250514 (Anthropic) — 200K 上下文
  gemini-2.5-pro (Google Gemini) — 1M 上下文

智能:
  claude-sonnet-4-20250514 (Anthropic) — 200K 上下文
  gemini-2.5-flash (Google Gemini) — 1M 上下文
  deepseek-chat (DeepSeek) — 64K 上下文

平衡:
  llama-3.3-70b-versatile (Groq) — 128K 上下文

快速:
  claude-haiku-4-5-20251001 (Anthropic) — 200K 上下文
  gemini-2.0-flash (Google Gemini) — 1M 上下文

本地:
  llama3.2 (Ollama) — 128K 上下文
```

### `/providers`

列出所有 20 个提供商及其认证状态。

```
/providers
```

示例输出：
```
LLM 提供商 (20)：

  Anthropic          ANTHROPIC_API_KEY       已配置    3 个模型
  OpenAI             OPENAI_API_KEY          缺失       6 个模型
  Google Gemini      GEMINI_API_KEY          已配置    3 个模型
  DeepSeek           DEEPSEEK_API_KEY        缺失       2 个模型
  Groq               GROQ_API_KEY            已配置    4 个模型
  Ollama             (不需要密钥)         就绪       3 个模型
  vLLM               (不需要密钥)         就绪       1 个模型
  LM Studio          (不需要密钥)         就绪       1 个模型
  ...
```

---

## 环境变量摘要

所有提供商环境变量的快速参考：

| 提供商 | 环境变量 | 必需 |
|----------|---------|----------|
| Anthropic | `ANTHROPIC_API_KEY` | 是 |
| OpenAI | `OPENAI_API_KEY` | 是 |
| Google Gemini | `GEMINI_API_KEY` 或 `GOOGLE_API_KEY` | 是 |
| DeepSeek | `DEEPSEEK_API_KEY` | 是 |
| Groq | `GROQ_API_KEY` | 是 |
| OpenRouter | `OPENROUTER_API_KEY` | 是 |
| Mistral AI | `MISTRAL_API_KEY` | 是 |
| Together AI | `TOGETHER_API_KEY` | 是 |
| Fireworks AI | `FIREWORKS_API_KEY` | 是 |
| Ollama | `OLLAMA_API_KEY` | 否 |
| vLLM | `VLLM_API_KEY` | 否 |
| LM Studio | `LMSTUDIO_API_KEY` | 否 |
| Perplexity AI | `PERPLEXITY_API_KEY` | 是 |
| Cohere | `COHERE_API_KEY` | 是 |
| AI21 Labs | `AI21_API_KEY` | 是 |
| Cerebras | `CEREBRAS_API_KEY` | 是 |
| SambaNova | `SAMBANOVA_API_KEY` | 是 |
| Hugging Face | `HF_API_KEY` | 是 |
| xAI | `XAI_API_KEY` | 是 |
| Replicate | `REPLICATE_API_TOKEN` | 是 |

---

## 安全说明

- 所有 API 密钥都存储为 `Zeroizing<String>` -- 当值从内存中丢弃时，密钥材料会自动用零覆盖。
- 认证检测（`detect_auth()`）只检查 `std::env::var()` 是否存在 -- 它从不读取或记录实际的密钥值。
- 通过 REST API 设置的提供商 API 密钥（`POST /api/providers/{name}/key`）遵循相同的清零策略。
- 健康端点（`/api/health`）从不暴露提供商认证状态或 API 密钥。详细信息在 `/api/health/detail` 后面，需要认证。
- 所有 `DriverConfig` 和 `KernelConfig` 结构体都实现带密钥脱敏的 `Debug` -- API 密钥在日志中打印为 `"***"`。
