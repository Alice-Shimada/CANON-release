# Exact FLINT final check

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
strict parser and fourteen acceptance conditions retain their declared scope.

Optional `method_options.flint_serializer` accepts hash-bound `executable` and
`source` descriptors for the [structural converter](../flint-serialization/README.md).
It changes how gauge residuals are sent to FLINT. The exact gauge equation and
separate basis-definition check remain the same. Omitting it retains the Wolfram
postfix encoder. Successful output records the selected converter and source
hashes, with separate export and conversion timings.

With `method_options.progress: true`, preparation events separately measure the
five input loads, input-schema validation, matrix/domain/trace validation,
the existing `Together[Det[transformation]]` invertibility check, and trace
preparation. These wrappers leave the checked expressions and evaluation order
unchanged. `progress: false` writes no diagnostic event file. The compiled
serializer streams one coefficient at a time; its memory use still depends on
the input and largest coefficient.

The quadratic fixture publishes factored-root basis rows and expanded-root T;
its raw DE retains the factored root after independent manufacture. It has two
variables, a nontrivial lower normalization and an epsilon-dependent invertible
map. An actual old basis-helper rejection is preserved. The necessary basis
repair changes only exact equal-radicand framing and small runtime metadata;
its independent `T*basisRows-I` equation, serializer/native/readback body and
canonical-zero-string acceptance remain intact.
