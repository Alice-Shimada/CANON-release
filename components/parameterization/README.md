# Reducer-neutral parameterization

Select this package's `components.json` for `PREPARE`. Its code dependencies
are CANON's common `MethodCardCore.wl` and `PhysicalDerivative.wl`, supplied by
`{canon}`. It preserves a symbolic chart and generates physical derivative data. Selection
of discovery, reduction and DE-building implementations belongs to other steps.

The standard [physical derivative module](../../docs/physical-derivatives.md)
generates `prepared-derivatives.wl` automatically. Supply routing and kinematics;
a hand-written `prepared_derivatives` reference in a new-family spec is rejected.

The common request's `payload.family_spec` is a WL descriptor. The spec uses
`canon-neu/parameterization-spec/v1` and declares `family_ref`, `basis_ref`,
`chart_id`, `topology`, `integral_head`, ordered `variables`, `dimension`,
`regulator`, `dimension_rule`, `loop_momenta`, and `external_momenta`.
Momentum labels are symbols; variables may also be indexed expressions such as
`x[1]`. `topology` is the declared family label and `integral_head` is the
scientific integral notation; neither is silently replaced by the other.

Routing is given by parallel `propagator_momenta` and
`propagator_masses_squared` lists, with denominator convention `q_i^2 - m_i^2`.
Supply `index_order`, `propagator_slots` and `top_level_sectors` explicitly.
Index labels may be strings or symbolic labels: WL outputs retain them, while
the JSON reduction view represents them as strings.
Internal squared masses may be symbolic and remain separate from the routing.
All momenta must be linear in the declared loop and independent external
momenta after the supplied momentum relations are applied.

`chart_type` selects one of two input forms:

- `vectors`: supply the symbolic `vectors` matrix in the same order as external
  momenta, a diagonal `metric`, and explicit `external_basis` positions. The
  selected independent vectors must span all supplied vectors. Their component
  count is a property of the supplied chart, not a fixed four-dimensional
  constant. Scalar products and dependent momentum relations are derived before
  any point substitution. The full original vectors remain in `family_data`.
- `scalar-products`: external momenta are the independent list. Supply a complete
  symmetric chart as rules `{{p,p}->s, {p,q}->t/2, {q,q}->m2}` and optional
  explicit `momentum_rules` eliminating dependent momenta in the routing. These
  rules must resolve directly to the independent list. No external vectors or
  external dimension are invented.

Optional `point` is a list of exact numeric rules for declared variables or
invariants. It may be absent or partial. Remaining symbolic coefficients must
have explicit `invariants` records, each with a WL `name` and integer
`mass_dimension`; dimensions are never guessed. For a fully numeric point this
list can be empty. Optional `parameters` is preserved; otherwise it consists
of the declared dimension, variables and invariants. The regulator and dimension
remain symbolic. Inexact points and unbound remaining invariant symbols fail, including inexact
complex numbers. Exact complex rational coefficients remain supported. The
dimension rule must replace the declared dimension; variables, momentum labels,
dimension and regulator must not be confused. Sector masks must be nonnegative
and may set only the declared propagator slots.

The outputs are:

- `family_data`, WL `canon-neu/parameterized-family/v1`: complete symbolic
  routing, masses, vectors or scalar products, momentum relations, declared
  orders/identities, point rules and source hash;
- `reducer_family`, JSON `canon-neu/reducer-family/v1`: the declared point's
  routing/scalar products, or a symbolic reduction view. All expression values
  use WL `InputForm` strings. Its family reference is relative to this file;
- `prepared_family`, standard WL `canon-neu/prepared-family/v1`: normal family
  metadata including both `topology` and `integral_head`, and relative references
  to these outputs and the generated physical derivatives. An optional
  `ordered_masters` reference is rebased from the spec; missing masters are marked
  false in `available_inputs`. An optional
  `operator_source_symbol_map` is passed through for standard derivative readers.
- `prepared_derivatives`, WL `canon.prepared-derivatives/v2`: exact physical
  kinematic chain-rule records in the declared variable and denominator order.

The JSON reduction view follows the shared neutral contract: `family_ref`,
`basis_ref`, `chart_id`, `topology`, `integral_head`, `index_order`,
`propagator_slots`, `top_level_sectors`; momentum-name lists; `propagators` with
`momentum`/`mass_squared`; `scalar_products` with `momenta`/`value`; explicitly
dimensioned remaining `invariants`; the exact `point`; dimension, variables,
regulator, dimension rule and relative `family_data` descriptor. It contains no
software selection, process settings, project directory or native configuration.

`PREPARE` returns `PASS/PARAMETERIZATION_READY`. It writes no native project and
does not discover masters or reduce integrals. Adapters consume the same neutral
view and apply their documented capability limits. The symbolic
`prepared_family` and `prepared_derivatives` feed the standard target,
reduction and DE interfaces with matching source identities.

A failed JSON export returns `FAIL/REDUCER_FAMILY_EXPORT_FAILED` before publishing
the prepared-family descriptor.

Copy the small `examples/` directory into a writable run location. From its
parent directory, these calls prepare an indexed vector chart and an unrelated
symbolic invariant chart:

```sh
python3 /path/to/CANON/run_step.py examples/vector-prepare.json examples/vector-prepared --components /path/to/parameterization/components.json
python3 /path/to/CANON/run_step.py examples/scalar-prepare.json examples/scalar-prepared --components /path/to/parameterization/components.json
python3 /path/to/CANON/run_step.py examples/scalar-build.json examples/scalar-de --components /path/to/parameterization/components.json
```

The scalar example generates its derivatives and supplies a master and analytic
reduction rules; the existing default DE builder obtains `d I/du = -eps/u I`. These are
bounded fixtures, not a newly executed native reduction. Paths in the spec are
relative to that spec, while request descriptors are relative to their JSON.
Moving the complete directory tree preserves references.

For the bounded scientific and relocation tests, provide a fresh output directory:

```sh
python3 /path/to/parameterization/tests/run.py --canon /path/to/CANON --output /path/to/new-test-run
```

The suite uses one Wolfram kernel at a time, supplied analytic bubble rules and
no native reduction process. It verifies arbitrary and indexed charts,
explicit masses and invariant dimensions, and the default discovery/DE consumers after
relocation. Its generated selection manifest chooses phases independently.

An existing output artifact is never silently reused as a new preparation result.
A refused artifact write returns `FAIL/ARTIFACT_WRITE_FAILED`.
