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

主 Agent 可使用全部 `statemng` tools。持续研究的执行任务只能派发给项目级 custom agent `persistent_research_worker`，并只传入总体任务名、内部任务 ID 和必要的研究指令。该 agent 的 `.codex/agents/persistent-research-worker.toml` 在 tool 配置层禁止 `statemng_task_accept` 和 `statemng_task_unblock`；不得用未施加这一限制的内置 subagent 代替。

subagent 只负责领取、读取、执行、登记产物，并提交、阻塞或报告失败。只有主 Agent 可以审查并接受结果，也只有主 Agent 可以在确认阻塞条件解除后重新开放任务。

并行任务分别创建 subagent，且不超过 Codex 当前会话的并发限制。主 Agent 等待并检查相应任务状态；若 subagent 异常退出且任务仍为 `running`，主 Agent 检查 workspace 和 artifact 后，通过失败或阻塞 tool 记录决定。

初版只在已注册入口对应的 Codex Local 会话中执行持续研究。主 Agent 在首次状态调用前自行运行安装程序的 `--check`；若入口缺失或指向其他 checkout，主 Agent 重新安装入口并停止当前持续研究，待全新 Local 会话重新加载 MCP。Worktree 会话仍可正常创建和用于其他工作，但必须停止持续研究并报告接入错误。

安装或配置变化后，必须在全新 Local 会话中验证：会话可以启动；`statemng` tools 已暴露；`statemng_project_list` 可实际调用；worker 看不到 `statemng_task_accept` 和 `statemng_task_unblock`。还必须用不可启动的临时 MCP 配置做故障注入，确认会话仍能启动而持续研究被拒绝。

Adapter 不保存状态，也不启动 Codex 之外的 Agent 进程。
