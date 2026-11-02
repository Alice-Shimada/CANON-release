# Exact equal-radicand FLINT regression

The normalization boundary canonicalizes the finite list of exact rational
radicands with `Factor[Together[radicand]]`, verifies each rational difference
is exactly zero, and merges only equal radicands. It retains the principal
square root. It does not identify unequal radicands through a square factor,
sign, numeric sample or branch choice. Existing strict native parsing, native
source/binary, postfix protocol and scientific checkers are unchanged.

Install the new producer, verifier, Python preparation/driver and this document
under `tests/construction-arithmetic` according to `source-layout.json`. The
portable manifest uses the existing relative `run.py` and typed matrix probe;
the normal constructor uses its public two-argument Wolfram adapter. The tested
workspace manifest instead references the accepted frozen three-argument
provider and launcher in place. No unchanged launcher/provider source is copied.

A caller creates a fresh work directory and `test-config.json` with its checkout,
Python, full ordered component selection plus the portable manifest, environment,
CPU, RSS and per-call/overall budgets, guarded source files, `fixture_directory`,
`normal_runtime` and `old_runtime`. Old and new runtimes must bind the same installed
native and parent sources; only `flint_helper` differs. The caller supplies the
old pinned helper snapshot independently of any state-management installation.
Native/kernel/library paths remain configuration values. Set `verify_tag` to
`final`, `pre_calls` to the public producer request/output if desired, and retain
one first-launch `execution-budget.json` across preparation and all subsequent
calls; never reset it. There is no Fermat invocation or cancellation replay.

Run public `PREPARE_RADICAND_FIXTURES` into the fixture directory using the complete
selection and a hash-bound normal runtime. Its `method_options` select Together
with `candidate_lower_transform_reduce` and `candidate_full_gauge_reduce` set to
`flint`. Then run `prepare_equal_radicands.py --work WORK` to bind the produced
fixture descriptors and old/new runtimes into 14 templates. Finally run
`test_equal_radicands.py --work WORK`. The driver uses public `PREPARE_REQUEST`
and fixture steps, the existing local-jobs `run_owned` lifetime, caller limits,
then the independent public verifier. It reuses already completed case outputs;
no accepted scientific result needs replay solely for packaging.

The suite requires a nonempty case collection and successful independent
verification before reporting `all_pass`. Expected errors must occur at the
intended arithmetic/domain boundary with actual MatrixQ input; their return code
is 1, while successful preparation/construction/verification returns 0. The old
mixed-spelling full gauge and matrix probe reject multiple structural radicands;
the new helper passes a nonzero prescribed target, complete raw gauge, source
composition, basis rows and inverse transformation. Positive probes cover the
physical lambda spellings, rational equality, negative/odd half powers, a root in
a denominator, principal-branch retention and ordinary rational/single-root
inputs. Unequal, square-related, sign-related, nested, inexact and transcendental
radicands remain rejected.

This is an exact small-example engineering regression, not physical canonical
acceptance. The previous physical rejected matrix was not saved. Its possible
connection to the two lambda spellings remains a boundary hypothesis. The tiny
fixture measurements establish no physical performance improvement. Frame and
operation timings use elapsed differences on the same kernel clock; nested
intervals must not be added. Native-child cancellation retains accepted T024
scope because the native engine, call and execution ownership are unchanged.
