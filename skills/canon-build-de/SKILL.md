---
name: canon-build-de
description: Build exact ordered differential-equation matrices from affine family operators, ordered masters, and fully reduced rules.
---

# Build differential equations

Load the three mathematical inputs in one Wolfram kernel and call:

```wl
Get[FileNameJoin[{repoRoot, "mma", "lib", "DEBuilder.wl"}]];
result = BuildDifferentialEquations[family, masters, rules];
```

Follow `INTERFACES.md`: `family` contains only declared parameters and ordered
`m x (m+1)` affine operators; `masters` fixes matrix order; immediate `rules`
must already close exactly on those masters. Require a result with exactly
`matrices` and `validity`.

`exact-point-samples` proves only the one recorded exact-rational assignment of
all declared parameters, including dimension, per pair after symbolic differentiation. Require
`validity["flat"] === True` and every pair record's `"zero"` value to be `True`;
there is no sampling retry or alternate point. Do not make the core find
executables, run Kira, generate targets, choose operators, read/write files, or
produce state/provenance metadata. The Agent serializes and registers the
accepted result outside the core when the workflow requires an artifact.
