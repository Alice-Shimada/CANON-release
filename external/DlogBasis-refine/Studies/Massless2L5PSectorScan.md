# Massless 2L5P pentabox sector scan

## Scope

The scanned family is the planar massless two-loop five-point pentabox of
arXiv:1807.09812.  Its official `pentabox_basis2.txt` ancillary contains 61
distinct scalar master-integral atoms and exactly 46 sectors.  The ancillary
SHA256 used here is
`a5a9529d8b1e5d9af72685261dd5b1238e656e7e3757f732ae193a7e91396841`.

For each sector, the scan uses the largest numerator degree and dot degree
actually present among those 61 masters.  It tests both LBL orders and all
named-loop dimension pairs `(d_k1,d_k2) in {2,4,6}^2`, for 18 configurations
per sector and 828 runs in total.  `F` denotes the family order `{k1,k2}` and
`R` its reverse.  Dimensions remain attached to the named loops when the order
is reversed.

The 828-run classification table below is a frozen historical baseline from
package commit `0ec9e6b48482751121acbcc96af4c1d1cad883fb`.  It is retained for
provenance and is not a current-backend classification.  In particular, the
current FiniteFlow ordered-cut backend advances sectors 182, 218, and 229 from
the baseline `U` label.  The strict-backend discussion below is itself now a
historical comparison: the first-nonzero regulated generalized-cut backend
recovers both the undotted direction and the propagator-8 dot in sector 182,
and recovers the analogous article dot in sectors 218 and 229.  These are
finite-affine candidate results, not exact-dlog or UT certificates.

The result labels have deliberately limited meanings:

- `C`: the target base dimension `(4,4)` returns at least as many independent
  finite-affine constant-LS directions as the article has masters in that
  sector.
- `S`: only a uniform shifted base dimension `(2,2)` or `(6,6)` reaches that
  count.  Like a mixed-dimension result, this requires a dimension-shift/IBP
  certificate before it represents the article's `D=4-2 epsilon` family.
- `P`: only a mixed-dimension LBL proposal reaches that count.  This is not yet
  a same-dimensional Feynman-integral candidate without a dimension-shift/IBP
  certificate.
- `U`: every tested configuration is stopped by a genuine multivariate
  algebraic cover.  This is a method limitation, not a no-candidate result.

No entry is a global constant-LS, UT, canonical-basis, or IBP-independence
certificate: infinity and chart transitions are not included.  Rows marked
`partial` attain the article count on an incomplete candidate chart.

## Historical baseline result

The frozen baseline classification was:

| class | sectors | article masters |
|---|---:|---:|
| target `(4,4)` count reached | 26 | 31 |
| uniform dimension-shift proposal only | 5 | 5 |
| mixed-dimension proposal only | 7 | 7 |
| multivariate algebraic cover unresolved | 8 | 18 |
| total | 46 | 61 |

`(N,D)` below is `(numerator degree bound, dot degree bound)`.  The route column
gives a simplest successful configuration and the represented/full candidate
count when it matters.

| ID | first eight sector bits | masters | `(N,D)` | result | route / obstruction |
|---:|:---:|---:|:---:|:---:|:---|
| 53 | 10101100 | 1 | (0,2) | C | F/R `(4,4)`, 15/15 |
| 57 | 10011100 | 1 | (0,2) | C | F/R `(4,4)`, 15/15 |
| 58 | 01011100 | 1 | (0,2) | C | F/R `(4,4)`, 15/15 |
| 63 | 11111100 | 1 | (0,1) | C | F/R `(4,4)`, 7/7 |
| 148 | 00101001 | 1 | (0,2) | S | F/R `(2,2)`, 10/10 |
| 152 | 00011001 | 1 | (0,2) | S | F/R `(2,2)`, 10/10 |
| 154 | 01011001 | 1 | (0,1) | P | R `(2,4)`, 5/5 |
| 158 | 01111001 | 1 | (0,1) | C | R `(4,4)`, 6/6 |
| 162 | 01000101 | 1 | (0,2) | S | F/R `(2,2)`, 10/10 |
| 165 | 10100101 | 1 | (0,1) | P | R `(2,4)`, 5/5 |
| 167 | 11100101 | 1 | (0,1) | C | R `(4,4)`, 6/6 |
| 178 | 01001101 | 1 | (0,1) | P | F `(2,4)`, 5/5 |
| 180 | 00101101 | 1 | (0,1) | P | F `(2,4)`, 5/5 |
| 181 | 10101101 | 1 | (0,0) | C | F/R `(4,4)`, 1/1 |
| 182 | 01101101 | 2 | (0,1) | U | non-square multivariate cover, 6/6 chart |
| 183 | 11101101 | 1 | (0,0) | C | R `(4,4)`, 1/1 |
| 186 | 01011101 | 1 | (0,0) | C | F/R `(4,4)`, 1/1 |
| 190 | 01111101 | 1 | (0,0) | C | R `(4,4)`, 1/1 |
| 194 | 01000011 | 1 | (0,2) | S | F/R `(2,2)`, 10/10 |
| 196 | 00100011 | 1 | (0,2) | S | F/R `(2,2)`, 10/10 |
| 197 | 10100011 | 1 | (0,1) | P | R `(2,4)`, 5/5 |
| 199 | 11100011 | 1 | (0,1) | C | R `(4,4)`, 6/6 |
| 201 | 10010011 | 1 | (0,1) | P | R `(2,4)`, 5/5 |
| 202 | 01010011 | 1 | (0,1) | P | R `(2,4)`, 5/5 |
| 203 | 11010011 | 1 | (0,1) | C | R `(4,4)`, 6/6 |
| 205 | 10110011 | 1 | (0,1) | C | R `(4,4)`, 6/6 |
| 206 | 01110011 | 1 | (0,1) | C | R `(4,4)`, 6/6 |
| 207 | 11110011 | 2 | (1,1) | C | R `(4,4)`, 2 directions, partial 14/42 |
| 214 | 01101011 | 1 | (0,0) | C | F/R `(4,4)`, certified-square reduction, 1/1 |
| 218 | 01011011 | 2 | (0,1) | U | non-square multivariate cover, 6/6 chart |
| 220 | 00111011 | 1 | (0,0) | C | F/R `(4,4)`, certified-square reduction, 1/1 |
| 222 | 01111011 | 2 | (0,1) | U | non-square multivariate cover, 7/7 chart |
| 227 | 11000111 | 1 | (0,0) | C | F/R `(4,4)`, certified-square reduction, 1/1 |
| 229 | 10100111 | 2 | (0,1) | U | non-square multivariate cover, 6/6 chart |
| 230 | 01100111 | 1 | (0,0) | C | F/R `(4,4)`, certified-square reduction, 1/1 |
| 231 | 11100111 | 2 | (0,1) | U | non-square multivariate cover, 7/7 chart |
| 242 | 01001111 | 1 | (0,1) | C | F `(4,4)`, 6/6 |
| 244 | 00101111 | 1 | (0,1) | C | F `(4,4)`, 6/6 |
| 245 | 10101111 | 1 | (0,0) | C | F `(4,4)`, 1/1 |
| 246 | 01101111 | 2 | (0,1) | U | non-square multivariate cover, 7/7 chart |
| 247 | 11101111 | 3 | (2,0) | U | non-square cover and partial 6/15 chart |
| 250 | 01011111 | 1 | (0,0) | C | F `(4,4)`, 1/1 |
| 251 | 11011111 | 2 | (1,0) | C | F/R `(4,4)`, 2 directions, partial 2/5 |
| 253 | 10111111 | 2 | (1,0) | C | F/R `(4,4)`, 2 directions, partial 2/5 |
| 254 | 01111111 | 3 | (1,0) | U | non-square cover and partial 3/5 chart |
| 255 | 11111111 | 3 | (2,0) | C | R `(4,4)`, 3 directions, partial 3/10 |

## Why the former strict backend found only one direction in sectors 182, 218, and 229

These three sectors are one cyclic pattern.  At forward `(4,4)` with bounds
`(N,D)=(0,1)`, the complete six-candidate charts are ordered as the undotted
integral followed by one dot on each of the five active propagators.  After
removing the common analytic unit, their candidate ratios are identically

```text
{1, 1/z5, 1/z4, 1/z3, 1/z2, 1/z1}.
```

Consequently the five double-pole constraints are the same in all three
sectors,

```text
H = {{0,0,0,0,0,1},
     {0,0,0,0,1,0},
     {0,0,0,1,0,0},
     {0,0,1,0,0,0},
     {0,1,0,0,0,0}}.
```

Thus `H.c=0` sets every dotted coefficient to zero before the residual conic
is considered.  The four finite terminal rows have support only on the
undotted column.  Up to orientation they are

```text
182: {+1,-1,-1,+1}/(2 (s12+s23)),
218: {-1,+1,+1,-1}/(2 (s45+s51)),
229: {-1,+1,+1,-1}/(2 (s34+s45)).
```

The respective strict normalizations are therefore `2 (s12+s23)`,
`-2 (s45+s51)`, and `-2 (s34+s45)`, and the finite constant-LS quotient has
dimension exactly one.  A fresh check of both loop orders and all 18 named-loop
dimension pairs in `{2,4,6}^2` found this one direction only at `(4,4)` and no
dotted direction at any tested dimension.

The ancillary file nevertheless contains two master atoms in each sector.  In
all three cases the second atom is the propagator-8 dot:

```text
182: eps^4 (v1+v2) I[0,1,1,0,1,1,0,1] ,
     eps^3 v1 v2   I[0,1,1,0,1,1,0,2] ;
218: eps^4 (v4+v5) I[0,1,0,1,1,0,1,1] ,
     eps^3 v4 v5   I[0,1,0,1,1,0,1,2] ;
229: eps^4 (v3+v4) I[1,0,1,0,0,1,1,1] ,
     eps^3 v3 v4   I[1,0,1,0,0,1,1,2] .
```

Here `vi=s(i,i+1)/mu^2`.  The displayed dotted integrand has a genuine
`dz5/z5^2` pole.  Dots on other propagators cannot cancel it because they
belong to different divisor rows.  Multiplying the dot by an ISP numerator
can cancel the row only when that numerator combination vanishes on `z5=0`;
then it is divisible by the cut propagator and reduces to an undotted form.

The degree-one reduced numerator chart makes the remaining obstruction
explicit.  In every sector the higher-pole kernel has dimension two, but one
direction has zero finite signature, so the quotient by that kernel still has
dimension one.  The zero-finite-signature directions and their residual conic
forms are

```text
182: -I[a11=-1] + I[a10=-1]
     -> -dt dz7/((t+s12-s45) (t-s12+s45));
218: -s45 I0 + (s45/s51) I[a10=-1] + I[a6=-1]
     -> dt dz7/(s51 (t-1) (t+1));
229: -s45 I0 + (s45/s34) I[a11=-1] + I[a5=-1]
     -> dt dz7/(s34 (t-1) (t+1)).
```

Each coefficient is independent of `z7`.  With `w=1/z7`, one has
`dz7=-dw/w^2`, so these forms have a double pole at infinity rather than a
missing finite residue.  They are not d-log candidates.

This explains the count mismatch using only strict residue constraints.  The
paper selects a pure basis of *integrals* and uses integral reduction for
linear independence; it states d-log integrands as a sufficient construction,
not as a necessary characterization of every displayed pure integral.  The
propagator-8 dot may have a different d-log representative only after an
integrated or total-derivative relation.  Such an identification is outside
the package's no-IBP, exact-integrand scope.  Numerator charts outside the
reduced chart still stop at a multivariate algebraic cover, so this calculation
is not a global no-go theorem for all possible numerator representations.

## Restored divisor recursion

The old divisor enumeration is mathematically valid on the part restored here.
After the ordered propagator cut, every half-integer factor is first decomposed
exactly as

`P = q^2 R`.

Only when every residual square class `R` is independent of the remaining
Baikov variables and the whole cut form becomes rational (up to one common
constant sheet phase) is it sent to the finite rational divisor tree.  No
`PowerExpand` identity is used.  For each linearly reducible finite divisor
`t=0`, the aligned candidate row is expanded as

`sum_m r_m t^m dt`.

Every `r_m` with `m <= -2` becomes a module constraint and `r_-1` is recursed
as a differential form in the remaining variables.  Consequently, propagator
dots are handled by the same method: their higher Laurent coefficients must
cancel before Singular solves the constant-residue module.

This exact branch recovers sectors 53, 57, 58, 63, 214, 220, 227, and 230.
For example, the sector-214 cut reduces on a fixed sheet to a rational two-form
with two linear divisors; the two flag residues differ only by orientation and
are proportional to `1/(s12-s34+s51)`.  Module lift therefore supplies the
normalization `s12-s34+s51`.

The old root-by-root algorithm is not restored for genuine multivariate
algebraic roots.  In that situation an individual algebraic root
`z-c_i(z')` is not generally a divisor of the original Baikov form.  Treating
such roots independently can create spurious poles.  The required next backend
must combine conjugate roots back into the original irreducible Baikov
polynomial and propagate its discriminant square class while trying residual
variable orders.

## Top-sector correction

The top sector has three, not five, masters.  The three distinct top-sector
atoms in the article ancillary are

```text
{1,1,1,1,1,1,1,1,-1,-1,0}
{1,1,1,1,1,1,1,1,-1, 0,0}
{1,1,1,1,1,1,1,1, 0,-1,0}
```

Counting canonical basis expressions by the bitwise OR of every sector in the
expression incorrectly assigns five basis elements to the top sector.  Their
top-sector projection has rank three.  The corrected scan finds three
directions at reverse `(4,4)`, with parities `Even, Odd, Odd`; the odd
normalizations contain the expected five-point Gram square root.  This reaches
the article multiplicity, but only on a 3/10 candidate chart.  Relating these
three directions to the article's chosen numerator masters is outside the
package's no-IBP scope.

## Remaining work

1. Complete the infinity/chart-transition atlas and spanning-subcut analysis
   for 182, 218, and 229 if an alternative exact d-log numerator
   representative is required.  The article's dotted atoms are not themselves
   exact d-log integrands.
2. Implement the multivariate algebraic construction for sectors 222, 231,
   and 246.
3. Add numerator-coordinate chart blocks for sectors 247 and 254, then apply
   the same multivariate algebraic backend.  Their present charts are 6/15 and
   3/5 respectively.
4. Keep uniform and mixed loop-dimension results labelled as proposals; the
   package does not identify them with the common-dimensional article basis.

## Reproduction

Run the complete scan with

```bash
wolframscript -file Studies/ScanMassless2L5PSectors.wls \
  /path/to/FiniteFlow.m \
  /path/to/pentabox_basis2.txt \
  /path/to/full-scan.wl
```

Optional sector IDs after the output path run a checkpoint subset.  A clean
full scan can be summarized with

```bash
wolframscript -file Studies/SummarizeMassless2L5PScan.wls \
  /path/to/full-scan.wl \
  /path/to/summary.wl \
  /path/to/full-scan.wl
```

The committed machine-readable summary is
`Studies/Massless2L5PSectorScanResults.wl`; it stores the exact coefficient
directions, source hashes, scan hashes, and labels for the historical baseline
table above.  It does not describe the current source bytes or supersede the
current three-sector calculation.

## Primary sources

- T. Gehrmann, J. M. Henn, N. A. Lo Presti,
  *Pentagon functions for massless planar scattering amplitudes*,
  arXiv:1807.09812.
- J. Chen et al., *Baikov representations, intersection theory, and canonical
  Feynman integrals*, arXiv:2202.08127, especially section 4.2.
- J. Henn, B. Mistlberger, V. A. Smirnov, P. Wasser, *Constructing d-log
  integrands and computing master integrals for three-loop four-particle
  scattering*, arXiv:2002.09492, for the original DlogBasis algorithm.
