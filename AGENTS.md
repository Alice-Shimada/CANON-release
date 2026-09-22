# CANON Agent Rules

CANON's scientific interfaces and method cards are independent of the agent host
and model. Start with [canon-workflow](skills/canon-workflow/SKILL.md) to choose
the next scientific action. Use [docs/agent-workflow.md](docs/agent-workflow.md)
for input preparation and [docs/installation.md](docs/installation.md) for the host capability
contract. Codex-specific setup is in [docs/hosts/codex.md](docs/hosts/codex.md).
Documentation and packaging of selected historical examples do not initiate new
scientific research or require replay.

For integral-basis discovery from a defined family (UT or canonical), run a
bounded DlogBasis-refine candidate search first on unresolved sectors, following
the exact exceptions in [core selection](skills/canon-search-core/SKILL.md).
The proposal requires family and provider inputs. Candidate derivative data,
including `exact_strategy`, are prepared for the subsequent IBP bridge. This
priority also applies when a rational DE is available. The user's scope and
current evidence govern method selection across worker assignments; finite
search bounds are sufficient.

Check completion before selecting methods or creating workers. Matching
FINAL_CHECK `PASS/ALL_PASS` ends scientific work for that scope: submit, review,
accept and deliver. Further scientific work requires an unresolved requested
scope or changed inputs. See the scope and handoff rules in the workflow entry.

## Persistent research access

1. Load `persistent-scientific-research` for multi-step scientific research.
2. The user interacts with the main agent. Never ask the user to operate the
   internal state CLI.
3. Use the project's `statemng` MCP tools for every state operation.
4. Only the main agent may call `statemng_task_accept` or `statemng_task_unblock`.
5. In Codex, dispatch persistent research only through the project's
   `persistent_research_worker` custom agent, restricted to the six worker tools.
   When host-side tool filtering is unavailable, the launcher
   runtime guard must already be bound by the main agent's `init` or `resume`,
   and the worker must verify its restricted role in `task_show` before research.
   Other hosts use native subagents with the same six-tool state boundary; they
   need neither the Codex role name nor its authorization fields.
6. If `statemng` tools are unavailable, stop research and report the integration
   error. Do not bypass state management.
7. Do not use the removed `workflow.py`.
8. The current Codex adapter supports Local sessions. In a Worktree session,
   stop persistent research and report the integration error; do not operate
   another checkout's state directory.
9. Before its first state call, the Codex main agent must run
   `state-management/adapters/codex/install_launcher.py --check`. If it fails,
   install the launcher internally and stop the current research until a new
   Local session loads the MCP configuration. Do not use tools that may point
   to another checkout or ask the user to install it. After a successful check,
   call `init` or `resume` before creating workers to bind the coordinator.

## Distribution and paths

Resolve repository scripts and `external/` source from the current checkout.
Read installed tool entries, executables and thread budgets from task parameters,
the environment or Wolfram configuration. Do not hardcode personal directories
or platform constants. See [README.md](README.md) and
[external/README.md](external/README.md) for configuration fields.

Use `external/DlogBasis-refine` or the caller's declared installation of that
package. Record its declared revision and source hash; the outer CANON Git HEAD
is not the dependency revision.

Distribute external packages as separate source snapshots with their provenance
and licenses. Distribution preparation does not compile dependencies or copy
local binaries, foundation libraries, research run directories or machine-local
launchers. Task descriptions give the required entries, resource budget and path
bases; workers use that installation configuration directly.

## Overall architecture

One local CLI stores independent overall research tasks. The MCP tools expose
that CLI to the coordinator and workers. The host creates and runs subagents;
the state manager records work and does not choose scientific methods.

```mermaid
flowchart TD
    U["User supplies the scientific goal"] --> M["Main agent"]
    M --> N{"Overall task name is clear?"}
    N -- "No" --> LIST["project list, then ask the user"]
    LIST --> I{"Task exists?"}
    N -- "Yes" --> I
    I -- "No" --> INIT["init with the goal file"]
    I -- "Yes" --> RESUME["project resume"]
    INIT --> PLAN["Plan necessary tasks and direct dependencies"]
    RESUME --> INSPECT["Inspect unfinished runs and retained artifacts"]
    INSPECT --> PLAN
    PLAN --> READY["task ready"]
    READY --> SPAWN["Create a native worker with task name and task ID"]
    SPAWN --> CLAIM["Worker: claim, then show"]
    CLAIM --> RESEARCH["Read dependencies; write new results in the workspace"]
    RESEARCH --> ART["artifact add for each new result"]
    ART --> SUBMIT["task submit with one entry artifact"]
    SUBMIT --> REVIEW["Main agent reviews inputs, checks and criteria"]
    REVIEW -- "Specific verification gap" --> VERIFY["Bounded verification worker"]
    VERIFY --> REVIEW
    REVIEW -- "Accepted" --> ACCEPT["task accept"]
    ACCEPT --> VIEW["Unlock dependencies and rebuild the state view"]
    VIEW --> PLAN
    REVIEW -- "Rejected" --> FAIL["task fail"]
    RESEARCH -- "Attempt failed" --> FAIL
    FAIL --> PLAN
    REVIEW -- "External condition needed" --> BLOCK["task block"]
    RESEARCH -- "External condition needed" --> BLOCK
    BLOCK --> WAIT["Wait for the recorded condition"]
    WAIT --> UNBLOCK["Main agent confirms resolution and unblocks"]
    UNBLOCK --> PLAN
    PLAN -- "Goal met" --> REPORT["Report the checked result"]
```

Every task-scoped call carries the same explicit `task_name`. A task JSON status
of `completed` is the completion fact; dependency readiness and Markdown views
are derived from it.

### Storage and artifact handoff

```text
.state-management/<task-name>/
  meta.json                  Overall goal and schema version
  tasks/T-001.json            Task, dependencies, state and accepted run
  runs/R-001/run.json         Run identity, timing and result
  runs/R-001/workspace/       Writable area for that run
  artifacts/                 Registered immutable result files
  .locks/                    Task-level locks, not research state
  views/PROJECT_STATE.md     Rebuildable state summary
```

An overall task directory is the self-contained unit for recovery or migration.
Individual runs reuse earlier artifacts by reference. There is no shared mutable
scientific state across overall task directories.

- The workspace limits writes. Read the needed dependency artifacts directly at
  `project_root / dependencies[].artifacts[].stored_path` from `task_show`.
  Copy only an input that the tool actually needs to modify.
- List shared input producers and the latest needed result directly in
  `depends_on`. A sector task can depend on the original DE/rules producers and
  the latest accepted prefix; do not pass them through nested historical bundles.
- Register each new or changed result separately. `task_submit` names one entry
  artifact, optionally a short index. Keep unchanged DEs, rules, source, tools and
  historical artifacts under their existing references and registered hashes.
  Do not copy, repack or rescan whole dependency trees.
- A new accepted prefix still contains its complete cumulative transformation,
  basis and matrices, including lower-sector normalization. Do not embed old
  prefix bundles, run workspaces or dependency archives. Extract only needed
  members of existing archives. Full archives are for explicit delivery or
  migration needs.
- Run the existing necessary scientific gates on changed candidates and
  prefixes. Main-agent review checks inputs, checker results and acceptance
  criteria. `CHECK_CORE`, `CHECK_CANONICAL` and `FINAL_CHECK` already provide
  independent mathematical verification. Additional clean replay, candidate
  bridging, IBP or family reruns require a concrete failure, changed input or
  implementation, or a user request.
- Submit, review and accept when the criteria are met. A further verification
  task must name a specific unresolved question. Provenance or packaging alone
  is not a reason to delay accepted scientific progress.

### Coordinator and worker loop

1. Determine one overall task name. Reuse the name already selected by the user.
   If it remains ambiguous, list existing tasks and ask the user to choose.
   Initialize a new task or resume an existing one, then create necessary work.
2. Query ready tasks and dispatch native workers with the overall task name and
   task ID. Supply required skills, input references and the resource budget.
3. Each worker claims and shows its task, reads dependencies in place and writes
   new results in its workspace. It registers new artifacts and submits them,
   or records a concrete failure or external block.
4. The main agent reviews the result. Use a separate verification worker only
   for a specific unresolved issue; that worker submits evidence and never
   accepts the original task.
5. The main agent accepts a result when its criteria are met. Only a completed
   task satisfies dependencies.
6. A blocked task returns to ready only after the main agent confirms the
   recorded external condition has been resolved and calls `unblock`.
7. Continue or revise the plan from accepted evidence. A failed method or ansatz
   is not a proof that the scientific goal is impossible.

### Task states

```text
pending -> ready -> running -> submitted -> completed
```

| State | Meaning |
|---|---|
| `pending` | Dependencies are not yet completed. |
| `ready` | A worker can claim the task. |
| `running` | A worker has claimed the task and owns the current run. |
| `submitted` | The run awaits main-agent review. |
| `completed` | The main agent accepted the run and its artifacts. |
| `blocked` | A recorded external condition must be resolved. |
| `failed` | The attempt failed without an immediate retry. |

Running or submitted tasks may become blocked. Main-agent `unblock` returns a
blocked task to ready. A failed run with `retryable: true` makes its task ready;
otherwise the task becomes failed. Only the state tools, through the CLI, change
these states.
