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

After a matching final pass, no further scientific method is run for the same
unchanged scope. Completion depends on the requested deliverables, not the number
of methods tried or the budget remaining. Method comparisons require a separate
user request. Delivery records the methods used, applicable route exceptions and
any unmet workflow requirements. Unused optional methods are normal; only an
unmet applicable requirement is a workflow deviation.

## 2. Locate the first unfinished step

Read the task goal, supplied runtime, latest accepted prefix and the current
step's scientific `result.json`. Use the same family, variable order, resident sector,
source basis and selected candidate throughout a step. A file from a rejected
or unrelated attempt does not advance the pipeline.

Apply these rules in order:

1. If the user budget is exhausted, save the accepted prefix and unresolved
   step. Do not launch another attempt or report scientific completion.
2. If a required file/tool is missing or a process failed before writing its
   result, use **Operational failures** below.
3. If the latest result is FAIL, ERROR or INCONCLUSIVE, use **Result routing**.
4. Otherwise use **Forward routing**, taking the first row whose condition holds.

## 3. Forward routing

| Current state | Next action | Read |
|---|---|---|
| `FINAL_CHECK` returned `PASS/ALL_PASS` | Finish the handoff in section 1 and stop this scope. | [final check](../canon-final-check/SKILL.md) |
| `NEXT_SECTOR` returned `summary.complete: true` | Run `mma/CheckFullSystem.wls` (`FINAL_CHECK`) on the original DE and complete accepted prefix. | [final check](../canon-final-check/SKILL.md) |
| A newly committed prefix has not been advanced | Run `mma/NextSector.wls` (`NEXT_SECTOR`). If complete, run FINAL_CHECK; otherwise select its returned sector. | [commit](../canon-commit-sector/SKILL.md) |
| `CHECK_CANONICAL` returned `PASS/CANONICAL_PASS` | Run `mma/CommitSector.wls` (`COMMIT_SECTOR`) with the complete returned transform and check artifact. | [commit](../canon-commit-sector/SKILL.md) |
| `SOLVE_TAIL` returned `PASS/TAIL_READY` | Run `mma/CheckCanonical.wls` (`CHECK_CANONICAL`). | [canonical check](../canon-check-canonical/SKILL.md) |
| `full_sector_de` exists for the passing selected core | Run `mma/SolveTail.wls` (`SOLVE_TAIL`), including when no alphabet was supplied. | [tail](../canon-solve-tail/SKILL.md) |
| `CHECK_CORE` returned `PASS/CORE_PASS` | Run `mma/BuildFullSectorDE.wls` (`BUILD_FULL_DE`). | [full DE](../canon-build-full-de/SKILL.md) |
| An untested `core_candidates` artifact exists | Run `mma/CheckSectorCore.wls` (`CHECK_CORE`). | [core check](../canon-check-core/SKILL.md) |
| An integral-candidate IBP bridge exists but no routed core pool | Run `mma/RouteCoreCandidates.wls` (`ROUTE_CORE_CANDIDATES`). | [core search](../canon-search-core/SKILL.md) |
| Integral candidates exist but have not been reduced | Keep them. Complete any missing candidate derivative inputs, then run `mma/ReduceCandidateIBP.wls`. | [IBP](../canon-reduce-ibp/SKILL.md) |
| The current `sector_basis` and `sector_cut_de` exist, with no untested candidate | Select a core method using **Core selection** below. | [core search](../canon-search-core/SKILL.md) |
| The original `ordered_master_de` exists, but the current cut is absent | Run `mma/SliceSectorCutDE.wls` (`SLICE_CUT_DE`). Reuse the original DE. | [cut DE](../canon-build-cut-de/SKILL.md) |
| Masters/sectors exist and derivative targets have complete IBP coverage | Run `mma/BuildSectorCutDE.wls` (`BUILD_CUT_DE`) once. | [cut DE](../canon-build-cut-de/SKILL.md) |
| Masters/sectors exist, but derivative targets lack IBP rules | Generate the required targets and run `mma/ReduceIBP.wls`. | [IBP](../canon-reduce-ibp/SKILL.md) |
| `prepared_family` exists, but ordered masters/sectors are not bound | Run `mma/DiscoverSectors.wls` (`DISCOVER`). | [discovery](../canon-discover-sectors/SKILL.md) |
| No `prepared_family` exists | Prepare missing typed inputs, then run `mma/PrepareFamily.wls` (`PREPARE`). | [preparation](../canon-prepare-family/SKILL.md) |

After NEXT_SECTOR reports completion, run FINAL_CHECK with the complete
original-DE inputs described in the final-check skill. For a new sector, use
that sector's intermediate artifacts and the cumulative accepted prefix.
The order is ascending `(propagator_count, sector_id)`, preserving resident
master order within each sector.

Most table entries use `wolframscript -file SCRIPT INPUT.json OUTPUT_DIR` and
write `result.json`. The two IBP adapters are exceptions: follow their explicit
positional commands in the IBP skill and inspect the returned WL artifact.

## 4. Core selection

Follow [canon-search-core](../canon-search-core/SKILL.md), which defines the
method choices and their input requirements. Its default for a defined
family and UT/canonical integral-basis search is one bounded DlogBasis-refine
search, followed by candidate IBP reduction and CHECK_CORE. An attempt consists
of a `DlogBasisSearch` call with declared finite bounds. Package loading and family
construction are preparation steps.

Each operation requires its own inputs. Candidate derivative `exact_strategy`
belongs to the IBP bridge and may be prepared after the proposal. The
core-selection skill defines direct-DE exceptions. The method catalog provides
capabilities and contracts; exhaustive provider or numerator/dot enumeration is
not required. Method choices follow the overall goal and current evidence
throughout worker handoffs.

After a direct-DE exception applies, a small explicitly normalized UT seed set
can select INITIAL's seeded core card alongside the other SEARCH_CORE providers.
Use `methods/initial/run.wls` with explicit `SEARCH_CORE`. The legacy official
ladder evidence steps are reference validation only; they cannot satisfy
CORE_PASS, select a method, or run automatically after a failed core attempt.
Libra's bounded normalization and CANONICA's finite block ansatz extend this same
node. CANONICA's subsector D solving and checkpoints extend SOLVE_TAIL. Every
proposal retains the existing independent checks and forward-routing order.

## 5. Result routing

Read `status`, `code` and `summary`; exit code zero is not scientific success.
Follow the first applicable row. Preserve the failed input and latest accepted
prefix. A new attempt must change the stated failing hypothesis or input.

| Result or evidence | Next action |
|---|---|
| Missing IBP targets or unreduced integrals | Extend coverage for those targets, then repeat only the affected construction. Candidate assessment follows complete reduction. |
| An input/schema/tool error with a result file | Fix the named field, path, convention or installation in the step's skill, then resume that operation using unaffected artifacts. |
| `CORE_FAIL`, `CANDIDATE_BUDGET_EXHAUSTED`, or `SELECT_CORE_METHOD` | Read the candidate rejection/rank and return to core selection. Do not call SOLVE_TAIL for a failed core. |
| `TAIL_UNSOLVED` | Follow the tail skill's diagnostic table. It distinguishes epsilon dependence, missing letters/higher poles and the rational backend domain. |
| `TAIL_FAIL` from CHECK_CANONICAL | Read its failed full-prefix flags. A core that still passes calls for a full representative/tail correction, then SOLVE_TAIL and CHECK_CANONICAL on that changed proposal. |
| `nonrationalinv` or `remaining_algebraic_tail_outside_rational_CANONICA_domain` | Use the algebraic branch in the core/tail skill. Do not remove the rationality check or repeat the same backend call with more time. |
| `METHOD_EXHAUSTED` or `OUT_OF_SCOPE` | Record the exhausted method and ansatz. The coordinator selects the next applicable untried branch within budget, or reports the precise unresolved scope. |
| A source-gauge, identity, ordering or committed-prefix check fails | Resolve the named input/convention/composition mismatch before downstream steps. Preserve all lower-sector normalization in the cumulative map. |

Method exhaustion describes the attempted ansatz and bounds. If no implemented
method applies, report which new input or mathematical construction is needed.
Scientific acceptance uses the returned checker results; solver development is
a separately scoped task.

## 6. Operational failures

- Missing path: resolve it in the process that opens it. Artifact paths in WLS
  requests are relative to their declaring JSON; state artifact paths use the
  returned project root. Do not guess another checkout or copy whole trees.
- Tool/import/Singular error: inspect the actual stderr and declared runtime.
  Complete the family momentum/kinematic rules before retrying a candidate
  search. A container shell and a bridged Wolfram process can have different PATHs.
- Timeout: retain partial stdout/stderr and the last saved artifact. Identify
  the stage before extending its budget; cancellation must reach a bridged job.
  No output does not by itself establish a dead kernel or mathematical failure.

Read [installation](../../docs/installation.md) for the host contract. Once the
specific operational condition is fixed, resume the affected step. Do not repeat
accepted sectors, candidate reductions or unchanged scientific checks simply
because a new agent takes over.
