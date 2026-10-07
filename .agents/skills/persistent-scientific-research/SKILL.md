---
name: persistent-scientific-research
description: Use for multi-step scientific research in CANON, including master-integral differential equations, UT bases, canonical forms, and epsilon forms.
---

# Persistent Scientific Research

The scientific workflow is independent of the host and model. Use
[`canon-workflow`](../../../skills/canon-workflow/SKILL.md) to choose the next
scientific step and interpret results, and
[`docs/agent-workflow.md`](../../../docs/agent-workflow.md) to prepare inputs.
Host setup is described in
[`docs/installation.md`](../../../docs/installation.md); Codex-specific rules below
apply only in Codex. Documentation and packaging of user-selected historical
examples do not start a research run or require their scientific checks to be repeated.

Use the `statemng` MCP tools for every state operation. Never ask the user to run the internal CLI. If these tools are unavailable, stop and report the integration error.

In Codex, run persistent research only in a Local session. If the current session is a Worktree, stop and report the adapter error; do not operate state in another checkout. The MCP server is non-required only to keep the Codex session usable after an integration failure, never as permission to bypass state management.

Follow the `Overall architecture` protocol in the applicable root `AGENTS.md` or
`CLAUDE.md`.

Resolve scripts and `external/` from the current checkout. Read `external/README.md`
for installation and path semantics; pass installed tool entries, executable paths
and thread budgets in the task context. Do not assume a personal installation tree,
platform, or core count. Select candidate methods from the family geometry and
current evidence. When using DlogBasis-refine, record its declared package
revision plus actual file hash; an outer CANON Git HEAD is not a dependency
revision. External directories hold source for user installation, not
ready-built dependencies. Distribution preparation does not compile packages or copy
foundation libraries or machine launchers. Include research outputs only when the
user selects them for examples or delivery, retaining their original evidence scope.

Use returned paths verbatim; `task_name` is an identifier, not an installation
directory. Path bases differ between the state tools and scientific scripts:

| Value | Base or use |
| --- | --- |
| `task_show.workspace` | Absolute write directory for this run. |
| Dependency `stored_path` | Relative to `task_show.project_root`. |
| `artifact_add.path`, `task_submit.summary_file`, `task_fail/task_block.reason_file` | Absolute file within the overall task directory, or relative to that task directory. Using the returned workspace gives an unambiguous absolute path. |
| WLS input artifact `path` and `method_options.package_entry` | Relative to the JSON input file that declares them, unless absolute. |
| Installed package/executable entries | Use the declared runtime configuration, including any container-to-host path mapping. |

After a missing-file error, compare the exact attempted path with these values
in the process that opens it. A container alias need not exist on the host.
Correct the path before retrying; failed `Get` or unevaluated expressions provide
no scientific evidence. A missing path alone is not evidence of a broken mount
or a reason to copy packages or rebuild the environment.

## Main Agent

1. In Codex, before the first state call, internally run `state-management/adapters/codex/install_launcher.py --check`. If it fails, reinstall the launcher, stop the current research, and require a new Local session; never use tools that may target another checkout or ask the user to run the installer. The main Agent must successfully call `init` or `resume` before creating any worker so the runtime guard can bind the coordinator.
2. Determine one unambiguous overall `task_name`. If none is clear, call `statemng_project_list` and ask the user to choose; do not guess between existing tasks.
3. Call `statemng_init` for a new overall task or `statemng_project_resume` for an existing one.
4. Before creating a task, apply the completion rule in `canon-workflow`. A matching FINAL_CHECK ALL_PASS needs review, acceptance and delivery, not another scientific worker. Otherwise create only necessary subtasks. Write `objective` and `background` as strings, `acceptance_criteria` as an array of nonempty strings, and optional `required_skills` as an array of repository-relative `SKILL.md` paths. Criteria specify the result and required checks, not a new provenance or replay pipeline. List shared input producers and the latest needed result directly in `depends_on`; omit that tool argument when there are no dependencies, rather than passing an empty string. Do not add fields for scheduling priority or unrelated context.
5. Dispatch each ready subtask through the host's native worker with the six worker tools specified below, passing the overall task name, task ID, and necessary research instructions. In Codex, use only the project `persistent_research_worker` custom agent, not an unrestricted built-in worker. Other hosts use their own role names and enforce the same tool boundary.
6. Review the submitted inputs, checker results, and artifacts against the acceptance criteria. Existing independent scientific checkers provide the required mathematical verification. Additional replay or a verification worker needs a specific unresolved question, changed input/implementation, or user request; do not repeat a successful unchanged pipeline merely for main-Agent review. Accept once the criteria are met.
7. Alone call `statemng_task_accept` after successful review. Alone call `statemng_task_unblock` after confirming that a recorded blocking condition has actually been removed.
8. Replan from accepted evidence until the overall research goal is satisfied or an external block must be reported. Review a failed attempt's counterexample against its input and transformation convention; carry its scope into the next task's `background`. A continuation of a refuted ansatz requires a changed hypothesis or input. The result describes that ansatz within its stated bounds.

For a family-based integral-basis search, follow the evidence-based choices in
the [core-selection skill](../../../skills/canon-search-core/SKILL.md). Assign a
small dot/normalization bundle, a justified Gram construction, or a bounded
DlogBasis search as appropriate, and supply the selected card. DlogBasis is not
a prerequisite for the other choices. If the later bridge needs derivative
preparation, assign it with the saved candidates and the IBP skill. Proposal
inputs and candidate derivative inputs belong to separate operations. Carry
tested hypotheses, exact bounds and failures into subsequent assignments;
method restrictions come from the user and the applicable input contracts.

After each handoff, apply the main route to current evidence before dispatching.
If the requested scope passed FINAL_CHECK, complete review, acceptance and
delivery, then stop that scope. If science remains unresolved, carry its exact
gate, existing results and available methods into the continuation. Evaluate the
next method against the overall goal and current evidence.

For an obstruction claim, review the exact transformation class and every
hypothesis of the claimed implication using
[core selection](../../../skills/canon-search-core/SKILL.md#scope-of-an-obstruction).
Repeated IBP agreement or recomputation of an epsilon-zero residue is not an
independent proof of nonexistence. Default gauges may be singular at epsilon=0;
a matching checked core is a positive witness and takes precedence over an
informal negative diagnostic. Do not accept a finite-ansatz failure as a global
no-go certificate. Reserve `blocked` for an identified external condition;
algorithm exhaustion instead returns its bounds and next changed hypothesis.

In a continuation task, include the last result code/reason (or absence of a new
result), exact input/job references, and the changed hypothesis or operational
setting in `background`. Carry the applicable absolute deadline with timezone,
remaining time calculated from the current clock, other resource limits,
per-stage execution caps and their owning layers, and cancellation/collection
reserve; do not reset them at a handoff.
Give the worker the applicable step skill and method card. If the user supplied
components, also pass the complete ordered component selection, the selected
entry's instructions and any package workflow reported by `--describe`.
Invoke each scientific step through `run_step.py --components PATH` (repeat the
flag to compose packages);
the custom module's method instructions supersede the built-in method for that
entry, while the public scientific artifact and acceptance contracts still apply.
This task description
and its input references provide the scientific context for the continuation.

Before launch/resume or declaring a deadline reached, apply the
[execution budget and recovery rules](../../../skills/canon-workflow/SKILL.md#6-execution-budgets-and-operational-recovery).
At the applicable computation stop time, cancel through the owning host, confirm
native/bridged process closure and collect the last saved evidence. Accepted
diagnostic or partial tasks retain that limited scope; the coordinator still
routes unresolved authorized work from current evidence and remaining resources.

## Execution Subagent

1. Receive an explicit overall task name and task ID; do not infer another task.
2. Call `statemng_task_claim`, then `statemng_task_show` with the returned run ID.
   For an explicitly assigned continuation of an already running detached job,
   use the supplied existing run ID in `task_show` without claiming again.
3. In Codex, inspect the `codex_authorization` returned by `task_show` before beginning research. It must report an enforced runtime guard, `caller_role=worker`, the supplied overall task name, and the exact six worker tools; otherwise stop and report the adapter error. Host-side physical tool filtering remains preferred, but tool visibility alone is not an error on affected Codex versions. In other hosts, use that host's native permission contract; `codex_authorization` is neither required nor expected.
4. After `task_show` and before beginning research, read every `SKILL.md` listed in `required_skills` completely, in the supplied order. If the field is absent or empty, no additional skill is required.
5. Write only in the returned run workspace. Read the needed accepted dependency files in place using `project_root / dependencies[].artifacts[].stored_path`; retain their registered IDs and hashes. Use only the objective, background, acceptance criteria, required skills, and accepted dependency results supplied by `task_show`. Extract only needed members of an existing archive, not its whole dependency tree.
6. Register each new or changed deliverable file separately with `statemng_artifact_add`. Submit one entry artifact, which may index those files and existing dependency references. Do not embed predecessor archives, workspaces, or unchanged shared inputs. The overall task is self-contained; each run is not a standalone archive. A new canonical prefix still contains the complete cumulative mathematical result. Finish with exactly one of `statemng_task_submit`, `statemng_task_block`, or `statemng_task_fail` as soon as the task's result is ready. If an explicitly selected local execution component has detached the computation, first register its immutable job/watch handles and return `DEFERRED` with the task ID and run ID. The task stays `running` until the coordinator resumes this run and its result is collected. This exception does not mark launch or notification as scientific completion.
7. Never accept a task or unblock it. If either tool is visible, do not call it; the verified runtime guard must reject it before the CLI.

Do not use `workflow.py`.

Completion notifications target the bound coordinator session. The coordinator
reads the event, checks it still refers to the current run, and resumes collection
once. Preserve the existing job rather than resubmitting on every wakeup. A
replacement worker must be assigned the same task/run only after the previous
worker is inactive. All scientific review, acceptance, failure and unblock
operations still use the state MCP tools; the monitor does not perform them.
