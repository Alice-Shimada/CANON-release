# Native rational inverse regression

This engineering component validates only a minimal `inv` branch in the native
quadratic-pair utility. If b is zero it divides 1 by a with the same checked
rational division operator. All other native code is retained byte-for-byte.
Carry the full ordered component list from the caller, including the accepted
FINAL provider and this fixture manifest; inspect `--describe` before invocation.

The caller supplies installed compiler/include/link settings in build-config.json
and source/runtime/template descriptors in test-config.json. build_native_inverse.py
builds only this utility. prepare_native_inverse.py writes fixed exact fixture data and
public request templates. The test driver calls PREPARE_REQUEST and the existing
NORMALIZE_FLINT_FIXTURE through run_step.py under local-jobs run_owned, with the
caller CPU, RSS, per-call and fixed first-launch budgets. The one 256-term inverse
benchmark is frozen before either executable runs, once per executable. No tuning
or physical-family comparison is performed. Error fixtures preserve exact zero
rational and zero quadratic-norm behavior. A principal square root is not changed
to a signed linear polynomial.

The independent VERIFY_NATIVE_INVERSE provider uses only System Wolfram exact
rational/quadratic simplification of original inputs, independent gauge and basis
equations, and exact shared residue reconstruction. Existing tiny T027 rational
and quadratic accepted fixtures are bound in place, checked by the unchanged
FINAL provider with the new native, and compared with its independent Wolfram
backend. All fourteen acceptance flags are required. This does not certify the
physical family or explain its observed timings.

No Fermat package is selected or invoked. The old installation and root sources
are guarded by hashes. Existing strict grammar/domain tests and actual native
cancellation evidence are referenced because the one native arithmetic branch
does not change those interfaces or process lifetime. Native output, readback,
public receipts, call resources and actual group closure remain distinct records.
