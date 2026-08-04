---
name: persistent-scientific-research
description: Use for multi-step scientific research in CANON, including master-integral differential equations, UT bases, canonical forms, and epsilon forms.
---

# Persistent Scientific Research

Use the `statemng` MCP tools for every state operation. Never ask the user to run the internal CLI. If these tools are unavailable, stop and report the integration error.

Follow the complete `## 四、整体架构` protocol in the applicable root `AGENTS.md` or `CLAUDE.md`.

## Main Agent

1. Determine one unambiguous overall `task_name`. If none is clear, call `statemng_project_list` and ask the user to choose; do not guess between existing tasks.
2. Call `statemng_init` for a new overall task or `statemng_project_resume` for an existing one.
3. Create only necessary subtasks. Write each description as JSON containing exactly `objective`, `background`, and `acceptance_criteria`; do not place priority or unrelated context in it.
4. Dispatch each ready subtask only through the Codex `persistent_research_worker` custom agent, passing only the overall task name, task ID, and necessary research instructions. Do not use an unrestricted built-in worker.
5. Review submitted summaries and artifacts against the acceptance criteria. Independently verify important results when necessary.
6. Alone call `statemng_task_accept` after successful review. Alone call `statemng_task_unblock` after confirming that a recorded blocking condition has actually been removed.
7. Replan from accepted evidence until the overall research goal is satisfied or a genuine external block must be reported.

## Execution Subagent

1. Receive an explicit overall task name and task ID; do not infer another task.
2. Call `statemng_task_claim`, then `statemng_task_show` with the returned run ID.
3. Work only in the returned run workspace. Use only the objective, background, acceptance criteria, and accepted dependency results supplied by `task_show`.
4. Register each formal deliverable with `statemng_artifact_add`, then finish with exactly one of `statemng_task_submit`, `statemng_task_block`, or `statemng_task_fail`.
5. Never accept a task or unblock it. If either tool is visible, still do not call it and report the configuration error to the main Agent.

Do not use `workflow.py`.
