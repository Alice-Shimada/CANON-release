# Optional Libra controls

Use these contracts only when selecting the corresponding option in
[the Libra card](../SKILL.md). The ordinary single-variable call needs none of
these additional inputs. Every route returns a provisional core for CHECK_CORE;
these controls do not add acceptance gates or change the lower-sector basis.

## Explicit dependent-row hierarchy

On the single-variable route, when `method_options.dependent_row_strategy` is
omitted or `automatic`, the card keeps Libra's single automatic `FactorOut`
call. For `sector-de-closure`,
provide a `canon-neu/libra-dependent-row-hierarchy/v1` artifact as
`payload.dependent_row_hierarchy`.
Its `sector_hierarchy` is an `n×n` binary relation mask in the cut basis order,
not a row list. Its diagonal must be all ones; cycles are allowed. It must
bind sector/family/basis IDs and the complete basis order, with ordered
`master_sector_labels` and a positive integer `max_mask_nonzeros`. Its
`provenance` records `producer`, `tool`, `tool_revision`, `mapped_sectors -> False`,
`source_artifact` and `source_sha256`.

The single-variable explicit route derives `hde` from the actual post-Fuchsify residue matrices
with the semantics of Libra's automatic call and computes
`TClosure[hsector+hde]`. The budget counts mask ones after closure. If exceeded,
the card neither truncates nor uses `All`, retries, or calls `FactorOut`.
Within budget it calls `FactorOut[...,DependentRowIndices->combinedMask]`
once. Invalid schema, identity/order, mask, provenance, or budget is rejected
before searching.

For a multivariable proposal, `sector-de-closure` instead combines the supplied
sector hierarchy with the exact nonzero pattern of all symbolic directions.
The same identity, provenance and mask budget requirements apply.

Evidence records the strategy, hierarchy identity/hash, `MappedSectors` mode,
stage, dimension, `hsector`/`hde`/combined-mask counts and budget.

## Exact reference and finite parameter policy

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

## Bounded single-variable normalization

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
