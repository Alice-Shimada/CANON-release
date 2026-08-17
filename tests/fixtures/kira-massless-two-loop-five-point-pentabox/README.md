# Massless two-loop five-point pentabox fixture

This is the planar family of Gehrmann, Henn and Lo Presti,
arXiv:1807.09812, eq. (3.1). Slots 1--8 are propagators, slots 9--11 are
numerators. Kira may use `symbol_to_replace_by_one: s51` internally, but the
`kira2math` job has `reconstruct_mass: true`; its exported rules therefore
restore `s51`. The prepared derivatives and final differential equations keep
the ordered variables `{s12,s23,s34,s45,s51}` without a fixed-scale
substitution.

The directory contains only the frozen inputs needed by the minimal workflow:

- Kira family and kinematics configuration;
- one reduction job and one `kira2math` export job;
- the 61 preferred masters and two derivative targets;
- five exact affine operators and bounded enhanced-Baikov search data;
- `BuildPreparedPentabox.wls`, which derives the five lifts from the full
  unscaled external Gram matrix and writes only to a fresh output path.

The generator checks the coordinate Jacobian, the five Gram-lift equations,
the five Gram-determinant identities, all five bundles of affine denominator
identities, the masslessness of the momentum-conservation leg, and the full
unscaled Baikov determinant identity before writing the fixture.

The optional live test uses exactly 20 Kira threads:

```sh
wolframscript -file tests/RunPentaboxIBPLiveTest.wls KIRA_EXECUTABLE FRESH_OUTPUT
```

No Kira output, machine path, runtime log, hash certificate, or discovery
history is part of the fixture.
