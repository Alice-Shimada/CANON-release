# INITIAL official ladder: reference validation

This directory holds fixed INITIAL 2.1 massless planar three-loop four-point
ladder validation. It provides reference regression, component integration and
a reproducible normalization benchmark. It is outside the selectable core
method catalog. Ordinary scientific use starts at
[INITIAL SEARCH_CORE](../../methods/initial/SKILL.md).

## Explicit validation and compatibility addresses

| Step | Validation implementation | Existing compatibility address |
|---|---|---|
| `PROVIDE_UT_EVIDENCE` | `examples/initial-official-ladder/run.wls` | `methods/initial/run.wls` |
| `CHECK_UT_EVIDENCE` | `examples/initial-official-ladder/check.wls` | `mma/CheckUTEvidence.wls` |

Each script consumes `INPUT.json NEW_OUTPUT_DIR` through a fresh licensed kernel
with `-noinit -script`. The existing [request fixture](../../tests/fixtures/method_cards/initial-evidence-input.json)
illustrates fixed candidate and options. The compatibility provider selects this
validation only for an explicitly declared `PROVIDE_UT_EVIDENCE` step;
SEARCH_CORE never falls back here after failure.

## Fixed reference contract

Input is the official 26-element ladder in original basis order, with first
seed `G[2,{1,1,1,1,1,1,1,1,1,1,-1,0,0,0,0}]`, `D=4-2 eps`, `x=t/s`,
letters `{x,1+x}`, and `TakeRow=1`. Another family, seed, normalization, alphabet
or order is outside this validation scope. This constraint is specific to the
reference fixture; it does not describe INITIAL's active seeded-core interface.

Provider options are `package_entry`, `finite_flow_package_file`,
`finite_flow_library`, `reference_directory`, `initial_identity`,
`finiteflow_identity`, and optional positive integer `threads` (legacy default 1).
The reference directory contains `AMatrix_ladder.m`, `initial_basis_ladder.m`
and `TMatrix_ladder_to_UT.m`. Declared identities for this fixture remain
`INITIAL 2.1; 63d8f813ac415f82f7ef945ee7e3f78a242fae49` and
`FiniteFlow; 278344c169010b74e791af8c5604c8cb9cd8df11`.
Relative paths resolve from input JSON. Output must be new, with an existing
parent, outside components and references. No installation is modified.
Provider and checker both reject existing output directories, missing parents,
and component/reference paths before publishing even an error result. Directory
aliases and component file aliases retain protection for their physical targets.

The provider makes the original TCalc/basisChange attempt and publishes only
`PROVISIONAL/EVIDENCE_AWAITING_VERIFICATION` with `canon-neu/ut-evidence/v1`.
The checker rereads official sources, validates identities and hashes, requires
the original exact reference representation, and verifies invertibility, source
gauge, epsilon independence and fixed dlog span. It publishes
`PASS/VERIFIED_EVIDENCE` or `FAIL/EVIDENCE_REJECTED` only for that scope.
Checker options retain package, FiniteFlow and reference paths; the checker
hashes but does not execute either package.

Both INITIAL providers use the shared [runtime loader](../../mma/lib/InitialRuntime.wl).
It recognizes the exact INITIAL 2.1 source hash recorded in
[INTERFACES](../../INTERFACES.md) and assigns zero rank to the empty initial
training matrix in memory. This allows the original sampling loop to continue
with `threads=1`. Other source hashes use ordinary file loading. The original
package and snapshots remain unchanged; there is no thread increase or retry.
The provider summary and evidence `method.initial_runtime` record original
source path/hash plus adapter id/path/hash/applied. The native official provider
regression explicitly selects one thread and still requires the independent
official reference checker.

Reference equality is intentionally strict (`SameQ`), for fixed-fixture
regression. A different constant gauge or basis permutation may give a valid
scientific candidate while failing this reference test. Use SEARCH_CORE and
independent main checks for those candidates. An epsilon form alone does not
prove general UT normalization or fix all constant/epsilon factors.

## Result interpretation and regression

Results and produced WL artifacts carry `interface` metadata identifying
`role="official-reference-validation"`, `lifecycle="compatibility"`,
`core_selection_eligible=false`, `workflow_action="none"`, and
`verification_scope="fixed-official-normalized-ladder-reference"`.
Existing artifacts without the new metadata remain readable; actual scope and
claims are checked from inputs, not trusted metadata. The reference receipt
may support a specifically bound normalization premise for the official seed;
it cannot automatically establish another seed as UT.

The [validation guide](../../docs/initial-method-card-validation.md) describes
the commands and independent checks. Regression includes
[interface separation](../../tests/test_initial_interface.py), fixed-reference
tests in [test_method_cards.py](../../tests/test_method_cards.py), and the active
provider's [official isomorphic probe](../../tests/test_initial_core.py).
No case executes merely by reading or distributing this example.
