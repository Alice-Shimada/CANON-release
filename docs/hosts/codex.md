# Codex host setup

This page documents the existing Codex adapter. The scientific components and
generic agent requirements are described in [Installation](../installation.md).

## Requirements

Use macOS or Linux, Python 3.10 or newer, and a checkout trusted by Codex. Persistent
research currently runs only in a **Local** session for the original checkout:
`.git` must be a directory, with Git's git-dir and common-dir both identifying
that checkout's `.git`. Worktree sessions remain usable for ordinary editing but
must not run persistent research or operate another checkout's state.

The repository's [.codex/config.toml](../../.codex/config.toml) registers the
server through a machine-local launcher. The adapter does not select a model;
model selection remains with the host.

## First setup

1. Open the repository in Codex Desktop and follow its project-trust prompt.
2. Create a Local session. A missing `statemng` launcher should not prevent the
   session itself from starting.
3. Give the agent the following request:

   ```text
   Prepare statemng Codex integration for this CANON checkout.
   Confirm this is a Local session and that .git is a directory, with git-dir
   and common-dir both identifying this checkout's .git.
   Run state-management/adapters/codex/install_launcher.py, then run it with
   --check to confirm that the launcher points to this checkout.
   Do not run the statemng CLI or create or change research state.
   Report the check result and whether a fresh Local session is needed.
   ```

4. If the host requires approval for the installer's machine-local writes, review
   the launcher and authorization-directory paths described below.
5. After installation, fully quit and reopen Codex Desktop, then create a fresh
   Local session in this repository. The old session does not hot-load its MCP
   tools after launcher installation.

The agent runs these commands from the repository root:

```sh
python3 state-management/adapters/codex/install_launcher.py
python3 state-management/adapters/codex/install_launcher.py --check
```

The installer writes the absolute checkout and Python paths into
`$HOME/.codex/statemng/CANON/mcp`, and prepares a checkout-specific authorization
directory under `$HOME/.codex/statemng/CANON/authorization/`. These are machine-local
adapter files; they are not research results and are not committed to Git. The
launcher serves one CANON checkout at a time for that user.

Both the main agent and the worker role use this registration:

```toml
[mcp_servers.statemng]
enabled = true
command = "/bin/sh"
args = ["-c", "exec \"$HOME/.codex/statemng/CANON/mcp\""]
required = false
default_tools_approval_mode = "writes"
```

The absolute launcher is necessary because Codex Desktop may start MCP processes
from `/`. `required = false` keeps a server startup problem from preventing the
Codex session from opening; unavailable tools still stop persistent research.

## Connection check

In the fresh Local session, ask:

```text
Check only the statemng MCP connection. Do not start research or change state.
Confirm this is a Local session, run
state-management/adapters/codex/install_launcher.py --check, and confirm
statemng_project_list is available on your MCP tool surface.
Call statemng_project_list through MCP once; do not substitute a shell command,
the statemng CLI, or a direct launch of mcp_server.py.
Report the launcher result and the complete structured MCP result.
```

A successful connection check means the session starts, launcher validation returns
`"ok": true`, the agent actually calls `statemng_project_list` through MCP, and
the result has `isError: false` with `structuredContent.ok: true`. An empty
`task_names` list is normal for a new checkout. Codex may display a namespaced
tool name such as `mcp__statemng__statemng_project_list`.

## Research and worker roles

After setup, describe the research goal in natural language. The main agent loads
the persistent-research skill and uses MCP for initialization, resumption,
dispatch, review, and acceptance. Research state lives in
`.state-management/[TASK_NAME]/`, which is excluded from Git.

Before its first state call, the main agent runs the launcher `--check`. It must
then successfully call `statemng_init` or `statemng_project_resume` before creating
workers, so the launcher-enabled guard can bind the coordinator for that overall
task. Use the project custom role `persistent_research_worker`, configured in
[persistent-research-worker.toml](../../.codex/agents/persistent-research-worker.toml).
Its state-tool allowlist contains only claim, show, artifact add, submit, block,
and fail. Only the main agent accepts results or reopens blocked tasks.

The adapter records a role-MCP regression in Codex `0.149.0`: workers can inherit
the main agent's visible tool surface. The existing runtime guard handles that
case using Codex's host-injected `_meta.threadId`. Before research, a worker must
read the `codex_authorization` returned by `task_show` and confirm an enforced
guard, `caller_role: "worker"`, the supplied overall task name, and the exact six
worker tools. Physical host-side filtering remains preferred. This guard is a
workflow isolation mechanism, not a boundary against malicious local processes.

The connection check above establishes tool access; it does not by itself test
the entire worker lifecycle. The [adapter notes](../../state-management/adapters/codex/ADAPTER.md)
describe the additional live checks needed after changing the integration,
including restricted worker calls and server-startup failure handling.

## Maintenance and recovery

When the checkout, Python path, or primary checkout changes, the agent reinstalls
and checks the launcher, then stops persistent research in that session until a
fresh Local session loads the configuration. If `--check` fails, the agent must
not use potentially stale MCP tools. If tools are unavailable, report the
integration error and stop research; do not bypass MCP with the CLI or edit
state JSON.

A coordinator binding is machine-local and is not copied with research artifacts.
For a deliberate handover to a new main session, the agent confirms that no worker
is active, obtains authorization for the handover, inspects the old binding with
`--show-coordinator TASK_NAME`, and resets only that binding with
`--reset-coordinator TASK_NAME --expected-thread-id UUID`. The installer records
the reset in its local audit log. The new main agent immediately resumes the task
through MCP to bind itself. See the adapter notes for this exceptional recovery
procedure; users do not need to run its internal commands.
