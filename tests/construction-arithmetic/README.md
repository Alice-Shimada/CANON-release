# Current-checkout construction arithmetic regression

Run `python3 test_construction_arithmetic.py --config CALLER.json --work FRESH_DIR`.
The config supplies all checkout, interpreter, runtime, fixture and component
paths, CPU/thread/RSS budgets and call limits. The test source contains no local
installation paths. Keep the complete caller component selection; append the
accepted fixture package, then an explicit BUILD_FULL_DE override selecting the
current checkout's two-argument script. Fixture helpers/verifiers retain their
three-argument launcher and use `runtime_config.library_root` for this checkout.

For a fresh checkout, append this directory's `components.json` and run
`PREPARE_FFT_FIXTURES` with the caller runtime descriptor in
`payload.method_options.runtime_config`. This writes the five base cases and
their prescribed expected targets in a caller-owned directory. Map
`native-unavailable` and `failed-reconstruction` to the `rational-nonzero`
template, and `default-unavailable` to `default`; the test driver sets the
corresponding runtime and case identity. Retained generated fixtures can also
be reused directly. No research-state directory is required.

`fixture_templates` maps each case name to its JSON; `fixture_artifacts` maps the
declared artifact filename to an absolute path and SHA256. `fixture_files` pins
the retained layout, including prescribed expected targets. `fixture_directory`
is the retained expected-target layout used by the unchanged exact verifier.
Only request identities, literal artifact paths and runtime bindings change.
The unavailable and failed runtime variants preserve missing-library and
zero-reconstruction-prime controls. No target or mathematical fixture changes.

The eight cases cover rational and quadratic-root nonzero couplings, a gauge
singular at epsilon zero, no prefix, default arithmetic, unsupported cubic roots,
unavailable native arithmetic, default arithmetic with unavailable native, and
failed reconstruction. The accepted verifier uses its independent manufactured
targets and raw gauge identities; it is not replaced by byte equality.

`block_regression: true` additionally runs the existing focused full-block
regression. Its seven cases cover three current masters, a nontrivial lower
transformation, strict zero-lower assembly and malformed/inexact row rejection.
The staged block fixture sources adapt only the native three-argument parser;
their mathematical and verifier bodies match the current repository sources.
The inexact-upper case retains its original limited fallback-selection scope.

All public calls use the existing `local-jobs/support.py::run_owned` owner for
bounded execution, recursive RSS sampling and process-group cleanup. The caller
provides `execution_timeout_seconds`, `cancellation_grace_seconds` and
`collection_reserve_seconds`; no additional native session is created. Root
BUILD_FULL_DE may use the accepted host adapter for explicit native accounting;
auxiliary helpers exec the supplied kernel directly. Call CPU is the difference
in reaped child user+system usage. Reaped maxRSS is suite-cumulative; sampled
aggregate RSS is per call. Native metrics emitted by the optional adapter have
their own declared scope.

Retain source guards, calls.json, both independent check receipts and report.json.
This checks tiny current-root integration only. It does not load a physical
family, establish canonical or UT acceptance, or measure physical speedup.

The explicit phase-map tests are documented in [PHASE-POLICY.md](PHASE-POLICY.md).
For the optional Fermat normalization backend, including mixed-backend selection
and startup/cancellation failure tests, see [FERMAT-POLICY.md](FERMAT-POLICY.md).

The explicit FLINT backend and corrected matrix-only probes are covered by
[`FLINT-POLICY.md`](FLINT-POLICY.md).

The exact FLINT global gauge check and its separate basis-definition check are
covered by [`FINAL-FLINT.md`](FINAL-FLINT.md), including independent Wolfram
references and separate wrong-gauge and wrong-basis failures.
Equivalent rational radicands with different expression forms and retained
principal-root branches are covered by [`EQUAL-RADICANDS.md`](EQUAL-RADICANDS.md).

The reduced input-validation traversal is covered by
[`VALIDATION.md`](VALIDATION.md). The native rational-inverse fast path is
covered by [`NATIVE-INVERSE.md`](NATIVE-INVERSE.md). Their small benchmarks report
preparation, serialization and native intervals separately; neither establishes
a physical-family speedup.

The optional compiled structural converter is covered by
[fast-serialization/README.md](fast-serialization/README.md). It checks exact
postfix equality, qualified and Unicode symbols, malformed input rejection,
independent full construction and all fourteen final conditions. Its fixed
small benchmark distinguishes serialization cost from total normalization time.
