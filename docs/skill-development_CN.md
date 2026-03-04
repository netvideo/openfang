# 技能开发

技能是可插拔的工具包，用于扩展 OpenFang 中智能体的功能。一个技能将一个或多个工具及其实现打包在一起，让智能体能够执行内置工具未涵盖的任务。本指南涵盖技能创建、清单格式、Python 和 WASM 运行时、发布到 FangHub 以及 CLI 管理。

## 目录

- [概述](#概述)
- [技能格式](#技能格式)
- [Python 技能](#python-技能)
- [WASM 技能](#wasm-技能)
- [技能依赖](#技能依赖)
- [安装技能](#安装技能)
- [发布到 FangHub](#发布到-fanghub)
- [CLI 命令](#cli-命令)
- [OpenClaw 兼容性](#openclaw-兼容性)
- [最佳实践](#最佳实践)

---

## 概述

一个技能包含：

1. 一个**清单**（`skill.toml` 或 `SKILL.md`），声明元数据、运行时类型、提供的工具和依赖。
2. 一个**入口点**（Python 脚本、WASM 模块、Node.js 模块或纯提示词 Markdown），实现工具逻辑。

技能安装到 `~/.openfang/skills/`，并通过技能注册表提供给智能体使用。OpenFang 附带 **60 个捆绑技能**，编译在二进制文件中，可立即使用。

### 支持的运行时

| 运行时 | 语言 | 沙箱化 | 说明 |
|---------|----------|-----------|-------|
| `python` | Python 3.8+ | 否（使用 `env_clear()` 的子进程） | 最容易编写。使用 stdin/stdout JSON 协议。 |
| `wasm` | Rust, C, Go 等 | 是（Wasmtime 双重计量） | 完全沙箱化。最适合安全敏感的工具。 |
| `node` | JavaScript/TypeScript | 否（子进程） | OpenClaw 兼容性。 |
| `prompt_only` | Markdown | 不适用 | 专业知识注入系统提示词。不执行代码。 |
| `builtin` | Rust | 不适用 | 编译到二进制文件中。仅用于核心工具。 |

### 60 个捆绑技能

OpenFang 包含 60 个专家知识技能，编译在二进制文件中（无需安装）：

| 类别 | 技能 |
|----------|--------|
| DevOps 与基础设施 | `ci-cd`, `ansible`, `prometheus`, `nginx`, `kubernetes`, `terraform`, `helm`, `docker`, `sysadmin`, `shell-scripting`, `linux-networking` |
| 云 | `aws`, `gcp`, `azure` |
| 语言 | `rust-expert`, `python-expert`, `typescript-expert`, `golang-expert` |
| 前端 | `react-expert`, `nextjs-expert`, `css-expert` |
| 数据库 | `postgres-expert`, `redis-expert`, `sqlite-expert`, `mongodb`, `elasticsearch`, `sql-analyst` |
| API 与 Web | `graphql-expert`, `openapi-expert`, `api-tester`, `oauth-expert` |
| AI/ML | `ml-engineer`, `llm-finetuning`, `vector-db`, `prompt-engineer` |
| 安全 | `security-audit`, `crypto-expert`, `compliance` |
| 开发工具 | `github`, `git-expert`, `jira`, `linear-tools`, `sentry`, `code-reviewer`, `regex-expert` |
| 写作 | `technical-writer`, `writing-coach`, `email-writer`, `presentation` |
| 数据 | `data-analyst`, `data-pipeline` |
| 协作 | `slack-tools`, `notion`, `confluence`, `figma-expert` |
| 职业发展 | `interview-prep`, `project-manager` |
| 高级 | `wasm-expert`, `pdf-reader`, `web-search` |

这些是使用 SKILL.md 格式的 `prompt_only` 技能 —— 专业知识被注入到智能体的系统提示词中。

### SKILL.md 格式

SKILL.md 格式（也用于 OpenClaw）使用 YAML 前言和 Markdown 正文：

```markdown
---
name: rust-expert
description: 专家级 Rust 编程知识
---

# Rust 专家

## 关键原则
- 所有权和借用规则...
- 生命周期注解...

## 常见模式
...
```

SKILL.md 文件会被自动解析并转换为 `prompt_only` 技能。所有 SKILL.md 文件都会通过自动化的**提示词注入扫描器**，检测覆盖尝试、数据泄露模式和 shell 引用，然后才会被包含。

---

## 技能格式

### 目录结构

```
my-skill/
  skill.toml          # 清单（必需）
  src/
    main.py           # 入口点（用于 Python 技能）
  README.md           # 可选文档
```

### 清单（skill.toml）

```toml
[skill]
name = "web-summarizer"
version = "0.1.0"
description = "将任意网页总结为要点"
author = "openfang-community"
license = "MIT"
tags = ["web", "summarizer", "research"]

[runtime]
type = "python"
entry = "src/main.py"

[[tools.provided]]
name = "summarize_url"
description = "获取 URL 并返回简明的要点总结"
input_schema = { type = "object", properties = { url = { type = "string", description = "要总结的 URL" } }, required = ["url"] }

[[tools.provided]]
name = "extract_links"
description = "从网页中提取所有链接"
input_schema = { type = "object", properties = { url = { type = "string" } }, required = ["url"] }

[requirements]
tools = ["web_fetch"]
capabilities = ["NetConnect(*)"]
```

### 清单章节

#### [skill] -- 元数据

| 字段 | 类型 | 必需 | 说明 |
|-------|------|----------|-------------|
| `name` | 字符串 | 是 | 唯一技能名称（用作安装目录名称） |
| `version` | 字符串 | 否 | 语义化版本（默认：`"0.1.0"`） |
| `description` | 字符串 | 否 | 人类可读的描述 |
| `author` | 字符串 | 否 | 作者名称或组织 |
| `license` | 字符串 | 否 | 许可证标识符（例如，`"MIT"`、`"Apache-2.0"`） |
| `tags` | 数组 | 否 | 用于在 FangHub 上发现的标签 |

#### [runtime] -- 执行配置

| 字段 | 类型 | 必需 | 说明 |
|-------|------|----------|-------------|
| `type` | 字符串 | 是 | `"python"`、`"wasm"`、`"node"` 或 `"builtin"` |
| `entry` | 字符串 | 是 | 入口点文件的相对路径 |

#### [[tools.provided]] -- 工具定义

每个 `[[tools.provided]]` 条目定义技能提供的一个工具：

| 字段 | 类型 | 必需 | 说明 |
|-------|------|----------|-------------|
| `name` | 字符串 | 是 | 工具名称（必须在所有工具中唯一） |
| `description` | 字符串 | 是 | 显示给 LLM 的描述 |
| `input_schema` | 对象 | 是 | 定义工具输入参数的 JSON Schema |

#### [requirements] -- 主机依赖

| 字段 | 类型 | 说明 |
|-------|------|-------------|
| `tools` | 数组 | 此技能需要主机提供的内置工具 |
| `capabilities` | 数组 | 智能体必须拥有的能力字符串 |

---

## Python 技能

Python 技能是最简单的编写方式。它们作为子进程运行，通过 stdin/stdout 上的 JSON 进行通信。

### 协议

1. OpenFang 向脚本的 stdin 发送 JSON 负载：

```json
{
  "tool": "summarize_url",
  "input": {
    "url": "https://example.com"
  },
  "agent_id": "uuid-...",
  "agent_name": "researcher"
}
```

2. 脚本处理输入并将 JSON 结果写入 stdout：

```json
{
  "result": "- 第一点\n- 第二点\n- 第三点"
}
```

如果发生错误，返回错误对象：

```json
{
  "error": "获取 URL 失败：连接被拒绝"
}
```

### 示例：网页总结器

`src/main.py`：

```python
#!/usr/bin/env python3
"""OpenFang 技能：网页总结器"""
import json
import sys
import urllib.request


def summarize_url(url: str) -> str:
    """获取 URL 并返回基本总结。"""
    req = urllib.request.Request(url, headers={"User-Agent": "OpenFang-Skill/1.0"})
    with urllib.request.urlopen(req, timeout=30) as resp:
        content = resp.read().decode("utf-8", errors="replace")

    # 简单提取：前 500 个字符作为总结
    text = content[:500].strip()
    return f"{url} 的总结：\n{text}..."


def extract_links(url: str) -> str:
    """从网页中提取所有链接。"""
    import re

    req = urllib.request.Request(url, headers={"User-Agent": "OpenFang-Skill/1.0"})
    with urllib.request.urlopen(req, timeout=30) as resp:
        content = resp.read().decode("utf-8", errors="replace")

    links = re.findall(r'href="(https?://[^"]+)"', content)
    unique_links = list(dict.fromkeys(links))
    return "\n".join(unique_links[:50])


def main():
    payload = json.loads(sys.stdin.read())
    tool_name = payload["tool"]
    input_data = payload["input"]

    try:
        if tool_name == "summarize_url":
            result = summarize_url(input_data["url"])
        elif tool_name == "extract_links":
            result = extract_links(input_data["url"])
        else:
            print(json.dumps({"error": f"未知工具：{tool_name}"}))
            return

        print(json.dumps({"result": result}))
    except Exception as e:
        print(json.dumps({"error": str(e)}))


if __name__ == "__main__":
    main()
```

### 使用 OpenFang Python SDK

对于更高级的技能，使用 Python SDK（`sdk/python/openfang_sdk.py`）：

```python
#!/usr/bin/env python3
from openfang_sdk import SkillHandler

handler = SkillHandler()

@handler.tool("summarize_url")
def summarize_url(url: str) -> str:
    # 在此实现
    return "总结..."

@handler.tool("extract_links")
def extract_links(url: str) -> str:
    # 在此实现
    return "链接1\n链接2"

if __name__ == "__main__":
    handler.run()
```

---

## WASM 技能

WASM 技能在沙箱化的 Wasmtime 环境中运行。它们非常适合安全敏感的操作，因为沙箱强制执行资源限制和能力限制。

### 构建 WASM 技能

1. 用 Rust（或任何可以编译为 WASM 的语言）编写技能：

```rust
// src/lib.rs
use std::io::{self, Read};

#[no_mangle]
pub extern "C" fn _start() {
    let mut input = String::new();
    io::stdin().read_to_string(&mut input).unwrap();

    let payload: serde_json::Value = serde_json::from_str(&input).unwrap();
    let tool = payload["tool"].as_str().unwrap_or("");
    let input_data = &payload["input"];

    let result = match tool {
        "my_tool" => {
            let param = input_data["param"].as_str().unwrap_or("");
            format!("已处理：{param}")
        }
        _ => format!("未知工具：{tool}"),
    };

    println!("{}", serde_json::json!({"result": result}));
}
```

2. 编译为 WASM：

```bash
cargo build --target wasm32-wasi --release
```

3. 在清单中引用 `.wasm` 文件：

```toml
[runtime]
type = "wasm"
entry = "target/wasm32-wasi/release/my_skill.wasm"
```

### 沙箱限制

WASM 沙箱强制执行：

- **燃料限制**：最大计算步数（防止无限循环）。
- **内存限制**：最大内存分配。
- **能力**：仅适用于智能体的能力。

这些派生自智能体清单中的 `[resources]` 部分。

---

## 技能依赖

技能可以在 `[requirements]` 部分声明依赖：

### 工具依赖

如果你的技能需要调用内置工具（例如，`web_fetch` 在下载页面前）：

```toml
[requirements]
tools = ["web_fetch", "file_read"]
```

技能注册表在加载技能前会验证智能体是否有这些工具可用。

### 能力依赖

如果你的技能需要特定能力：

```toml
[requirements]
capabilities = ["NetConnect(*)", "ShellExec(python3)"]
```

---

## 安装技能

### 从本地目录安装

```bash
openfang skill install /path/to/my-skill
```

这会读取 `skill.toml`，验证清单，并将技能复制到 `~/.openfang/skills/my-skill/`。

### 从 FangHub 安装

```bash
openfang skill install web-summarizer
```

这会从 FangHub 市场注册表下载技能。

### 从 Git 仓库安装

```bash
openfang skill install https://github.com/user/openfang-skill-example.git
```

### 列出已安装的技能

```bash
openfang skill list
```

输出：

```
3 skill(s) installed:

NAME                 VERSION    TOOLS    DESCRIPTION
----------------------------------------------------------------------
web-summarizer       0.1.0      2        将任意网页总结为要点
data-analyzer        0.2.1      3        统计分析工具
code-formatter       1.0.0      1        格式化 20+ 语言的代码
```

### 移除技能

```bash
openfang skill remove web-summarizer
```

---

## 发布到 FangHub

FangHub 是 OpenFang 的社区技能市场。

### 准备你的技能

1. 确保你的 `skill.toml` 有完整的元数据：
   - `name`、`version`、`description`、`author`、`license`、`tags`
2. 包含一个 `README.md`，其中有使用说明。
3. 在本地测试你的技能：

```bash
openfang skill install /path/to/my-skill
# 生成一个带有技能工具的智能体并测试它们
```

### 搜索 FangHub

```bash
openfang skill search "web scraping"
```

输出：

```
匹配 "web scraping" 的技能：

  web-summarizer (42 stars)
    将任意网页总结为要点
    https://fanghub.dev/skills/web-summarizer

  page-scraper (28 stars)
    从网页中提取结构化数据
    https://fanghub.dev/skills/page-scraper
```

### 发布

发布到 FangHub 将通过以下方式可用：

```bash
openfang skill publish
```

这会验证清单，打包技能，并将其上传到 FangHub 注册表。

---

## CLI 命令

### 完整技能命令参考

```bash
# 安装技能（本地目录、FangHub 名称或 git URL）
openfang skill install <source>

# 列出所有已安装的技能
openfang skill list

# 移除已安装的技能
openfang skill remove <name>

# 在 FangHub 上搜索技能
openfang skill search <query>

# 创建新技能脚手架（交互式）
openfang skill create
```

### 创建技能脚手架

```bash
openfang skill create
```

此交互式命令提示输入：
- 技能名称
- 描述
- 运行时类型（python/node/wasm）

它生成：

```
~/.openfang/skills/my-skill/
  skill.toml        # 预填充清单
  src/
    main.py         # 入门入口点（用于 Python）
```

生成的入口点包含一个可运行的模板，从 stdin 读取 JSON 并将 JSON 写入 stdout。

### 在智能体清单中使用技能

在智能体清单的 `skills` 字段中引用技能：

```toml
name = "my-assistant"
version = "0.1.0"
description = "一个拥有额外技能的助手"
author = "openfang"
module = "builtin:chat"
skills = ["web-summarizer", "data-analyzer"]

[model]
provider = "groq"
model = "llama-3.3-70b-versatile"

[capabilities]
tools = ["file_read", "web_fetch", "summarize_url"]
memory_read = ["*"]
memory_write = ["self.*"]
```

内核在智能体生成时加载技能工具和提示词，将它们与智能体的基础能力合并。

---

## OpenClaw 兼容性

OpenFang 可以安装和运行 OpenClaw 格式的技能。技能安装程序通过查找 `package.json` + `index.ts`/`index.js` 自动检测 OpenClaw 技能并进行转换。

### 自动转换

```bash
openfang skill install /path/to/openclaw-skill
```

如果目录包含 OpenClaw 风格的技能（Node.js 包），OpenFang：

1. 检测 OpenClaw 格式。
2. 从 `package.json` 生成 `skill.toml` 清单。
3. 将工具名称映射到 OpenFang 约定。
4. 将技能复制到 OpenFang 技能目录。

### 手动转换

如果自动转换不起作用，请手动创建 `skill.toml`：

```toml
[skill]
name = "my-openclaw-skill"
version = "1.0.0"
description = "从 OpenClaw 转换"

[runtime]
type = "node"
entry = "index.js"

[[tools.provided]]
name = "my_tool"
description = "工具描述"
input_schema = { type = "object", properties = { input = { type = "string" } }, required = ["input"] }
```

将其放在现有的 `index.js`/`index.ts` 旁边并安装：

```bash
openfang skill install /path/to/skill-directory
```

通过 `openfang migrate --from openclaw` 导入的技能也会在迁移报告中进行扫描和报告，并提供手动重新安装的说明。

---

## 最佳实践

1. **保持技能专注** —— 一个技能应该做好一件事。
2. **声明最小依赖** —— 只请求技能实际需要的工具和能力。
3. **使用描述性工具名称** —— LLM 读取工具名称和描述来决定何时使用它。
4. **提供清晰的输入模式** —— 为每个参数包含描述，以便 LLM 知道传递什么。
5. **优雅地处理错误** —— 始终返回 JSON 错误对象而不是崩溃。
6. **仔细版本控制** —— 使用语义化版本控制；破坏性更改需要主版本号升级。
7. **用多个智能体测试** —— 验证你的技能是否适用于不同的智能体模板和提供商。
8. **包含 README** —— 记录设置步骤、依赖和示例用法。
