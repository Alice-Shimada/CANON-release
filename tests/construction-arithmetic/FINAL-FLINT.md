# Exact FLINT FINAL regression

The new public option `method_options.gauge_backend: "flint"` checks every entry
of every direction of `A_i T - D_i T - T B_i` with the accepted strict FLINT
normalizer. The existing independently required invertibility of T makes this
equivalent to the original gauge relation. The checker uses the accepted B only
alongside this exact residual gate. A nonzero parsed residual makes
`exact_global_gauge` false and returns `FAIL/FULL_SYSTEM_FAIL`, without canonical
outputs. The fourteen scientific acceptance expressions remain byte-identical.

Supply the installed `flint_executable` path as a string, optional
`flint_executable_sha256`, and `flint_threads: 1`. Optional checked artifact
bindings `flint_gauge_helper`, `flint_normalization_helper` and `flint_source`
select caller-installed source; defaults are the corresponding files under the
current CANON checkout. Each helper is loaded and its public function checked
before construction. `GAUGE_BACKEND_UNAVAILABLE` records missing/mismatched
entries or failed initialization. `UNSUPPORTED_GAUGE_ARITHMETIC` records the
normalizer's domain rejection; `GAUGE_ARITHMETIC_FAILED` records native or strict
readback failure. There is no backend fallback. Successful canonical output
records source/helper/executable hashes, native header/runtime versions, one
thread and exact selected backend.

Residual normalization accepts exact rational functions or one unnested
principal quadratic generator, merging only strictly equal rational radicands.
It does not identify square-related, sign-related or numerically equal
radicands. Per-direction sparse products precede normalization. Product,
normalization, framing, native and readback timings/events retain their actual
clock scopes; nested intervals cannot be added. The native engine, binary,
normalizer and strict parser remain unchanged.

The quadratic fixture publishes factored-root basis rows and expanded-root T;
its raw DE retains the factored root after independent manufacture. It has two
variables, a nontrivial lower normalization and an epsilon-dependent invertible
map. An actual old basis-helper rejection is preserved. The necessary basis
repair changes only exact equal-radicand framing and small runtime metadata;
its independent `T*basisRows-I` equation, serializer/native/readback body and
canonical-zero-string acceptance remain intact.

For portable testing, install sources as `source-layout.json` specifies. Reuse
existing `run.py` and `components/local-jobs/support.py`; the new `final-host.py`
is the same exec adapter with only the public FINAL two-argument interface
adaptation. All installed kernel, library, source, native and thread paths come
from caller configuration. Create a fresh work directory and `test-config.json`
containing the checkout, full eleven-component selection plus the portable
manifest, CPU/RSS/timeout limits, environment with no usable Fermat path,
`normal_runtime`, `fixture_directory`, and hash-bound `gauge_options`. Optional
`fault_native` and `empty_gauge_helper` bind retained test-only failure controls;
unchanged controls are caller inputs, not copied dependencies.

Invoke public `PREPARE_FINAL_GAUGE_FIXTURES` with a hash-bound runtime, then run
`prepare_final_flint.py --work WORK` to create request templates and cases.
Use `test_final_flint.py --work WORK` with `verify_tag: "final"`. It binds cases
through `PREPARE_REQUEST`, runs public FINAL or typed engineering probes and
runs the independent verifier. Keep one first-launch `execution-budget.json`
from fixture preparation through collection; no cap reset. Case outputs are
reused, and a passing suite requires nonempty cases and independent checks.
The old basis rejection is historical engineering evidence, not a future
expected failure after integration.

Rational and quadratic FINAL cases agree with independent System Wolfram
inverse-gauge, prescribed-target, full basis and residue reconstruction. Bad
accepted B and bad basis fail separate gates. Domain probes use actual matrix
inputs and reach the new gauge helper's normalizer; they are explicitly
engineering probes because standard FINAL's unchanged exact input contract
rejects inexact input earlier. No scientific validator is bypassed. Missing
native, pin mismatch, native error and uninitialized helper cases fail closed.
No Fermat backend is initialized or invoked; legacy/default code is preserved
for other callers but only System Wolfram supplies comparisons here.

The retained suite has 227 true independent flags across 16 cases. Thirty-six
public calls have receipts and closed groups; an initial producer syntax-only
attempt lacks a receipt and final accounting and is separately retained with
closure evidence. A first failed verifier exposed a root-spelling coverage
assumption; its producer/input/request/output bytes remain retained. Only the
corrected quadratic input and affected verifier were rerun. Native cancellation
reuses accepted T024/A-4046 because execution ownership and native call are
unchanged. These tiny fixture results make no physical-family completion or
performance claim.
