# CANON research log

> Historical scope: this log records the evidence and decisions at the dates
> shown. For active work, follow [the current agent workflow](agent-workflow.md)
> and current skills; historical acceptance criteria are not new execution instructions.

Distribution note: machine-specific paths in the historical commands below are
expressed as configuration variables. Dates, hashes, versions, and verification
results retain their original recorded values; they are not a revalidation of the
current distribution. See `external/README.md` for the variable definitions.

This log records only milestones that change the research direction or central
conclusions. Routine command output remains in the test records and is not
repeated here.

## Acceptance criteria for this phase

1. First audit the current dirty worktree, conclusions handed over from earlier sessions, and existing tests. Identify which capabilities are executable, scaffolds only, or blocked by the external environment. Do not restore the deleted `workflow.py` or create a second state machine.
2. The INITIAL, Libra, and CANONICA method cards and machine-readable interfaces must retain these boundaries: INITIAL provides UT evidence or an explicit candidate transformation only for a specified, normalized candidate; Libra addresses localized structural defects in stages; CANONICA searches for an unknown overall rational canonical transformation. They must not form a fixed fallback chain.
3. `Inconclusive`, program/environment failure, and mathematical rejection of a candidate must be distinct outcomes. Backend failure must not automatically trigger candidate replacement or be interpreted as mathematical nonexistence of a solution.
4. Backends may produce only candidate transformations/systems. Final success requires an independent verifier checking at least convention consistency, invertibility, the exact gauge identity, epsilon factorization, absence of residual epsilon dependence after removing epsilon, the expected pole/dlog structure, and, for multiple variables, flatness at one deterministic exact rational point.
5. External package calls use only APIs verified against primary sources. If a package, version, or reproducible example is missing, deliver only an explicitly labeled contract, scaffold, or blocked capability; do not fabricate a successful path.
6. Complete at least one highest-value gap identified by the audit and check it automatically with representative positive and negative cases. Record commands, inputs, expectations/tolerances, actual summaries, verdicts, and artifact paths. An independent agent must review completed milestones that change later directions or central conclusions against these criteria; recheck after correcting substantive problems.
7. Use Git at key milestones to preserve the core source of truth. Exclude unrelated changes, large files, and reproducible generated outputs. Do not generate new TeX in this phase unless delivery requires it.

## Key milestones

### 2026-08-09 — Continuation boundaries confirmed

- Basis: the user's method-card boundary text, earlier `CANON`/`CANON-2` task records, and the current `AGENTS.md` and `persistent-scientific-research` rules.
- Conclusion: the earlier requirement to extend the Python workflow state machine is obsolete; the scientific boundaries of INITIAL/Libra/CANONICA remain valid. The earlier `full-prefix-tail-screen` already had 21/21 synthetic tests and an independent agent's `ACCEPT` record, but the current uncommitted worktree still needs a fresh audit.
- Open questions: which of the three core cards already call real packages and which remain scaffolds; whether the previously proposed `constant-gauge-audit` still has higher priority than completing the INITIAL card.

### 2026-08-09 — Current implementation audit accepted by the main reviewer

- Basis: artifact `A-001` from persistent task `T-001/R-001`; without package injection, 15 of 17 tests passed and 2 were skipped. With the registered Libra 1.2 and CANONICA 1.0.3 entries injected, 17/17 passed (43.303 s).
- Conclusion: CANONICA is already an executable single-variable direct rational-transformation generator. Libra's executable scope is single-variable staged core generation, not yet frozen-prefix structured repair. INITIAL has no card/interface/test in CANON. `NO_CANDIDATE` still mixes unsupported cases, computational failures, and mathematical failures; the general multivariable final verifier remains a scaffold. The proposed next milestone is an INITIAL evidence-only vertical slice restricted to the fixed official ladder, ahead of `constant-gauge-audit`.
- Open questions: the route and baseline evidence still need independent review. INITIAL support for arbitrary physical candidates still lacks a basis/order/seed/alphabet example verified against primary sources; it cannot be extrapolated from the official ladder.

### 2026-08-09 — Independent review of the route passed

- Basis: independent artifact `A-002` from `T-002/R-002`; rerunning with real Libra/CANONICA entries gave 17/17 passes (41.367 s), and A-001's file-level findings were checked individually.
- Conclusion: the review verdict was `ACCEPT`, with no corrections required. The INITIAL evidence-only vertical slice for the fixed official 26×26 ladder is the highest-value gap at this point. Four outcome classes must remain distinct: `INCONCLUSIVE/OUT_OF_SCOPE`, `ERROR/TOOL_*`, `FAIL/EVIDENCE_REJECTED`, and `PASS/VERIFIED_EVIDENCE`, which only the independent checker may issue.
- Open questions: check the resource cost of a real INITIAL run against the accepted invocation card before execution. Support must not be claimed for candidates outside the official ladder.

### 2026-08-09 — Fixed INITIAL ladder evidence slice completed

- Basis: `docs/initial-method-card-validation.md`; fixture-only INITIAL negative cases passed 5/5. In the private snapshot's 23-test method-card regression, 20 passed and 3 were skipped according to external-provider injection conditions.
- Conclusion: the new card covers only the registered official 26×26 ladder. The provider may return only `PROVISIONAL/EVIDENCE_AWAITING_VERIFICATION`; the independent checker may return `PASS/VERIFIED_EVIDENCE` only after recomputing the official A/basis/reference, transformation equality, invertibility, exact gauge identity, `B/eps`, and `{x,1+x}` dlog span. Out-of-scope cases, tool errors, evidence rejection, and verified success now have distinct types and do not trigger candidate replacement or repair.
- Real-run limitation: the only real `TCalc` invocation successfully delivered provisional evidence; the old general dlog checker then timed out at 240 seconds. After the fix, `TCalc` was not rerun. Instead, B was constructed independently using `basisChange` from the same official reference, and the checker produced a complete verified summary in 10.47 seconds. The real evidence is therefore explicitly recorded as provider success plus post-fix verification of the official reference by the checker, not uninterrupted end-to-end success in one process.
- Open questions: any other family, basis, seed, order, alphabet, or normalization remains `OUT_OF_SCOPE`; this slice does not support extrapolation.

### 2026-08-09 — Independent review and shared-worktree acceptance

- Basis: `T-004/R-004` artifact `A-004` returned `ACCEPT`. In a private copy, the reviewer reran the fixtures with 5/5 passes and the full 23-test regression with 20 passes/3 skips, and independently obtained checker `PASS/VERIFIED_EVIDENCE` using the official reference plus `basisChange`, without calling TCalc.
- Conclusion: A-003's dedicated dlog condition is exactly equivalent to the constant-residue span `{1/x,1/(1+x)}`. Under the convention `old_basis = T.new_basis`, directly checking `A.T-D[T,x]-T.B==0` is correct and requires no explicit inverse. The patch has been applied to the shared worktree.
- Program acceptance: shared-worktree INITIAL contract negative cases passed 5/5 (21.413 s). With the registered real Libra/CANONICA entries injected and INITIAL explicitly not injected, the full 23-test regression had 22 passes and 1 conditional skip (58.141 s), verdict PASS.
- Open questions: TCalc was not rerun after optimizing the checker. The evidence is strictly limited to one real provisional provider success plus one independent post-fix official-reference checker PASS; it does not establish uninterrupted end-to-end success or support for arbitrary candidates.

### 2026-08-09 — Prepared-basis contract, deterministic routing, and typed provider results

- Representative input: the existing exact 2×2 single-variable `sector-cut-de.wl`.
  The prepared-basis fixture explicitly includes preparation/family/basis identity,
  a frozen accepted lower prefix, two candidates with normalization/rank,
  diagonal/off-diagonal quality, a localized defect signature, an INITIAL evidence
  reference, plateau/pool/alternatives history, and remaining-problem classification.
- Expectations/tolerances: all criteria are exact symbolic criteria, with no
  numerical tolerance. The router must cover five fixed decisions;
  malformed/contradictory inputs must consistently return
  `ERROR/INVALID_PREPARED_BASIS`; changing INITIAL evidence must not change the
  route. Successful Libra/CANONICA providers are expected to return
  `PROVISIONAL/CANDIDATE_TRANSFORMATION`, after which only the independent checker
  may issue `PASS/CORE_PASS`.
- Focused command: `python3 -m unittest -v` ran the five prepared-basis branches,
  INITIAL non-control, malformed/contradictory inputs, Libra multivariable scope,
  CANONICA non-flatness, and two exhaustion tests; all passed. New tests exposed
  and corrected the original multivariable pair iterator in `FlatConnectionQ`;
  the fixture returned `True/False` respectively for flat/non-flat cases at one
  deterministic exact rational point.
- Real Libra command: `WolframKernel -noinit -noprompt -script methods/libra/run.wls`
  called the registered entry `$CANON_TEST_LIBRA_ENTRY` (1.2, entry SHA-256
  `b3574e7f560951516a289a8141aafbaf23f0f5ae563e29d0fa077b17ba4d3eb4`), using the
  caller-owned directory `validation-runs/libra-provider`. The actual provider
  summary was `PROVISIONAL/CANDIDATE_TRANSFORMATION`,
  `provider_check_eps_form=true`, and one candidate. `mma/CheckSectorCore.wls`
  returned `PASS/CORE_PASS` in `validation-runs/libra-checker`, with
  `invertible/exact_gauge/flat_connection/epsilon_factorized` all `true`.
- Real CANONICA command: a fresh kernel likewise called the registered entry
  `$CANON_TEST_CANONICA_ENTRY` (1.0.3, entry SHA-256
  `0bf334159265f17814fb21bf8f1248637e66622bc4a8a3768085f7416df9d200`), using the
  caller-owned directory `validation-runs/canonica-provider`. As with Libra, the
  actual provider summary was `PROVISIONAL/CANDIDATE_TRANSFORMATION`, a true
  provider epsilon check, and one candidate. The checker returned `PASS/CORE_PASS`
  in `validation-runs/canonica-checker`, with the same four flags all true.
- Artifact paths: both providers' `core-candidates.wl`/`result.json` and the
  checkers' `core-transform.wl`/`result.json` remain under `validation-runs/` in
  the run workspace above. They are reproducible verification outputs and are
  excluded from the delivered patch.
- Full regression: with registered real Libra/CANONICA entries injected and
  INITIAL explicitly not injected,
  `python3 -m unittest discover -s tests -p 'test_*.py' -v` reported `OK` for
  29 tests in 130.643 seconds. Only the conditional real INITIAL ladder test was
  skipped as expected; all other INITIAL and full-prefix regressions passed.
  Neither INITIAL nor `TCalc` ran, and the two transformation providers neither
  called each other nor used fallback.

### 2026-08-09 — A-007 rejection remediation and renewed acceptance

- Independent-review input: four blocking counterexamples from T-007/A-007. The
  revision removed obsolete `CANDIDATE_READY` from the method-card protocol;
  canonical quality and selected-candidate suspicion can no longer coexist;
  a localized rational defect must have both at least one `DEFECT` quality
  dimension and `rational_transformation_expected=True`;
  `alternatives_remaining` must exactly equal the number of declared minus
  attempted candidates, and no declared unattempted candidate may remain when
  the pool is exhausted or candidate selection is complete.
- New negative cases and expectations: all four inputs have no numerical
  tolerance and must consistently return `ERROR/INVALID_PREPARED_BASIS`, with
  fields `candidates.selected`, `remaining_problem.rational_transformation_expected`,
  `quality.localized_defect`, and `search_history.alternatives_remaining`,
  respectively. All four were rejected as expected, and the five valid route
  branches still produced their original decisions. The complete focused
  contract command ran 10 test methods in 54.267 seconds, `OK`.
- CANONICA load precedence: retain package-first loading so that creating
  ``Global`eps`` from the input first does not cause ``CANONICA`eps::shdw`` to
  interfere with the fail-closed package check. If both the tool and input fail,
  return a specific `ERROR/TOOL_*` deterministically; classify
  `ERROR/INVALID_DIFFERENTIAL_SYSTEM` only after the tool boundary passes. This
  is error precedence, not fallback.
- Real-provider recheck: registered entries and hashes were unchanged. R-008's
  caller-owned outputs are in `validation-runs/libra-provider`,
  `validation-runs/libra-checker`, `validation-runs/canonica-provider`, and
  `validation-runs/canonica-checker`. Both providers actually returned
  `PROVISIONAL/CANDIDATE_TRANSFORMATION`, one candidate, and a true provider
  epsilon check. Both independent checkers returned `PASS/CORE_PASS`, with
  `invertible/exact_gauge/flat_connection/epsilon_factorized` all true.
- Full regression: using registered Libra/CANONICA entries,
  `python3 -m unittest discover -s tests -p 'test_*.py' -v` reported `OK` for
  33 tests in 143.147 seconds. Only the conditional real INITIAL ladder test was
  skipped as expected. Neither INITIAL nor `TCalc` ran, and no external
  installation was modified.

### 2026-08-09 — Libra frozen-prefix structured-repair slice

- Fixed scope: v1 accepts only a single-variable exact rational `3×3` direct sum
  with `parameters -> {}`: an accepted canonical `1×1` prefix plus the Libra
  Tutorial #1 `2×2` tail-internal defect. Both source cross-blocks must be zero,
  and both transformation cross-mixings are forbidden. The defect kind must be
  exactly `current-current`/`epsilon-factorization`, the failure test must be
  `REGULATOR_INDEPENDENT_TERM`, and
  `full_entry = prefix_dimension + {row,column}`. Preflight also rechecks prefix
  flatness at one deterministic exact rational point, epsilon factorization,
  absence of residual dependence after removing the regulator, and the declared
  dlog alphabet. A jointly forged other kind and a noncanonical `1/x` prefix are
  both consistently rejected before package resolution.
- Authority boundary: the provider performs only the shape/domain/invertibility/
  frozen-prefix publication gate. The checker independently implements all
  scientific criteria and only canonicalizes/stats/hashes the authoritative
  entry; it does not evaluate the package or read/write Libra context state.
  The side-effect sentinel's body would write a marker and abort, but after
  hashing it the checker still completed with `PASS/VERIFIED_STRUCTURED_REPAIR`
  and no marker existed, proving that the provider code was not executed.
  A-011/A-013 counterexamples involving shared verdicts, forged provenance,
  mapping, undeclared `z`, other kinds, and noncanonical prefixes are all covered.
- Focused command: `PYTHONDONTWRITEBYTECODE=1 CANON_WOLFRAM_KERNEL="$CANON_WOLFRAM_KERNEL" python3 -m unittest -v tests.test_method_cards.MethodCardIntegrationTest.test_structured_repair_contract_rejects_route_pool_and_prefix_contradictions tests.test_method_cards.MethodCardIntegrationTest.test_structured_repair_preflight_enforces_mapping_direct_sum_and_parameters tests.test_method_cards.MethodCardIntegrationTest.test_structured_repair_preflight_requires_exact_defect_and_canonical_prefix tests.test_method_cards.MethodCardIntegrationTest.test_structured_repair_scope_invalid_system_and_method_exhaustion tests.test_method_cards.MethodCardIntegrationTest.test_structured_repair_checker_positive_and_adversarial_rejections tests.test_method_cards.MethodCardIntegrationTest.test_structured_repair_checker_hashes_package_without_executing_it`;
  actual result: `Ran 6 tests in 109.802s — OK`, with no numerical tolerance.
- Full-suite command for this historical source snapshot: `PYTHONDONTWRITEBYTECODE=1 CANON_WOLFRAM_KERNEL="$CANON_WOLFRAM_KERNEL" CANON_TEST_LIBRA_ENTRY="$CANON_TEST_LIBRA_ENTRY" CANON_TEST_CANONICA_ENTRY="$CANON_TEST_CANONICA_ENTRY" CANON_TEST_INITIAL_CONFIG= CANON_TEST_STRUCTURED_OUTPUT_ROOT="$CANON_TEST_STRUCTURED_OUTPUT_ROOT" python3 -m unittest discover -s tests -p 'test_*.py' -v`;
  actual result: `Ran 40 tests in 274.397s`: 37 passed, 1 conditional real INITIAL
  test was skipped, and two other kernels exited before writing results because
  of `OMP Error #178: Can't open SHM`. Rerunning only these two test methods,
  neither of which used a real provider, gave `Ran 2 tests in 39.716s — OK`;
  the complete suite was not restarted.
- The only real structured runner in that full suite received no transformation.
  Libra generated `{{1,0,0},{0,1,x},{0,0,1}}` itself and returned
  `PROVISIONAL/CANDIDATE_TRANSFORMATION`; the hash-only checker returned
  `PASS/VERIFIED_STRUCTURED_REPAIR`, with authenticated provenance and every exact
  scientific flag true. The caller-owned run is in R-014
  `full-suite-structured-R014/` and is excluded from the patch. Neither INITIAL
  nor `TCalc` nor CANONICA outside the existing regressions was called; there was
  no fallback or external write.

## 2026-08-09: ARM64 libomp sequential-launch lifecycle gate

- The Mathematica 14 ARM64 kernel links directly to bundled `libomp.dylib`; its
  registration is named `__KMP_REGISTERED_LIB_<pid>`. Before the single `execve`,
  the test launcher unlinks only the stale registration for the current future
  kernel PID; every outcome other than success or `ENOENT` fails closed. There
  is no retry, `KMP_DUPLICATE_LIB_OK`, result replacement, or external installation change.
- Fixed full-scale stress run: 84/84 kernel launches and result artifacts passed,
  18/18 tests, 0 abort/failure/error/skip, 306.808 seconds. Coverage includes the
  registered CANONICA provider/checker, prepared-basis paths, and structured
  preflight/checker negative cases.
- The only fresh full suite: 82/82 launches and result artifacts, 40 passes out of
  41 tests, with only the explicitly disabled real INITIAL ladder skipped;
  0 abort/failure/error, 300.870 seconds. Libra/CANONICA used registered entries;
  INITIAL `TCalc` did not run.

## 2026-08-09: Libra SEARCH_CORE explicit sector-de-closure

- Added caller-selected `sector-de-closure`: the typed artifact exactly binds cut
  identity/order and stores ordered sector labels, `MappedSectors=False`
  provenance, and a nonzero-count budget. The post-Fuchsify residue hierarchy has
  exact parity with Libra 1.2 Automatic semantics. If closure exceeds the budget,
  it does not truncate, use `All`, retry, or call `FactorOut`; the default route
  remains the original single Automatic call.
- Targeted coverage includes the default, full-mask forwarding, valid cycles,
  identity/order/shape/domain/diagonal/provenance/budget negative cases, and no
  call on overflow. An accepted caller-owned 62-master run obtained hsector/hde/
  combined nonzero counts of 366/516/534; the provider returned
  `PROVISIONAL/CANDIDATE_TRANSFORMATION`. The unchanged `CheckSectorCore` returned
  `PASS/CORE_PASS`, with invertibility/exact gauge/flatness/epsilon factorization all true.
- The only fresh full suite injected registered Libra/CANONICA, disabled real
  INITIAL, and used the reliable launcher: 47 tests in 277.319 seconds,
  `OK (skipped=1)`. Only the disabled real INITIAL ladder was skipped; there was no retry.

## 2026-08-09: Cross-method-card typed-contract hardening G1--G3

- Evidence: Libra, before package resolution, and CANONICA, after package loading
  and the public-symbol gate, both exactly validate sector/family/basis IDs and
  the complete basis order in `task`, `sector_basis`, and `sector_cut_de`. In
  14 identity/schema negative cases, the Libra package-load marker was always
  absent; the CANONICA load marker was always present, while scientific-call
  markers for `CheckIntegrability`, `SectorBoundariesFromDE`, and
  `RecursivelyTransformSectors` were always absent. Focused G1--G3 testing ran
  10 tests in 72.287 seconds, `OK`.
- Conclusion: all INITIAL terminal publications now go through the provider
  writer. Failure to establish provider-local reference/gauge/epsilon/dlog
  returns only `INCONCLUSIVE/METHOD_EXHAUSTED`; the independent `CheckUTEvidence`
  still exclusively issues `PASS`/`FAIL`. The tail screen changes only a budget
  stop with untested candidates remaining to
  `INCONCLUSIVE/CANDIDATE_BUDGET_EXHAUSTED`; complete all-bad-pool and pass paths,
  and repair metadata, are unchanged. The only full-suite run had 48 tests in
  329.463 seconds: 46 passes, 1 conditional real INITIAL skip, and 1 failure due
  to an outdated multivariable fixture identity. After adding that fixture's
  sector/family/basis binding, a focused recheck of the sole failure ran 1 test
  in 2.773 seconds, `OK`; the full suite was not restarted.
- Unresolved G4: primary-source support for faithful tool-cost bounds on CANONICA
  recursion and Libra legacy Automatic search is still missing. This milestone
  added no dimension cap, wall-clock surrogate, or call-count surrogate, and
  changed no default search strategy.

## 2026-09-05: All massless planar pentabox sectors completed

- Continuing from a 19-sector / 20-master prefix, completed 46/46 sectors and
  61/61 masters. The five-variable `FINAL_CHECK` returned `PASS/ALL_PASS`, with
  24 active letters and the Gram radical retained.
- General changes included epsilon-zero polynomial core candidates,
  two-dimensional epsilon-singular completion, affine-epsilon primitive tail
  repair, epsilon normalization of the complete prefix, and shared-residue
  solving in an algebraic quotient field. Fermat was available as an explicit
  final gauge-verification option; Mathematica separately proved all five
  full-variable gauge identities to be zero. No topology/sector-specific
  formulas were added.
- Software tests passed 14/14, 11/11, 4/4, and 3/3. Flatness still used the existing
  deterministic exact rational-point gate; no additional claim is made about
  UT properties of integral boundaries or search completeness for arbitrary MPL families.
- Report, complete basis/DE, and hash record:
  local run directory `runs/2l5p-complete-20260905-grs_ynfi/REPORT.md`
  (research artifacts are not distributed with the source).
  This run used a separate test directory with the user's authorization and
  did not operate `.state-management`.
