# Hermes Adapter

The main agent creates subagents through the native mechanism supplied by the
current Hermes session, passing only the overall task name, internal task ID, and
`statemng` protocol. Each subagent calls `task claim` and then `task show` after
starting, and finishes with `task submit`, `task block`, or `task fail`.

The main agent creates a separate subagent for each parallel task. The number
running concurrently must not exceed the native limit of the current Hermes
session. The main agent waits for subagents to finish and checks the corresponding
task states. If a subagent exits abnormally while its task remains `running`, the
main agent inspects the workspace and artifacts, then records its decision through
`task fail --retryable true` or `task block`.

The adapter stores no state and starts no agent processes outside Hermes.
