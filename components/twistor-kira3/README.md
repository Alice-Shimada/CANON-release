# Migration from the coupled twistor/Kira intake

This directory now contains only a two-step selection profile. `PREPARE` binds
to [parameterization](../parameterization/README.md); `DISCOVER` binds to the
independent [Kira adapter](../reducers/kira/README.md). There is no implementation
or native configuration here. Other steps keep their previously selected or
default implementations.

For new work, select each phase explicitly, using
[custom-kira.json](../profiles/custom-kira.json) or
[mixed-reducers.json](../profiles/mixed-reducers.json) as a starting point.
The first also selects Kira for `REDUCE_IBP`; the second selects separate
discovery, reduction and DE providers. Any chart supported by the selected
parameterization producer can be used with a compatible reducer.

Old request files need the following data migration:

1. Replace the old twistor family spec with a
   `canon-neu/parameterization-spec/v1` spec. Supply the symbolic vector chart
   using `chart_type: vectors`, or supply scalar products. Declare routing,
   squared masses, index order, dimensions and point separately. See the
   [vector example](../parameterization/examples/vector-spec.wl).
2. Run `PREPARE` with `payload.family_spec`. Its `family_data`, `reducer_family`
   and `prepared_family` artifacts contain scientific data and relative
   references, without selecting a reducer.
3. Put the executable, options and native seed or jobs into a separate
   [Kira backend configuration](../reducers/kira/examples/backend.json).
   The discovery request supplies `payload.reducer_family` from preparation
   and `payload.backend` pointing to this configuration.

The old `twistor-kira3-intake/v1` JSON and inline `payload.kira` configuration
are not inputs to these new providers. Saved `twistor-family/v1` scientific
artifacts remain readable by the [point-DE module](../point-de/README.md).
Existing results do not require scientific replay for this migration.
