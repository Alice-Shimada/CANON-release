---
name: canon-libra-core
description: Propose a core transformation for a small exact rational one-variable cut DE using bounded Libra Fuchsify and FactorOut stages.
---

# Libra rational-DE candidates: current automatic scope is one variable

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

## Multivariable capabilities and the runner's limit

Libra's `NewDSystem[ds,{x->Mx,y->My,...}]` stores a multivariable connection.
`Transform[ds,t]` updates every direction with its corresponding derivative
term, and `EFormQ[ds,eps]` checks all directions. The one-variable restriction
belongs to this runner, not to Libra as a whole.

`Fuchsify[ds,x]`, `FactorOut[ds,x,eps,mu]`, and visual balancing first construct
a transformation from the selected direction `ds[x]`. The bundled two-variable
tutorial applies `Fuchsify[ds,x]` and `Fuchsify[ds,y]` as needed, each followed
by `Transform[ds,t]` on the full system. It then combines samples of all
directions at common exact kinematic points for `FactorDependence` to find a
shared epsilon-factorization transformation. The bundled three-variable
presentation combines directional `VisBalancing`, single-direction `FactorOut`,
and `BlockTriangularToFuchsian`, then partially specializes each matrix only
in its own differential variable before `FactorDependence`. These examples
demonstrate multivariable use of the components; the presentation also lists
more systematic multivariable treatment as future work.

A noninteractive sequence of directional `Fuchsify` calls would therefore be
a bounded design based on those APIs, not an already validated capability of
this card. Such an implementation would need explicit variable traversal and
revisit rules, deterministic nonsingular sample choices, and saved samples.
Partial or full specialization can propose candidates but cannot certify them.
Acceptance still requires joint exact gauge, directional Fuchsianity, flatness,
and epsilon-factorization checks on the unspecialized full symbolic system.
Until that loop is implemented and validated, the runner returns
`INCONCLUSIVE/OUT_OF_SCOPE` for multivariable input, without a mathematical
rejection of the candidate.

`EFormQ[ds,eps]` only checks that dividing each connection matrix by `eps`
removes its `eps` dependence. It does not establish membership in a dlog
alphabet. Multivariable canonical acceptance also needs CANON's independent
multivariable dlog decomposition checks.

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
