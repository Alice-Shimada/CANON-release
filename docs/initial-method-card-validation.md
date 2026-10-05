# INITIAL official ladder validation

Use this guide for explicit validation of the official INITIAL ladder reference.
For core discovery from normalized seeds, use the
[INITIAL SEARCH_CORE card](../methods/initial/SKILL.md). The reference check is
outside core selection and does not run automatically after a failed core search.

## Requirements and inputs

Install INITIAL and FiniteFlow, including the native library, on the host that
runs the Wolfram kernel. Supply component paths and identities in the request;
see [installation](installation.md) and the
[official validation example](../examples/initial-official-ladder/README.md).
The reference directory must contain `AMatrix_ladder.m`,
`initial_basis_ladder.m` and `TMatrix_ladder_to_UT.m`.

The input is the official 26-element massless planar three-loop four-point
ladder, in its original basis order, with the fixed seed, normalization,
`D=4-2 eps`, `x=t/s`, alphabet `{x,1+x}` and `TakeRow=1` specified by the example.
Use the [request fixture](../tests/fixtures/method_cards/initial-evidence-input.json)
for the candidate and option fields. Another family, order, seed, normalization
or alphabet is outside this reference contract.

Relative component and artifact paths resolve from the request JSON. Provider
and checker outputs must each be new directories with existing writable parents,
outside component and reference locations, including their physical aliases.
Installations and reference files are read-only.

## Commands and compatibility

Use a fresh licensed kernel and the executor required by the selected host.
For a direct kernel installation, the compatibility commands are:

```bash
"${CANON_WOLFRAM_KERNEL:-WolframKernel}" -noinit -noprompt -script \
  methods/initial/run.wls PROVIDER_INPUT.json NEW_PROVIDER_OUTPUT_DIR
"${CANON_WOLFRAM_KERNEL:-WolframKernel}" -noinit -noprompt -script \
  mma/CheckUTEvidence.wls CHECKER_INPUT.json NEW_CHECKER_OUTPUT_DIR
```

The provider request must explicitly use `PROVIDE_UT_EVIDENCE`; the checker
request uses `CHECK_UT_EVIDENCE` and references the returned `ut_evidence` and
provider task ID. Their implementations are in
`examples/initial-official-ladder/`; the old addresses and v1 artifact schemas
remain compatible. Missing descriptive interface metadata in an older receipt
does not bypass the mathematical or identity checks.

## What the independent check establishes

The provider returns `PROVISIONAL/EVIDENCE_AWAITING_VERIFICATION`. The checker
rereads the authoritative reference and validates identities, hashes, exact
reference equality, invertibility and the source gauge equation
`A.T - D[T,x] - T.B == 0`.

For the fixed alphabet, the dlog gate requires every entry of
`(B/eps)*x*(1+x)` to be an epsilon-independent polynomial of degree at most one,
with no symbol other than `x`. This exactly tests the constant-residue span of
`{1/x,1/(1+x)}`; it uses no numerical tolerance.

`PASS/VERIFIED_EVIDENCE` applies only to this fixed official reference. Strict
reference equality can reject a different constant gauge or basis permutation
that remains a valid scientific candidate. Such candidates use SEARCH_CORE and
its independent main checks. This reference receipt neither certifies an
unrelated seed's UT normalization nor supplies CORE_PASS or workflow routing.

## Regression configuration

Configure `CANON_WOLFRAM_KERNEL` for the licensed test runtime. Interface
regressions use controlled fixtures and can be selected with:

```bash
python3 -m unittest discover -s tests -p test_initial_interface.py -v
```

To enable the real fixed-reference provider/checker regression, set
`CANON_TEST_INITIAL_CONFIG` to a component JSON using the fields described in
[the example](../examples/initial-official-ladder/README.md), then run:

```bash
python3 -m unittest -v \
  tests.test_method_cards.MethodCardIntegrationTest.test_initial_official_ladder_provider_and_independent_checker
```

An unconfigured runtime or real component test is explicitly skipped. The
[seeded-core tests](../tests/test_initial_core.py) have a separate opt-in official
isomorphic probe using `CANON_INITIAL_CORE_RUNTIME_OPTIONS`. Keep generated
outputs, timings and execution logs in a caller-owned local directory.
