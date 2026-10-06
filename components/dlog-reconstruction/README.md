# Sampled dlog reconstruction

This optional package fits constant rational residue matrices from a declared
sample set and supplied analytic letters. It does not find an integral basis,
change frames, reduce IBPs, or prove a global gauge transformation. Select
`components.json` on each `run_step.py` invocation; other CANON steps keep their
selected implementations. Read [WORKFLOW.md](WORKFLOW.md) for result routing.

The only installed dependency is Wolfram Language plus the explicitly supplied
CANON `mma/lib/MethodCardCore.wl`. The runner supplies it through `{canon}`.
`CANON_WOLFRAMSCRIPT` or `wolframscript` on PATH selects the executable. No optional
component imports another optional component. There are no background workers or
parallel kernels.

## Inputs

All steps use the common `canon-neu/script-input/v1` JSON envelope with `sector:
null`. Payload artifacts are `{ "path": "relative/file.wl" }`, optionally with a
`sha256`. Relative paths are resolved from the file that declares them.

`RECONSTRUCT_DLOG` takes `sample_set`, `raw_letters`, and `arithmetic`.
`CHECK_RECONSTRUCTION` takes the same original `sample_set` and `raw_letters`, plus
`reconstruction`. The checker uses the reconstruction's frozen arithmetic; an
explicit checker arithmetic value must match it. Descriptors copied from results
retain their SHA-256. Trusted WL input expressions are evaluated by `Get`.

The `canon-neu/de-sample-set/v1` Association contains shared identity fields
`family_id`, `basis_id`, `chart_id`, `frame_id`, `scope`, ordered symbolic
`variables` (including integer-indexed variables such as `x[1]`), symbolic
`regulator`, and the exact convention string
`D[basis, variables[[i]]] = matrices[[i]] . basis`. It contains `training` and
`validation` lists of `<|"id" -> "name", "path" -> "sample.wl"|>`; `blind` is
optional. IDs, file paths and exact points must be distinct. Validation is
mandatory for acceptance. No held-out file is opened by the fit.

Each `canon-neu/de-sample/v1` has those same fields, `point` as exact rules in
variable order, and `matrices` as the full ordered list of square connection
matrices, retaining symbolic regulator dependence. SparseArray matrices with
zero default are accepted. A missing row, column, direction, or unresolved coefficient is an
error. The independent checker reads every position, including zero positions.

The `canon-neu/raw-letters/v1` Association shares the identity fields and has
separate `labels` (unique strings) and `letters` (exact analytic WL expressions).
Letters may contain radicals but may not contain `Log`, approximate reals or the
regulator. Use one fixed analytic/root frame in all files. This package does not
choose branches; the frame and raw definitions are part of the input identity.

Exact arithmetic is `<|"mode" -> "exact"|>` in WL, or `{"mode":"exact"}` in
JSON. It requires exact sample coefficients. High precision must declare every
parameter, for example:

```json
{"mode":"high_precision", "precision":70,
 "residual_tolerance":"10^-40", "rank_tolerance":"10^-45",
 "recognition_tolerance":"10^-45", "max_denominator":1000,
 "max_numerator":1000}
```

Approximate input coefficients must already have at least the declared precision;
the package does not pad machine values. Tolerances may be positive numbers or
WL numeric-expression strings. Numeric rank uses column scaling and the declared
rank tolerance. Rational recognition uses `Rationalize` at the declared tolerance,
then enforces numerator and denominator bounds and checks the entire training
system. The linear solve includes only the union of nonzero training matrix
positions. Every other position has a zero residue; sparse full-matrix differences
in the checker also catch nonzeros appearing only at held-out points. No dense
matrix conversion or solve for all zero RHS columns is needed. Numerical
residuals are entrywise `Abs[error]/(1+Abs[target])`. Exact mode
uses exact simplification. Epsilon factorization is tested symbolically at each
supplied point by checking that `Together[A/eps]` has no regulator; numerical
coefficient accuracy and finite-point dlog matching remain separate claims.

## Outputs and scope

The fit returns `PROVISIONAL/DLOG_RECONSTRUCTED` and
`canon-neu/dlog-reconstruction/v1`: identity/scope, labels and raw letters, exact
rational sparse residue matrices for **every** letter, full symbolic matrices,
`Atilde = Sum[C_i Log[W_i]]`, independent training columns, arithmetic and source
hashes. Redundant columns receive zero matrices in this representative; the
coefficients are not claimed unique. More training equations than sampled rank
are required. Excluded columns are only dependent on the training samples.

The separate checker reloads the original sample set, sample files and letter
definitions, freshly differentiates `Log[W_i]`, checks hashes/identity/frame,
checks full matrices in every direction at training, validation and blind points,
and detects rank growth outside the training set. It also checks the candidate's
explicit matrices and logarithmic form against its exact residue matrices.
Only this step can return `PASS/RECONSTRUCTION_VALIDATED`, with a per-sample WL
receipt. That is finite-sample evidence, with declared tolerances when applicable;
it never emits `ALL_PASS`, proves alphabet completeness, or replaces CANON's
global gauge checker. Finite points cannot rule out every function that vanishes
on those points.

## Bounded letter proposals

`PROPOSE_LETTERS` takes `one_forms` and positive `max_letters` (default 32).
`canon-neu/analytic-one-forms/v1` has the shared identity and a `one_forms` list;
each item lists exact regulator-free coefficients in variable order. Optional
`seed_letters` contains additional user-supplied analytic expressions. The step
calls the common `DLogAlphabet` on rational entries and `QuadraticRootLetters` on
the supplied forms, retains supplied seeds, and truncates to the declared bound.
It returns provisional `raw_letters` that can be passed directly to the fit.

This is a pole-factor/quadratic-norm proposal, not a universal alphabet solver.
A linear B-wedge-B completion solver is not implemented. The separate exact
one-form/seed input is the hook for such a caller-supplied calculation; its output
still needs reconstruction and independent validation. No research-specific
Sigma formulas or external physical data are embedded.

## Synthetic example

From a CANON checkout, with an explicit writable example directory:

```sh
wolframscript -file components/dlog-reconstruction/examples/make-example.wls /path/to/example
python3 run_step.py /path/to/example/reconstruct.json /path/to/example/fit --components components/dlog-reconstruction/components.json
python3 run_step.py /path/to/example/check.json /path/to/example/check --components components/dlog-reconstruction/components.json
python3 run_step.py /path/to/example/propose.json /path/to/example/letters --components components/dlog-reconstruction/components.json
```

The example is a commuting 2x2 connection with two variables, a radical letter,
one redundant letter, three training points, one validation point and one blind
point. Append `high_precision` to the generator invocation for 90-digit input and
70-digit fitting. Output directories must be fresh. Files can move together:
all generated runtime references are relative to their declaring artifacts.

Run the bounded tests serially with:

```sh
python3 components/dlog-reconstruction/tests/test_reconstruction.py --canon . --work /path/to/fresh-test-work
```

Tests call every scientific step through `run_step.py --components ...`, use one
Wolfram kernel at a time, and retain a compact JSON receipt in the requested work
directory. No physical-family fit or reduction is run.
