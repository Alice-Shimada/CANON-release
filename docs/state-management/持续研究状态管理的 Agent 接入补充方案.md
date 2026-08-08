# 持续研究状态管理的 Agent 接入补充方案

## 一、定位

本方案是《跨通用 Agent 的持续研究状态管理基础设施设计方案》的接入补充，只增加 Agent 接入层，不另行改变基础方案已经确定的字段、状态、命令或运行规则。

目标是：

> 用户只需用自然语言提出科研问题；Codex、OpenCode、Claude Code 和 Hermes 自动发现状态管理能力，并在内部通过 tool calling 使用。用户不需要知道状态机或 CLI 的存在。

## 二、核心结构

```text
用户自然语言请求
        ↓
宿主 Agent 的规则入口与 Skill 入口
        ↓
本地 statemng MCP server
        ↓
现有 statemng CLI
        ↓
现有 JSON 状态目录
```

四个宿主共用同一个 Skill 协议和 MCP server。宿主适配层只负责自动发现与注册，不保存状态，也不实现状态转换。

## 三、规则与 Skill

### 3.1 规则入口

根目录 `AGENTS.md` 供 Codex、OpenCode 和 Hermes 使用，根目录 `CLAUDE.md` 供 Claude Code 使用。两个文件都必须包含以下入口规则：

1. 多步骤科研任务必须加载 `persistent-scientific-research` Skill；
2. 用户只与主 Agent 交互，不得要求用户执行内部 CLI；
3. 所有状态操作必须通过项目提供的 `statemng` tools 完成；
4. `task accept` 和 `task unblock` 只允许主 Agent 调用，subagent 不得调用；
5. 主 Agent 创建 subagent 时，必须通过宿主原生的 tool 权限或限制机制禁止其调用 `statemng_task_accept` 和 `statemng_task_unblock`；
6. tools 不可用时停止并报告接入错误，不得绕过状态管理继续研究；
7. 不得使用已经删除的 `workflow.py`。

除上述规则外，两个文件还必须将《跨通用 Agent 的持续研究状态管理基础设施设计方案》从 `## 四、整体架构` 标题开始，到 `## 五、主要组件` 标题之前的全部内容原封不动写入。标题、正文、Mermaid 图、目录结构、协作闭环和任务状态模型均不得删减、改写或另行概括。基础方案的这一节发生变化时，两个文件中的复制内容必须同步更新，并继续与基础方案原文完全一致。

### 3.2 公共 Skill

公共 Skill 位于：

```text
.agents/skills/persistent-scientific-research/SKILL.md
```

其 frontmatter 为：

```yaml
---
name: persistent-scientific-research
description: Use for multi-step scientific research in CANON, including master-integral differential equations, UT bases, canonical forms, and epsilon forms.
---
```

正文规定：

- 何种科研请求需要状态管理；
- 必须使用 `statemng` MCP tools；
- 用户不得被要求执行内部工具；
- 状态操作必须遵循 `AGENTS.md` 或 `CLAUDE.md` 中完整载入的“## 四、整体架构”；
- 主 Agent 负责审查结果，并独占 `statemng_task_accept` 和 `statemng_task_unblock`；
- subagent 只负责领取、读取、执行、登记产物以及提交、阻塞或报告失败，不得接受任务或解除阻塞；
- 主 Agent 创建 subagent 时必须禁止其调用上述两个专属 tools；
- tools 不可用时必须停止。

Codex 和 OpenCode 直接发现该 Skill。Claude Code 的 `.claude/skills/persistent-scientific-research/SKILL.md` 只保留相同 frontmatter，并要求读取上述公共 Skill，不复制其协议。Hermes 通过 `skills.external_dirs` 加载 `.agents/skills/`。

## 四、MCP tool calling 接口

### 4.1 MCP server

新增：

```text
state-management/mcp_server.py
```

服务采用本地 STDIO 方式运行，不需要网络、认证或远程服务。它只执行以下转换：

1. 接收结构化 tool 参数；
2. 转换为对应的 `statemng` CLI 调用；
3. 在仓库根目录执行；
4. 解析 CLI 返回的 JSON；
5. 将结果原样返回给 Agent。

MCP server 不直接读写状态文件，也不重新实现状态转换。

### 4.2 Tool 映射

每个已有 CLI 命令对应一个 MCP tool。tool 名为 `statemng_` 加命令路径，各级以 `_` 连接，例如：

```text
project list  -> statemng_project_list
task create   -> statemng_task_create
artifact add  -> statemng_artifact_add
task submit   -> statemng_task_submit
task unblock  -> statemng_task_unblock
```

全部已有命令按同一规则暴露，并满足：

- 参数与对应 CLI 参数一致；
- 返回值使用 CLI 原始 JSON；
- CLI 非零退出时 tool 返回失败；
- 不增加组合命令、自动命令或新状态操作；
- 只读 tool 设置 `readOnlyHint: true`，修改状态的 tool 设置 `readOnlyHint: false`。

### 4.3 仓库根目录

MCP server 启动后，根据自身路径确定仓库根目录：

```text
CANON/state-management/mcp_server.py
             ↓
CANON/
```

不增加 `project_root` 参数，也不依赖 Agent 当前所在的子目录。但宿主仍须先用确定的路径找到并启动 server；server 的自定位不能解决宿主从任意工作目录解析相对启动路径的问题。

## 五、宿主接入

| 宿主 | 规则入口 | Skill 入口 | MCP 注册 |
|---|---|---|---|
| Codex | `AGENTS.md` | `.agents/skills/` | `.codex/config.toml` |
| OpenCode | `AGENTS.md` | `.agents/skills/` | `opencode.json` |
| Claude Code | `CLAUDE.md` | `.claude/skills/` 薄入口 | `.mcp.json` |
| Hermes | `AGENTS.md` | `skills.external_dirs` 指向 `.agents/skills/` | `~/.hermes/config.yaml` |

所有宿主最终都启动同一个 `state-management/mcp_server.py`，不得增加宿主专用 MCP 实现。宿主适配层可以增加不保存状态的机器本地启动入口，用于把仓库配置映射到当前机器上的绝对 server 路径。

主 Agent 可以使用全部 `statemng` tools。各宿主创建 subagent 时必须使用自身原生的 tool 权限或限制机制，至少禁止 `statemng_task_accept` 和 `statemng_task_unblock`；不得仅依靠 subagent 自觉区分权限。该限制只属于宿主接入层，不改变 MCP server 和 CLI 的统一实现。

OpenCode 和 Claude Code 使用仓库级配置；OpenCode 对该 server 设置 `codemode: false`，使 tools 直接暴露给 Agent。宿主可以在显示名称中增加 server 命名空间，但 MCP tool 的协议名称不变。

### 5.1 Codex

Codex 使用仓库级 `.codex/config.toml` 声明 server，但不在配置中使用 checkout 相对路径。接入 Agent 运行 `state-management/adapters/codex/install_launcher.py`，在 `$HOME/.codex/statemng/CANON/mcp` 原子安装机器本地入口；入口记录当前 checkout 中 `state-management/mcp_server.py` 和可执行 Python 的绝对路径。该文件不保存研究状态，不进入版本控制；checkout 或 Python 路径变化时由接入 Agent 重新安装，不得要求用户执行。

主 Agent 与 `persistent_research_worker` 都通过 `/bin/sh` 调用上述入口，设置 `enabled = true`、`required = false`，并且不设置 `cwd`。`required = false` 是会话保活边界：MCP 启动失败时，Codex 会话仍能创建和恢复；但规则与 Skill 继续要求 tools 不可用时立即停止持续研究并报告接入错误，绝不允许绕过状态管理。worker 的配置还必须从 tool surface 禁止 `statemng_task_accept` 和 `statemng_task_unblock`。

初版只允许在机器本地入口所注册的 Codex Local 会话中执行持续研究。主 Agent 在首次状态调用前自行运行安装程序的 `--check`；若入口缺失或指向其他 checkout，主 Agent 重新安装入口并停止当前持续研究，待全新 Local 会话重新加载 MCP。Worktree 会话可以正常启动并处理其他工作，但不得运行持续研究。后续若要支持 Worktree，必须先提供能够按会话 checkout 选择入口的宿主机制。

Codex 接入必须完成四层验证：配置静态校验；从 `/` 启动入口并完成 MCP initialize、tools/list 和只读 tool 调用；在全新 Local 会话中确认 tools 实际暴露；用不可启动的临时 MCP 配置确认 server 失败时会话仍可启动。配置或入口发生变化后，必须重新执行验证。

Hermes 的 MCP 与外部 Skill 目录需要在宿主配置中注册一次；该机器相关配置不写入仓库。完成注册后，用户仍只需用自然语言提出任务。

接入修改必须在各宿主的全新会话中验证，确认规则与 Skill 已加载，并且每个 MCP tool 都可调用。宿主要求项目信任或配置确认时，使用其原生确认机制，不得绕过。

## 六、现有说明调整

### 6.1 `README.md`

删除或替换所有关于旧 `workflow.py` 的说明，只保留：

- 用户直接向 Agent 提出科研目标；
- Agent 自动使用项目内部的持续研究基础设施；
- 用户不需要调用状态管理 CLI；
- 两份状态管理设计文档的位置。

### 6.2 Adapter

保留并更新：

```text
state-management/adapters/codex/ADAPTER.md
state-management/adapters/opencode/ADAPTER.md
state-management/adapters/claude-code/ADAPTER.md
state-management/adapters/hermes/ADAPTER.md
```

每份 Adapter 只说明该宿主如何发现规则、加载 Skill、注册同一个 MCP server，以及主 Agent 创建 subagent 时如何禁止其调用 `statemng_task_accept` 和 `statemng_task_unblock`。Codex Adapter 还必须说明机器本地入口、会话保活边界、Local 限制和宿主级验证。Adapter 不重复 CLI 协议或状态机运行流程，但必须明确：只有主 Agent 可以接受任务和解除阻塞，subagent 只能提交、阻塞或报告失败。

## 七、文件布局

```text
CANON/
├── AGENTS.md
├── CLAUDE.md
├── .agents/
│   └── skills/
│       └── persistent-scientific-research/
│           └── SKILL.md
├── .claude/
│   └── skills/
│       └── persistent-scientific-research/
│           └── SKILL.md
├── .codex/
│   ├── config.toml
│   └── agents/
│       └── persistent-research-worker.toml
├── .mcp.json
├── opencode.json
├── state-management/
│   ├── mcp_server.py
│   ├── statemng
│   ├── state_management/
│   ├── adapters/
│   │   ├── codex/
│   │   │   ├── ADAPTER.md
│   │   │   └── install_launcher.py
│   │   ├── opencode/
│   │   ├── claude-code/
│   │   └── hermes/
│   └── tests/
│       ├── test_mcp_server.py
│       └── test_codex_adapter.py
└── README.md
```

状态管理代码和测试继续集中在 `state-management/`。仓库根目录及宿主目录只放自动发现所需的规则、Skill 入口和配置文件。
