---
name: canon-solve-tail
description: Complete a passing sector core, infer supported dlog letters, and diagnose unresolved lower-sector couplings.
---

# Solve the current tail

## Invocation

After CORE_PASS and BUILD_FULL_DE, invoke:

```text
python3 run_step.py INPUT_JSON OUTPUT_DIRECTORY
```

Use a `SOLVE_TAIL` envelope with `full_sector_de` and `core_transform` from the
same selected candidate. Provide `method_options.package_entry` for an installed
CANONICA when a rational backend solve is needed. Already solved and supported
algebraic completions need no package call. Read `OUTPUT_DIRECTORY/result.json`;
an exit code of zero alone does not mean success.

| Result | Next action |
|---|---|
| `PASS/TAIL_READY` | Pass the returned `sector_transform` and the same `full_sector_de` to CHECK_CANONICAL. Commit only its passing result. |
| `INCONCLUSIVE/TAIL_UNSOLVED` | Read `summary.reason` and `summary.diagnostics`, then use the evidence table below. Keep the latest accepted prefix and saved full DE. |
| `ERROR/TOOL_UNAVAILABLE` | Supply the declared backend installation; no mathematical search has been exhausted. |
| `ERROR/EXECUTION_INTERRUPTED` | Resume or revise the interrupted computation; this is not a failed ansatz. |
| `ERROR/INVALID_TAIL_INPUT` | Repair the selected-candidate binding before solving. |
| No result, or a process timeout | Inspect retained stdout/stderr and the last actual stage before changing the budget. Do not infer mathematical failure. |

The returned transform is the complete prefix map, including any changed lower
normalization. Carry it and its alphabet together into CHECK_CANONICAL and
COMMIT_SECTOR. Do not splice in only the current-sector diagonal block.

## Bounded CANONICA controls and continuation

The legacy backend uses `tail_strategy="monolithic"` by default. Core-card
options do not configure this node. Its separate `method_options` contract is:

| Option | Default | Meaning |
|---|---:|---|
| `package_entry` | Wolfram package lookup | CANONICA entry for a needed backend call |
| `tail_strategy` | `monolithic` | `monolithic` or explicit `subsector` |
| `d_delta_numerator_degree` | 0 | Nonnegative integer degree increment for D |
| `max_wall_seconds` | 60 | Positive shared time limit for backend D stages and epsilon normalization |
| `max_subsector_steps` | 64 | Positive per-attempt step budget; explicit option requires `subsector` |
| `max_ansatz_terms` | 256 | Positive integer limit for a supplied finite D ansatz |

Unknown options and invalid budgets return `ERROR/INVALID_OPTIONS`. Built-in
algebraic and affine proposals run as before. If their rational remainder needs
the backend, `subsector` infers contiguous blocks from the actual transformed
active lower DE using CANONICA's public sector API, checks their triangularity,
and calls `CalculateNextSubsectorD` once per remaining lower block. Trace entry
counts are not matrix widths. The completed D is lifted into the full prefix,
then full-prefix epsilon normalization runs. Stage messages, block bounds,
timing, attempted ansatz and stopped reason are retained in `summary.backend`.

For a directed attempt, provide `payload.d_ansatz`, a SHA-256 descriptor for
`canon-neu/canonica-rational-ansatz/v1`, with `kind -> "D"`. Its `identity`
binds `sector`, `family_id`, `current_basis_id`, `accepted_prefix_id`,
`candidate_id`, `source_basis`, `regulator`, and `source_de_sha256` (the input
full-DE file's byte hash). Its `scope` is
`<|"block_bounds" -> {activeLowerDimension+1,activeDimension}|>`, its
`variables` match the full DE, and its nonempty `terms` contain only exact
rational functions of those kinematic variables. Regulator-dependent terms,
roots, unknown symbols, wrong source/block, or too many terms are rejected.
The artifact is a rational-function basis for each D solve, not a matrix of
preselected coefficients. Explicit D input requires `subsector`.

When a bounded subsector attempt stops, `TAIL_UNSOLVED` can include a hashed
`tail_checkpoint` artifact. Pass that descriptor as `payload.tail_checkpoint`
with `tail_strategy="subsector"` to continue the remaining blocks. Validation
binds the complete source, selected candidate, base transformation, active rows,
partition and package entry hash; it also checks the partial D's shape and
rational domain. Changed sources or malformed checkpoints return input errors.
Checkpoint progress establishes no canonical claim. A resumed complete result
still goes through CHECK_CANONICAL and FINAL_CHECK. The step budget is local to
the new attempt; no automatic resume or budget increase occurs.

## What the script tries automatically

The script applies the following proposals to matching input structures.

| Structure | Built-in proposal |
|---|---|
| Regulator-only common factors in the tail | Try an exact rational normalization directly to epsilon form, including factors such as `1 - 2 eps`; use the affine normalization only if residual epsilon dependence remains. |
| Affine normalized tail `R0 + eps R1` | An algebraic primitive of `R0` in every variable, followed by a lower-sector shear. |
| One current master and one supported quadratic root | A neutral lower lift when needed, then a primitive with coefficient `1/(1+2 c eps)` from the scalar radicand residue. This can remove higher poles of a `1/q` primitive. |
| Several current masters | A bounded completion from the simplest row and its first derivatives; an exact full-rank cut aligns the rows. |
| Remaining rational coefficients | CANONICA off-diagonal completion and full-prefix epsilon normalization. |

Each completion still needs the existing exact epsilon and shared-dlog gates.
None of these ansatzes is a complete solver for arbitrary algebraic tails.
See [normalization and tails](../canon-search-core/references/normalization-and-tails.md)
for the gauge convention, equations and algebraic-letter construction.

## Alphabet input is optional

Use `declared_alphabet: null` at BUILD_FULL_DE when no alphabet is supplied.
SOLVE_TAIL extracts pole-factor candidates and proposes supported quadratic-root
ratios directly from the DE. A user-provided complete alphabet is not a
prerequisite for attempting the solve. Explicit letters, when available, use
ordinary exact Wolfram expressions in a `canon-neu/declared-alphabet/v1` artifact.
The shared-residue checker determines whether the proposed span is sufficient.

## Replan from the actual obstruction

Diagnostics describe the matrices retained after the built-in attempts, not a
proof about every possible basis. `current_master_count`, `epsilon_factorized`,
`affine_in_epsilon`, `rational_coefficients` and `alphabet_candidate_count` let
the coordinator distinguish the following cases without repeating the same run.

| Evidence | Next bounded hypothesis |
|---|---|
| Epsilon factorization fails | Inspect exact `Together[B_i/eps]` and a failing coupling. Change the rational epsilon normalization or full integral representative; integer-power scans cannot remove mixed epsilon factors. |
| Epsilon factorization passes, dlog fitting fails | Inspect both the letter span and pole orders on the algebraic cover. Root-odd terms need suitable algebraic letters; `dQ/q^3 = 2 dq/q^2` needs a basis repair before letters can suffice. |
| `remaining_algebraic_tail_outside_rational_CANONICA_domain` | Built-in proposals did not solve this algebraic input. Use a motivated representative/Gram correction, an explicit algebraic-letter proposal, or a genuine rationalizing chart with its full Jacobian. Do not send the same input to the rational backend with a longer timeout. |
| `backend_no_transformation` | Inspect the rational backend's retained output and change the failed ansatz or representative within budget. |
| `subsector_budget_exhausted` with `tail_checkpoint` | Review the completed blocks and budget. Continue the bound checkpoint only when further bounded work is warranted. |
| `subsector_no_transformation` | Use the recorded failing lower block and package messages to revise the finite D ansatz or full representative. Preserve completed-block evidence. |
| `epsilon_normalization_no_transformation` | D completion alone is insufficient; inspect the full-prefix epsilon-normalization stage and its messages. |

For a backend failure, `summary.backend_stage` is `TransformOffDiagonalBlock`
(off-diagonal completion on the active closure) or `TransformDlogToEpsForm`
(full-prefix epsilon normalization). The `backend_failure` descriptor points to
`backend-failure.wl`, a `canon-neu/tail-backend-failure/v1` Association. It records
the stage, candidate, resolved package entry, and immediate call context:
variables, backend regulator, active positions, sector boundaries, initial
transformation, matrices, and explicit options. `backend_return` contains the
actual saved return under `HoldComplete`, so loading the artifact keeps that
return inert. Wrong-sized, singular or inexact backend transformations are
also retained as failed backend returns. The diagnostic makes no additional backend call. It preserves
`INCONCLUSIVE/TAIL_UNSOLVED` and the bounded backend failure reason; a returned `False`
does not identify a finer cause or prove that every ansatz is exhausted.
Non-backend unsolved results omit these backend-specific fields and artifacts.

For a family-based UT/canonical search, reconsider the bounded integral-candidate route
if it has not supplied the needed full representative. Follow the evidence-based
choices in the [core-selection skill](../canon-search-core/SKILL.md). A passing core
only covers the diagonal block. Reuse existing reductions and the accepted lower
prefix; one unresolved tail does not require rebuilding the whole family.
