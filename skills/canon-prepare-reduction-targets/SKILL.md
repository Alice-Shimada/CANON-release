---
name: canon-prepare-reduction-targets
description: Prepare the declared ordered masters' symbolic affine derivative targets for reduction.
---

# Prepare symbolic reduction targets

Invoke `python3 run_step.py INPUT.json FRESH_OUTPUT_DIR`, carrying the selected
component manifests. Set `step` to `PREPARE_REDUCTION_TARGETS`; its payload has
`prepared_family` and `master_basis` artifact descriptors. See
`interfaces/reduction-targets-request.example.json` for the complete envelope.

Both artifacts must declare matching string `family_ref` and `basis_ref` values.
The shared loader checks these identities once before loading derivatives;
a mismatch returns `ERROR/SOURCE_BASIS_MISMATCH` with no artifacts in both
`PREPARE_REDUCTION_TARGETS` and `BUILD_CUT_DE`.

An optional `payload.prepared_derivatives` descriptor selects a derivative file
relative to the request. Otherwise the step loads the derivative file declared
by `prepared_family`, resolving its path relative to that prepared-family file.
The explicit selection is authoritative; both paths use one normalization.
`BUILD_CUT_DE` accepts the same optional descriptor. The step applies the explicit
`operator_source_symbol_map` and shares the same derivative normalization with
`BUILD_CUT_DE`. The prepared variable order and matching ordered operator keys
are authoritative: normalization sets the redundant derivative `variables`
field to that checked order without changing the source file. V2 affine records
and the existing single-variable legacy record form are supported.

``CANON`CandidateIBPBridge`MasterDerivativeTargets`` computes the symbolic targets
from the declared source masters. It removes source masters and duplicate
targets while preserving the helper's first-occurrence order. No coordinates,
regulator values, dimension substitution or frames are specialized here.

`PASS/REDUCTION_TARGETS_READY` returns `reduction_targets`, with schema
`canon-neu/reduction-targets/v1`, `family_ref`, source `basis_ref`, ordered
`targets`, ordered `masters`, and an empty symbolic `point` list. Pass it and the
same source basis to the selected `REDUCE_IBP` adapter. An empty target list is
valid when the affine derivatives already close on the supplied masters.
The result prepares reduction input; it does not establish reduction coverage,
UT behavior or canonical form.

## Shared helper contract

Load `MethodCardCore.wl` and `SectorDE.wl`. The latter exports:

- `LoadPreparedDerivatives[prepared, preparedPath, masterBasis, derivativePath:Automatic]`:
  load and check the external derivative records once; return `derivatives` and
  `input_form`. A selected explicit path is already resolved by the caller;
  `Automatic` uses the prepared family's embedded reference.
- `NormalizePreparedDerivatives[value, variables, denominatorCount]`: the same
  checked normalization for an in-memory external value.
- `BuildOrderedMasterDE[prepared, masterBasis, reduction, normalized]`: consume
  that checked result and, with `DEBuilder.wl` loaded, build the complete ordered
  DE once, apply the declared dimension rule, and check exact closure once.
- `ValidateOrderedMasterDE[ordered]`: validate an external complete DE before
  slicing. Internally built matrices do not pass through this check again.
- `CurrentSectorRecord[ordered, manifest, requestedSector]`: check the manifest
  binding and select the complete sector record for the shared
  ``CanonMethodCard`SectorDEArtifacts[ordered, manifest, record]`` pure slicer.

The helpers return `Failure` for invalid inputs. Malformed affine data retain
`INVALID_PREPARED_DERIVATIVES`; unclosed or non-rational constructed DEs retain
`INVALID_DIFFERENTIAL_EQUATION`. Exact slices inherit the checked matrices and
are not subjected to another rationality or full-matrix publication check.
