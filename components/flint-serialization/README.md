# Optional FLINT expression serialization

`fullform_postfix.cpp` converts a framed Wolfram FullForm expression to the
postfix format consumed by the existing FLINT quadratic-pair utility. It performs
structural conversion only. FLINT still performs all arithmetic, and the existing
strict result parser checks the returned coefficients.

Compile this source with an installed C++17 compiler into a caller-selected
location. The reusable build helper is
[`build_serializer.py`](../../tests/construction-arithmetic/fast-serialization/build_serializer.py).
Run it with `--work WORK`; that directory supplies `build-config.json` containing
`compiler`, `flags`, `cpu`, `environment`, `timeout_seconds`, `source` and
`executable`. Relative source/output paths resolve from `WORK`. The helper records
the actual compiler command and source/executable hashes. Selecting serialization
does not compile or install anything, and no binary is distributed here.

Add this object to the construction runtime JSON, or to `FINAL_CHECK`'s
`payload.method_options` when `gauge_backend` is `"flint"`:

```json
{
  "flint_serializer": {
    "executable": {"path": "installed/fullform_postfix", "sha256": "<executable SHA256>"},
    "source": {"path": "source/fullform_postfix.cpp", "sha256": "<source SHA256>"}
  }
}
```

Paths resolve from the JSON file declaring them. Both hashes and the executable's
format version are checked before use. Omitting the object retains the Wolfram
postfix encoder. There is no fallback after a selected converter fails.

The shared normalizer determines exact rational radicand equality and preserves
the principal quadratic root. The converter accepts only the declared symbols,
exact integers and rationals, sums, products, bounded integer powers, and the
declared matrix dimensions. It rejects malformed or unsupported structure before
arithmetic. Qualified names and Unicode symbols retain their identities. Native
text is never evaluated, and the converter creates no detached process.

The Wolfram writer streams one FullForm coefficient at a time in UTF-8 under a
fixed symbol context. It does not construct a string for the entire matrix.
Additional formatting storage depends on the largest coefficient and the frame;
the input matrix and existing domain construction still occupy memory. This does
not impose an absolute memory ceiling. Open, write and close failures stop the
call before conversion or arithmetic. Owned streams close on failure or abort,
and a failed close retains its handle for cleanup.

Runtime records separate FullForm export, conversion, native arithmetic and
strict readback. A faster conversion alone does not establish a faster complete
calculation. The [regression suite](../../tests/construction-arithmetic/fast-serialization/README.md)
compares exact postfix bytes and independent mathematical results, including the
separate fourteen final checks.
The [streaming regressions](../../tests/construction-arithmetic/stream-serialization/README.md)
also cover output-stream lifetime and a fixed-input memory comparison.
