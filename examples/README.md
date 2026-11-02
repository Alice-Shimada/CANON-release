# AI4UT examples

These are the three primary families in the AI4UT manuscript, checked against
its Overleaf source on 2026-11-02. The exports use the final local results that
also appear in the article's supplementary data.

| Directory | Masters | Sectors | Variables | Active letters |
| --- | ---: | ---: | --- | ---: |
| [double-box](double-box/) | 37 | 24 | `{s,t,Q3sq,Q4sq,m2}` | 21 |
| [pentabox](pentabox/) | 61 | 46 | `{s12,s23,s34,s45,s51}` | 24 |
| [three-loop](three-loop/) | 40 | 28 | `{s,u}` | 3 |

Each directory contains only:

- `canonical-basis.wl`: the ordered list of canonical integral expressions `J`.
- `alphabet.wl`: the ordered list of exact letters `W`.
- `Atilde.wl`: the explicit square matrix of linear combinations of `Log[W[a]]`.

The notation `W[a]` in the matrix means element `a` of `alphabet.wl`; it is a
symbolic label, not an extra function to determine. The convention is

$$
\mathrm dJ=\epsilon\,\mathrm d\widetilde A\,J,\qquad
\widetilde A=\sum_a R_a\log W_a.
$$

`Atilde.wl` contains no overall epsilon factor. Its row and column order is the
basis order. The original integral heads and coefficient expressions are
preserved. These compact exports contain no source-basis transformation, runtime
record, reduction table or intermediate result. See [Reading results](../docs/results.md)
for a Wolfram example and the distinction from the workflow's full output format.

## Integral conventions

All families use `d = 4 - 2 eps`. For the head and denominator order specified
below, `H[a1,...,aN]` denotes

$$
H_{a_1,\ldots,a_N}=\mathcal N_L(\epsilon)
\int\prod_{r=1}^{L}\frac{\mathrm d^d k_r}{i\pi^{d/2}}
\prod_{j=1}^{N}(D_j+i0)^{-a_j}.
$$

The kinematics-independent normalization is
`N2 = Exp[2 EulerGamma eps]` for the double box and
`N3 = Exp[3 EulerGamma eps]` for the saved three-loop convention. For the
pentabox, the manuscript's displayed measure uses `N2 = 1`; a common
kinematics-independent factor can be applied to all its integrals without
changing this DE. The basis files preserve the formal integral heads, so such
a factor belongs to the definition of the head, not to an extra basis conversion.
No kinematics-dependent scale factor is added to these exports. In particular,
the double box does not include `(m2)^(2 eps)`; adding it would shift the
connection by `2 eps dlog(m2)` times the identity. Nonpositive ISP indices
represent numerator insertions. Square roots retain the saved exact expressions;
no branch replacement or logarithm expansion is made.

## Off-shell double box

The integral head is `PDB`, with nine indices. All external momenta are incoming,
`p1+p2+p3+p4=0`, `p1^2=p2^2=0`, `p3^2=Q3sq`, `p4^2=Q4sq`,
`s=(p1+p2)^2`, and `t=(p2+p3)^2`. `m2` is the internal squared mass.
For loop momenta `l1,l2`, the denominator order is

```text
D1 = l1^2                 D2 = (l1+p1)^2
D3 = (l1-p2)^2            D4 = (l2+p1)^2
D5 = (l2-p2)^2            D6 = (l1-l2)^2
D7 = (l2-p2-p3)^2-m2      D8 = l2^2
D9 = (l1-p2-p3)^2
```

Slots 1–7 are physical propagators; slots 8–9 are ISPs with nonpositive indices.
The alphabet has 17 rational and four algebraic letters, with the shared root
`sqrt((s-Q3sq-Q4sq)^2-4 Q3sq Q4sq)`. Use the order and exact expressions in
[alphabet.wl](double-box/alphabet.wl).

## Massless pentabox

The integral head is `pentabox5`, with eleven indices. All external momenta are
incoming, `Sum[p_i,{i,1,5}]=0` and `p_i^2=0`. The independent invariants are
`s12,s23,s34,s45,s51`, where `sij=(pi+pj)^2`. For loop momenta `k1,k2`,

```text
D1 = k1^2                     D2 = (k1+p1)^2
D3 = (k1+p1+p2)^2              D4 = (k1+p1+p2+p3)^2
D5 = k2^2                     D6 = (k2+p1+p2+p3)^2
D7 = (k2-p5)^2                D8 = (k1-k2)^2
D9 = (k1-p5)^2                D10 = (k2+p1)^2
D11 = (k2+p1+p2)^2
```

Slots 1–8 are physical propagators; slots 9–11 are ISPs with nonpositive indices.
All five variables, including the scale direction, are retained. The fixed
orientation uses 24 active letters from the supplied pentagon alphabet; the
export is not a claim to discover the full cyclic alphabet. The exact Gram
square root and letter order are in [alphabet.wl](pentabox/alphabet.wl).

## Three-loop family

The integral head is `threeLoopParametric3513`, with twelve indices in the
original slot order. `p^2=l^2=0`, `(p+l)^2=s`, and `u` is dimensionless.
For loop momenta `q1,q2,q3`,

```text
D1 = q1^2                     D2 = (p+q3)^2
D3 = (q1+u p)^2               D4 = (q2+(1-u) p)^2
D5 = (q1+q2)^2                D6 = (l+q1+q2)^2
D7 = (q2+q3)^2                D8 = q3^2
D9 = (l+q2+q3-u p)^2          D10 = q2^2
D11 = (l-p+q3)^2              D12 = (q1-q3+u p)^2
```

Physical slots are `{1,4,5,6,8,9,11,12}`; ISP slots `{2,3,7,10}` have
nonpositive indices. The alphabet is `{s,u,1-u}`, and the scale residue is
`-3 IdentityMatrix[40]`. In particular, `dlog(1-u)=du/(u-1)`.

## Source and verification

The retained final receipts all report `FINAL_CHECK: PASS / ALL_PASS`, with
14 true checks, including the complete basis definition, exact global gauge
identity, symbolic flatness, epsilon factorization and common constant residues.
The pentabox and three-loop exports replace the older examples previously
published in this repository; their current saved evidence includes symbolic
flatness. The double-box export reuses its complete verified local system.

The following SHA256 values identify the original full workflow artifacts from
which the expression-only release files were extracted. They are source hashes,
not hashes of the smaller files in this directory.

| Family | Original canonical-basis SHA256 | Original canonical-de SHA256 |
| --- | --- | --- |
| Double box | `73a52ca5911ad223e58bbbda7479bd2c2bfeee38f26dee42c0071a85c4013e9e` | `d7bbcf4119abdb597e76cfd4bf122a9d3f89c976af8f13d41f1e6fc95765c059` |
| Pentabox | `9aa82e546e4cadf393590fecc4ee698c222ddee7241ae695d53e37d8545d282e` | `516308551f813e2f6122e33330bda021d1b6e4e8d5d0c03b252476c5a59ba5f8` |
| Three loop | `a66715ac9b63e14e0aad1a0ea35b36d98948dc1e8e47457a698ac3fc3b8be44b` | `db1e5e5e85170371b337e18a4d8e369b9e485ab7bd0748aadeed9738f73ca54d` |

Release preparation checked these hashes against the article's supplementary
bundle and verified exact expression readback after export. It ran no new IBP,
family reconstruction or full-family canonical check. A canonical DE does not
supply boundary constants or prove uniform-weight normalization by itself.
