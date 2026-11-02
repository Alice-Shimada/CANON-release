---
name: canon-canonica-core
description: Propose rational current-sector core transformations with CANONICA using one default recursive attempt or a finite directed T ansatz, for a flat rational DE in one or more variables after selecting a direct-DE route.
---

# CANONICA current-cut candidate route

## Routing contract

- **Role / stage:** transformation provider, `SEARCH_CORE`.
- **Activation:** a main direct-DE method selected under
  [core selection](../../skills/canon-search-core/SKILL.md), justified by the
  family geometry, available inputs and current evidence.
- **Boundary:** read the ordered current-sector cut; propose its rational
  gauge transformation without changing `accepted_prefix`.
- **Attempt:** one `RecursivelyTransformSectors` call with declared degree
  options by default. An explicit finite `t_ansatz` instead selects one bounded
  sequence of public block stages on this same cut. No automatic degree
  expansion, retry, or other provider call.
- **Handoff:** provisional `core_candidates` to `CHECK_CORE`; return the failed
  stage and attempted options to the coordinator when no candidate is produced.

## Trigger and scope

Use compatible CANONICA 1.0.3 to propose a rational gauge transformation for the
current sector's cut differential system. CANON does not install or register
CANONICA and does not assume a particular tool workspace layout.

This card supports rational DE matrices in one or more kinematic variables,
with an explicit, fixed basis order, a flat connection, and sector boundaries
supplied by the artifact or inferred by CANONICA. Algebraic transformations,
elliptic systems, unbounded ansatz searches, and physical boundary conditions
are outside its scope. Defined-family proposal and candidate derivative
preparation follow the input stages in core selection.

A rational DE need not admit a rational gauge transformation. For example,
`A = (1/(2 x) + eps/x) dx` requires `old = Sqrt[x] new` to obtain
`B = eps dx/x`. On `nonrationalinv`, identify the required algebraic
normalization. This does not imply an invalid DE or the absence of a canonical
form. Removing a private rationality check does not extend the rational
algorithms in stock CANONICA.

Choose the next hypothesis from the evidence. If the rational core is regular
at epsilon zero, consider the finite [epsilon-zero ansatz](../epsilon-zero/SKILL.md).
If the integral geometry suggests a normalization or numerator, return to
integral candidates; see the [Gram card](../gram/SKILL.md) when applicable.
Transform every differential direction only when an actual rationalizing
coordinate chart is available; declaring `q^2 = Q(x)` alone is not a
rationalization. See [normalization and tails](../../skills/canon-search-core/references/normalization-and-tails.md)
for gauge conventions, root derivatives, and tail completion. These are
conditional choices, not an exhaustive fallback sequence.

## Inputs and invocation

From `project_root`, run
`python3 run_step.py INPUT.json OUTPUT_DIR --method canonica`
with the standard `SEARCH_CORE` input,
`sector_basis`, `sector_cut_de`, and an available Wolfram kernel. Supply CANONICA
through either:

1. `method_options.package_entry`, resolved relative to `input.json` when it
   is not absolute; or
2. a standard Wolfram `$Path` installation resolved by `FindFile["CANONICA`"]`.

The three `method_options` degree fields below are nonnegative integer
increments, each defaulting to `0`, preserving the package's default ansatz:

| Field | CANONICA option |
|---|---|
| `t_delta_numerator_degree` | `TDeltaNumeratorDegree` |
| `t_delta_denominator_degree` | `TDeltaDenominatorDegree` |
| `d_delta_numerator_degree` | `DDeltaNumeratorDegree` |

These fields bound one declared attempt; they do not add an automatic tuning
loop. Unknown options or invalid values return `ERROR/INVALID_OPTIONS` before
package loading. `max_wall_seconds` is a positive number, default `60`, shared
by every solver and verification stage of the attempt; `max_ansatz_terms` is a
positive integer, default `256`, bounding an explicit ansatz's list length. Set
the wall limit within the task's execution budget. A later enlarged ansatz is a
new coordinator-selected attempt with its own recorded scope.

The card records the resolved entry, resolution source, entry SHA-256, and
Wolfram `$Version`/`$SystemID`, together with the effective `ansatz_options`.
It does not require a machine-specific fixed hash; independent checkers decide
scientific acceptance.

The runner resolves, hashes, loads, and checks the package's public symbols
before evaluating `sector_cut_de`. This avoids creating ``Global`eps`` from the
input before package loading and triggering ``CANONICA`eps::shdw``. If both
the tool and input fail, the specific `ERROR/TOOL_*` takes precedence. Only
after that boundary passes can invalid or nonflat input return
`ERROR/INVALID_DIFFERENTIAL_SYSTEM`. This order is not provider fallback.

## Optional finite directed T ansatz

`payload.t_ansatz` is a `mathematica-expression` artifact descriptor containing
`path` and the file's mandatory `sha256`; relative paths are resolved from the
JSON input. Its WL association has schema
`canon-neu/canonica-rational-ansatz/v1` and the following fields:

```wl
<|"schema" -> "canon-neu/canonica-rational-ansatz/v1", "kind" -> "T",
  "identity" -> <|"sector" -> sector, "family_id" -> familyID,
    "basis_id" -> basisID, "source_basis" -> sourceBasis,
    "regulator" -> regulator, "source_de_sha256" -> cutFileSHA256|>,
  "scope" -> <|"block_index" -> blockIndex, "block_bounds" -> {firstRow, lastRow}|>,
  "variables" -> variables, "terms" -> {1, x, 1/(1 - x)}|>
```

Every identity field must match the current raw cut, including its complete
basis order and raw artifact byte SHA-256. The ordered variables must match
the cut; `block_index` and `block_bounds` must identify one supplied or inferred
boundary. `terms` is a nonempty finite list of exact rational functions of the
declared kinematic variables only. Approximate numbers, epsilon dependence,
undeclared symbols, symbolic powers, roots and special functions are rejected.
Bad schema, descriptor hash, identity, scope, variables or term budget returns
`ERROR/INVALID_ANSATZ` before a solver call.

The directed branch visits each declared block exactly once. It passes `terms`
as the public positional ansatz to `TransformNextDiagonalBlock`, which invokes
`TransformDiagonalBlock`; other blocks retain the package's default ansatz.
It then calls `TransformOffDiagonalBlock` and `TransformDlogToEpsForm` once for
that cut block, as in the public `TransformNextSector` implementation. These
internal cut stages remain `SEARCH_CORE`. They do not read lower physical
sectors or change `accepted_prefix`. The explicit list is never passed to
`RecursivelyTransformSectors` as an unsupported option.

The full returned transformation is checked against the original cut in every
differential direction, with exact rational coefficients and a nonzero
determinant, before emitting a provisional candidate. CHECK_CORE still decides
scientific acceptance.

## Diagnostics and shared control helper

`methods/canonica/Control.wl` exports functions in context
``CanonCANONICAControl` `` for the core runner and the separate tail operation:

- `CaptureStage[expr, stage, block, seconds, attemptedAnsatz:<||>]` has
  `HoldFirst` and returns `<|"result" -> value, "diagnostics" -> association|>`.
  It applies one finite time limit, retains raw messages in the caller's log,
  and records message tags, failed stage/block, elapsed time, timeout/abort,
  and the attempted options or artifact provenance.
- `LoadFiniteAnsatz[task, inputPath, payloadKey, expected, maxTerms]` returns
  `terms` and `provenance`, or `Failure["INVALID_ANSATZ", ...]`.
  `expected` contains `kind`, exact `identity`, exact `scope`, and ordered
  `variables`; callers bind their own source-gauge identity. The helper checks
  the descriptor hash, exact rational domain, declared variables and term cap.
- `ClassifyMessages[messageTags, stage]` groups necessary rational/trace
  conditions separately from finite ansatz and epsilon-normalization failures.

`result.json` retains the structured attempts, `diagnostics.wl` preserves their
WL receipt, and `canonica-messages.log` retains the original package messages.
The recursive branch localizes a failure from the returned completed partial
gauge when available; it does not replay the package to discover a stage.

| Evidence | Diagnostic class and meaning |
|---|---|
| `nonrationalinv`, `nonrationaltr` | `rational_transformation_obstruction`: the current rational route needs a changed normalization or chart hypothesis. |
| `noepsform`, `ndlogtr`, `trace` | `trace_necessary_condition_failed`: the package's necessary condition fails for this input. |
| `finiteansatzfailed`, `nosol`, or a silent failed finite stage | `finite_ansatz_exhausted`: the declared finite ansatz produced no solution. |
| `epsnormalization` or a failed explicit epsilon-normalization stage | `epsilon_normalization_failed`: the current normalization attempt failed. |
| Wall limit or abort | `time_budget_exhausted` or `aborted`: the attempt is operationally incomplete. |

Every scientific exhaustion remains `INCONCLUSIVE/METHOD_EXHAUSTED` for this
operation. A finite ansatz limit is not a proof that the family lacks a
canonical basis. Raw messages are retained even when the package words a
necessary-condition failure more broadly.

## Result and next action

Success writes `canon-neu/core-candidates/v1` using
`old_basis = transformation . new_basis`, with the entry, supplied or inferred
sector boundaries, alphabet, and provider epsilon-form result.
`mma/CheckSectorCore.wls` independently recomputes the acceptance conditions.
Provider success is `PROVISIONAL/CANDIDATE_TRANSFORMATION`; exhausted stages
return `INCONCLUSIVE/METHOD_EXHAUSTED`. A caught abort returns
`ERROR/EXECUTION_INTERRUPTED` and is not evidence of ansatz exhaustion; invalid or nonflat input returns
`ERROR/INVALID_DIFFERENTIAL_SYSTEM`. The card never returns `PASS` or a
mathematical rejection `FAIL`. Exhaustion concerns this method, not the family.

This card performs no IBP reduction, sector reordering, off-diagonal lower-sector
tail solve, or modification of `accepted_prefix`. CANONICA's separate use inside
`mma/SolveTail.wls` belongs to `SOLVE_TAIL`, with full-prefix inputs and a
`CHECK_CANONICAL` handoff; the options above apply only to this core runner.
This card cannot accept its own candidates. It calls neither Libra nor INITIAL
and is not a fixed fallback
after Libra. After `CHECK_CORE` passes, continue with `BUILD_FULL_DE`,
`SOLVE_TAIL`, and `CHECK_CANONICAL`; use `FINAL_CHECK` when the stated scope is
complete. On exhaustion, return the specific failed stage to the workflow entry.
