# Agent integration supplement for persistent-research state management

> Historical scope: this document preserves an earlier integration design,
> including proposed host support and the requirement to copy protocol text
> verbatim. It is not evidence that those integrations are implemented, nor does
> it govern active work. Follow [the current agent workflow](../agent-workflow.md),
> [installation guide](../installation.md), and current skills for active use.

## 1. Purpose

This supplements the *Design for persistent-research state-management
infrastructure across general-purpose agents* with an agent integration layer.
It does not change the fields, states, commands, or operating rules established
by the base design.

The goal is:

> Users state scientific questions in natural language. Codex, OpenCode, Claude
> Code, and Hermes automatically discover the state-management capability and use
> it internally through tool calling. Users do not need to know that the state
> machine or CLI exists.

## 2. Core structure

```text
User's natural-language request
        ↓
Host agent's rule and skill entry points
        ↓
Local statemng MCP server
        ↓
Existing statemng CLI
        ↓
Existing JSON state directory
```

The four hosts share one skill protocol and MCP server. Host adapters handle only
automatic discovery, registration, and necessary call-permission restrictions;
they neither store research state nor implement state transitions. Machine-local
adapter authorization records are not task/run/artifact sources of truth.

## 3. Rules and skill

### 3.1 Rule entry points

The root `AGENTS.md` is for Codex, OpenCode, and Hermes; the root `CLAUDE.md` is for
Claude Code. Both files must contain these entry rules:

1. Multi-step scientific research tasks must load the `persistent-scientific-research` skill;
2. Users interact only with the main agent and must not be asked to run the internal CLI;
3. All state operations must use the project's `statemng` tools;
4. Only the main agent may call `task accept` and `task unblock`; subagents may not;
5. When creating subagents, the main agent must first use the host's native tool permissions or restrictions to prohibit `statemng_task_accept` and `statemng_task_unblock`. If the host version is confirmed unable to apply that restriction, only an explicitly defined, runtime-verifiable, fail-closed compatibility guard from that host's adapter is permitted;
6. If tools are unavailable, stop and report an integration error; do not bypass state management to continue research;
7. Do not use the deleted `workflow.py`.

In addition to these rules, both files must reproduce the entire *Design for
persistent-research state-management infrastructure across general-purpose agents*
section beginning at `## 4. Overall architecture` and ending just before
`## 5. Main components`, verbatim. The headings, prose, Mermaid diagram, directory
structure, collaboration loop, and task state model must not be shortened,
rewritten, or separately summarized. Whenever that section of the base design
changes, the copies in both files must be updated to remain exactly identical
to the base text.

### 3.2 Shared skill

The shared skill is located at:

```text
.agents/skills/persistent-scientific-research/SKILL.md
```

Its frontmatter is:

```yaml
---
name: persistent-scientific-research
description: Use for multi-step scientific research in CANON, including master-integral differential equations, UT bases, canonical forms, and epsilon forms.
---
```

The body specifies:

- Which scientific requests need state management;
- Mandatory use of the `statemng` MCP tools;
- That users must not be asked to run internal tools;
- That state operations follow the complete `## 4. Overall architecture` section included in `AGENTS.md` or `CLAUDE.md`;
- That the main agent reviews results and exclusively calls `statemng_task_accept` and `statemng_task_unblock`;
- That subagents only claim, read, execute, register artifacts, and submit, block, or report failure; they may neither accept tasks nor unblock them;
- That the main agent must prohibit subagents from calling those two exclusive tools when creating them;
- That work must stop if tools are unavailable.

Codex and OpenCode discover this skill directly. Claude Code's
`.claude/skills/persistent-scientific-research/SKILL.md` contains only the same
frontmatter and an instruction to read the shared skill above, without copying
its protocol. Hermes loads `.agents/skills/` through `skills.external_dirs`.

## 4. MCP tool-calling interface

### 4.1 MCP server

Add:

```text
state-management/mcp_server.py
```

The service runs locally over STDIO and needs no network, authentication, or
remote service. It performs only these conversions:

1. Receive structured tool parameters;
2. Convert them into the corresponding `statemng` CLI call;
3. Execute it at the repository root;
4. Parse the CLI's JSON response;
5. Return the result unchanged to the agent.

The MCP server neither reads/writes state files directly nor reimplements state
transitions.

### 4.2 Tool mapping

Each existing CLI command maps to one MCP tool. Its name is `statemng_` followed
by the command path with levels joined by `_`, for example:

```text
project list  -> statemng_project_list
task create   -> statemng_task_create
artifact add  -> statemng_artifact_add
task submit   -> statemng_task_submit
task unblock  -> statemng_task_unblock
```

Expose all existing commands under the same rule, with these conditions:

- Parameters match the corresponding CLI parameters;
- Return values use the CLI's original JSON;
- A nonzero CLI exit makes the tool return failure;
- No combined commands, automatic commands, or new state operations are added;
- Read-only tools set `readOnlyHint: true`; state-changing tools set `readOnlyHint: false`.

### 4.3 Repository root

After startup, the MCP server determines the repository root from its own path:

```text
CANON/state-management/mcp_server.py
             ↓
CANON/
```

Do not add a `project_root` parameter or depend on the agent's current
subdirectory. The host still needs a definite path to locate and start the
server; server self-location does not solve the host's problem of resolving a
relative launch path from an arbitrary working directory.

## 5. Host integration

| Host | Rule entry | Skill entry | MCP registration |
|---|---|---|---|
| Codex | `AGENTS.md` | `.agents/skills/` | `.codex/config.toml` |
| OpenCode | `AGENTS.md` | `.agents/skills/` | `opencode.json` |
| Claude Code | `CLAUDE.md` | Thin entry in `.claude/skills/` | `.mcp.json` |
| Hermes | `AGENTS.md` | `skills.external_dirs` points to `.agents/skills/` | `~/.hermes/config.yaml` |

All hosts ultimately start the same `state-management/mcp_server.py`; do not add
host-specific MCP implementations. A host adapter may add a stateless,
machine-local launch entry to map repository configuration to the absolute server
path on the current machine.

The main agent may use all `statemng` tools. When creating subagents, each host
must first use its native tool permissions or restrictions to prohibit at least
`statemng_task_accept` and `statemng_task_unblock`; do not rely only on subagents
to respect role boundaries voluntarily. If a particular host version is known
unable to apply role-level tool restrictions, the same MCP facade may authorize
calls in a mode explicitly enabled by that host's launcher. It must preserve the
generic launch mode, CLI, and research schema and expose runtime authorization
results that agents can check.

OpenCode and Claude Code use repository-level configuration. OpenCode sets
`codemode: false` for this server so tools are exposed directly to the agent.
Hosts may add a server namespace to display names, but MCP tool protocol names
remain unchanged.

### 5.1 Codex

Codex declares the server in repository-level `.codex/config.toml` without a
checkout-relative path in that configuration. The integration agent runs
`state-management/adapters/codex/install_launcher.py` to atomically install a
machine-local entry at `$HOME/.codex/statemng/CANON/mcp`. The entry records absolute
paths to the current checkout's `state-management/mcp_server.py` and an executable
Python. This file stores no research state and is not version-controlled. The
integration agent reinstalls it when the checkout or Python path changes; users
must not be asked to do so.

The main agent and `persistent_research_worker` both invoke that entry through
`/bin/sh`, set `enabled = true` and `required = false`, and leave `cwd` unset.
`required = false` preserves session availability: Codex sessions can still be
created and resumed after an MCP startup failure. Rules and the skill nevertheless
require an immediate stop to persistent research and an integration-error report
if tools are unavailable; bypassing state management is never allowed. Worker
configuration uses a six-item `enabled_tools` allowlist. For Codex versions
affected by the role-MCP configuration regression, the launcher also explicitly
enables a coordinator runtime guard: the main agent binds the overall task with
`init/resume` before creating any worker; a different Codex `threadId` is allowed
only the six worker tools. Binding records are stored per checkout/task in a
machine-local `0700` adapter directory, outside `.state-management` and Git;
automatic takeover is forbidden.

The first version permits persistent research only in the Codex Local session
registered by the machine-local entry. Before its first state call, the main
agent runs the installer's `--check` itself. If the entry is missing or points to
another checkout, the main agent reinstalls it and stops current persistent
research until a fresh Local session reloads MCP. Worktree sessions can start
normally and handle other work, but may not run persistent research. Worktree
support requires a host mechanism that selects the entry according to the
session's checkout first.

Codex integration must pass five verification layers: static configuration
validation; launch from `/` followed by MCP initialize, tools/list, and a read-only
tool call; guard tests for first binding, cross-thread rejection, process restart,
and explicit takeover; confirmation of actual main-agent/worker `threadId`
isolation in a fresh Local session; and a temporary MCP configuration that cannot
start, confirming that the session still starts after server failure. Repeat
verification whenever the configuration or entry changes.

Hermes requires a one-time registration of MCP and the external skill directory
in host configuration. This machine-specific configuration is not stored in the
repository. After registration, users still only state tasks in natural language.

Integration changes must be verified in a fresh session for each host, confirming
that rules and skills load and every MCP tool can be called. When a host requires
project trust or configuration confirmation, use its native confirmation mechanism;
do not bypass it.

## 6. Changes to existing documentation

### 6.1 `README.md`

Remove or replace every description of the old `workflow.py`, retaining only:

- Users give scientific objectives directly to the agent;
- The agent automatically uses the project's internal persistent-research infrastructure;
- Users do not need to call the state-management CLI;
- The locations of the two state-management design documents.

### 6.2 Adapters

Retain and update:

```text
state-management/adapters/codex/ADAPTER.md
state-management/adapters/opencode/ADAPTER.md
state-management/adapters/claude-code/ADAPTER.md
state-management/adapters/hermes/ADAPTER.md
```

Each adapter describes only how its host discovers rules, loads the skill,
registers the same MCP server, and prohibits subagents created by the main agent
from calling `statemng_task_accept` and `statemng_task_unblock`. The Codex adapter
must also describe the machine-local entry, session-availability boundary, Local
restriction, conditional runtime guard, explicit takeover, and host-level
verification. Adapters do not duplicate the CLI protocol or state-machine flow,
but must state explicitly that only the main agent may accept and unblock tasks;
subagents may only submit, block, or report failure.

## 7. File layout

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

State-management code and tests remain together in `state-management/`. The
repository root and host directories contain only the rules, skill entry points,
and configuration needed for automatic discovery.
