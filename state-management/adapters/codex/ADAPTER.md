# Codex Adapter

Codex 从根目录 `AGENTS.md` 读取完整运行规则，从 `.agents/skills/persistent-scientific-research/SKILL.md` 加载公共 Skill，并通过 `.codex/config.toml` 注册 `statemng` MCP server。项目必须处于 trusted 状态。

Codex Desktop 的 MCP 子进程可能从 `/` 启动，不能使用相对于项目目录的 `command`、`args` 或 `cwd`。接入 Agent 必须执行 `state-management/adapters/codex/install_launcher.py`，将当前 checkout 的绝对 MCP server 路径原子写入：

```text
$HOME/.codex/statemng/CANON/mcp
```

这是机器本地的启动入口，不保存研究状态，也不提交到仓库。checkout 移动、Python 路径变化或切换主要 checkout 后，接入 Agent 必须重新执行安装程序；不得要求用户执行内部命令。

主 Agent 和 `persistent_research_worker` 都使用 `/bin/sh` 调用该入口，并统一设置：

```toml
enabled = true
required = false
```

`required = false` 只隔离 MCP 启动故障，确保 Codex 会话仍可创建和恢复。若 tools 没有暴露，Agent 仍必须停止持续研究并报告接入错误，不得改用 CLI 或绕过状态管理。

主 Agent 可使用全部 `statemng` tools。持续研究的执行任务只能派发给项目级 custom agent `persistent_research_worker`，并只传入总体任务名、内部任务 ID 和必要的研究指令。该 agent 的 `.codex/agents/persistent-research-worker.toml` 使用六项 `enabled_tools` allowlist；不得用未施加这一限制的内置 subagent 代替。

Codex `0.149.0` 的 role-MCP 配置回归会使 worker 继承主 Agent 的完整 tool surface。作为有界 fallback，安装入口显式启用 Codex runtime guard：主 Agent 必须在创建任何 worker 前先成功调用 `init` 或 `resume`，以 Codex 宿主覆盖注入的 `_meta.threadId` 在机器本地、按 resolved checkout 与总体任务原子绑定 coordinator。绑定后 coordinator 可调用全部 tools，其他 thread 只允许六项 worker tools。`task_show` 的 MCP 包装结果包含 `codex_authorization`，worker 必须验证 guard、角色和 task scope 后才开始研究。

coordinator lease 位于 `$HOME/.codex/statemng/CANON/authorization/`，不属于研究状态，不进入 Git，也不随总体任务复制。它禁止自动抢占。新主会话确需接管时，主 Agent先确认没有活跃 worker，并在获得用户授权后用安装器的 `--show-coordinator TASK_NAME` 核对旧 ID，再以 `--reset-coordinator TASK_NAME --expected-thread-id UUID` 精确清理；操作会写入机器本地 audit log。随后必须由新主 Agent立即 `resume` 重绑。

该 fallback 只隔离正常 Codex agent 工作流中的误调用，不是同机恶意安全边界：任意本地进程仍可能伪造 JSON-RPC 或直接调用 CLI。上游恢复 role-level MCP capability reduction 并经真实 Local 验证后，应重新评估 guard；物理隐藏始终是首选层。

subagent 只负责领取、读取、执行、登记产物，并提交、阻塞或报告失败。只有主 Agent 可以审查并接受结果，也只有主 Agent 可以在确认阻塞条件解除后重新开放任务。

并行任务分别创建 subagent，且不超过 Codex 当前会话的并发限制。主 Agent 等待并检查相应任务状态；若 subagent 异常退出且任务仍为 `running`，主 Agent 检查 workspace 和 artifact 后，通过失败或阻塞 tool 记录决定。

初版只在已注册入口对应的 Codex Local 会话中执行持续研究。主 Agent 在首次状态调用前自行运行安装程序的 `--check`；若入口缺失或指向其他 checkout，主 Agent 重新安装入口并停止当前持续研究，待全新 Local 会话重新加载 MCP。Worktree 会话仍可正常创建和用于其他工作，但必须停止持续研究并报告接入错误。

安装或配置变化后，必须在全新 Local 会话中验证：会话可以启动；`statemng` tools 已暴露；`statemng_project_list` 可实际调用；主 Agent 的 `init/resume` 完成 coordinator 绑定；worker 的 `task_show` 报告受限角色；即使 main-only tools 仍可见，其调用也在 CLI 前被拒绝且状态不变。还必须用不可启动的临时 MCP 配置做故障注入，确认会话仍能启动而持续研究被拒绝。

Adapter 不保存研究状态，也不启动 Codex 之外的 Agent 进程；仅保存上述机器本地、可审计的 Codex 调用授权记录。
