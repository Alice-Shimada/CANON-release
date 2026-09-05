---
name: canon-build-cut-de
description: Build the exact current-sector quotient basis and cut differential equation from accepted preparation, discovery, and reduction artifacts.
---

# Build the sector cut differential equation

In the assigned run workspace, invoke:

```text
wolframscript -file mma/BuildSectorCutDE.wls INPUT.json FRESH_OUTPUT_DIR
```

The `BUILD_CUT_DE` payload contains `prepared_family`, `master_basis`,
`sector_manifest`, and `ibp_reduction`. The prepared family explicitly
declares `regulator` and `dimension_rule`; never infer either from a symbol name.

The script converts the accepted affine denominator records to the one
`DEBuilder` family object and calls `BuildDifferentialEquations` exactly once on
the complete ordered master basis and fully reduced rules. It then finds every
master whose positive propagator bits equal the requested sector bits, in the
resident master order, and takes the same positions from the rows and columns of
each ordered matrix. The column projection quotients only strict proper-subsector
tails; no same-sector entry or mixture is removed. Apply the declared dimension
rule only after constructing the complete differential equation.

PASS writes `canon-neu/sector-basis/v1`, `canon-neu/sector-cut-de/v1`, and the
same call's complete `canon-neu/ordered-master-de/v1` for downstream prefix
construction. The convention is
`D[basis, variable[[i]]] == matrices[[i]].basis`. `sector_boundaries` contains matrix index intervals; `proper_subsectors` lists
the strict proper subsectors defining the quotient. This result certifies the exact
ordered cut block and the recorded DE validity scope; it does not establish a UT
basis, canonical form, global IBP completeness, or a full-system certificate.

For each later resident sector, invoke `mma/SliceSectorCutDE.wls` with step
`SLICE_CUT_DE`. It consumes only the accepted `ordered_master_de` and
`sector_manifest`, directly slices the matching rows and columns, and emits only
`sector_basis` and `sector_cut_de` without rebuilding the differential equation.

For a DE-only route, use ``CANON`CandidateIBPBridge`MasterDerivativeTargets`` to generate targets from the ordered masters
and prepared derivatives, then run the existing ReduceIBP adapter. No integral
candidate artifact is needed.
