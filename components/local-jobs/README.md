# Local jobs and completion callbacks

This optional package provides local asynchronous execution and a small file
outbox. Python's standard library is its only implementation dependency. CANON's
runner is supplied explicitly by the manifest's `{canon}` argument. Execution
requires POSIX process groups and `waitid(WNOWAIT)`; unsupported hosts return an
operational error. It starts no SSH connection, host session API or installed
service. All five steps use CANON's common JSON request and result envelopes.

Select this package alongside the scientific package:

```sh
python3 /path/to/CANON/run_step.py request.json output \
  --components /path/to/local-jobs/components.json \
  --components /path/to/scientific-package/components.json
```

Read [WORKFLOW.md](WORKFLOW.md) for the agent handoff. Other CANON steps retain
their selected implementations. Runtime results never return scientific `PASS`.

## Submit, collect and cancel

`SUBMIT_JOB` takes this payload:

```json
{
  "request": {"path": "science/request.json"},
  "run_id": "caller-declared-run-1",
  "components": ["science/components.json"],
  "environment": {"OMP_NUM_THREADS": "1"},
  "cancel_grace_seconds": 1
}
```

The scientific request keeps its original location and path base. Its declared
resource budget is unchanged. Optional `method` selects a named scientific
method. When `components` is omitted, the currently selected component stack is
inherited; an empty list explicitly selects CANON defaults. Component paths here
are relative to this submission request. `environment` contains only explicit
caller overrides; ordinary process environment inheritance supplies the rest.
No whole environment is saved.

Submission calls the explicit CANON runner's `--describe`, records its resolved
command and component selection in `job/invocation.json`, and launches a detached
supervisor. The supervisor inherits that environment, including the resolved
`CANON_COMPONENTS` and interpreter for nested calls. Saved explicit overrides and
runtime selection keys are restored before launching the child. It executes the resolved
command directly. Selection changes in later calls cannot redirect it. Leave
the selected source files and input files in place while that invocation runs.
This snapshots command selection, not an installed software distribution.

The immediate result is `PROVISIONAL/JOB_SUBMITTED`, with a `job` descriptor for
`job/job.json`. The handle has unique `job_id` and declared `run_id`, and relative
references to the terminal checkpoint, scientific result and invocation record.
PID records are informational. They are never used by collect or cancel to kill
a process.

`COLLECT_JOB` and `CANCEL_JOB` take `{"job":{"path":".../job.json"}}`.
Collection does not resubmit or wait for computation. Cancellation writes a
token-bound request, consumed by the still-owning supervisor. It sends TERM to
the child process group, then KILL after the grace interval. The supervisor
keeps the child unreaped until the group has closed, preventing PID reuse during
group cancellation. Same-group descendants are closed when the step exits.
Components that start separate groups must forward cancellation to those groups.

The supervisor writes `job/terminal.json` atomically after real child exit and
group cleanup. An invalid/missing scientific result or nonzero exit is a failed
operational outcome. A zero exit with a valid matching result is `succeeded`,
including a completed check returning `FAIL` or a provider returning
`INCONCLUSIVE`. The verbatim scientific status and code are retained in the
checkpoint, collection summary and event for scientific routing. Neither
operational outcome accepts research. Cancellation reports `cancelled`, including when
requested before the child starts.

| Collection code | Meaning |
|---|---|
| `JOB_RUNNING` | No terminal receipt yet; no conclusion about scientific completion. |
| `JOB_FINISHED` | Terminal succeeded; read the separately referenced scientific result. |
| `JOB_FAILED` | Terminal failure; read its return code, reason and scientific result if present. |
| `JOB_CANCELLED` | Supervisor consumed cancellation and closed its owned process group. |

`JOB_RUNNING` also covers a missing checkpoint after an uncatchable supervisor
crash. This package does not guess success, reuse a PID, or restart computation
in that case. Collection and completed handles remain readable after relocation
of their artifact tree. Resolved command metadata describes the original
execution and is not replayed by collection. Move live jobs only after completion.

## Completion-only watch

`WATCH_COMPLETION` creates a watch with this payload:

```json
{
  "checkpoint": {"path": "job/terminal.json"},
  "job_id": "the-job-id-from-job.json",
  "run_id": "caller-declared-run-1",
  "mode": "once",
  "interval_seconds": 5,
  "target": {
    "host": "declared-host",
    "session": "declared-session",
    "message": "Continue from the saved checkpoint."
  },
  "callback": {
    "argv": ["installed-callback-command", "--fixed-option"],
    "cwd": ".",
    "timeout_seconds": 30
  }
}
```

Copy both identities exactly. `mode: once` performs one bounded scan and at most
one callback attempt. `mode: background` starts a detached wait loop, checking
only the checkpoint at the requested interval. Both return a relative `watch`
descriptor. To resume or retry, call `WATCH_COMPLETION` with
`{"watch":{"path":".../watch.json"},"mode":"once"}` or `background`.
It reloads the existing outbox. Concurrent scans are serialized by a per-watch
file lock; a background loop also holds its own lifetime lock. No global
database or scheduler exists.

A checkpoint has this minimal normalized form:

```json
{
  "schema": "canon-neu/local-checkpoint/v1",
  "job_id": "declared-job-id",
  "run_id": "declared-run-id",
  "terminal": true,
  "status": "succeeded",
  "result": {"path": "science/result.json"}
}
```

Terminal `status` is `succeeded`, `failed` or `cancelled`. A missing file or
`terminal: false` stays pending; mismatched identities are an error before
delivery. `result` is optional. A checkpoint producer should use atomic file
replacement. There is no log inspection or natural-language interpretation.

For another checkpoint format, optionally supply a fixed `check` command with
the same `argv`, `cwd` and `timeout_seconds` fields as `callback`. The monitor
appends the checkpoint's absolute path to that argv. The command returns zero
and prints one normalized checkpoint JSON value, including matching identities.
Its combined output must contain only that JSON. It may return `terminal: false`;
nonzero exit or malformed JSON output creates an operational error event. The normalized terminal
output is saved separately, leaving the original checkpoint untouched. Any
returned `result.path` is relative to the original checkpoint.

A failed check command produces `event_kind: watch_error`, `outcome: check_error`
and `computation_terminal: false`, with its error receipt. It uses the same
callback retry and acknowledgment path, then stops the watch after delivery.
It never manufactures a failed computation checkpoint. Correct that specific
check condition and create a new watch; the prior error event remains immutable.
Identity mismatches still reject delivery and must be resolved explicitly.

## Delivery contract

When terminal, the watch atomically saves `event.json` before invoking the
callback. The event contains stable `event_id`, job/run/watch identities,
`outcome`, relative checkpoint/result references, and the exact declared
`target.host`, `target.session` and fixed `target.message`. The configured argv
is executed without a shell, with the event's absolute path appended. Every
attempt uses that same event ID. Relative script/argument paths resolve from the
declared command `cwd`, itself relative to the watch-creation request; bare
executable names use the inherited PATH. Paths containing spaces remain single
argv entries. Script arguments are not guessed or rewritten.

Exit zero acknowledges that the adapter accepted delivery. `delivery.json`
records acknowledgment independently of the scientific result. It does **not**
mean the target model completed a turn or accepted a research task. Nonzero
exit/timeout remains pending, with attempt count and return code. One-shot scans
retry explicitly; background mode retries on its interval. Repeated scans after
acknowledgment do not deliver again.

Delivery is **at least once**. A crash between receiver acceptance and local
acknowledgment can repeat the command. The receiver must persistently deduplicate
`event_id` before starting its continuation action. A new watch has a new ID;
reuse the existing handle when retrying the same delivery. The fake receiver in
[examples/fake_session_receiver.py](examples/fake_session_receiver.py) illustrates
durable command acceptance and deduplication without contacting any agent host.
Replacing that argv is the entire host adapter boundary; this package installs
no actual Codex callback or control socket.

`CANCEL_WATCH` takes `{"watch":{"path":".../watch.json"}}`. It stops checks
and retries, and interrupts an owned check/callback command when running. It
does not cancel the scientific job or retract an already accepted callback.
The background loop notices cancellation even during its interval wait. Events
and delivery records remain on disk.

## Synthetic example and tests

From this package directory, with the actual CANON checkout supplied:

```sh
python3 /path/to/CANON/run_step.py examples/submit.json demo-out/submit \
  --components components.json
python3 /path/to/CANON/run_step.py examples/collect.json demo-out/collect \
  --components components.json
```

The first command submits the included short synthetic step. Repeat collection
if its checkpoint is still pending. To test notification, create a watch request
using the returned job/run IDs, use the fake receiver argv
`["python3", "fake_session_receiver.py", "../demo-out/fake-session.json"]`, and
declare `cwd` relative to the request so it resolves to `examples/`. The fake
target may use any explicit host/session strings; it records them locally.

Run the bounded tests with the checkout location explicitly configured:

```sh
CANON_TEST_ROOT=/path/to/CANON python3 tests/test_local_jobs.py
```

The tests use real short subprocesses and a fake receiver, relocate the package
into a path containing spaces, check terminal failure/cancellation and command
timeouts, and exercise retries, duplicate scans and lost acknowledgments. They
create no live host callback or service and close their owned processes.
