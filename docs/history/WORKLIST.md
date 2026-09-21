# Historical CANON scientific worklist (not a state board)

> This file preserves scientific design intent that remains useful as a
> reference. Its checkboxes and legacy `workflow.py` milestones are not current
> task status or authority and must not advance state. Current research state
> is managed only through `statemng` as defined in the root `AGENTS.md` and
> `README.md`. For active work, follow [the current agent workflow](../agent-workflow.md)
> and current skills. Status statements below retain their historical scope.

## Background

Persistent research is managed by the `statemng` MCP; agents perform scientific
calculations by calling explicit Mathematica interfaces.

## Goal

Construct and verify a canonical/UT basis sector by sector, keeping the process
simple, resumable, and checkable.

## 1. Orchestration framework

- [x] Complete per-overall-task `statemng` state directories, the MCP interface, and the Codex Local adapter
- [x] Complete the persistent-research claim/show/workspace/artifact/submit/review loop

## 2. Preprocessing and family preparation

- [x] Integrate a production typed family-spec
    `PrepareFamily.wls` binds the collaborator's declared family/basis identity,
    Kira/project sources, ordered masters, sector source, explicit regulator, and
    dimension rule; it does not infer scientific inputs

## 3. IBP reduction and DE construction

- [x] Perform IBP reduction
    The minimal Kira adapter runs explicit reduction/export jobs and returns only
    masters in Kira's original order and fully back-substituted rules; positive
    tests check exact target coverage and closure of all RHS expressions on masters
- [x] Construct and check the DE
    The purely in-memory `BuildDifferentialEquations[family, masters, rules]`
    retains only affine master derivatives, a single rule vectorization, ordered
    matrix assembly, and exact curvature; for multiple variables it records only
    one explicit exact spectator slice, without retries
- [x] Construct the current-sector cut DE
    `BuildSectorCutDE.wls` calls DEBuilder once for the complete ordered master
    basis, then takes the same-sector row/column block at the resident sector
    positions; the quotient discards only proper-subsector tails
- [x] Prioritize enhanced-Baikov zero-growth and explicit per-variable fallback
    `ChooseDerivativeOperator` searches for exact membership within the declared
    degree bound; on a miss, it directly returns the affine operator without an error
- [x] Integrate the collaborator's exact Baikov-cofactor-to-reducer-target conversion
    The candidate bridge retains the measure prefactor, protected-slot subsector
    tails, signed numerator indices, and candidate identity; its reductions still
    do not constitute UT or canonical-form proofs
- [ ] Two-loop five-point massless analytic regression
    The 61-master Kira project and five-variable operator inputs are frozen; the
    real 20-thread Kira reduction, complete derivative rules, five DE matrices,
    and ten bivariate slices must be accepted in a fresh workspace outside
    version control
    The current fresh enumeration contains 305 master derivatives, 874 elements
    in the master+target union, and 813 nonmaster targets; current DlogBasis-refine
    can produce one finite affine candidate in sector 148 at common dimension
    four and total dot bound 2, but generalized-cut coverage is still partial;
    the corresponding Kira/DE/FINAL_CHECK has not yet started

## 4. Ansatz generation and checking

- [x] Integrate DlogBasis-refine to generate integral candidates before reduction
    `methods/dlogbasis/run.wls` calls the public `DlogBasisSearch` directly;
    candidates still require subsequent reduction and independent canonical-form checks.
- [x] Connect reduced candidate bundles to the independent core checker
    For groups formed by sector rank, the adapter constructs `R` and `T=R^-1`
    in resident order; the checker stops at the first pass and retains candidate
    IDs/rejection traces, and repair becomes eligible only after exact exhaustion
    of the declared pool
- [x] Construct the complete lower-prefix/current-sector candidate pool
    Reuse the full ordered DE from the same `BUILD_CUT_DE` call directly; the
    accepted raw lower transformation and each group's complete reduced rows
    determine a unique block-lower completion without dropping proper-subsector couplings
- [x] Run the candidate-first tail screen
    `SOLVE_TAIL` screens all declared completions in order; a budget stop is
    distinct from actual pool exhaustion, and the first sector explicitly follows
    the no-tail path
- [x] Independently check the complete prefix's canonical dlog form for each sector
    `CHECK_CANONICAL` recomputes the complete gauge transformation from the source
    DE; current-current block failures route to `CORE_FAIL`, while failures confined
    to lower/cross/full-prefix checks route to `TAIL_FAIL`

- [x] Advance sector by sector using an immutable accepted prefix
    `COMMIT_SECTOR` accepts only a passing canonical artifact and accumulates the
    raw transformation; `NEXT_SECTOR` reconstructs the next sector as a pure
    function of the resident manifest and accepted trace

- [ ] Perform sector-by-sector checks in a stateful notebook
    Use this only to optimize repeated rule loading; scientific artifacts and
    resume must not depend on notebook/kernel state

## 5. Sector correction mechanism

- [ ] When off-diagonal entries are incorrect, decide whether to test a different ansatz or find a transformation to repair them
    Prefer a better ansatz that directly yields the form a+b eps, avoiding repair
    where possible. Criterion: if integrating a+b eps produces transcendental
    functions, replace the ansatz
    An algorithm to repair eps^n dependence
    Current Libra structured repair covers only a single-variable direct-sum
    slice with zero cross-block; it is not a general nonzero lower-tail solver

## 6. Submission and final checks

- [x] Implement sector canonical acceptance and commit
    Update the accepted prefix only after the complete prefix passes exact gauge,
    flatness at one deterministic exact rational point, and epsilon/dlog checks;
    retain old source/basis/transformation/matrix blocks and sector/candidate
    traces in resident order

- [x] Implement `CheckFullSystem.wls`
    Independently verify the global gauge transformation from the complete
    ordered master DE and cumulative accepted transformation; only after the
    complete resident trace, flatness at one deterministic exact rational point,
    epsilon factorization, and multivariable shared-residue dlog checks all pass,
    publish the canonical basis, verified DE, and deterministic alphabet of
    nonzero residues; large systems may explicitly select the Fermat exact backend

## 7. Acceptance before release

- [x] Run the complete process on a small family
    One-loop massless triangle sector 5 passed real DlogBasis-refine, Kira3, and
    every method-card stage through `ALL_PASS`; the planar 2l5p pentabox on
    2026-09-05 completed 46 sectors / 61 masters, with five-variable final checks
    `ALL_PASS` and 24 active letters; no additional claim is made about UT boundary properties
- [x] Establish regression tests
    Keep deterministic focused tests by default; fresh live Kira end-to-end runs
    require an explicit script invocation
