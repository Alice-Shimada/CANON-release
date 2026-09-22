---
name: canon-libra-structured-repair
description: Run bounded Libra repair inside the 2x2 tail of an exact single-variable direct sum with a frozen accepted 1x1 prefix, given an explicit REPAIR_WITH_LIBRA route, and publish only compatible provisional candidates.
---

# Libra structured repair

## Trigger and prerequisites

Use only when the task explicitly requests this opt-in repair contract.
This is separate from `methods/libra`'s `SEARCH_CORE` and the general
`mma/SolveTail.wls` route. It requires a validated `canon-neu/prepared-basis/v1`,
a route decision exactly equal to `REPAIR_WITH_LIBRA`, and a
`canon-neu/libra-structured-repair-input/v1` request with complete pool-exhaustion
evidence: no alternatives remain and every declared candidate was attempted.
A plateau is diagnostic metadata only and does not authorize repair. The
current general prepared-basis router does not emit `REPAIR_WITH_LIBRA`;
this card retains a separately scoped explicit-input contract. General studies
start at the [workflow entry](../../skills/canon-workflow/SKILL.md).

## Inputs and command

Use an installed WolframKernel with `-noinit -noprompt -script` to run
`run.wls <input.json> <fresh-output-dir>`. Inject a read-only Libra entry through
`method_options.package_entry`. The runner records the loaded version identity,
disables Fermatica, and uses only `NewDSystem`, `Fuchsify`, `Transform`,
`FactorOut`, `OverallTransformation`, and `EFormQ`. The caller must own the new
output directory, which must not already exist. No other solver or fallback
is invoked.

The v1 scope is one exact rational variable, `parameters -> {}`, and the
direct sum of an accepted canonical `1x1` prefix and a `2x2` current tail.
Both cross blocks must be zero and transformation mixing is forbidden. The
defect must be an epsilon-factorization failure inside the `current-current`
tail, with failed test `REGULATOR_INDEPENDENT_TERM`. Preflight checks the accepted prefix exactly for flatness, epsilon
factorization, regulator independence after division, and the declared dlog
alphabet. The prepared `(row,column)` must map exactly to
`full_entry = 1 + {row,column}`. This contract does not cover general
off-diagonal or full-prefix repair.

Multivariable or nonlocal problems return `INCONCLUSIVE/OUT_OF_SCOPE`;
invalid or nonflat full systems return `ERROR/INVALID_DIFFERENTIAL_SYSTEM`.
If bounded stages produce no matrix candidate preserving the prefix identity
and zero forbidden mixing blocks, the result is
`INCONCLUSIVE/METHOD_EXHAUSTED`, without a nonexistence claim.

## Result and next action

Success is only `PROVISIONAL/CANDIDATE_TRANSFORMATION` with
`canon-neu/libra-structured-repair-candidate/v1`: original and transformed full
matrices, full transformation, prefix order and dimension, local target
signature, Libra identity/hash/options/stages, and nonauthoritative evidence.
The publication gate checks shape, declared exact coefficient syntax,
invertibility, prefix identity, and forbidden mixing. It does not apply the
final canonical-form, epsilon-factorization, dlog, or target-acceptance tests.

Only `mma/CheckStructuredRepair.wls` can accept the scientific result. Its
`checker_options` must independently supply the authoritative Libra identity,
entry, and SHA-256. The checker normalizes the path, reads file metadata, and
hashes the read-only entry; it never evaluates the package or changes Libra
context state. It checks provider provenance field by field, applies its own
full scientific criteria (including the full gauge relation, flatness, epsilon
factorization, declared dlog alphabet, target removal, and preservation of all
accepted blocks), and retains authenticated entry/hash/options/stages/runtime
in the verified artifact. Only the checker can return
`PASS/VERIFIED_STRUCTURED_REPAIR`; forged provider `PASS` fields are rejected
with `FAIL/STRUCTURED_REPAIR_REJECTED`.
