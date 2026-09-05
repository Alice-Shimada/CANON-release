---
name: persistent-scientific-research
description: Use for multi-step scientific research in CANON, including master-integral differential equations, UT bases, canonical forms, and epsilon forms.
---

# Persistent Scientific Research

Use the `statemng` MCP tools for every state operation. Never ask the user to run the internal CLI. If these tools are unavailable, stop and report the integration error.

In Codex, run persistent research only in a Local session. If the current session is a Worktree, stop and report the adapter error; do not operate state in another checkout. The MCP server is non-required only to keep the Codex session usable after an integration failure, never as permission to bypass state management.

Follow the complete `## 四、整体架构` protocol in the applicable root `AGENTS.md` or `CLAUDE.md`.

## Main Agent

1. In Codex, before the first state call, internally run `state-management/adapters/codex/install_launcher.py --check`. If it fails, reinstall the launcher, stop the current research, and require a new Local session; never use tools that may target another checkout or ask the user to run the installer. The main Agent must successfully call `init` or `resume` before creating any worker so the runtime guard can bind the coordinator.
2. Determine one unambiguous overall `task_name`. If none is clear, call `statemng_project_list` and ask the user to choose; do not guess between existing tasks.
3. Call `statemng_init` for a new overall task or `statemng_project_resume` for an existing one.
4. Create only necessary subtasks. Write each description as JSON containing `objective`, `background`, and `acceptance_criteria`; when the task requires repository skills, also add the optional `required_skills` array with each repository-relative `SKILL.md` path. Do not place priority or unrelated context in it.
5. Dispatch each ready subtask only through the Codex `persistent_research_worker` custom agent, passing only the overall task name, task ID, and necessary research instructions. Do not use an unrestricted built-in worker.
6. Review submitted summaries and artifacts against the acceptance criteria. Independently verify important results when necessary.
7. Alone call `statemng_task_accept` after successful review. Alone call `statemng_task_unblock` after confirming that a recorded blocking condition has actually been removed.
8. Replan from accepted evidence until the overall research goal is satisfied or a genuine external block must be reported.

## Execution Subagent

1. Receive an explicit overall task name and task ID; do not infer another task.
2. Call `statemng_task_claim`, then `statemng_task_show` with the returned run ID.
3. In Codex, inspect the `codex_authorization` returned by `task_show` before beginning research. It must report an enforced runtime guard, `caller_role=worker`, the supplied overall task name, and the exact six worker tools; otherwise stop and report the adapter error. Host-side physical tool filtering remains preferred, but tool visibility alone is not an error on affected Codex versions. In other hosts, use that host's native permission contract; `codex_authorization` is neither required nor expected.
4. After `task_show` and before beginning research, read every `SKILL.md` listed in `required_skills` completely, in the supplied order. If the field is absent or empty, no additional skill is required.
5. Work only in the returned run workspace. Use only the objective, background, acceptance criteria, required skills, and accepted dependency results supplied by `task_show`.
6. Register each formal deliverable with `statemng_artifact_add`, then finish with exactly one of `statemng_task_submit`, `statemng_task_block`, or `statemng_task_fail`.
7. Never accept a task or unblock it. If either tool is visible, do not call it; the verified runtime guard must reject it before the CLI.

Do not use `workflow.py`.
