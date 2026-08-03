# 跨通用 Agent 的持续研究状态管理基础设施设计方案

$\epsilon$-form 构建并非线性流程：一个算例通常需要派发数量众多、相互关联的异步任务，并在不同方法和候选方案之间不断探索、验证和回溯。任务之间的依赖关系必须严格遵循，每次尝试产生的成功经验、失败原因和中间结果也必须妥善保存，供后续任务判断与复用。单个 Markdown 文档适合呈现研究记录，却难以可靠管理并发领取、依赖解锁和状态转换，也难以保证不同会话、不同 Agent 始终使用同一组有效事实。本方案因此以任务目录内的 JSON 数据和受控 CLI 管理任务状态与研究轨迹，以 Markdown 作为可读视图，为持续研究提供可靠的状态管理基础。

**文档版本：** v0.1
**系统定位：** 面向 Codex、Hermes、Claude Code 等通用 Agent 的持续研究基础设施
**核心形态：** 内部 CLI + 按总体任务隔离的文件存储 + 平台适配层
**核心约束：**

1. 用户只与 Codex、Hermes、Claude Code 等主 Agent 交互；
1. CLI 仅作为主 Agent 与 subagent 的内部协作接口，不直接面向用户；
1. 所有 subagent 均由当前宿主 Agent 的原生机制创建；系统本身不启动额外的 Agent 进程；
1. 所有持久化状态和研究产物均位于项目内的 `.state-management/[TASK_NAME]/`；
1. 项目状态独立于任何特定 Agent 的会话。

## 一、项目目标

本系统旨在为不同通用 Agent 提供一套统一的持续研究机制，使其能够：

- 将复杂研究目标拆解为长期任务；
- 使用自身原生 subagent 并行执行子任务；
- **跨会话保存研究进度**；
- **管理任务依赖、阻塞和结果交接**；
- 累积研究证据、决策与产物；
- 保存任务的成功、失败经验及中间结果，供后续任务复用；
- 在更换 Codex、Hermes 或 Claude Code 后继续同一项目。


系统不要求不同 Agent 拥有完全相同的内部实现，而是统一它们对外表现出的研究协作协议。

## 二、系统的核心模型

整个系统可以概括为：

> 主 Agent 负责规划和调度，原生 subagent 负责执行，CLI 和任务目录内的 JSON 文件负责保存并约束共享状态。

整体关系如下：

```
用户
  │
  ▼
主 Agent
Codex / Hermes / Claude Code
  │
  ├── 读取项目状态和任务协议
  │
  ├── 调用 statemng CLI 管理项目
  │
  └── 使用自身原生能力创建 subagent
                │
                ▼
         原生 subagent
                │
                ├── 通过 CLI 领取任务
                ├── 读取任务上下文
                ├── 执行研究
                └── 通过 CLI 提交结果
```

其中：

- 用户只看到主 Agent；
- 主 Agent 是研究负责人和任务调度者；
- subagent 是临时研究执行者；
- CLI 是所有 Agent 共享的任务协议；
- `.state-management/[TASK_NAME]/` 内的 JSON、Markdown 和研究产物保存总体任务的长期状态。

## 三、核心设计原则

### 3.1 模型负责研究，程序负责秩序

Agent 负责：

- 理解和拆解研究问题；
- 提出假设、设计验证并分析结果；
- 判断下一步研究方向。


CLI 和底层程序负责：

- 持久化任务状态、运行历史和研究产物；
- 检查任务依赖，保证任务领取与状态转换合法。


系统不能仅依靠提示词要求 Agent “记得更新进度”，关键状态必须通过 CLI 修改。

### 3.2 项目状态不依赖会话

任何 Agent 会话都可以结束、压缩或被替换。

新会话启动后，主 Agent 应通过 CLI 恢复：

- 当前研究目标；
- 已完成、正在执行、阻塞和可继续执行的任务；
- 已形成的证据和结论。


Agent 会话是临时计算环境，项目状态才是长期事实。

### 3.3 CLI 不负责创建 subagent

CLI 只管理任务，不直接启动或控制 subagent。

任务分配分为两个层面。

#### 逻辑分配

CLI 记录任务由哪个执行实例领取：

```
statemng task claim T-012 \
  --executor-ref codex:dispatch-7f3a
```

`executor_ref` 是本次派发的唯一执行实例引用，不是固定的 subagent 名称。Adapter 应使用宿主平台提供的 thread 或 agent ID；如果该 ID 不可用或可能复用，则由主 Agent 生成 `dispatch_id`，单独使用或与平台 ID 组合，保证每次派发的 `executor_ref` 唯一。

#### 物理分配

主 Agent 使用自身原生能力创建一个 subagent，并把总体任务目录、内部任务 ID 和 `executor_ref` 告诉它。

因此：

> CLI 管理任务运行及其执行实例引用，主 Agent 决定创建哪个 subagent 执行任务。

### 3.4 使用统一协议，而不是统一内部实现

不同 Agent 的 subagent 创建方式可能不同：

```
Codex Adapter
Claude Code Adapter
Hermes Adapter
```

但创建后的 subagent 都遵守相同协议：

```
领取任务
→ 读取任务
→ 执行任务
→ 登记产物
→ 完成或阻塞任务
```

平台差异只存在于“如何创建原生 subagent”，不进入核心任务系统。

### 3.5 Markdown 用于阅读，JSON 用于运行

系统可以在总体任务目录内生成：

```
PROJECT_STATE.md
RESEARCH_LOG.md
DECISIONS.md
```

供人类和 Agent 阅读。

运行时状态保存在 JSON 文件中，Markdown 只由 JSON 状态生成或更新。

原则是：

> JSON 是事实源，Markdown 是人类可读投影。

这样既保留透明度，也避免多个 Agent 并发修改同一个进度文档产生冲突。当前版本面向个人科研使用，不引入 SQL；若以后出现大规模并发或集中部署需求，再单独评估数据库迁移。

### 3.6 按总体任务隔离

项目初始化后，所有状态管理产物都必须位于：

```
.state-management/[TASK_NAME]/
```

这里的 `[TASK_NAME]` 指需要长期管理的总体研究任务，内部再拆分为 `T-001`、`T-002` 等任务单元。不同总体任务使用彼此独立的同级目录，不共享可变状态。对于 $\epsilon$-form 项目，总体任务可以对应一个 integral family，目录为 `.state-management/[FAMILY_NAME]/`。

总体任务名称必须本身就是合法目录名，不得包含路径分隔符，也不得为 `.` 或 `..`。CLI 不对名称做隐式改写，从而保证目录名与任务名称一致。

## 四、整体架构

系统由四个主要部分组成。

```
┌──────────────────────────────────────┐
│              用户                     │
└─────────────────┬────────────────────┘
                  ▼
┌──────────────────────────────────────┐
│          通用 Agent 主会话             │
│ Codex / Hermes / Claude Code          │
│                                      │
│ 研究规划 · 调度 · 综合 · 用户交互       │
└──────────┬────────────────┬──────────┘
           │                │
           │ CLI            │ 原生 subagent 机制
           ▼                ▼
┌───────────────────┐  ┌───────────────────┐
│ State Management  │  │ Native Subagents  │
│ CLI: statemng     │◀─│                   │
│ 任务 · 状态 · 产物 │  │ 调研 · 推理 · 编程 │
│ 依赖 · 运行历史     │  │ 验证 · 综合        │
└──────────┬────────┘  └───────────────────┘
           ▼
┌──────────────────────────────────────┐
│ Task-scoped JSON · Artifacts · Views │
└──────────────────────────────────────┘
```

## 五、主要组件

### 5.1 主 Agent

主 Agent 是系统中的研究负责人。

主要职责：

- 接收用户目标，读取项目状态并制定研究计划；
- 创建任务及其依赖，选择可并行推进的任务；
- 创建原生 subagent，并向其传递总体任务目录、内部任务 ID 和 `executor_ref`；
- 检查执行状态，处理阻塞与失败，并组织结果综合；
- 向用户汇报阶段结果。


主 Agent 不应亲自完成所有子任务，也不应把全部项目状态只保存在自身上下文中。

### 5.2 原生 subagent

subagent 只能由宿主 Agent 的原生机制创建。

subagent 的职责应尽量单一：

- 调研或理论分析；
- 代码实现或实验执行；
- 数据分析或结果审查；
- 综合写作。


每个 subagent 启动时只需要得到：

- 总体任务目录；
- 内部任务 ID；
- `executor_ref`；
- CLI 使用协议。


任务的详细背景由 subagent 自行通过 CLI 获取。`priority` 只供主 Agent 排程，不传给 subagent，也不进入其任务上下文。

### 5.3 平台 Adapter

Adapter 不负责调度任务，也不负责启动外部进程。

它只描述当前平台如何使用自身原生 subagent。

例如：

```
adapters/
├── codex/
│   └── ADAPTER.md
├── hermes/
│   └── ADAPTER.md
└── claude-code/
    └── ADAPTER.md
```

每个 Adapter 应规定：

1. 如何创建原生 subagent，并传递总体任务目录、内部任务 ID 和 `executor_ref`；
1. 如何取得宿主平台的执行实例标识，或生成唯一的 `dispatch_id`；
1. 如何并行执行及限制最大并发数；
1. 如何判断 subagent 已结束，并处理异常退出；
1. 宿主 Agent 能力不足时如何降级。


Adapter 应尽量薄，不保存任何项目状态。

### 5.4 State Management CLI

CLI 是系统的内部控制接口。

调用者是：

- 主 Agent；
- 原生 subagent；
- 必要时的验证 subagent。

用户不需要知道 CLI 的存在。


CLI 应具备以下特点：

- 接口精简稳定，默认输出 Agent 可可靠解析的 JSON；
- 错误码明确；
- 支持文件输入，避免长文本 shell 转义；
- 状态更新具有原子性，重复调用尽量保持幂等。


命令名称统一为 `statemng`。具体实现应提供独立命令入口；hook 只能调用该入口，不定义另一套状态更新路径。

## 六、CLI 命令设计

*（需要后续详细设计。这里只提供初步参考，不以这里的设计为准。）*

### 6.1 初始化项目

```
statemng init [TASK_NAME]
```

职责：

- 创建 `.state-management/[TASK_NAME]/`；
- 初始化 JSON 状态文件、artifact 和运行目录；
- 写入 schema 版本及总体任务名称；
- 生成初始 Markdown 状态视图。


若同名总体任务目录已经存在，命令必须停止，不能覆盖。初始化后，主 Agent 进入该总体任务目录；本节其余命令均从该目录执行，CLI 不跨目录读写其他总体任务。


建议返回：

```
{
  "success": true,
  "task_name": "[TASK_NAME]",
  "task_root": "/path/to/project/.state-management/[TASK_NAME]",
  "schema_version": 1
}
```

### 6.2 恢复项目状态

```
statemng project resume --json
```

供主 Agent 每次新会话开始时调用。

返回内容应包括：

- 项目目标；
- 已完成、运行中、阻塞和可执行的任务；
- 最近关键决策与建议的下一步动作。


该命令应返回压缩后的项目状态，而不是整个历史记录。

### 6.3 创建任务

```
statemng task create \
  --title "调查相关研究工作" \
  --description-file task.md \
  --depends-on T-001,T-002 \
  --priority 80 \
  --json
```

设计要求：

- 自动生成稳定任务 ID；
- 支持依赖、优先级、任务类型和验收标准；
- 记录父任务关系；
- 详细描述优先通过文件传入。


`priority` 只用于主 Agent 在多个 `ready` 任务之间排序，不传给 subagent，也不由 `task show` 返回。


返回：

```
{
  "success": true,
  "task_id": "T-012",
  "status": "pending",
  "dependencies": ["T-001", "T-002"]
}
```

依赖全部完成后，系统自动将任务转为 `ready`。

### 6.4 查询可执行任务

```
statemng task ready --json
```

供主 Agent 判断应该创建哪些 subagent。

支持筛选：

```
statemng task ready \
  --type literature-review \
  --limit 4 \
  --json
```

返回内容应保持精简：

```
{
  "tasks": [
    {
      "task_id": "T-012",
      "title": "调查相关研究工作",
      "priority": 80,
      "estimated_scope": "medium"
    }
  ]
}
```

### 6.5 领取任务

> **备忘（当前版本不实现）：** 后续可以考虑在 `claim` 阶段设置并发限制：当当前总体任务中处于 `running` 的任务达到上限时，`statemng` 拒绝新的领取请求，从而间接限制同时进入执行阶段的 subagent 数量。该机制不能限制宿主已经创建的 subagent 总数，创建侧的并发仍由主 Agent 和 Adapter 控制。若以后实施，还需要单独设计并发判断的原子性、领取被拒绝后的处理，以及异常退出遗留 `running` 状态时的额度恢复；当前版本不定义相关参数和协议。

```
statemng task claim T-012 \
  --executor-ref codex:dispatch-7f3a \
  --json
```

该命令通常由 subagent 启动后首先调用。

职责：

- 原子检查任务是否为 `ready`；
- 防止多个 subagent 重复领取；
- 将任务变为 `running`；
- 创建唯一 `run_id`；
- 记录 `executor_ref` 和领取时间。


`executor_ref` 必须由 Adapter 或主 Agent 为每次派发动态取得或生成，且不得复用。它只用于关联任务运行与宿主执行实例；`run_id` 才是后续状态更新的运行身份。

返回：

```
{
  "success": true,
  "task_id": "T-012",
  "run_id": "R-048",
  "executor_ref": "codex:dispatch-7f3a",
  "status": "running"
}
```

若任务已被领取：

```
{
  "success": false,
  "error": "TASK_ALREADY_CLAIMED"
}
```

### 6.6 读取任务

```
statemng task show T-012 \
  --run-id R-048 \
  --json
```

返回：

- 任务目标、背景和验收标准；
- 前置任务结果及相关 artifact；
- 当前工作目录与允许创建的子任务范围；
- 时间或资源预算。


该命令不返回 `priority`。


这样主 Agent 不需要在创建 subagent 时复制完整上下文。

### 6.7 报告进度

```
statemng task heartbeat T-012 \
  --run-id R-048 \
  --message "已筛选出 15 项相关工作，正在进行结构化比较" \
  --json
```

用于记录语义进展。

设计要求：

- 短任务无需频繁调用；
- 长任务应在阶段切换时调用；
- heartbeat 只说明 Agent 报告了进展；
- 不能单独证明实际进程仍然存活。

### 6.8 登记产物

\command? hook? *Sys.argv*

```
statemng artifact add \
  --task T-012 \
  --run-id R-048 \
  --path runs/R-048/workspace/literature-review.md \
  --type literature-review \
  --json
```

职责：

- 验证文件存在；
- 计算内容哈希；
- 保存来源任务和运行 ID；
- 复制或登记到统一 artifact 目录；
- 返回 artifact ID。


返回：

```
{
  "success": true,
  "artifact_id": "A-031",
  "stored_path": ".state-management/[TASK_NAME]/artifacts/A-031.md"
}
```

任务的重要结果不能只存在于 subagent 的聊天回复中。

### 6.9 完成任务

```
statemng task complete T-012 \
  --run-id R-048 \
  --summary-file runs/R-048/workspace/summary.md \
  --artifact A-031 \
  --json
```

职责：

- 检查调用者是否持有当前任务；
- 检查必要产物是否已经提交；
- 检查验收字段是否完整；
- 在同一次 `tasks/T-012.json` 原子替换中写入 `success: true`，并将任务设为 `completed`；
- 自动解锁依赖该任务的后续任务；
- 记录完整运行历史。


返回：

```
{
  "success": true,
  "status": "completed",
  "unlocked_tasks": ["T-015"]
}
```

### 6.10 阻塞任务

```
statemng task block T-012 \
  --run-id R-048 \
  --reason-file blocker.md \
  --json
```

适用于：

- 缺少关键数据、权限或外部条件；
- 需要用户或主 Agent 决定研究方向；
- 前提假设无法验证或任务定义存在歧义；
- 发现超出当前任务边界的问题。


阻塞不同于失败。已经形成的中间产物必须保留。

### 6.11 标记任务失败

```
statemng task fail T-012 \
  --run-id R-048 \
  --reason-file failure.md \
  --retryable true \
  --json
```

失败信息应包括：

- 失败原因；
- 已尝试的方法；
- 是否建议重试；
- 是否建议换一种 Agent 角色；
- 是否需要重新定义任务。


主 Agent 根据这些信息决定重新派发或终止任务。

### 6.12 查询状态

```
statemng task status T-012 --json
```

或：

```
statemng task list \
  --status running,blocked \
  --json
```

主要供主 Agent 使用。

返回：

- 当前状态、`executor_ref` 和 run ID；
- 最近一次 heartbeat 与最新进展；
- 已提交产物；
- 已运行时长和重试次数。

### 6.13 读取研究产物

```
statemng artifact show A-031 --json
```

或：

```
statemng artifact list \
  --task T-012 \
  --json
```

主 Agent 或综合 subagent 通过 artifact 获取结果，而不是依赖原始 subagent 会话仍然存在。

### 6.14 项目校验

```
statemng doctor --json
```

用于检测：

- JSON 文件损坏、字段不一致或存在无效、循环的任务依赖；
- 丢失的 artifact；
- 缺失或重复的 `executor_ref`；
- 长期停留在 `running`、需要主 Agent 或 Adapter 核实执行实例状态的任务；
- 不兼容的 schema 版本；
- 断电后遗留的临时文件、孤立 artifact，以及没有 `success: true` 完成记录的运行。

### 6.15 断电恢复

总体任务恢复时，只有已经原子写入 `success: true` 且任务状态为 `completed` 的运行才视为成功。`statemng project resume --json` 应列出所有未成功结束的运行及其目录，但不自动删除文件，也不自动重试。

该命令可以依据已提交的任务依赖确定性地恢复 `pending` 到 `ready` 的转换并重建 Markdown 视图；是否保留未成功运行的文件则必须由主 Agent 判断。

主 Agent 逐项检查这些运行的 JSON 状态、日志、workspace 和 artifact，并决定：

- 结果完整且可验证：保留结果并补交完成记录；
- 中间结果仍有价值：保留相应文件，将任务重新设为 `ready` 或 `blocked`；
- 文件无效、重复或已不再需要：只清理该运行的目录，再重新派发或结束任务。


清理由主 Agent 使用宿主环境的文件操作直接执行，不增加 `statemng cleanup` 或 `statemng recover` 命令。若需要改变任务状态，主 Agent 先通过现有的 `complete`、`block` 或 `fail` 命令记录决定，再直接清理选定文件。清理范围必须限制在当前 `.state-management/[TASK_NAME]/runs/[RUN_ID]/`；已登记 artifact、成功运行和其他总体任务目录不得删除。无法判断时默认保留。对于 $\epsilon$-form 任务，清理前尤其应检查耗时的符号计算、候选变换和验证残差是否仍可复用。

## 七、任务状态模型

建议采用以下状态：

```
pending
   │
   │ 依赖满足
   ▼
 ready
   │
   │ subagent claim
   ▼
 running
  ├───────────────┬───────────────┐
  ▼               ▼               ▼
completed       blocked          failed
                                    │
                                    │ retry
                                    ▼
                                  ready
```

状态含义：

- `pending`：前置依赖尚未完成；
- `ready`：可以被 subagent 领取；
- `running`：已经由某个 subagent 领取；
- `completed`：完成并通过基本验收；
- `blocked`：需要用户、主 Agent 或外部条件介入；
- `failed`：本次执行失败；
- `cancelled`：任务被主 Agent 主动取消。


只有 CLI 可以修改任务状态。

## 八、主 Agent 与 subagent 的协作流程

（*需要后续详细设计。这里只提供初步参考，不以这里的设计为准。）*

### 8.1 用户提出研究目标

用户对主 Agent 说：

```
系统性研究不同通用 Agent 的持续研究机制，
并形成一套跨平台设计方案。
```

### 8.2 主 Agent 初始化或恢复总体任务

主 Agent 先确定总体任务名称，并检查对应目录是否存在。

若 `.state-management/cross-agent-state-management/` 不存在，说明该总体任务尚未初始化。主 Agent 在项目根目录执行：

```
statemng init cross-agent-state-management
```

初始化命令已经创建初始状态，因此不再执行 `resume`。

若该目录已经存在，主 Agent 进入目录并执行：

```
statemng project resume --json
```

读取已有研究状态。两种情况下，后续操作均在该总体任务目录内进行。

### 8.3 主 Agent 创建任务

例如：

```
T-001：研究 Codex 的相关机制
T-002：研究 Hermes 的相关机制
T-003：研究 Claude Code 的相关机制
T-004：比较三者并形成统一抽象
```

其中：

```
T-004 depends on T-001, T-002, T-003
```

### 8.4 主 Agent 查询可执行任务

```
statemng task ready --json
```

得到：

```
T-001
T-002
T-003
```

### 8.5 主 Agent 创建原生 subagent

这一步不通过 CLI。

主 Agent 使用当前平台的原生 subagent 能力创建三个 subagent，并为每次派发取得或生成唯一的 `executor_ref`。

传给每个 subagent 的启动提示词应采用固定模板：

```
你是当前项目的研究 subagent。

总体任务目录：/path/to/project/.state-management/cross-agent-state-management
内部任务 ID：T-001
Executor Ref：codex:dispatch-a91c

请严格执行以下协议：

1. 执行：
   statemng task claim T-001 --executor-ref codex:dispatch-a91c --json

2. 读取返回的 run_id。

3. 执行：
   statemng task show T-001 --run-id <run_id> --json

4. 根据任务目标完成研究。

5. 所有重要结果必须保存为文件，并通过
   statemng artifact add 登记。

6. 完成时调用 statemng task complete。

7. 无法完成时调用 statemng task block 或 fail。

不要只在聊天中返回结果。
```

### 8.6 subagent 领取任务

subagent 执行：

```
statemng task claim T-001 \
  --executor-ref codex:dispatch-a91c \
  --json
```

取得：

```
run_id = R-001
```

然后读取完整任务：

```
statemng task show T-001 \
  --run-id R-001 \
  --json
```

### 8.7 subagent 执行并提交结果

完成研究后：

```
statemng artifact add \
  --task T-001 \
  --run-id R-001 \
  --path runs/R-001/workspace/codex-report.md \
  --type research-report \
  --json
```

再执行：

```
statemng task complete T-001 \
  --run-id R-001 \
  --summary-file runs/R-001/workspace/summary.md \
  --artifact A-001 \
  --json
```

### 8.8 主 Agent 检查状态

主 Agent 通过：

```
statemng task list \
  --status running,completed,blocked,failed \
  --json
```

检查所有 subagent 的结果。

主 Agent 不需要依赖 subagent 的聊天消息作为唯一交接方式。

### 8.9 自动解锁综合任务

当 T-001、T-002、T-003 全部完成后，T-004 自动进入 `ready`。

主 Agent 再创建一个原生综合 subagent，让其领取 T-004。

综合 subagent 通过 CLI 读取三个前置任务的 artifact，形成最终报告。

## 九、Adapter 的正式定义

Adapter 是平台相关的 subagent 调用规范，不是独立运行时。实际实现可以采用平台专用指令或项目级 Agent 配置，必要时辅以宿主平台 hooks 和少量 bootstrap prompt 脚本。

Adapter 不得：

- 绕过 CLI 修改 JSON 事实源或自行定义另一套任务状态；
- 保存独立的研究历史或绕过 CLI 提交结果；
- 启动宿主 Agent 之外的模型进程。

## 十、持久化目录设计

*（需要后续详细设计。这里只提供初步参考，不以这里的设计为准。）*

项目内部按总体任务维护独立目录：

```
.state-management/
├── [TASK_NAME_1]/
│   ├── meta.json
│   ├── events/
│   │   ├── E-001.json
│   │   └── E-002.json
│   ├── tasks/
│   │   ├── T-001.json
│   │   └── T-002.json
│   ├── runs/
│   │   └── R-001/
│   │       ├── run.json
│   │       ├── logs/
│   │       │   └── L-001.json
│   │       └── workspace/
│   ├── artifacts/
│   │   ├── A-001.md
│   │   └── A-002.json
│   ├── .locks/
│   └── views/
│       ├── PROJECT_STATE.md
│       ├── TASK_BOARD.md
│       ├── DECISIONS.md
│       └── RESEARCH_LOG.md
└── [TASK_NAME_2]/
    └── ...
```

其中：

- `meta.json`：总体任务名称、目标和 schema 版本；
- `tasks/*.json`：内部任务、依赖、当前状态和运行结果，是任务状态的事实源；
- `runs/[RUN_ID]/run.json`：单次运行的身份、时间和结果记录；
- `events/*.json`：不可变的逐事件审计记录，不代替当前 JSON 状态；
- `artifacts/`：正式研究产物；
- `runs/[RUN_ID]/workspace/`：每次运行的隔离工作目录；
- `runs/[RUN_ID]/logs/*.json`：该次运行的逐条日志；
- `.locks/`：CLI 使用的任务级锁文件，不保存研究状态；
- `views/`：自动生成的人类可读状态文件。


每个 `[TASK_NAME]` 目录都是完整、自包含的状态单元，可以独立复制、归档或恢复。`.state-management/` 下不设置跨总体任务共享的可变状态。

## 十一、可靠性要求

### 11.1 原子任务领取

两个 subagent 同时领取同一任务时，只允许一个成功。CLI 应对稳定的 `.locks/T-xxx.lock` 加排他锁，在锁内重新读取和校验 `tasks/T-xxx.json`，并通过同目录临时文件、落盘和原子替换提交新状态。进程退出或断电后锁由操作系统释放。

### 11.2 幂等操作

同一个 `run_id` 重复提交相同 artifact 时，不应产生无限重复记录。

### 11.3 运行身份验证

只有持有当前 `run_id` 的 subagent 才能完成、阻塞或失败该任务。

`executor_ref` 只用于追踪执行实例，不能代替 `run_id` 进行状态更新，也不能用于多个派发。

### 11.4 非法退出处理

若 subagent 已退出但任务仍处于 `running`：

- 主 Agent 应检查状态；
- 将本次运行标记为异常；
- 根据任务属性重新设为 `ready` 或 `blocked`；
- 保留已有产物和日志。


由于 CLI 不直接管理 subagent 进程，异常退出检测主要由主 Agent 和 Adapter 负责；断电后的判断和清理遵循 6.15。

### 11.5 工作目录隔离

每个运行使用独立 workspace：

```
.state-management/[TASK_NAME]/runs/R-001/workspace/
```

多个 subagent 不应直接同时修改同一份关键文件。

正式结果通过 artifact 机制汇合。

### 11.6 防止死循环

自动重试及自动创建子任务必须设置次数、深度和数量上限。
