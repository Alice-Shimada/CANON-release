# Hermes Adapter

主 Agent 使用 Hermes 当前会话提供的原生 subagent 机制创建 subagent，只传入总体任务名、内部任务 ID 和 `statemng` 协议。subagent 启动后依次执行 `task claim` 与 `task show`，结束前执行 `task submit`、`task block` 或 `task fail`。

并行任务由主 Agent 分别创建 subagent；同时运行数不得超过当前 Hermes 会话的原生并发限制。主 Agent 等待各 subagent 结束，并检查对应任务状态。若 subagent 异常退出且任务仍为 `running`，主 Agent 检查 workspace 和 artifact 后，通过 `task fail --retryable true` 或 `task block` 记录决定。

Adapter 不保存状态，也不启动 Hermes 之外的 Agent 进程。
