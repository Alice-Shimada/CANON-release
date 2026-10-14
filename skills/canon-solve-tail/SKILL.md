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
same selected candidate. With the default component, the built-in proposals below
run automatically before a needed rational backend solve. Provide
`payload.method_options.package_entry` for an installed
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

## What the script tries automatically

One SOLVE_TAIL invocation selects and applies these proposals from the input
structure. The agent does not dispatch the internal branches separately.

| Structure | Built-in proposal |
|---|---|
| Regulator-only common factors in the tail | Try an exact rational normalization directly to epsilon form, including factors such as `1 - 2 eps`; use the affine normalization only if residual epsilon dependence remains. |
| Affine normalized tail `R0 + eps R1` | An algebraic primitive of `R0` in every variable, followed by a lower-sector shear. |
| One current master and one supported quadratic root | A neutral lower lift when needed, then a primitive with coefficient `1/(1+2 c eps)` from the scalar radicand residue. This can remove higher poles of a `1/q` primitive. |
| Several current masters | A bounded completion from the simplest row and its first derivatives; an exact full-rank cut aligns the rows. |
| Remaining algebraic connection with kinematically constant dlog residues | Solve the full-prefix residue intertwiner for an exact rational function of epsilon, including gauges singular at epsilon zero. |
| Remaining rational coefficients | CANONICA off-diagonal completion, then supported fixed-pole lower-shear repair and full-prefix epsilon normalization. |

Each completion still needs the existing exact epsilon and shared-dlog gates.
None of these ansatzes is a complete solver for arbitrary algebraic tails.
The default runner reports `summary.builtin_completion` with `attempted`,
`method` and `solved`, even when a later backend stage fails. `solved` describes
the built-in proposal; only the final result and independent checks establish
the outgoing claim.

The algebraic dlog normalization is an internal fallback, after the existing
primitive and derivative proposals. It uses the same `max_wall_seconds` control
(60 seconds by default), with fixed finite bounds: dimension 128, alphabet 128,
400,000 equations, algebraic field basis 256, and two million stored sparse
coefficients (with a separate bound on the resulting nullspace). It tries exact nonzero reference values and
finite free-parameter choices; it does not solve arbitrary kinematic gauges or
remove higher-order poles. Its optional
`summary.builtin_completion.dlog_epsilon_normalization` receipt records the
actual stage, including a time or size limit. Such a limit or failed search
remains inconclusive. The rational backend retains its whole-input domain guard.

After rational D completion, the same full-prefix residue solver runs inside
SOLVE_TAIL. It assembles individual linear coefficients, reduces rational rows
first and orders them by sparsity; regulator-dependent rows are reduced exactly
over the rational-function field. Every full-prefix equation and free direction
is retained, including inactive-to-active couplings. Already epsilon-factorized
residues need no linear solve. This stage shares the remaining backend wall
budget and retains the native normalization fallback.

For one rational variable, epsilon-Fuchsian lower/current diagonal blocks and
fixed rational poles, a bounded lower shear first removes higher finite poles
and polynomial infinity terms. Its 64 corrections, dimension 128 and two-million
Sylvester-entry limits are internal bounds. Unsupported roots, moving poles or
diagonal blocks retain the existing fallback. The shear preserves both diagonal
blocks and checks the complete exact differential gauge identity. This capability
uses the existing SOLVE_TAIL request and independent CHECK_CANONICAL gate.

Before assigning an expensive experimental tail capability, reuse the matching
`summary.builtin_completion` receipt produced by the ordinary SOLVE_TAIL call.
If none exists, run an applicable bounded attempt or record the concrete skip
reason (unsupported domain, available budget, or selected replacement workflow).
Carry this receipt or reason into the development assignment. Reuse unchanged
evidence and honor the selected component's workflow.
See [normalization and tails](../canon-search-core/references/normalization-and-tails.md)
for the gauge convention, equations and algebraic-letter construction.

## Alphabet input is optional

Use `declared_alphabet: null` at BUILD_FULL_DE when no alphabet is supplied.
SOLVE_TAIL extracts pole-factor candidates and proposes supported quadratic-root
ratios directly from the DE. A user-provided complete alphabet is not a
prerequisite for attempting the solve. Explicit letters, when available, use
ordinary exact Wolfram expressions in a `canon-neu/declared-alphabet/v1` artifact.
The shared-residue checker determines whether the proposed span is sufficient.

## Bounded CANONICA controls and continuation

The default rational backend uses `tail_strategy="monolithic"`; an ordinary call
needs no finite D artifact or checkpoint. Select `subsector` only for a bounded
block attempt or continuation. Its block partition is inferred from the actual
DE. See [the optional backend contract](references/canonica-controls.md) for
options, a supplied `d_ansatz`, checkpoint identity and budgets. Core-card options
do not configure SOLVE_TAIL. These controls keep the same outgoing full-prefix
transformation and independent acceptance gates.

## Replan from the actual obstruction

Read this section when SOLVE_TAIL remains unresolved. Diagnostic fields are
output evidence; they add no required input or precondition to a normal call.
They describe the matrices retained after the built-in attempts, not every
possible basis. `current_master_count`, `epsilon_factorized`,
`affine_in_epsilon`, `rational_coefficients` and `alphabet_candidate_count` let
the coordinator distinguish the following cases without repeating the same run.

`coefficient_scopes` gives row/column counts and exact nonrational-entry counts
for `whole`, `current`, `current_to_lower`, `active_closure`, `inactive` and
`inactive_to_active`. `active_positions` is the dependency closure seeded by
all current rows in the retained post-proposal matrices; positions are one-based
in the complete prefix. The `current` and `inactive` scopes are their square
diagonal blocks. A nonrational lower block does not establish that the current
block or its direct tail is nonrational. Conversely, a rational active square
does not certify that lifting its transformation is safe: inspect inactive-to-active
couplings and complete-prefix epsilon normalization. These fields diagnose scope;
they neither relax the rational backend's whole-input guard nor replace the full
gauge and dlog checks. Root counts alone do not establish an obstruction.

| Evidence | Next bounded hypothesis |
|---|---|
| Epsilon factorization fails | Inspect exact `Together[B_i/eps]` and a failing coupling. Change the rational epsilon normalization or full integral representative; integer-power scans cannot remove mixed epsilon factors. |
| Epsilon factorization passes, dlog fitting fails | Inspect both the letter span and pole orders on the algebraic cover. Root-odd terms need suitable algebraic letters; `dQ/q^3 = 2 dq/q^2` needs a basis repair before letters can suffice. |
| `remaining_algebraic_tail_outside_rational_CANONICA_domain` | Built-in proposals did not solve this algebraic input. Use a motivated representative/Gram correction, an explicit algebraic-letter proposal, or a genuine rationalizing chart with its full Jacobian. Do not send the same input to the rational backend with a longer timeout. |
| `backend_no_transformation` | Inspect the rational backend's retained output and change the failed ansatz or representative within budget. |
| `subsector_budget_exhausted` with `tail_checkpoint` | Review the completed blocks and budget. Continue the bound checkpoint only when further bounded work is warranted. |
| `subsector_no_transformation` | Use the recorded failing lower block and package messages to revise the finite D ansatz or full representative. Preserve completed-block evidence. |
| `epsilon_normalization_no_transformation` | D completion alone is insufficient; inspect the full-prefix epsilon-normalization stage and its messages. |

For a backend failure, `summary.backend_stage` distinguishes off-diagonal
completion from full-prefix epsilon normalization. The `backend_failure`
descriptor retains the immediate call and inert saved return in
`backend-failure.wl`. Use the [backend evidence contract](references/canonica-controls.md#retained-backend-failure)
when inspecting that call. It makes no extra backend invocation; a returned
`False` identifies no finer cause and does not exhaust every ansatz.
Non-backend failures omit these backend-specific fields.

For a family-based UT/canonical search, reconsider the bounded integral-candidate route
if it has not supplied the needed full representative. Follow the evidence-based
choices in the [core-selection skill](../canon-search-core/SKILL.md). A passing core
only covers the diagonal block. Reuse existing reductions and the accepted lower
prefix; one unresolved tail does not require rebuilding the whole family.
