# Construction normalization

`BUILD_FULL_DE` accepts `payload.method_options.normalization_backend`:

- `"together"` (the default) uses Wolfram `Together`.
- `"finiteflow"` uses the caller's installed FiniteFlow `FFTogether` for the
  general construction's matrix normalizations.
- `"flint"` uses the caller's installed exact quadratic-pair engine, reducing
  the root relation during native arithmetic and reading back nonzero coefficients.
- `"fermat"` uses the caller's installed Fermatica/Fermat for exact matrix
  normalization in the declared rational or single-quadratic domain.

This option changes arithmetic in construction. It does not replace
`CHECK_CORE`, `CHECK_CANONICAL`, or `FINAL_CHECK`, and a construction `PASS`
does not certify a canonical or UT basis. The separate zero-block assembly and
`block_backend` option retain their existing scope.

Use `normalization_backends` to select particular phases explicitly. Unspecified
phases inherit `normalization_backend`; the only accepted phase names are
`source_current_lower_reduce`, `current_core_inverse_reduce`,
`candidate_lower_transform_reduce`, and `candidate_full_gauge_reduce`.
For example, this policy uses FiniteFlow only for the candidate lower map:

```json
{
  "normalization_backend": "together",
  "normalization_backends": {
    "candidate_lower_transform_reduce": "finiteflow"
  }
}
```

Choose a policy from measured costs. There is no automatic backend fallback.
Unknown phase names and invalid values are rejected. If every effective phase
uses `together`, no native backend is loaded, even when the default was
overridden from a native backend. The runtime record includes the complete effective
map and reports `backend: mixed` for a mixture; each event records its actual
phase backend.

For `finiteflow`, supply `method_options.runtime_config` as a JSON artifact
descriptor with `path` and `sha256`. The JSON requires:

| Field | Meaning |
| --- | --- |
| `finiteflow_entry` | `path`/`sha256` descriptor for the installed `FiniteFlow.m`. |
| `finiteflow_library` | `path`/`sha256` descriptor for the installed native library. |
| `finiteflow_threads` | Positive integer used for both `FFNThreads` and reconstruction `NThreads`. |
| `finiteflow_max_primes` | Optional nonnegative reconstruction bound; default 5. Zero is useful for failure testing. |
| `finiteflow_revision` | Optional declared dependency revision; record unknown when the installed build is not established. |

Paths inside that JSON resolve relative to the JSON file. The normal public
runner selects the Wolfram executable; the runtime descriptor above configures
arithmetic, not process ownership or a wall-time limit. Caller-selected execution
components continue to own resource limits and cancellation.

Initialization records automatic library discovery, then binds the declared
library through the installed package's loader. It checks that the native
`LibraryFunction` actually names that library. The entry/library hashes and
thread settings are written to `arithmetic-runtime.json`; native binding is
recorded in `native-load-readback.json`. Missing or mismatched installations
return a scoped error without falling back to another backend.

The supported coefficient domain is exact rational functions and unnested
principal quadratic powers of rational radicands. Identical radicands share a
formal generator during reconstruction, after which the original principal
roots are restored. This preserves the expression without `PowerExpand` or
numerical substitutions; it need not find a minimal algebraic normal form.
Unsupported roots, inexact or transcendental coefficients, undefined restored
expressions, and unsuccessful reconstruction produce explicit errors.

`normalization-events.jsonl` records relative start/end times for the source
lower block, current inverse, candidate lower transformation and full gauge
normalizations. Nonconstant `FFTogether` calls include their row and column.
Matrix intervals include their entry intervals and must not be added to them
as disjoint costs. These events are operational measurements, not proof of
mathematical acceptance.

For `fermat`, the same hash-bound runtime JSON requires:

| Field | Meaning |
| --- | --- |
| `fermat_dependency` | `path`/`sha256` descriptor for `mma/lib/FermatBlockArithmetic.wl`. |
| `fermatica_entry` | `path`/`sha256` descriptor for the installed `Fermatica.wl`. |
| `fermat_executable` | `path`/`sha256` descriptor for the installed Fermat executable; `FERMATPATH` must resolve to that path. |
| `fermat_threads` | `1`, the supported execution setting for this backend. |

Paths resolve relative to the runtime JSON. Set a phase value to `"fermat"`
explicitly; other phases keep their configured backends. The runtime records
the actual package, executable, dependency hashes and versions. Together,
FiniteFlow, Fermat and FLINT can be selected for different phases in the same call.

The Fermat backend accepts exact rational matrices or matrices with one
unnested principal quadratic generator. It restores that generator after exact
binomial reduction, without `PowerExpand` or numerical substitution. Multiple
or nested roots, inexact/transcendental input and native arithmetic failures
return scoped errors. This matrix normalization interface does not change the
separate zero-block route's applicability conditions.

The constructor also checks helper loading and initialization before loading
the scientific inputs. A failed helper cannot silently produce a construction
PASS. Independent tiny fixtures, installation checks and public cancellation
coverage are described in
[`tests/construction-arithmetic/FERMAT-POLICY.md`](../tests/construction-arithmetic/FERMAT-POLICY.md).


The normalizer validates expression nodes during serialization and validates the
collected symbol list once. The native utility handles a purely rational inverse
as `1/a`, retaining the general quadratic inverse for a nonzero root coefficient.
Select the source and executable from the same installed build; runtime hashes
identify which implementation a call actually used.

For `flint`, the hash-bound runtime JSON requires:

| Field | Meaning |
| --- | --- |
| `flint_helper` | `path`/`sha256` descriptor for `mma/lib/FlintNormalization.wl`. |
| `flint_source` | `path`/`sha256` descriptor for `components/basis-diagnostic/flint_pair.cpp`. |
| `flint_executable` | `path`/`sha256` descriptor for the caller's installed quadratic-pair executable. |
| `flint_threads` | `1`, matching the current native implementation. |
| `flint_serializer` | Optional object with hash-bound `executable` and `source` descriptors for the structural converter described below. |

The executable is an installation input; selecting this backend does not build
or copy a binary. Runtime records include source, helper and executable hashes,
header/runtime versions, effective phase choices and thread settings. For
example, to select FLINT for the two candidate stages:

```json
{
  "normalization_backend": "together",
  "normalization_backends": {
    "candidate_lower_transform_reduce": "flint",
    "candidate_full_gauge_reduce": "flint"
  }
}
```

The supported matrix contains exact rational functions or one unnested
principal quadratic generator. Radicands with different expression forms share
that generator only when exact rational normalization proves they are equal.
Unequal radicands are not merged by a square factor, sign or branch choice.
Each call retains a small `radicand-frame.json` with the raw and canonical
radicands and the domain decision, including rejected frames.
Native arithmetic uses pairs `a + b sqrt(lambda)`
and reduces the root relation at each operation. The output parser accepts only
exact integer/declared-variable arithmetic; it checks pair counts, variable
indices, version/count receipts and the native zero flag. Constants use an
internal unencoded variable slot that cannot appear in output. The native
protocol supports at most 64 variable slots and integer powers with absolute
value at most 10000. Unsupported domains and undefined inverses fail closed.

Events distinguish radicand canonicalization, serialization, native arithmetic and readback within each
inclusive phase interval. See
[`tests/construction-arithmetic/FLINT-POLICY.md`](../tests/construction-arithmetic/FLINT-POLICY.md)
for the focused regression interface and the corrected matrix-probe boundary.
Strict radicand equality and principal-branch retention are tested in
[`EQUAL-RADICANDS.md`](../tests/construction-arithmetic/EQUAL-RADICANDS.md).

An explicit `flint_serializer` selects compiled conversion of the framed
expression to the existing native postfix format. Wolfram formats the exact
expression in FullForm; the converter checks the declared symbols, arithmetic
structure and matrix dimensions before publishing the postfix file. It performs
no algebra. Without this option, serialization uses the existing Wolfram encoder.
The FullForm writer formats and writes one coefficient at a time. It avoids a
full-matrix string, while retaining the input matrix and the largest individual
formatted coefficient in memory. Stream errors stop before native arithmetic.
The root relation, native arithmetic and strict result parser are shared by both
paths. Invalid configuration or conversion fails without backend fallback.

`flint_fullform_export` and `flint_converter` are separate intervals before
`flint_native` and `flint_readback`. Compare their sum to the former
`flint_serialize` interval; do not add the containing normalization interval.
See [installation and configuration](../components/flint-serialization/README.md)
and [independent regression coverage](../tests/construction-arithmetic/fast-serialization/README.md).
