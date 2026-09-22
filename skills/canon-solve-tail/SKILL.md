---
name: canon-solve-tail
description: Complete a passing sector core, infer supported dlog letters, and diagnose unresolved lower-sector couplings.
---

# Solve the current tail

## Invocation

After CORE_PASS and BUILD_FULL_DE, invoke:

```text
wolframscript -file mma/SolveTail.wls INPUT_JSON OUTPUT_DIRECTORY
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
| No result, or a process timeout | Inspect retained stdout/stderr and the last actual stage before changing the budget. Do not infer mathematical failure. |

The returned transform is the complete prefix map, including any changed lower
normalization. Carry it and its alphabet together into CHECK_CANONICAL and
COMMIT_SECTOR. Do not splice in only the current-sector diagonal block.

## What the script tries automatically

The script applies the following proposals to matching input structures.

| Structure | Built-in proposal |
|---|---|
| Regulator-only common factors in the tail | Exact rational epsilon normalization, including factors such as `1 - 2 eps`. |
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

For a family-based UT/canonical search, reconsider the bounded integral-candidate route
if it has not supplied the needed full representative. Keep DlogBasis-refine's
priority from the [core-selection skill](../canon-search-core/SKILL.md). A passing core
only covers the diagonal block. Reuse existing reductions and the accepted lower
prefix; one unresolved tail does not require rebuilding the whole family.
