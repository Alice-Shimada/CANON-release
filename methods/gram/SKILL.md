---
name: canon-gram-integral-candidates
description: Construct bounded Gram-numerator candidates across loop orders, leg counts, masses, and reference dimensions when cut and d-dimensional IBP ranks disagree, dimensional continuation is unresolved, or full-DE lower-sector couplings fail.
---

# Gram numerators and off-cut representatives

## Trigger and role

Use when the current report identifies a cut/IBP rank gap, unresolved dimensional
continuation, or a geometrically supported change to an off-cut representative.
Select the operation through the [workflow entry](../../skills/canon-workflow/SKILL.md).

This card guides **integral construction** at `PROPOSE_INTEGRAL_CANDIDATES`,
including complete replacement definitions for the current sector. It supplements
the [DlogBasis-refine card](../dlogbasis/SKILL.md). It introduces no UT acceptance
criterion, post-reduction transformation search, standalone `run.wls`, or
automatic routing. Construct an [integral-candidates/v1](../../INTERFACES.md#integral-candidatesv1)
artifact and use the existing IBP, core, and full-prefix checks. Candidates
remain provisional.

Selected-cut residues, d-dimensional IBP classes, and off-cut representatives
of full integrals are distinct. Gram structures help choose dimensional
continuations and contact terms; writing a cut polynomial as a determinant
alone is insufficient. This card fixes no loop order, leg count, mass pattern,
topology, reference dimension, sector rank, or kinematic coordinates. Select
structures supported by the family geometry; neither a four-dimensional chiral
representation nor a nonelliptic function class is assumed. These are reusable
construction and diagnostic principles, not a guarantee of an MPL/UT basis or
a finite search that finds one.

## Inputs and bounded scope

Fix the family's propagator/ISP order, momentum routing, masters and sector
order, loop count L, `d = D0 - 2 epsilon`, external-momentum dimension and
independent external span, Gram convention, any parity tensors/algebraic
branches, and the existing lower-sector basis. Use the family's independent
coordinates without assuming twistors, massless external legs, or a fixed
number of differential directions. From the current failure report, separately
record IBP rank, current-sector and lower-sector failure support, and exact
epsilon dependence. Without a full report, propose a hypothesis rather than
assuming a tail failure.

Declare numerator degree and its counting convention (loop momentum or
Baikov/ISP), dots, external-prefactor degree/denominator support, epsilon
normalization, contact pinch support, and candidate count. Prefer low-degree
structures covered by existing reductions. This is not a search of every Gram
numerator. Preserve provenance, structurally independent directions, and a
complete ordered bundle for the current block.

## Constructing candidates

1. **Define transverse Gram data from the actual external span.** For a
   nondegenerate external basis `E={e1,...,er}`, let `M_ij=e_i.e_j` and
   `v_a=(l_a.e_i)`. Then
   `tau_ab=l_a.l_b-v_a^T M^-1 v_b`, with `a,b=1,...,L`.
   For `G(U;V)=det(2 u_i.v_j)`, the Schur complement gives
   `tau_ab=G({l_a,E};{l_b,E})/(2 G(E;E))`.
   Do not use this quotient where the external Gram vanishes. Choose a
   nondegenerate kinematic region or a scalar-product/polynomial representation
   without dividing by that Gram. If a source uses `det(u_i.v_j)`, the conversion
   factor for an n-dimensional Gram determinant is `2^n`.
2. **Keep the full geometry before taking the cut.** Start from full subloop
   Grams, transverse projections, or scalar kernels; use parity/chiral
   combinations only when available. Use cut/LS data to choose a reasonable
   external normalization and check infinity in the chosen chart. Do not set
   propagators to zero first and treat the remaining polynomial as the unique
   off-cut continuation. Keep complete products: their cross contact terms may
   supply the needed correction.
3. **Identify missing directions relative to the reference dimension.** If
   IBP leaves a rank deficit, try bounded `tau_ab`, minors/products,
   routing-dependent combinations, and external Gram cofactors. Transverse does
   not imply evanescent: when `r<D0`, `tau_ab` can contain physical D0-dimensional
   transverse components. Label only combinations that vanish by strict D0
   rank constraints as evanescent, such as suitable `(D0+1)`-order Grams of loop
   and external vectors. Do not set them to zero inside regulated d-dimensional
   integrals. Choose external prefactors from mass dimension, singularities,
   and symmetries; no fixed parity root, Mandelstam degree, or epsilon power is
   a universal normalization.
4. **Use parity or cut branches only when supported.** Organize candidates by
   the actual discrete symmetries and combine cut solutions into compatible
   rows. Changing an algebraic-root branch is not automatically physical parity.
   A four-dimensional chiral seed is one special case: try paired parity-even
   and parity-odd parts and, when motivated, a subloop chirality flip. State
   full-d trace-pairing and parity-odd tensor projection conventions. Different
   d-dimensional continuations remain different candidates even if their
   integer-dimensional cuts coincide.
5. **Try Gram cofactors when motivated.** For a full Baikov Gram polynomial
   `Delta(D,z)`, `K_i=partial_Di Delta` may give lower-degree candidates. State
   which independent ISPs are held fixed, include chain-rule terms under a
   coordinate change, and differentiate before taking the cut. A cofactor that
   passes the cut check can still lack contact terms. Before using dimensional
   shifts or radial IBP to lower degree, establish the identity in the relevant
   integral or cut quotient and record its scope.

These structures define a finite candidate syntax, not a mandatory sequence
for every sector.

## Choosing the next hypothesis from a failure

| Current evidence | Next step | Unsupported conclusion |
|---|---|---|
| Independent finite residues on the selected cut, but zero or deficient d-dimensional IBP projection | Inspect twisted-exact directions, missing residues/infinity information, and dimensional continuation; add geometrically independent rows and test their analytic-d projection rank | Cut-residue rank equals the master count, or every deficit requires an evanescent row |
| Epsilon-independent terms remain in the current-sector block | Change its Gram combinations, external cofactors, chiral continuation, or normalization | Lower-sector additions alone can fix the failing diagonal block |
| Core passes but lower-sector terms have epsilon denominators | Locate pole-supported columns and inspect the pinch projections, epsilon normalization, and full gauge residual | An affine-tail primitive formula applies immediately, or every such pole has a contact solution |
| Core passes and the tail is `a(x)+epsilon b(x)` | Choose contact terms or another off-cut representative from the failing columns' pinch geometry; solve all directions jointly | A one-point, one-direction fit establishes a multivariable correction |
| A single-row replacement improves but still fails | Replace compatible Gram/symmetry/branch rows together and check the complete bundle | Single-row exchange tests have excluded the new bundle |

For the current physical propagator set S and a finite multi-index set A, use
an ansatz such as

```text
N_new = N_seed + sum_{alpha in A} (product_{i in S} D_i^alpha_i) P_alpha
               + N_evanescent,    1 <= sum_i alpha_i <= k_max.
```

The contact part vanishes under the polynomial restriction that sets every
propagator to zero. For unit powers, cancelling its denominators gives pinch
integrals. With dots, inspect the actual remaining powers: a numerator that
vanishes on the cut need not have zero higher-pole residue or affect only
lower sectors. Single and double contacts are small starting spaces, not a
universal maximum order. `N_evanescent` vanishes only under the declared strict
reference-dimensional restriction. It generally changes d-dimensional cuts
and the current-sector IBP projection and is distinct from a contact term.

Use propagators commonly missing from the bad columns to narrow `P_alpha`.
A pinch sector without an independent master can still supply the required
tail after IBP. Explain clusters of residuals rather than interpolating entries
without bounds. Incompatibility across directions excludes only the chosen
constant-coefficient ansatz. A geometrically motivated prefactor extension may
still work; that failure does not exclude the contact route.

Check the complete matrix equation. For `J=(L,C)` with
`A={{A_LL,0},{A_CL,A_CC}}`, keep L fixed and set `C'=C+F L`. Then

```text
A'_CL = A_CL + dF + F A_LL - A_CC F,   A'_CC = A_CC.
```

Only when both diagonal blocks are in epsilon form and F is epsilon-independent
does `dF=-A_CL^(0)` remove the zeroth-order term; the entire new block still
needs checking. This also shows why a lower-only repair cannot fix a failing
current diagonal block. An invertible same-sector change independent of both
kinematics and epsilon cannot turn a nonzero zeroth-order tail block into zero.

## Connecting to the workflow

- Expand Grams/traces exactly into finite integral combinations for **this
  family**. Leave no unresolved `Gram`, cut roots, or private abbreviations in
  `exact_definition`. Put epsilon/kinematic factors in the definition or
  `normalization.factor` exactly once. Retain stable IDs, bounds, and actual
  tool provenance; do not claim a DlogBasis-refine call that did not occur.
- `CandidateIBPBridge.wl`'s `CompileCandidateIBPTargets` includes candidates and
  derivatives in every direction. Differentiate before fixing kinematics,
  including prefactors, radicals, external bases, and contact coefficients.
  Check existing reduction coverage first and reuse it with
  `AttachCandidateIBPReduction`. Add reductions only for missing targets;
  `ReduceCandidateIBP.wls` launches a reduction, not a read-only coverage check.
- `RouteCoreCandidates.wls` currently selects an independent row basis and
  single-row exchanges. For a hypothesis requiring several simultaneous row
  changes, submit a separate complete ordered bundle of the required rank so
  it becomes that run's row basis. Do not expect single-row exchanges to find
  it automatically. Keep every lower-sector column of `full_new_basis_rows`.
- Follow `CHECK_CORE -> BUILD_FULL_DE -> SOLVE_TAIL -> CHECK_CANONICAL`, then
  `FINAL_CHECK` for the cumulative transformation of the stated family scope.
  Respect each interface's coefficient domain and scope. This card only
  reproposes current integrals; it does not edit the accepted lower basis.
  If the formal `SOLVE_TAIL` step changes lower epsilon normalization, retain
  its complete cumulative transformation. Gram/dot-pool exhaustion is not a
  prerequisite for the available DE methods or `SOLVE_TAIL`.

Return the changed rows, full off-cut formulas, finite domain, current IBP
rank, current/lower failure support and epsilon profile, target coverage,
whole-bundle check scope, and next falsifiable hypothesis. Reuse unchanged raw
DE and reduction data instead of rebuilding the family DE for each numerator.

## Evidence limits

Record rank, cut/LS evidence, full epsilon form, dlog/alphabet, and UT
normalization separately. All-direction checks at fixed kinematic points with
analytic epsilon are strong candidate evidence, not all-kinematics
`CANONICAL_PASS`. Freeze fitted formulas and test independent points without
refitting. Checking only the overall scaling direction is insufficient, and
epsilon form alone does not determine boundary weight normalization.

For elliptic or more general non-MPL cut periods, Gram constructions may simplify
numerators but do not automatically remove period normalization. Do not force
such systems into a rational/MPL route or promote top-cut results to a full-family
conclusion.
