# Fermat phase regression

This directory's `components.json` includes the tiny fixture producer, independent
verifier and domain-rejection interface. The `faults/` packages exercise isolated
helper-load and initialization failures. They are test providers, not scientific
backends. The production constructor checks helper startup before constructing
the DE; its existing zero-block route and scientific gates retain their scope.

Use the existing `run.py`, `BuildFixtures.wls`, `VerifyFixtures.wls` and a
caller-configured host launcher.
The runtime supplies kernel command, library_root, native descriptors, cpu and
thread/resource allocations. Set FERMATPATH to the declared executable and
CANON_TEST_FERMATICA_ENTRY to the real package entry for controlled fault tests.
No executable or runtime directory is distributed by these source files.

test_fermat_policy.py accepts --work CALLER_DIRECTORY containing test-config.json,
cases.json and templates. All paths and resources are caller fields. Rebase the
tested cases to a caller-owned/retained fixture bank, preserving the exact maps,
expected statuses/codes, prescribed targets and raw gauge. When needed, prepare
the existing rational/quadratic bank through PREPARE_FFT_FIXTURES and the new
2+2 example through PREPARE_FERMAT_BLOCK_FIXTURES. The latter's upper coupling and
nonzero lower rows are deliberate; accepted-prefix names in this manufactured
input do not certify a physical canonical prefix.

Select root's existing two-argument BUILD_FULL_DE through
a configured wolframscript or compatible adapter. Auxiliary producers/verifier and
isolated startup-fault providers use the existing three-argument run.py convention.
Keep the full caller component order. NORMALIZE_FERMAT_FIXTURE receives a hash-bound
arithmetic_helper descriptor. Keep every native installation field in config.

NativeFailure.wl and NativeWait.wl are explicitly test-only injections: both first
load the real package; the former forces FTogether to return $Failed, and the latter
starts a real Fermat child and waits for public cancellation. They are not production
backends or performance workloads. Existing local-jobs exclusively owns and closes
the job group. The tested cancellation observed a real running native child on CPU21,
then read a public cancelled terminal and checked process/group absence.

The checked development run covered 201 exact/policy flags and eight cancellation
flags. Retain the new run's verifier receipts, cancellation checks, measured call
records and source guards. Preserve failed development receipts separately.
These tests claim explicit exact arithmetic capability only, with no speedup or
physical-family completion claim.

The matrix-only negative probe input boundary was subsequently corrected. Four
older domain-rejection flags were masked by an Association-only reader; the
corrected input and domain checks are documented in
[`FLINT-POLICY.md`](FLINT-POLICY.md). Normal full-gauge and actual native-cancellation
evidence remains applicable.
