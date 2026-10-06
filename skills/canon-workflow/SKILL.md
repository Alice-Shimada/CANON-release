---
name: canon-workflow
description: Start or resume CANON research and choose the next scientific command from the latest artifacts and result code.
---

# CANON workflow: choose one next action

Use this entry point for a new or continued canonical-basis/UT-integral task.
The same routing applies to every model and host. Select the next action from
current artifacts, then read its step skill and applicable method card.

The coordinator owns task planning and acceptance through the
[persistent research skill](../../.agents/skills/persistent-scientific-research/SKILL.md).
Workers execute their assigned step and return its result or precise method
limit. The coordinator preserves the user's overall scientific objective across
assignments.

## 1. Check completion before planning work

First match the result to the user's requested scope and current inputs.

| Current evidence | Do this next |
|---|---|
| FINAL_CHECK is `PASS/ALL_PASS` for the entire requested scope and unchanged inputs | Finish the handoff below. Do not select another scientific method. |
| Only a requested subset is complete; the user requested more | Keep that result and work only on the remaining scope. |
| Inputs changed after the passing check | Identify the affected result and run the necessary changed-input work. The old pass does not certify the new input. |
| No matching final pass | Continue to section 2. |

**Finish the handoff:** the worker registers the final artifacts, submits, and
returns. The coordinator reviews the existing receipt, accepts when its criteria
are met, delivers the result, and stops this scope. Pending acceptance is a
review step.

A task completed for diagnostic or partial evidence certifies only its stated
criteria; it does not close an unresolved scientific gate. The coordinator
continues meaningful authorized work while requested scope and resources remain
and no external block prevents progress. Worker completion alone does not end
the overall task.

After a matching final pass, no further scientific method is run for the same
unchanged scope. Completion depends on the requested deliverables, not the number
of methods tried or the budget remaining. Method comparisons require a separate
user request. Delivery records the methods used, applicable route exceptions and
any unmet workflow requirements. Unused optional methods are normal; only an
unmet applicable requirement is a workflow deviation.

## 2. Locate the first unfinished step

Execute named steps through `python3 run_step.py INPUT.json OUTPUT_DIR`, passing
this task's `--components` manifest when one was supplied. `--list` and
`--describe` identify the selected command and instruction file. Read that file
before preparing the call. Built-in method choices below apply to default
components; an explicitly selected replacement uses its own method instructions
and the same outgoing artifact and acceptance contracts. If a package provides
an unqualified `SEARCH_CORE`, use it without a built-in `--method` selection.
See [component packages](../../docs/components.md).

For supported operations, call these interfaces and existing programs. Record
mathematical inputs and options as data. Use
[PREPARE_REQUEST](../canon-prepare-request/SKILL.md) to bind producer artifacts
into a consumer request when needed. A missing computational capability is a
separate component development task with a reusable interface and tests; do not
silently introduce a task-local scientific glue program during research.

Parameterization and native backend choice are independent. A profile may bind
PREPARE, DISCOVER, REDUCE_IBP and BUILD_CUT_DE to different packages using `from`
references. Use the exact selected entry; do not infer Kira from twistor
coordinates or assume that one discovery provider also owns later reductions.
Native integral encodings and source-basis conversion belong to adapters.

When `--describe` reports a selected package's `workflow` instructions, use that
route for its declared scope. Carry the whole ordered component selection into
worker assignments and child calls. A sample-based reconstruction route may
prepare derivatives after discovery, collect point DEs, request more samples or
letters, and finish at its own independent checker. Preserve its stated evidence
scope and result code; do not relabel it as the default exact-global-gauge
`ALL_PASS`. The default table below remains the route when no replacement route
applies. Components are switched between invocations; a running calculation's
implementation is not changed in place.

Read the task goal, supplied runtime, latest accepted prefix and the current
step's scientific `result.json`. Use the same family, variable order, resident sector,
source basis and selected candidate throughout a step. A file from a rejected
or unrelated attempt does not advance the pipeline.

Apply these rules in order:

1. Check the actual remaining budget as described in section 6. If it is
   exhausted or only the declared shutdown/collection reserve remains, save the
   accepted prefix and unresolved step. Do not launch another attempt or report
   scientific completion.
2. If a required file/tool is missing or a process failed before writing its
   result, use **Execution budgets and operational recovery** below.
3. If the latest result is FAIL, ERROR or INCONCLUSIVE, use **Result routing**.
4. Otherwise use **Forward routing**, taking the first row whose condition holds.

## 3. Forward routing

| Current state | Next action | Read |
|---|---|---|
| `FINAL_CHECK` returned `PASS/ALL_PASS` | Finish the handoff in section 1 and stop this scope. | [final check](../canon-final-check/SKILL.md) |
| `NEXT_SECTOR` returned `summary.complete: true` | Run `FINAL_CHECK` on the original DE and complete accepted prefix. | [final check](../canon-final-check/SKILL.md) |
| A newly committed prefix has not been advanced | Run `NEXT_SECTOR`. If complete, run FINAL_CHECK; otherwise select its returned sector. | [commit](../canon-commit-sector/SKILL.md) |
| `CHECK_CANONICAL` returned `PASS/CANONICAL_PASS` | Run `COMMIT_SECTOR` with the complete returned transform and check artifact. | [commit](../canon-commit-sector/SKILL.md) |
| `SOLVE_TAIL` returned `PASS/TAIL_READY` | Run `CHECK_CANONICAL`. | [canonical check](../canon-check-canonical/SKILL.md) |
| `full_sector_de` exists for the passing selected core | Run `SOLVE_TAIL`, including when no alphabet was supplied. | [tail](../canon-solve-tail/SKILL.md) |
| `CHECK_CORE` returned `PASS/CORE_PASS` | Run `BUILD_FULL_DE`. | [full DE](../canon-build-full-de/SKILL.md) |
| An untested `core_candidates` artifact exists | Run `CHECK_CORE`. | [core check](../canon-check-core/SKILL.md) |
| An integral-candidate IBP bridge exists but no routed core pool | Run `ROUTE_CORE_CANDIDATES`. | [core search](../canon-search-core/SKILL.md) |
| Integral candidates exist but have not been reduced | Keep them. Complete any missing candidate derivative inputs, then run `REDUCE_CANDIDATE_IBP`. | [IBP](../canon-reduce-ibp/SKILL.md) |
| The current `sector_basis` and `sector_cut_de` exist, with no untested candidate | Select a core method using **Core selection** below. | [core search](../canon-search-core/SKILL.md) |
| The original `ordered_master_de` exists, but the current cut is absent | Run `SLICE_CUT_DE`. Reuse the original DE. | [cut DE](../canon-build-cut-de/SKILL.md) |
| Masters/sectors exist and derivative targets have complete IBP coverage | Run `BUILD_CUT_DE` once. | [cut DE](../canon-build-cut-de/SKILL.md) |
| No original DE exists; symbolic parameterized family data exist but physical derivative records are absent | Run `PREPARE_DERIVATIVES`. Agents do not write the records. | [physical derivatives](../canon-prepare-derivatives/SKILL.md) |
| Masters/sectors exist, with symbolic derivatives but no target artifact | Run `PREPARE_REDUCTION_TARGETS`. | [targets](../canon-prepare-reduction-targets/SKILL.md) |
| Derivative targets exist but lack IBP rules | Run `REDUCE_IBP` for those targets. | [IBP](../canon-reduce-ibp/SKILL.md) |
| `prepared_family` exists, but ordered masters/sectors are not bound | Run `DISCOVER`. | [discovery](../canon-discover-sectors/SKILL.md) |
| No `prepared_family` exists | Prepare missing typed inputs, then run `PREPARE`. | [preparation](../canon-prepare-family/SKILL.md) |

After NEXT_SECTOR reports completion, run FINAL_CHECK with the complete
original-DE inputs described in the final-check skill. For a new sector, use
that sector's intermediate artifacts and the cumulative accepted prefix.
The order is ascending `(propagator_count, sector_id)`, preserving resident
master order within each sector.

Every executable step uses the common input/output pair and writes `result.json`.
For default `SEARCH_CORE`, select `--method canonica`, `libra`, `epsilon-zero`
or `residue-balance`
as directed by core selection; the runner does not choose a method.

For explicitly selected detached execution, a submission returns an operational
job handle, not a finished scientific result. Keep the scientific step pending
within its current running task; collect the child result when the terminal
checkpoint arrives, then apply scientific routing. Do not treat a successful
launch or a completion notification as a passed scientific check. The optional
execution package's instructions define submit, collect, cancel and watch calls.

## 4. Core selection

Follow [canon-search-core](../canon-search-core/SKILL.md), which chooses a
bounded hypothesis from the family geometry, available inputs and current
evidence. A simple sector may be handled by selected dots and natural
normalization; a concrete numerator, dimensional or contact-term hypothesis may
favor Gram constructions. Use DlogBasis-refine when a general bounded search or
leading-singularity information is useful. It is not compulsory before every
other method. Integral proposals use candidate IBP reduction and CHECK_CORE.
For a selected DlogBasis attempt, invoke `DlogBasisSearch` with finite bounds;
package loading and family construction are preparation steps.

Each operation requires its own inputs. Candidate derivative `exact_strategy`
belongs to the IBP bridge and may be prepared after the proposal. The
core-selection skill also describes applicable direct-DE choices. The method catalog provides
capabilities and contracts; exhaustive provider or numerator/dot enumeration is
not required. Method choices follow the overall goal and current evidence
throughout worker handoffs. Record tested decision rules with their inputs,
bounds and checker evidence so later choices can improve without broadening the
scientific claim or repeating accepted work.

## 5. Result routing

Read `status`, `code` and `summary`; exit code zero is not scientific success.
Follow the first applicable row. Preserve the failed input and latest accepted
prefix. A new attempt must change the stated failing hypothesis or input.

| Result or evidence | Next action |
|---|---|
| A matching exact CORE_PASS exists, including when an older diagnostic claimed an obstruction | Reuse that positive witness and follow forward routing to BUILD_FULL_DE. A diagnostic cannot veto a passing gauge identity. |
| Missing IBP targets or unreduced integrals | Extend coverage for those targets, then repeat only the affected construction. Candidate assessment follows complete reduction. |
| Native/exported master count differs from the declared source basis | Compare exact ordered lists, target coverage and closure using the IBP skill. Counts alone neither establish missing masters nor justify a larger seed. |
| An input/schema/tool error with a result file | Fix the named field, path, convention or installation in the step's skill, then resume that operation using unaffected artifacts. |
| `CORE_FAIL`, `CANDIDATE_BUDGET_EXHAUSTED`, or `SELECT_CORE_METHOD` | Read the candidate rejection/rank and return to core selection. Do not call SOLVE_TAIL for a failed core. |
| `TAIL_UNSOLVED` | Follow the tail skill's diagnostic table. It distinguishes epsilon dependence, missing letters/higher poles and the rational backend domain. |
| `TAIL_FAIL` from CHECK_CANONICAL | Read its failed full-prefix flags. A core that still passes calls for a full representative/tail correction, then SOLVE_TAIL and CHECK_CANONICAL on that changed proposal. |
| Core `nonrationalinv`, an exhausted epsilon-zero ansatz, or an epsilon-zero no-go claim | Follow direct-DE selection: DIAGNOSE_CORE, then residue-balance when applicable and untried. Preserve the actual limitation; it is not a proof of nonexistence. |
| `remaining_algebraic_tail_outside_rational_CANONICA_domain` | Use the algebraic branch in the tail skill. Do not remove the rationality check or repeat the same backend call with more time. |
| `METHOD_EXHAUSTED` or `OUT_OF_SCOPE` | Record the exhausted method and ansatz. The coordinator selects the next applicable untried branch within budget, or reports the precise unresolved scope. |
| A source-gauge, identity, ordering or committed-prefix check fails | Resolve the named input/convention/composition mismatch before downstream steps. Preserve all lower-sector normalization in the cumulative map. |

Method exhaustion describes the attempted ansatz and bounds. If no implemented
method applies, report which new input or mathematical construction is needed.
Scientific acceptance uses the returned checker results; solver development is
a separately scoped task.
Reserve a blocked task for a named external condition. An exhausted method or
an unproved no-go argument calls for a changed hypothesis, a scoped capability
task, or an unresolved report; it does not establish an external block.

## 6. Execution budgets and operational recovery

Before launch or resumption, distinguish four limits:

| Limit | Meaning and control |
|---|---|
| Overall wall deadline | The user's stop time. Record an absolute timestamp with timezone; convert an elapsed-time allowance from its recorded start. |
| Execution timeout | A cap enforced by the shell, host job, bridge or selected component. Record each applicable value, owning layer and source (user instruction, component default or agent allocation). |
| Tool/UI/MCP wait limit | How long a call waits for output. Check whether the host merely yields or actually cancels; a response wait is not automatically a calculation cap. |
| Mathematical search bounds | Record each option's declared unit and scope: degree/dot/ansatz bounds restrict the search; a candidate count may only truncate returned output. Neither is an execution timeout. |

When a deadline applies, read system time before each launch/resume and before
declaring it reached. Compute remaining time from that clock and the recorded
deadline, reserving time for cancellation grace and result collection. Choose a
step allocation that fits the remaining budget and available stage-cost evidence;
record the allocation and reserve in the task context. Do not silently extend a
user's deadline or search bounds. A guessed clock is not budget evidence.

`run_step.py` dispatches the selected command without a global execution timeout.
Read the selected component's runtime settings and host cancellation semantics;
the earliest applicable execution cap or deadline wins. To adjust a timeout,
change the setting at its owning layer within the user's budget, including any
shorter outer cap. Do not impose a universal 120-second limit or shrink a step
merely to match a generic response-wait default. Use the host's supported
execution timeout or an explicitly selected [detached execution component](../../components/local-jobs/README.md)
when needed; retain its job handle and collection route instead of adding a
second runner. Detachment preserves the user's execution budget. A timed-out
bounded search is incomplete, not `METHOD_EXHAUSTED`.

Handle operational failures at the affected stage:

- Missing path: resolve it in the process that opens it. Artifact paths in WLS
  requests are relative to their declaring JSON. Use `task_show.workspace` and
  `project_root / stored_path` verbatim; never reconstruct directories from a
  task-name spelling. For truncated tool output, read its reported saved output
  or retrieve the needed fields before using a path. Do not guess another
  checkout, diagnose a broken mount from a missing path alone, or copy whole trees.
- Tool/import/Singular error: inspect the actual stderr and declared runtime.
  Complete the family momentum/kinematic rules before retrying a candidate
  search. A container shell and a bridged Wolfram process can have different PATHs.
- Timeout/cancellation: preserve raw outputs, stdout/stderr, command, cap/source,
  timestamps and job handle. Identify the interrupted stage from phase evidence;
  if none is available, record the stage as unknown. A wait that merely yielded
  calls for collecting the same job. Cancellation must reach the owned native or
  bridged process; confirm closure before a replacement launch.
  Silence alone does not establish OOM, a dead kernel or mathematical failure.
- Result freshness: only a receipt produced by the current invocation describes
  its outcome. Preserve older receipts under their original references. A stage
  stopped without a current `result.json` is operationally incomplete; record
  that separately rather than copying an old result or asserting scientific PASS
  or method exhaustion. Never rewrite generated receipts to fit a later attempt.

Resume only the affected stage through `run_step.py` and the complete component
selection. For example, after completed native Kira reduction with failed import,
use the [public import recovery](../../components/reducers/kira/README.md#requests-and-configuration)
with `import_from` pointing to the original native output and an appropriate
`import_timeout_seconds`, preserving the same input bindings in a fresh output.
Do not rerun native reduction solely to retry import or call internal `Interop`
directly to evade dispatch. Retain original evidence; register corrected inputs
and new results separately, using `PREPARE_REQUEST` for artifact bindings when
needed. If the selected component lacks recovery, identify that capability gap
for component development rather than bypassing its public contract.

Read [installation](../../docs/installation.md) for the host contract. Once the
specific operational condition is fixed, resume the affected step. Do not repeat
accepted sectors, candidate reductions or unchanged scientific checks simply
because a new agent takes over.
