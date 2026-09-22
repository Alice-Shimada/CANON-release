# Codex Adapter

Codex reads the complete operating rules from the root `AGENTS.md`, loads the
shared skill from `.agents/skills/persistent-scientific-research/SKILL.md`, and
registers the `statemng` MCP server through `.codex/config.toml`. The project must
be trusted.

Codex Desktop may start MCP subprocesses from `/`, so `command`, `args`, and `cwd`
must not be relative to the project directory. The integrating agent must run
`state-management/adapters/codex/install_launcher.py` to atomically write a launcher
containing the current checkout's absolute MCP server path at:

```text
$HOME/.codex/statemng/CANON/mcp
```

This machine-local entry point stores no research state and is not committed to
the repository. After moving the checkout, changing the Python path, or switching
the primary checkout, the integrating agent must rerun the installer. Do not ask
the user to run internal commands.

Both the main agent and `persistent_research_worker` invoke this entry through
`/bin/sh` with these settings:

```toml
enabled = true
required = false
```

`required = false` only isolates MCP startup failures so that Codex sessions can
still be created and resumed. If tools are not exposed, the agent must still stop
persistent research and report the integration error. It must not fall back to
the CLI or bypass state management.

The main agent may use all `statemng` tools. Persistent research execution tasks
must be assigned only to the project custom agent `persistent_research_worker`,
passing the overall task name, internal task ID, and necessary research instructions.
Its `.codex/agents/persistent-research-worker.toml` uses an `enabled_tools` allowlist
of six tools. Do not replace it with a built-in subagent lacking this restriction.

A role-MCP configuration regression in Codex `0.149.0` causes workers to inherit
the main agent's complete tool surface. As a bounded fallback, the installed
launcher explicitly enables a Codex runtime guard. Before creating any worker,
the main agent must successfully call `init` or `resume`. Using `_meta.threadId`,
which the Codex host overrides and injects, the guard atomically binds a coordinator
in machine-local storage for the resolved checkout and overall task. Once bound,
the coordinator may call all tools; other threads may call only the six worker
tools. The MCP wrapper for `task_show` includes `codex_authorization`; a worker
must verify the guard, role, and task scope before starting research.

The coordinator lease lives under `$HOME/.codex/statemng/CANON/authorization/`.
It is not research state, is not committed to Git, and is not copied with an
overall task. Automatic takeover is prohibited. If a new main session needs to
take over, the main agent first confirms that no workers are active. After
obtaining user authorization, it uses the installer's `--show-coordinator TASK_NAME`
to check the old ID, then removes that exact binding with
`--reset-coordinator TASK_NAME --expected-thread-id UUID`. This operation writes
a machine-local audit log. The new main agent must then immediately call `resume`
to bind itself.

This fallback prevents accidental calls in normal Codex agent workflows; it is
not a security boundary against malicious processes on the same machine. Any local
process could still forge JSON-RPC or call the CLI directly. Reassess the guard
after upstream role-level MCP capability reduction is restored and verified in a
real Local session. Physical tool hiding remains the preferred layer.

Subagents only claim, read, execute, register artifacts, and submit, block, or
report failure. Only the main agent may review and accept results or reopen a
task after confirming that its blocking condition has been removed.

Create a separate subagent for each parallel task without exceeding the current
Codex session's concurrency limit. The main agent waits and checks the corresponding
task states. If a subagent exits abnormally while its task remains `running`, the
main agent inspects the workspace and artifacts, then records its decision through
the failure or block tool.

The initial implementation permits persistent research only in the Codex Local
session corresponding to the registered entry point. Before the first state call,
the main agent runs the installer's `--check` itself. If the entry is missing or
points to another checkout, the main agent reinstalls it and stops the current
persistent research until a fresh Local session reloads MCP. Worktree sessions
can still be created and used for other work, but must stop persistent research
and report an integration error.

After installation or configuration changes, verification in a fresh Local
session must show that: the session starts; `statemng` tools are exposed;
`statemng_project_list` can actually be called; the main agent's `init/resume`
binds the coordinator; and the worker's `task_show` reports a restricted role.
Even if main-only tools remain visible, their calls must be rejected before
reaching the CLI and leave state unchanged. Fault injection with a temporary MCP
configuration that cannot start must also confirm that the session remains usable
while persistent research is refused.

The adapter stores no research state and starts no agent processes outside Codex.
It stores only the machine-local, auditable Codex call-authorization records
specified above.
