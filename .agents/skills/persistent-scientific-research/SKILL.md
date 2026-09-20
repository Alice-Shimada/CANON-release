---
name: persistent-scientific-research
description: Use for multi-step scientific research in CANON, including master-integral differential equations, UT bases, canonical forms, and epsilon forms.
---

# Persistent Scientific Research

The scientific workflow is independent of the host and model. Use
[`docs/agent-workflow.md`](../../../docs/agent-workflow.md) to prepare inputs,
choose the next scientific step, and interpret results. Host setup is described in
[`docs/installation.md`](../../../docs/installation.md); Codex-specific rules below
apply only in Codex. Documentation and packaging of user-selected historical
examples do not start a research run or require their scientific checks to be repeated.

Use the `statemng` MCP tools for every state operation. Never ask the user to run the internal CLI. If these tools are unavailable, stop and report the integration error.

In Codex, run persistent research only in a Local session. If the current session is a Worktree, stop and report the adapter error; do not operate state in another checkout. The MCP server is non-required only to keep the Codex session usable after an integration failure, never as permission to bypass state management.

Follow the complete `## 四、整体架构` protocol in the applicable root `AGENTS.md` or `CLAUDE.md`.

Resolve scripts and `external/` from the current checkout. Read `external/README.md`
for installation and path semantics; pass installed tool entries, executable paths
and thread budgets in the task context. Do not assume a personal installation tree,
platform, or core count. Use DlogBasis-refine for candidate proposals and record the
declared package revision plus actual file hash; an outer CANON Git HEAD is not a
dependency revision. External directories hold source for user installation, not
ready-built dependencies. Distribution preparation does not compile packages or copy
foundation libraries or machine launchers. Include research outputs only when the
user selects them for examples or delivery, retaining their original evidence scope.

## Main Agent

1. In Codex, before the first state call, internally run `state-management/adapters/codex/install_launcher.py --check`. If it fails, reinstall the launcher, stop the current research, and require a new Local session; never use tools that may target another checkout or ask the user to run the installer. The main Agent must successfully call `init` or `resume` before creating any worker so the runtime guard can bind the coordinator.
2. Determine one unambiguous overall `task_name`. If none is clear, call `statemng_project_list` and ask the user to choose; do not guess between existing tasks.
3. Call `statemng_init` for a new overall task or `statemng_project_resume` for an existing one.
4. Create only necessary subtasks. Write each description as JSON containing `objective`, `background`, and `acceptance_criteria`; when the task requires repository skills, also add the optional `required_skills` array with each repository-relative `SKILL.md` path. Criteria specify the result and required checks, not a new provenance or replay pipeline. List shared input producers and the latest needed result directly in `depends_on`, so workers can reuse their artifacts in place. Do not place priority or unrelated context in the description.
5. Dispatch each ready subtask through the host's native worker with the six worker tools specified below, passing the overall task name, task ID, and necessary research instructions. In Codex, use only the project `persistent_research_worker` custom agent, not an unrestricted built-in worker. Other hosts use their own role names and enforce the same tool boundary.
6. Review the submitted inputs, checker results, and artifacts against the acceptance criteria. Existing independent scientific checkers provide the required mathematical verification. Additional replay or a verification worker needs a specific unresolved question, changed input/implementation, or user request; do not repeat a successful unchanged pipeline merely for main-Agent review. Accept once the criteria are met.
7. Alone call `statemng_task_accept` after successful review. Alone call `statemng_task_unblock` after confirming that a recorded blocking condition has actually been removed.
8. Replan from accepted evidence until the overall research goal is satisfied or a genuine external block must be reported.

## Execution Subagent

1. Receive an explicit overall task name and task ID; do not infer another task.
2. Call `statemng_task_claim`, then `statemng_task_show` with the returned run ID.
3. In Codex, inspect the `codex_authorization` returned by `task_show` before beginning research. It must report an enforced runtime guard, `caller_role=worker`, the supplied overall task name, and the exact six worker tools; otherwise stop and report the adapter error. Host-side physical tool filtering remains preferred, but tool visibility alone is not an error on affected Codex versions. In other hosts, use that host's native permission contract; `codex_authorization` is neither required nor expected.
4. After `task_show` and before beginning research, read every `SKILL.md` listed in `required_skills` completely, in the supplied order. If the field is absent or empty, no additional skill is required.
5. Write only in the returned run workspace. Read the needed accepted dependency files in place using `project_root / dependencies[].artifacts[].stored_path`; retain their registered IDs and hashes. Use only the objective, background, acceptance criteria, required skills, and accepted dependency results supplied by `task_show`. Extract only needed members of an existing archive, not its whole dependency tree.
6. Register each new or changed deliverable file separately with `statemng_artifact_add`. Submit one entry artifact, which may index those files and existing dependency references. Do not embed predecessor archives, workspaces, or unchanged shared inputs. The overall task is self-contained; each run is not a standalone archive. A new canonical prefix still contains the complete cumulative mathematical result. Finish with exactly one of `statemng_task_submit`, `statemng_task_block`, or `statemng_task_fail` as soon as the task's result is ready.
7. Never accept a task or unblock it. If either tool is visible, do not call it; the verified runtime guard must reject it before the CLI.

Do not use `workflow.py`.
