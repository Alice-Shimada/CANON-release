---
name: canon-libra-core
description: Propose a rational core using the single-variable Libra route or an explicit finite multivariable direction sequence with shared regulator factorization.
---

# Libra rational-DE core candidates

## Routing contract

- **Role / stage:** transformation provider, `SEARCH_CORE`.
- **Activation:** a main direct-DE method selected under
  [core selection](../../skills/canon-search-core/SKILL.md).
- **Boundary:** read the ordered current-sector cut; propose its rational
  gauge transformation without changing the lower-sector basis.
- **Attempt:** for one variable, optional bounded normalization, `Fuchsify`
  and one `FactorOut`. For multiple variables, an explicitly requested finite
  `Fuchsify` sequence followed by one joint coefficient-equation solve.
- **Handoff:** provisional `core_candidates` to `CHECK_CORE`; return the stopped
  stage and evidence when the bounded route is exhausted.

## Trigger and scope

Use the caller's supplied, loaded Libra package to propose an epsilon-form
transformation for a small rational current-sector cut system. CANON does not
install or register Libra and assumes no particular tool workspace layout.

The default route has exactly one kinematic variable and a rational square
DE matrix small enough for headless `Fuchsify` followed by `FactorOut`.
For a multivariable cut, explicitly supply `method_options.direction_sequence`
as described below. Its presence selects the bounded multivariable route.
The runner uses Mathematica with ``Libra`$LibraUseFermat = False``.
Fermatica, `BirkhoffGrothendieck`, interactive visual operations, algebraic
roots, and physical boundary conditions are outside this card's scope.

Multivariable input without a direction sequence returns
`INCONCLUSIVE/OUT_OF_SCOPE` before package loading. Read
[multivariable capabilities and limits](references/multivariable.md).
`EFormQ` checks
epsilon factorization, not dlog alphabet membership. The independent canonical
checks remain necessary.

## Capability and cost hierarchy

These are implementation priorities, not an execution sequence. Choose the
applicable core route first, then its shared controls. Use retained stage costs;
dimension alone is not a cost threshold and needs no trial solely to estimate it.

| Level | Workflow use | Cost and implementation boundary |
|---|---|---|
| Shared factorization controls | [Exact reference and finite parameter choices](#exact-reference-and-free-parameter-choices) address singular specializations in either route. | Small implementation scope; trials reuse the solved template but retain bounded validation cost. Defaults stay unchanged. |
| Scoped core constructions | Small single-variable core; [bounded normalization](#explicit-bounded-normalization-within-search_core) for supported integer offsets; [explicit multivariable sequence](#explicit-multivariable-direction-sequence), using `[]` when already Fuchsian. | Choose the smallest supported construction. Dense coefficient extraction and elimination can dominate; these routes produce only a core. |
| Separate solver development | A named capability gap or measured bottleneck warrants another backend or broader normalization. | Separate implementation and independent tests; keep `GaussSolve` unless replacement evidence justifies a change. |

Route stopped attempts through the workflow's
[result and budget rules](../../skills/canon-workflow/SKILL.md#5-result-routing).
Record changed hypotheses and allocations in the existing decision note.

## Inputs, invocation, and dependent rows

From `project_root`, run
`python3 run_step.py INPUT.json OUTPUT_DIR --method libra`
with standard `SEARCH_CORE` input,
`sector_basis`, `sector_cut_de`, and an available Wolfram kernel.
Supply `method_options.package_entry`, relative
to `input.json` if not absolute, or install the `Libra` context on Wolfram
`$Path` for `FindFile["Libra`"]`. The card records the entry, SHA-256,
resolution source, reported Libra version, and Wolfram `$Version`/`$SystemID`.
It does not read hep-tools machine state.

On the single-variable route, when `method_options.dependent_row_strategy` is
omitted or `automatic`, the card keeps Libra's single automatic `FactorOut`
call. For `sector-de-closure`,
provide a `canon-neu/libra-dependent-row-hierarchy/v1` artifact in `payload`.
Its `sector_hierarchy` is an `n×n` binary relation mask in the cut basis order,
not a row list. Its diagonal must be all ones; cycles are allowed. It must
bind sector/family/basis IDs and the complete basis order, with ordered
`master_sector_labels`, `producer`/`tool_revision`, `MappedSectors=False`,
source artifact/hash, and a positive integer `max_mask_nonzeros`.

The single-variable explicit route derives `hde` from the actual post-Fuchsify residue matrices
with the semantics of Libra's automatic call and computes
`TClosure[hsector+hde]`. The budget counts mask ones after closure. If exceeded,
the card neither truncates nor uses `All`, retries, or calls `FactorOut`.
Within budget it calls `FactorOut[...,DependentRowIndices->combinedMask]`
once. Invalid schema, identity/order, mask, provenance, or budget is rejected
before searching.

## Result and next action

The card records the loaded Libra identity, exact transformation, full transformed
matrix list, and provider `EFormQ`, without a literal version-equality gate.
Until `mma/CheckSectorCore.wls` independently checks it, output is only
`PROVISIONAL/CANDIDATE_TRANSFORMATION`; the provider never returns `PASS` or
a mathematical `FAIL`. The explicit hierarchy route also records the strategy,
artifact identity/hash, `MappedSectors` mode, stage, dimension,
`hsector`/`hde`/combined-mask counts and budget. The default free-parameter
choice remains all ones; explicit alternatives are described below.
After `CHECK_CORE` passes, continue with `BUILD_FULL_DE`,
`SOLVE_TAIL`, and `CHECK_CANONICAL`; use `FINAL_CHECK` when the stated scope is
complete.

Unresolved `Fuchsify` or `FactorOut` stages return
`INCONCLUSIVE/METHOD_EXHAUSTED`; invalid or nonflat input returns
`ERROR/INVALID_DIFFERENTIAL_SYSTEM`. Exhaustion applies to this bounded route,
not to the existence of a canonical basis. There is no silent fallback to
`Rookie`, interactive operations, Fermatica, CANONICA, INITIAL, or rewriting
the lower-sector basis. Return the stopped stage and its evidence to the
workflow entry.

## Exact reference and free-parameter choices

These options apply to both routes:

| Option | Default | Meaning |
|---|---:|---|
| `reference_regulator` | exact `1/2` | JSON integer or `{"numerator": 1, "denominator": 2}` with integer numerator and nonzero integer denominator |
| `free_parameter_strategy` | `ones` | One all-ones trial, or explicit `bounded-rational-search` |
| `free_parameter_max_trials` | 64 | Positive integer trial cap; may be supplied only with `bounded-rational-search` |

Approximate references (including JSON `0.5`), unknown strategies and invalid
budgets return `ERROR/INVALID_OPTIONS` before loading Libra. A singular reference
returns `INCONCLUSIVE/METHOD_EXHAUSTED` with `REFERENCE_EPSILON_SINGULAR`;
it is not a failure of the generic symbolic system. Selecting another exact
reference is a caller decision, never an automatic retry.

The bounded policy tries all ones, all zeros, then each unit vector, in that
order, stopping at the first valid factor or the trial cap. Duplicated points
are omitted for zero or one free parameter. Every trial checks exact rational
shape and generic invertibility. Multivariable trials also check kinematic
constancy, every coefficient equation and the shared reference identity in
**all** directions. Single-variable bounded trials check exact epsilon
factorization of the transformed connection. The ordinary provider endpoint
and independent `CHECK_CORE` checks still apply.

Evidence records the exact reference string, strategy, trial values,
determinants, validation flags and selected index. Multivariable trial details
are in the WL provider/diagnostic artifact; the JSON summary gives counts and
bounds. Single-variable details are in `summary.dependent_rows`. A truncated
policy reports `FREE_PARAMETER_BUDGET`; failure of all tried points describes
this finite policy, not nonexistence of an invertible intertwiner. Neither
option enlarges a time budget or changes the coefficient domain.

## Explicit multivariable direction sequence

For example, for a cut with `variables={x,y}`:

```json
{"direction_sequence": [1, 2], "factorization_max_equations": 4096,
 "max_wall_seconds": 60}
```

These are `method_options`, alongside the existing `package_entry` and optional
`dependent_row_strategy`. Indexes are one-based positions in the cut's ordered
variables. The sequence is a scientific proposal selected by the agent. Subsets,
repeated directions and `[]` are allowed. An empty sequence requests only shared
factorization of an already Fuchsian connection. The provider neither adds
directions nor retries a different order. The sequence is valid only for a cut
with at least two distinct variables and a separate regulator.

Each requested `Fuchsify` transformation is applied to **all** directions.
After the sequence, every directional connection, including its singularity at
infinity, must pass Libra's `FuchsianQ`. A later directional transformation may
spoil an earlier one; local success alone is insufficient.

For the resulting matrices `A_a`, the adapter calls public
`FactorDependence[{A_a/eps,...},eps,mu,Solve->False,Sort->False]` to obtain
one shared transformation template and its linear equations. It clears rational
denominators and collects every coefficient in all declared kinematic variables.
One public `GaussSolve` call solves those equations over the generic rational
coefficient field. Before solving, exact numeric content is removed and
proportional duplicates are dropped in first-occurrence order. Symbolic factors
are retained, and every selected factor is checked against the original
coefficient equations and every directional identity. Free parameters follow
the selected finite policy above. The result
must be exact rational, generically invertible and independent of all kinematic
variables, and must satisfy every coefficient equation. There is no sampling or
regulator-zero specialization of the symbolic system. The selected exact reference
`eps=mu` must be defined.

`factorization_max_equations` is a positive integer, default 4096. It counts
nonzero monomial coefficients before deduplication. Exceeding it stops before
the linear solve; equations are never truncated. This bounds solver input size,
not the cost of generating a polynomial. The summary preserves that raw
`factorization_equation_count` and separately reports
`factorization_solver_equation_count` after numeric-content deduplication
(`null` until extraction and deduplication finish). Deduplication reduces
redundant solve work; it does not remove coefficient-extraction cost.
`max_wall_seconds` is a finite positive
number, default 60, shared by the whole multivariable proposal. These two options
require an explicit `direction_sequence` and do not change the legacy route.

The explicit `sector-de-closure` mask combines the supplied sector hierarchy
with the exact nonzero pattern of **all** symbolic directions. Its existing
identity, provenance and mask budget requirements still apply.

The full symbolic endpoint must remain Fuchsian and epsilon factorized in every
direction. Success returns the existing `core_candidates` artifact with the
complete cumulative transformation and full matrix list. It remains provisional
until `CHECK_CORE`; `BUILD_FULL_DE`, `SOLVE_TAIL`, `CHECK_CANONICAL` and
`FINAL_CHECK` retain their existing roles. No lower-sector basis is changed here.
This adds a pole-structure construction alongside CANONICA, without requiring
UT seeds, a declared alphabet or a full kinematic transformation ansatz.

Stopped attempts return `INCONCLUSIVE/METHOD_EXHAUSTED` and an exact
`libra_diagnostic` artifact containing the last retained cumulative transformation,
connection and local-step trace. The JSON summary records the stage, limits and
counts; mathematical expressions remain in WL artifacts. A `TIME_BUDGET` with
`timed_out=true` means the attempt did not finish, not that the construction
space has no solution. Singular reference values, failed Fuchsian endpoints,
singular free-parameter choices and unresolved coefficient equations describe
this proposal only. Diagnostics are not accepted cores or a resume interface.

## Explicit bounded normalization within SEARCH_CORE

This option applies to the single-variable route. Multivariable input with
`normalization_strategy=bounded` returns `INCONCLUSIVE/OUT_OF_SCOPE`.

`method_options.normalization_strategy` is `none` by default. This preserves the
existing six-symbol provider contract and the original Fuchsify/FactorOut route.
Select `bounded` explicitly to normalize integer residue offsets before those
same stages. This is an option inside the Libra SEARCH_CORE node; it neither
changes the core-selection order nor starts a separate scientific workflow.
It additionally requires public `GetSubspaces`, `Projector`, and `Balance`.

The optional budgets below are positive integers. They are valid only with
`normalization_strategy=bounded`; unknown options, invalid strategies, and
noninteger/nonpositive budgets return `ERROR/INVALID_OPTIONS` before package
loading. Omitted bounded budgets use the fixed defaults below.

| Option | Default | Bound |
|---|---:|---|
| `normalization_max_steps` | 8 | Accepted balance steps |
| `normalization_max_projectors` | 64 | Projector constructions, accumulated across all steps |
| `normalization_max_dimension` | 8 | Cut matrix dimension, checked before subspace construction |
| `normalization_max_seconds` | 30 | Total normalization stage time, including analysis and public primitive calls |

The existing task execution budget still applies to Fuchsify, FactorOut, and
the remaining runner. The normalization timer does not grant extra time to
those stages. Exhaustion never enlarges a budget, truncates a projector,
retries another strategy, or silently falls back to the `none` route.

The bounded domain is one exact rational variable with analyzable linear pole
factors and Infinity. Pole positions must be independent of epsilon. The
connection at epsilon zero must be defined and Fuchsian at every singularity;
this is distinct from requiring the generic-epsilon connection to be Fuchsian.
Existing generic-epsilon irregularities are allowed only while their pole
ranks do not increase under a proposed balance. Generic residue eigenvalues
must be exact rational expressions whose epsilon-zero intercepts can be
proved to be integers. Nonlinear/algebraic pole factors, moving epsilon poles,
undefined epsilon-zero limits, irregular epsilon-zero connections, noninteger
intercepts, or parameter-dependent undecidable intercepts return a specific
`INCONCLUSIVE/OUT_OF_SCOPE` limit. No parameter or regulator specialization is
used to make an undecidable intercept pass.

At each finite step, the adapter calls `GetSubspaces` on the generic-epsilon
matrix with `All->False` and `UseFermat->False`. It considers individual Jordan
tower prefixes and prefixes of the returned ordered tower list. It pairs
equal-dimensional left/right subspaces at distinct singularities, up to the
global projector budget. It does not enumerate arbitrary tower subsets or
call `Rookie`, and it never constructs Jordan data first at epsilon zero.

Each proposed projector must have the expected rank and satisfy `P.P=P`.
Each balance must be exact rational and invertible. The adapter verifies both
the local and cumulative source identity `A.T-D[T,x]-T.B=0`, recomputes all
singularities (including Infinity), checks that no generic pole rank increases,
and requires the sum of absolute integer residue intercepts over all
singularities to decrease strictly. Rejected candidates remain in the trace.
Only a zero final deviation completes normalization; lack of a progressing
candidate or a budget limit returns `INCONCLUSIVE/METHOD_EXHAUSTED`.

For `A=(1+eps)/x`, Libra's ordered balance endpoints
`Balance[{{1}},{x,Infinity,0}]` produce `T=x` and `B=eps/x`. For
`A={{(1+eps)/x,eps},{0,eps/x}}`, the corresponding rank-one projector produces
`T=DiagonalMatrix[{x,1}]` and `B=eps {{1,1},{0,1}}/x`. Libra's reversed endpoint
order `{x,0,Infinity}` produces `1/x`; the adapter preserves the package's
actual convention. The second source has a generic rank-one irregularity at
Infinity, although its epsilon-zero connection is Fuchsian; the accepted
balance removes that irregularity and preserves the final generic Jordan
connection. These examples remain provisional until independent CHECK_CORE.

Successful output remains the standard `core_candidates` artifact with the
complete cumulative transformation and source basis order. Candidate
`provider_evidence.normalization` and `result.summary.normalization` record the
strategy, actual budgets, dimension, elapsed time, steps/projector count,
initial/final singularity data, rejected and accepted attempts, exact balance
matrices, cumulative transformation, and individual verification outcomes.
Limits also record `limit_code`, `stopped_stage`, and available partial
transformation history. `timed_out` is true for `SECONDS_BUDGET` and false for
other outcomes; use the workflow's operational recovery for an interrupted attempt.
The lower-sector prefix is never changed.
