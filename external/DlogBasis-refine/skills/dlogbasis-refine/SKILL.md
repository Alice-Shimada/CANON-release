---
name: dlogbasis-refine
description: Use the local DlogBasis-refine Wolfram package to construct families, choose loop-by-loop order and dimensions, scan bounded numerators and dots, generate regulated constant-leading-singularity candidates, or connect those candidates to CANON.
---

# DlogBasis-refine

Use the caller-declared DlogBasis-refine checkout. In the CANON distribution it is
`external/DlogBasis-refine`, relative to the CANON project root. Resolve it from
the current project or this skill's package root, never from a personal directory.
Source revisions are recorded in CANON's `external/sources.json`; do not use a
parent repository's Git HEAD as this package's revision. Standalone study scripts
accept the declared revision through `DLOGBASIS_REVISION`.
Load `DlogBasis.wl`; the public context is ``DlogBasis``` and the main API is
``DlogBasis`DlogBasisSearch``. Do not use the retired
``DlogBasisRefine`GenerateSectorCandidates`` interface.

## Direct search

Construct the family with ``DlogBasis`CreateDlogFamily``. Pass the sector as a
bit list with one entry for every element of `Family["Propagators"]`; use zero
for ISP slots. Call:

```wl
result = DlogBasis`DlogBasisSearch[
  family, sector,
  "LoopSpecifications" -> {
    <|"Momentum" -> k2, "BaseDimension" -> 4|>,
    <|"Momentum" -> k1, "BaseDimension" -> 2|>
  },
  "NumeratorDegreeBound" -> 2,
  "DotDegreeBound" -> 1,
  "NumeratorPositions" -> Automatic,
  "FiniteFlowPackageFile" -> finiteFlowFile
];
```

The order of `LoopSpecifications` is the LBL integration order. Each
`BaseDimension` is attached to the named loop momentum, so reordering loops
does not reassign dimensions. The actual regulated dimensions are
`D0_i-2 DlogBasis`DimensionalRegulator`; never replace this search by an
integer-`D0` form.

`NumeratorDegreeBound` and `DotDegreeBound` are separate total-degree bounds.
`NumeratorPositions -> Automatic` scans the reduced chart and singleton
missing-numerator charts; pass an explicit position list only when the chart is
part of the requested experiment. `ResidualBackend -> "Current"` is the
supported default. Use `"ImplicitAlgebraicExperimental"` only for an explicit
experiment and report it as such.

Read candidate directions from `result["CandidateCombinations"]`. Preserve
`ScientificStatus`, `CandidateChartCompleteQ`,
`AffineFiniteConstantResiduesVerifiedQ`, and the three global certification
flags. A nonempty list is a bounded finite-affine constant-LS proposal. It does
not prove global dlog behavior, UT, IBP independence, completeness, or a
canonical differential-equation basis.

The installed 2l5p and 3l5p family examples are under `Tests/Families`; the
2l5p family source and literature-derived sector manifest are under
`Resources/Pentabox2L5P`. Run package tests in a fresh noninteractive kernel
with `Tests/RunTests.wls` and an explicit `FiniteFlow.m` path.

## CANON adapter

CANON calls `methods/dlogbasis/run.wls`. Its prepared `family_data` must return
an association containing `"Family"`, while `sector_source` supplies the exact
sector bits and basis count. Set these `method_options`:

- `package_entry`: the canonical `DlogBasis.wl` path;
- `finite_flow_package_file`: the installed `FiniteFlow.m` path;
- `loop_order`: one-based positions in `Family["LoopMomenta"]`;
- `loop_dimensions`: the corresponding `D0_i` values;
- optionally `numerator_positions`, `residual_backend`, and
  `singular_executable`.

The CANON power-counting payload supplies `numerator_degree` and total
`max_added_dots`. The adapter converts inert
``DlogBasis`DlogIntegral[hash,{a1,...}]`` atoms to CANON
`j[topology,a1,...]`, maps kinematic variables by their declared order, and
groups the returned candidate directions according to the current-sector basis
count. Treat its output as `PROVISIONAL/INTEGRAL_CANDIDATES`; downstream IBP and
independent CANON checks retain acceptance authority.
