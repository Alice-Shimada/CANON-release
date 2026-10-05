---
name: canon-libra-core
description: Propose a core transformation for a small exact rational one-variable cut DE, with optional bounded normalization before Libra Fuchsify and FactorOut.
---

# Libra rational-DE candidates: current automatic scope is one variable

## Routing contract

- **Role / stage:** transformation provider, `SEARCH_CORE`.
- **Activation:** a main direct-DE method selected under
  [core selection](../../skills/canon-search-core/SKILL.md).
- **Boundary:** read the ordered current-sector cut; propose its rational
  gauge transformation without changing the lower-sector basis.
- **Attempt:** optional bounded normalization, then `Fuchsify` and one `FactorOut` call using the selected
  dependent-row strategy and the task's execution budget.
- **Handoff:** provisional `core_candidates` to `CHECK_CORE`; return the stopped
  stage and evidence when the bounded route is exhausted.

## Trigger and scope

Use the caller's supplied, loaded Libra package to propose an epsilon-form
transformation for a rational current-sector cut system. Libra itself can
store and transform multivariable DEs; this runner implements and has been
validated only for small single-variable automatic problems. CANON does not
install or register Libra and assumes no particular tool workspace layout.

The supported input has exactly one kinematic variable and a rational square
DE matrix small enough for headless `Fuchsify` followed by `FactorOut`.
The runner uses Mathematica with ``Libra`$LibraUseFermat = False``.
Fermatica, `BirkhoffGrothendieck`, interactive visual operations, algebraic
roots, and physical boundary conditions are outside this card's scope.
For defined-family UT or canonical integral-basis discovery, respect the bounded
[workflow entry](../../skills/canon-workflow/SKILL.md); an available rational
DE alone is not a reason to skip integral candidates.

Multivariable input returns `INCONCLUSIVE/OUT_OF_SCOPE`. For work on extending
the adapter, read [multivariable capabilities and limits](references/multivariable.md);
those package capabilities are not implemented by this runner. `EFormQ` checks
epsilon factorization, not dlog alphabet membership. The independent canonical
checks remain necessary.

## Inputs, invocation, and dependent rows

From `project_root`, run
`wolframscript -file methods/libra/run.wls INPUT.json OUTPUT_DIR`
with standard `SEARCH_CORE` input,
`sector_basis`, `sector_cut_de`, and an available Wolfram kernel.
Supply `method_options.package_entry`, relative
to `input.json` if not absolute, or install the `Libra` context on Wolfram
`$Path` for `FindFile["Libra`"]`. The card records the entry, SHA-256,
resolution source, reported Libra version, and Wolfram `$Version`/`$SystemID`.
It does not read hep-tools machine state.

When `method_options.dependent_row_strategy` is omitted or `automatic`, the
card keeps Libra's single automatic `FactorOut` call. For `sector-de-closure`,
provide a `canon-neu/libra-dependent-row-hierarchy/v1` artifact in `payload`.
Its `sector_hierarchy` is an `n×n` binary relation mask in the cut basis order,
not a row list. Its diagonal must be all ones; cycles are allowed. It must
bind sector/family/basis IDs and the complete basis order, with ordered
`master_sector_labels`, `producer`/`tool_revision`, `MappedSectors=False`,
source artifact/hash, and a positive integer `max_mask_nonzeros`.

The explicit route derives `hde` from the actual post-Fuchsify residue matrices
with the semantics of Libra's automatic call and computes
`TClosure[hsector+hde]`. The budget counts mask ones after closure. If exceeded,
the card neither truncates nor uses `All`, retries, or calls `FactorOut`.
Within budget it calls `FactorOut[...,DependentRowIndices->combinedMask]`
once. Invalid schema, identity/order, mask, provenance, or budget is rejected
before searching.

## Result and next action

The card records the loaded Libra identity, exact transformation, transformed
matrix, and provider `EFormQ`, without a literal version-equality gate.
Until `mma/CheckSectorCore.wls` independently checks it, output is only
`PROVISIONAL/CANDIDATE_TRANSFORMATION`; the provider never returns `PASS` or
a mathematical `FAIL`. The explicit hierarchy route also records the strategy,
artifact identity/hash, `MappedSectors` mode, stage, dimension,
`hsector`/`hde`/combined-mask counts, budget, and deterministic `C[*] -> 1`
specialization. After `CHECK_CORE` passes, continue with `BUILD_FULL_DE`,
`SOLVE_TAIL`, and `CHECK_CANONICAL`; use `FINAL_CHECK` when the stated scope is
complete.

Unresolved `Fuchsify` or `FactorOut` stages return
`INCONCLUSIVE/METHOD_EXHAUSTED`; invalid or nonflat input returns
`ERROR/INVALID_DIFFERENTIAL_SYSTEM`. Exhaustion applies to this bounded route,
not to the existence of a canonical basis. There is no silent fallback to
`Rookie`, interactive operations, Fermatica, CANONICA, INITIAL, or rewriting
the lower-sector basis. Return the stopped stage and its evidence to the
workflow entry.

## Explicit bounded normalization within SEARCH_CORE

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
transformation history. The lower-sector prefix is never changed.
