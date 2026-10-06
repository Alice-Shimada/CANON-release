# Agent use of local jobs

1. Select the scientific request and component stack within the task's resource
   budget. Call `SUBMIT_JOB` through the ordinary CANON runner. Preserve its
   `job` descriptor and `job_id`/`run_id` in the task handoff.
2. Treat `JOB_SUBMITTED` as a launch receipt. It is not scientific completion.
   Use `COLLECT_JOB` on the existing handle; never silently resubmit it.
3. If a host command adapter is configured, create `WATCH_COMPLETION` for that
   job's terminal checkpoint and exact identities. Supply a fixed continuation
   message and explicit host/session. A background watch checks completion only.
   Without an adapter, use bounded one-shot collection when resuming work.
4. On delivery, read the event and collect the existing job. Inspect the usual
   scientific result and route it through the selected scientific workflow.
   Callback acknowledgment records delivery only. Scientific checkers and the
   authorized coordinator retain their existing acceptance roles.
5. For cancellation, use `CANCEL_JOB`. To stop notification checks or retries,
   use `CANCEL_WATCH`. These are independent actions. Preserve terminal errors
   and unfinished checkpoints in the handoff.

The package never calls statemng or accepts, unblocks or revises research tasks.
The agent continues to register artifacts and submit through its authorized
state tools. Host-specific transport is supplied by the callback command; there
is no automatic Codex session integration.
