# Final CANON result for the three-loop sector-3513 family

## Outcome

The blind, two-variable rational-dlog canonicalization is complete:

- 40 Kira masters in 28 ordered sectors;
- resident status `ALL_SECTORS_ACCEPTED`;
- final report `UT_PREFIX_PASS`, claim class `DLOG`, zero failures;
- exact certification of all 1600 positions of the 40 by 40 prefix;
- physical alphabet `{s,u,1-u}`;
- no numerical connection reconstruction and no determinant-based
  invertibility shortcut.

The scale equation is

```text
A_s = -3 epsilon/s I_40.
```

The `u` matrix and every other entry are proportional to `epsilon`; after
factoring it out, both complete matrices are exactly epsilon-independent.
The exported sparse matrices contain 40 and 259 nonzero entries respectively.

## DlogBasisNext-first restart

Every diagonal block was reconsidered before any off-diagonal fitting.  The
search order was:

1. DlogBasisNext `LoopByLoopDlogBasis`, including loop-order changes, dots,
   and ISP numerators;
2. exact Kira/FireFly quotient-rank and diagonal differential-equation checks;
3. only after the diagonal block passed, exact regulator normalization and
   complete Hom-space lower-sector repair;
4. resident full-prefix acceptance with the lower basis frozen.

This is not a requirement that every dlog one-form contain every variable.
For example, `d u/(1-u)` remains a valid one-variable letter in the
two-variable system.

The top sector 3513 is a direct rank-three DlogBasisNext frame.  Its normalized
leading singularities are `{I/8,-I/8,-I/16}` and dots/numerators supply the
independent directions before any epsilon-rational normalization.  The final
common `epsilon^3` is selected only afterwards by the complete 3 by 37 Hom
cokernel: powers 0, 1, 2, and 4 have exact rank obstructions, while power 3
passes the original unexpanded equation, rational-dlog, and twisted-flatness
gates.  No accepted row is rescaled.

Sector 3481 is the bounded exception, not a reversal of the priority.  The
only v008-covered rank-three DlogBasisNext bundle has an exact mixed-pole trace
obstruction to every kinematics-independent `C(epsilon)` normalization.  A
kinematic gauge exists but is much larger.  After this negative certificate,
the shorter exact rank-three frame was selected.  Its complete tail requires a
common `epsilon` on the current block and the isolated sector-3353 rescaling

```text
epsilon (1-4 epsilon) (1-5 epsilon).
```

The degree-two denominator is fixed by the exact recurrence
`a_n = 9 a_(n-1) - 20 a_(n-2)` and a nonzero Hankel minor.  Thus factors such
as `(1-4 epsilon)` and `(1-5 epsilon)` were kept exactly; no epsilon-zero
truncation was used.  Other factors such as `(1-3 epsilon)` that appear in
individual bad entries are absorbed by the Hom tail when the exact equations
permit it, rather than being guessed as basis normalizations.

## Authoritative artifacts

- `final-canonical-system.m`
  - schema `canon.final-rational-dlog-system/v1`;
  - canonical basis length 40;
  - basis transformation dimensions 40 by 40;
  - complete `s` and `u` connection matrices, each 40 by 40;
  - SHA256
    `d33a3bf496490bb461dcdae5a4e0225c8d17889da7be6b68fa270b5a3888e488`.
- `accepted-prefix-checkpoint-final.m`
  - 28 accepted sector bundles with disjoint row support covering rows 1--40;
  - 837 exact materialized positions and 763 certified structural zeros;
  - SHA256
    `572602ae3c35f093d0a74b08e05d6c95d46d874e8202c6a2cc5e9007be7ac466`.
- `sector-candidates/3353.m`
  - SHA256
    `e9d38b814a62d36ce3fdf0aabf472001ca4f8ac1259a085b4319140ee8bb90d1`.
- `sector-candidates/3481.m`
  - SHA256
    `9236be9c73a3fe569edae69a5f0d17dd4a36f11d482ee28bd3e091e49f45851b`.
- `sector-candidates/3513.m`
  - SHA256
    `0bb8946a1684daec12690e3f23b331a3103e3293f82fe96625e9978b44599f62`.

The final export joins all 28 accepted row bundles.  An earlier export that
contained only rows 38--40 was detected by independent audit and overwritten;
its hash is deliberately not authoritative.

## Exact evidence and regression

The resident notebook returned the final `UT_PREFIX_PASS` after applying the
official candidate files.  The final connection audit independently checked
the full dimensions, sparse nonzero counts, disjoint row partition,
epsilon-independence after factoring, final report, and all 28 on-disk
candidate hashes.

Package regression on the final source tree:

```text
wolframscript -file tests/RunTests.wl
272/272 passed

wolframscript -file tests/RunKiraIntegration.wl
12/12 passed
```

The Kira integration path includes the incremental rule-refresh workflow and
uses the locally installed Kira 3 build with FireFly support.

Useful detailed certificates:

- `scratch/3513-dlog-v008-rank3-repair-report.md`;
- `scratch/3513-eps3-normalization-certificate.md`;
- `scratch/3481-dlog-frame-normalization-decision.md`;
- `scratch/3481-combined-normalization-production-certificate.md`.

These establish an exact rational canonical differential equation.  As usual,
integrand-level dlog/constant-leading-singularity evidence plus an exact
canonical DE is not by itself a separate proof of every possible global
uniform-transcendentality statement or of boundary data.
