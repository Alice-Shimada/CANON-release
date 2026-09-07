# INITIAL fixed-ladder method-card validation

Date: 2026-08-09. Scope: the registered INITIAL 2.1 official massless planar 3-loop
4-point ladder only. No generated matrix, cache, package file, or external output is part of the
source patch.

## Contract cases

The fixture-only command was:

```bash
python3 -m unittest -v \
  tests.test_method_cards.MethodCardIntegrationTest.test_initial_out_of_scope_family_is_inconclusive_without_tool_action \
  tests.test_method_cards.MethodCardIntegrationTest.test_initial_missing_registered_components_is_tool_error \
  tests.test_method_cards.MethodCardIntegrationTest.test_initial_mismatched_tool_identity_is_error \
  tests.test_method_cards.MethodCardIntegrationTest.test_initial_checker_rejects_identity_order_seed_and_reference_mismatch \
  tests.test_method_cards.MethodCardIntegrationTest.test_initial_checker_ignores_forged_provider_pass_claims
```

Expected and actual outcomes were identical: another family returned
`INCONCLUSIVE/OUT_OF_SCOPE` with `workflow_action=none`; missing/mismatched registered
components returned `ERROR/TOOL_*`; wrong provider task, family, candidate, basis, order,
normalization, reference, or seed returned `FAIL/EVIDENCE_REJECTED`; and a forged artifact whose
provider booleans claimed success was rejected as singular. No numerical tolerances are used: all
identity, reference, gauge, regulator, and dlog checks are exact. Actual result: 5/5 passed in
28.624 s.

The full private-snapshot regression command was:

```bash
python3 -m unittest -v tests.test_method_cards
```

Actual result: 23 tests in 79.112 s, `OK (skipped=3)`. Only the three explicitly injected real
CANONICA, Libra, and INITIAL provider tests were skipped; all fixture-only INITIAL cases and all
pre-existing Libra/CANONICA/full-prefix cases passed.

## Real registered integration and checker qualification

The historical real `TCalc` launch used a fresh unittest-owned temporary directory on
Mathematica 14 ARM64. That platform describes this evidence, not a current runtime requirement.
The equivalent current command takes the component configuration described in
[external/README.md](../external/README.md):

```bash
CANON_TEST_INITIAL_CONFIG="$CANON_TEST_INITIAL_CONFIG" \
python3 -m unittest -v \
  tests.test_method_cards.MethodCardIntegrationTest.test_initial_official_ladder_provider_and_independent_checker
```

The provider used INITIAL identity `2.1; 63d8f813ac415f82f7ef945ee7e3f78a242fae49`,
FiniteFlow identity `278344c169010b74e791af8c5604c8cb9cd8df11`, four threads,
`TakeRow -> 1`, official A/basis/reference, and exact `{x,1+x}` input. It completed and returned
`PROVISIONAL/EVIDENCE_AWAITING_VERIFICATION`; the test then entered the independent checker, so
the provider never exercised final PASS authority. The original checker used the generic
per-entry `DLogConnectionQ` and timed out after its 240 s bound. Total test time was 341.137 s;
there was no Mathematica error output. This run is therefore recorded as a successful real
provider integration followed by a checker-performance failure, not as an end-to-end verified
run.

The checker was corrected without launching `TCalc` again. Its exact gauge gate now checks
`A.T - D[T,x] - T.B == 0` directly, avoiding an unnecessary symbolic `Inverse[T]`. For this
fixed alphabet it checks every entry exactly by requiring `(B/eps)*x*(1+x)` to be an
epsilon-independent polynomial of degree at most one with no symbol other than `x`; this is
equivalent to the constant-residue span of `{1/x,1/(1+x)}` and fails closed on other poles or
kinematic variables.

Post-fix validation constructed B from the official A and official reference with the registered
`basisChange` call only (no `TCalc`), then invoked `mma/CheckUTEvidence.wls` on a new output
directory. B construction took 2.25 s; the final stricter checker took 10.47 s and returned
`PASS/VERIFIED_EVIDENCE`. Its actual summary reported all of
`official_reference_match`, `invertible`, `exact_gauge`,
`epsilon_independent_after_division`, and `declared_dlog_alphabet` as true. The generated smoke
artifacts were kept outside the source snapshot and are not delivered.

Relevant source paths are `methods/initial/SKILL.md`, `methods/initial/run.wls`,
`mma/CheckUTEvidence.wls`, and `tests/test_method_cards.py`. The automated real test retains a
600 s provider timeout and 240 s checker timeout; after the correction the checker-only official
reference validation is far below that bound.

## Shared-worktree acceptance

After independent review artifact `A-004` returned `ACCEPT`, the patch was applied to the shared
worktree. The five fixture-only INITIAL contract tests passed in 21.413 s. The full command used
the registered real CANONICA and Libra entries while explicitly leaving
the real INITIAL configuration unset (now `CANON_TEST_INITIAL_CONFIG`); it ran 23 tests in 58.141 s with 22 passes and the one
expected real INITIAL provider skip. No TCalc was launched during shared-worktree acceptance.

## Distribution update (2026-09-07)

The provider now accepts independent INITIAL/FiniteFlow/reference paths and an optional
positive thread count (default 1), resolved relative to its input JSON. The checker accepts
its own entry and reference paths. There is no fixed machine directory or OS/architecture
check. The fixed official ladder scope, exact tool identities and scientific checks remain
part of this method card. The relocation regression uses a synthetic 26-dimensional fixture;
it checks component wiring and exact checker behavior, not real INITIAL performance.
