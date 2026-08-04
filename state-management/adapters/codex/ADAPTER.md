# Codex Adapter

Codex 从根目录 `AGENTS.md` 读取完整运行规则，从 `.agents/skills/persistent-scientific-research/SKILL.md` 加载公共 Skill，并通过 `.codex/config.toml` 注册项目内的 `state-management/mcp_server.py`。项目必须处于 trusted 状态；配置变更后使用全新会话验证加载结果。

主 Agent 可使用全部 `statemng` tools。持续研究的执行任务只能派发给项目级 custom agent `persistent_research_worker`，并只传入总体任务名、内部任务 ID 和必要的研究指令。该 agent 的 `.codex/agents/persistent-research-worker.toml` 在 tool 配置层禁止 `statemng_task_accept` 和 `statemng_task_unblock`；不得用未施加这一限制的内置 subagent 代替。

subagent 只负责领取、读取、执行、登记产物，并提交、阻塞或报告失败。只有主 Agent 可以审查并接受结果，也只有主 Agent 可以在确认阻塞条件解除后重新开放任务。

并行任务分别创建 subagent，且不超过 Codex 当前会话的并发限制。主 Agent 等待并检查相应任务状态；若 subagent 异常退出且任务仍为 `running`，主 Agent 检查 workspace 和 artifact 后，通过失败或阻塞 tool 记录决定。

Adapter 不保存状态，也不启动 Codex 之外的 Agent 进程。
