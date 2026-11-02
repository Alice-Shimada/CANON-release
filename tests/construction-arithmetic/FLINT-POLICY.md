# Explicit FLINT construction arithmetic

The public fixture entries in `components.json` include `NORMALIZE_FLINT_FIXTURE`,
`VERIFY_FLINT_FIXTURES` and `EARLY_ARITHMETIC_RUNTIME_FIXTURE`. They use the existing
three-argument `run.py` launcher. The normal constructor retains its own public
adapter. All kernel, component, library, native executable and resource settings
come from the caller configuration.

Prepare a caller-owned work directory with `test-config.json`, `cases.json`,
`runtime/normal.json` and the retained/prescribed `templates/rational-nonzero.json`
fixture bank. Then `prepare_flint_fixtures.py --work WORK_DIRECTORY` adds independent
literal pair targets and labelled native-failure controls. The driver
`test_flint_policy.py --work WORK_DIRECTORY` reads that configuration, binds the
fixtures and runs the public calls. Reuse the existing prescribed full-gauge
fixture producers and verifiers. Supply a hash-bound runtime with `flint_helper`,
`flint_source`, `flint_executable` and `flint_threads: 1`; the installed native
source and binary are not rebuilt by these tests.

Coverage includes rational and principal-quadratic nonzero coefficients,
nontrivial full gauges, constant matrices, mixed phase choices, invalid domains,
malformed native output, initialization errors and actual native-child
cancellation. Native nonzero output is parsed with a limited arithmetic grammar,
without evaluating native text as Wolfram code. Serialization, native execution
and readback are timed separately. Nested intervals cannot be added.

The matrix-only Fermat fixture now resolves the hash-bound input path, reads
literal Wolfram data and requires `MatrixQ`. The earlier generic reader required
an Association and masked four intended domain-rejection probes. Corrected
multiple-root, nested-root, inexact and transcendental probes now exercise their
intended domain checks; a controlled native-error probe reaches the selected
Fermat operation boundary. Normal full-gauge tests and the original actual
Fermat cancellation did not use that faulty input path.

The accepted focused suite has 376 true flags across 35 cases and eight native
cancellation flags. These establish the tested engineering interface and exact
small examples; real-family performance and scientific gates are separate.

The subsequent [equal-radicand regression](EQUAL-RADICANDS.md) covers the
normalization of strictly equal rational radicands before single-root framing.
Its 14 cases and 202 independent checks include expanded/unexpanded forms,
root denominators and a principal-branch counterexample. Distinct, square-related
or sign-related radicands remain rejected. The original parser and native engine
are unchanged; the actual native cancellation evidence remains applicable.
