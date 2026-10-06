# Point differential equations

This optional package prepares exact point derivatives, constructs a complete
connection from supplied reduction rules, and collects references to samples.
It adds `PREPARE_POINT`, `BUILD_POINT_DE`, and `COLLECT_DE_SAMPLES`. Select its
`components.json` with `run_step.py --components`; it changes no default step.
The only code dependency is CANON's `mma/lib/MethodCardCore.wl`, passed through
the manifest's explicit `{canon}` argument. Wolfram is selected by the runner's
`CANON_WOLFRAMSCRIPT` or PATH. No reducer is launched by this package.

## Implemented mathematical scope

Inputs describe massless propagators `q_i^2`, with `q_i` linear in the declared
loop and external momenta. External momenta have supplied symbolic four-vectors
and a nonsingular four-vector external basis, in metric `{1,-1,-1,-1}`. With
`L` loops the family must contain exactly `L (L+1)/2 + 4 L` independent affine
propagator/ISP coordinates. Lower-rank external kinematics, internal masses,
incomplete coordinates, and loop epsilon tensors are outside this input scope.
Loop count, master count, propagator order, variable order, integral head,
dimension symbol and its regulator rule all come from inputs. Variables can be
symbols or indexed expressions such as `x[1]`.

Loop-loop scalar products remain independent in dimension `d`. In particular,
a Gram determinant containing one loop momentum and four external momenta is
not set to zero. Only the external frame is four-dimensional.

Numerators may be polynomials in propagator coordinates with exact rational or
algebraic external coefficients and regulator factors. The supported atoms are:

- `sp[q] = q.q` and `sp[q,r] = q.r`;
- `Gram[{q1,...},{r1,...}] = Det[2 sp[qi,rj]]`;
- `Eps[q1,q2,q3,q4] = 4 I Det[{q1,q2,q3,q4}]`, for external arguments;
- `prop[i]`, the `i`th propagator/ISP coordinate.

These atom names are recognized in any Wolfram context. Exact square roots use
Wolfram's branch at the supplied point; coordinate and frame singularities are
excluded. This package provides no analytic continuation prescription.

## PREPARE_POINT

The common JSON envelope has `step: "PREPARE_POINT"` and four WL descriptors in
`payload`: `family_data`, `master_basis`, `candidates`, and `point_spec`. Paths
are relative to that JSON file.

`family_data` is a reducer-neutral `canon-neu/parameterized-family/v1` vector
chart, with `family_ref`, `chart_id`, `integral_head`, `variables`, `regulator`,
`dimension_rule`, `metric`, `loop_momenta`, `external_momenta`, `external_basis`,
`vectors`, `propagator_momenta` and `propagator_masses_squared`. This point method
requires symbolically zero internal masses; it returns
`UNSUPPORTED_POINT_DE_MASSES` for a massive family and
`UNSUPPORTED_POINT_DE_CHART` for a scalar-product chart. A zero mass at just one
point does not make a variable-mass chart equivalent to the supported method.
Its declared chart ID must agree with `point_spec`.

Saved `canon-neu/twistor-family/v1` artifacts remain readable, using their
original `propagators` list of momentum squares. Reading these files imports no
old intake code. The stored preparation point is informational here:
`point_spec.point` chooses the current differentiation point.
`master_basis` is the standard
`canon-neu/master-basis/v1`, with ordered `masters`, `family_ref`, and `basis_ref`.
The master order is preserved.

`candidates` is a `canon-neu/point-candidates/v1` Association with `basis_id` and
ordered `rows`. Each row is a sum of terms. A term is an Association with an
integer `indices` list and a `numerator` expression:

```wl
<|"schema" -> "canon-neu/point-candidates/v1", "basis_id" -> "candidate-C",
  "rows" -> {
    {<|"indices" -> {1,1,0,0,0}, "numerator" -> x|>},
    {<|"indices" -> {1,1,1,0,0}, "numerator" -> eps sp[l,p1]|>,
     <|"indices" -> {1,1,0,0,0}, "numerator" -> 1/x|>}
  }|>
```

This specifies supplied candidates. Candidate discovery and its validation
remain separate upstream work; this package performs no candidate search.

`point_spec`, schema `canon-neu/point-spec/v1`, contains `family_id`, the final
`basis_id`, `chart_id`, `frame_id`, an explicit sector `scope` Association,
exact `point` rules for every ordered variable, and a symbolic square `frame`.
`family_id` must agree with both input family references. If candidate rows form
the column vector `C`, the final basis is `J = R.C`, with `R = point_spec.frame`.
Use an identity matrix for an unchanged frame. A nonconstant repair or external
algebraic normalization belongs in this matrix and in the declared frame ID.

Geometry, explicit numerator coefficients and the symbolic frame are
differentiated **before** point substitution. Scalar-product/Gram/epsilon atoms
are evaluated together with their fixed-propagator-coordinate derivatives.
The target union contains candidate projections, all candidate derivatives,
all ordered master derivatives and the masters themselves. Outputs are:

- `prepared_point`: expressions, derivatives, frame value and derivatives,
  ordered masters, identities, point and relative hashed input references;
- `reduction_targets`: `canon-neu/reduction-targets/v1`, with explicit
  `family_ref`, source `basis_ref`, target list, ordered masters and point;
- `reduction_kinematics`: the point's frozen propagator momenta, independent
  external momenta and scalar products;
- `targets_text` and `preferred_masters_text`: integral-list files using the
  declared integral head without Wolfram context prefixes.

## Per-point reduction handoff

Every reduction must use the **same exact point** as its derivatives. Call the
selected parameterization `PREPARE` through `run_step.py` for that point, with
the same symbolic geometry/routing and the new point rules. Pass its neutral
`reducer_family` plus the complete `PREPARE_POINT` target union and preferred
masters to the separately selected `REDUCE_IBP` backend. Backend configuration
and resources are explicit inputs to that adapter. This package does not import
the parameterization or reducer implementation.

The backend owns native project creation and its reduction/export jobs. A
discovery/initiate-only job does not compute these target reductions. A native
project frozen at p00 must not be reused as p01 kinematics. Family and target
heads must agree with the declared adapter encoding; no alias is guessed.

The emitted `reduction-kinematics.wl` is a compact record of the required point
configuration. Bind the supplied rule descriptor to the kinematics actually
used by the reduction. A file match records the caller's declaration; it does
not certify how an external reducer was run.

## BUILD_POINT_DE

Supply `prepared_point` and `ibp_reduction` descriptors. The latter loads either
the standard WL Association containing `masters`/`rules`, or a WL list of fully
back-substituted immediate rules. A descriptor can give `integral_head` to map a
declared reducer head into the prepared master head. No implicit family alias is
guessed.

For a point reduction, include `kinematics`, relative to the request JSON:

```json
"ibp_reduction": {
  "type": "mathematica-expression",
  "path": "reduced/ibp-reduction.wl",
  "kinematics": "prepared/reduction-kinematics.wl"
}
```

`kinematics` may instead reference that point's original
`canon-neu/parameterized-family/v1` artifact, or a saved legacy
`canon-neu/twistor-family/v1` artifact. The declared family, variable order and
point must agree. Point rules must contain no unspecialized kinematic variables.
Alternatively, set `"symbolic": true` for explicitly supplied symbolic rules
valid as functions of the variables; these are specialized at the requested
point. This alternative is used by the small analytic bubble fixture. Do not
set both `symbolic` and `kinematics`.

Reduction must cover the entire target union, be linear in exactly the declared
masters, and leave these source masters as the identity basis. There must be as
many independent candidate rows as masters. Missing targets, changed source
basis, or rank failure return a failed result and a diagnostic, without a sample.

Let `C = T.I`, let `A_I` be the reduced master connection, and let `Q_k` be the
reduced derivative of `C`. Then

```text
projection       = R T
d_k projection   = (d_k R) T + R (Q_k - T A_I,k)
A_J,k            = ((d_k R) T + R Q_k) (R T)^-1.
```

The dimension rule is applied after reduction, retaining full regulator
dependence. `PASS/POINT_DE_BUILT` writes `de_sample`, `point_projection` and
`point_check`. The sample uses `canon-neu/de-sample/v1`, with all ordered
matrices, exact point, identity/scope fields, and the shared convention
`D[basis, variables[[i]]] = matrices[[i]] . basis`.

The check artifact reports complete target coverage, the algebraic gauge
identity and epsilon factorization **at this point**. A non-factorized sample is
still a valid sample and is retained. These outputs do not establish a global
canonical form, a UT basis or a full-family result. Use the reconstruction
component's independent validation, or the existing exact scientific gates for
their own applicable scope.

## COLLECT_DE_SAMPLES

Supply `training` and `validation` lists of `{id,path}` objects, plus optional
`blind`. For example:

```json
{
  "schema": "canon-neu/script-input/v1", "task_id": "COLLECT",
  "step": "COLLECT_DE_SAMPLES", "sector": null,
  "payload": {
    "training": [{"id": "p01", "path": "p01/de-sample.wl"}],
    "validation": [{"id": "p02", "path": "p02/de-sample.wl"}]
  }
}
```

IDs, paths and points must be disjoint. Samples must agree on family, basis,
chart, frame, sector scope, variable/regulator order, matrix dimensions and
convention. The output `de_sample_set`, schema `canon-neu/de-sample-set/v1`, is a
small index with paths relative to its own file. Samples are read one at a time;
only their metadata and points are retained. Matrices are not copied.
Moving a complete path tree preserves these references. The index establishes
input consistency and point separation; it performs no fitting or global check.

## Small example and tests

Copy `examples/` into a writable run directory. The synthetic one-loop fixture
uses supplied analytic bubble rules, `C=x I` and `R=1/x`; its one-direction
connection is `-2 eps/x`, hence `-eps` at `x=2`. No native dependency is built and
no Kira/FIRE job is run.

From the directory containing the copied `examples/`, run:

```sh
python3 /path/to/CANON/run_step.py examples/prepare.json examples/prepared --components /path/to/point-de/components.json
python3 /path/to/CANON/run_step.py examples/build.json examples/sample --components /path/to/point-de/components.json
```

The bounded test runner creates its own small fixture tree, exercises positive
and negative scientific cases through `run_step.py`, moves that tree, and reads
the original references from the new location. It runs at most one Wolfram
kernel at a time and requires a fresh output directory:

```sh
python3 /path/to/point-de/tests/run.py --canon /path/to/CANON --output /path/to/new-test-run
```

`evidence.json` records the scoped checks. The suite includes explicit
coefficient and frame derivatives, external Gram/epsilon atoms, regulated loop
Gram data, indexed variables, two loops, changed master basis, incomplete
reductions, mismatched reduction points, rank failure and relocation.
