# Algebraic normalization and epsilon-dependent tails

Read this when a rational core needs a root, or a passing core leaves a failing
full-sector tail. Use the existing providers and gates; the examples explain
their hypotheses and do not add another checking pipeline.

## Fix the transformation convention

CANON uses `old_basis = T . new_basis`. For each independent variable `x_a`,

```text
B_a = T^-1 (A_a T - partial_a T).
```

An additional change `new_basis = H . next_basis` gives `T_total = T H`.
Use this convention when interpreting a provider or deriving a scaling sign.
Flatness is an integrability condition, not an epsilon-form or UT certificate.

## A rational connection can need an algebraic normalization

For a scalar block `A = d log g(x) + eps omega(x)`, choosing `T = g` gives
`B = eps omega`. For example,

```text
A = (1/(2 x) + eps/x) dx,    T = sqrt(x),    B = eps dx/x.
```

The input is rational but this transformation is algebraic. CANONICA's
`nonrationalinv` therefore calls for a different hypothesis within the relevant
coefficient field, not removal of its rationality check. For a rational core
regular at `eps = 0`, the [epsilon-zero card](../../../methods/epsilon-zero/SKILL.md)
offers a bounded algebraically normalized polynomial ansatz; its optional
`declared_alphabet` artifact supplies algebraic generators. It is not a general
algebraic solver. Integral candidates provide another route; use the
[Gram card](../../../methods/gram/SKILL.md) when the family geometry supports it.

Keep exact roots and their defining relations consistently in all directions.
For `q = sqrt(Q(x))`, `partial_a q = (partial_a Q)/(2 q)`; `q` is neither a
constant nor a new independent invariant. If using a genuine rationalizing
chart `x = phi(y)`, pull back every direction,

```text
A_y,b = sum_a (partial phi_a / partial y_b) A_x,a(phi(y)),
```

then apply the gauge formula in `y`. Merely naming `q^2 = Q(x)` supplies no such
chart. Unjustified root identities or `PowerExpand` do not prove a gauge relation.
A scalar normalization still needs lifting to the full system, where it changes
the off-diagonal couplings.

## Integer epsilon powers versus rational epsilon factors

For `H(eps) = diag(h_i(eps))`, the kinematic derivative of `H` vanishes, so

```text
C_a,ij = (h_j/h_i) B_a,ij.
```

Strict epsilon factorization means every `Together[C_a,ij/eps]` is independent
of `eps`. This is exactly the existing `EpsilonFactorizedQ` criterion. Regularity
at zero and a leading power of at least one are weaker conditions.

If every nonzero entry is a single monomial `b_a,ij(x) eps^m_a,ij`, an integer
power choice `h_i = eps^k_i` must satisfy
`m_a,ij + k_j - k_i = 1` for every entry and direction. Inequalities remove
poles; they do not give these equalities. Even an acyclic coupling graph can
have incompatible constraints along different paths.

For a concrete mixed-power entry with nonzero, epsilon-free `K(x)`,

```text
B_21 = K(x) (1/eps - 2),
C_21/eps = K(x) (eps^(k_1-k_2-2) - 2 eps^(k_1-k_2-1)).
```

The two exponents differ by one for every integer choice. No pure epsilon-power
scaling fixes this entry. Changing the sign of a power inequality cannot help.
This excludes only that scaling ansatz after the chosen core transformation.

For comparison, the rational ratio `h_1/h_2 = eps^2/(1 - 2 eps)` turns this
single entry into `eps K(x)`. This is an illustration, not a solution for the
other entries: every direction and incoming lower-sector coupling still matters.
[SOLVE_TAIL](../../canon-solve-tail/SKILL.md) already extracts full regulator-only
rational factors and attempts the remaining normalization. Retain its complete
returned prefix transformation, including any changed lower-sector normalization.

## When an off-diagonal shear is needed

With both diagonal blocks already in epsilon form, write

```text
B_a = [[eps P_a, 0], [R_a, eps Q_a]],
old = S . new,    S = [[I, 0], [U, I]].
R'_a = R_a + eps Q_a U - eps U P_a - partial_a U.
```

If `U` is epsilon-independent and `R_a` is affine in epsilon, cancelling the
epsilon-zero tail asks for `partial_a U = R_a^(0)` in every variable. Solving
one direction alone is insufficient. The remaining epsilon and dlog conditions
are checked by the existing full-sector gate; cancelling this term alone is
not a canonical result. A lower-block shear does not repair a failing core.

Use `CHECK_CORE -> BUILD_FULL_DE -> SOLVE_TAIL -> CHECK_CANONICAL` and commit
only a passing result. The affine-tail integration and subsequent backend calls
are already implemented in `mma/SolveTail.wls`; do not replace them with an
unbounded hand-built normalization search. On failure, use the actual residual
to decide whether the next proposal changes the core, regulator normalization,
or proper-subsector terms of the full integral representatives.

## Alphabet and completion

An input alphabet is optional. With `declared_alphabet: null`, BUILD_FULL_DE
stores an empty declaration and SOLVE_TAIL constructs candidates from the DE.
The agent should run that entry before asking for a complete external alphabet.
Pole factors give the ordinary candidates; they do not alone determine the
required algebraic letters. In particular, `d log Q` is unchanged under
`q -> -q`, whereas `d log ((h + q)/(h - q))` changes sign.

The implemented `QuadraticRootLetters` proposal treats the other invariants as
coefficients and looks for a variable `x` with

```text
Q = a^2 x^2 + B x + C.
If C = r^2, try h = a x - r and h = a x + r.
Otherwise try h = (partial_x Q)/(2 a).
W = (h + sqrt(Q))/(h - sqrt(Q)).
```

For the first construction, `h^2 - Q = (±2 a r - B) x`; for the second,
`h^2 - Q = B^2/(4 a^2) - C`. These cancellations motivate a small candidate
set rather than a search over arbitrary expressions. Coefficient square roots
are constructed by factorization, without `PowerExpand`. This is a proposal
for supported quadratic-root structure, not complete alphabet discovery for
multiple roots, higher-degree algebraic curves or arbitrary families.

For each matrix entry, DLogResidues fits constants shared by every variable
direction. Exact point evaluations propose those constants; substitution into
the original expressions modulo the root relations proves each direction.
Zero residues are removed from the final output. An explicit alphabet, if
available, can still be supplied as exact expressions and undergoes the same
check. Carry `sector_transform.alphabet` into the committed prefix; final
checking uses that accepted alphabet.

Epsilon factorization alone also permits higher poles on an algebraic cover.
For `q^2 = Q`, a nonzero `dQ/q^3 = 2 dq/q^2` term cannot be a constant sum
of logarithmic derivatives of algebraic letters. Such a term needs a basis
repair; adding root-odd letters alone cannot remove it.

For a scalar current block the implemented repair may change only its lower
lift to expose an affine normalized tail, integrate its epsilon-zero part,
and try the regulator factor `1/(1+2 c eps)` from the scalar diagonal residue
at `Q`. The `1/q` primitive and diagonal coupling contribute to the same higher
root pole and must be cancelled together. The proposal is adopted only when
the full epsilon/shared-dlog check succeeds; CHECK_CANONICAL then recomputes
the original source gauge. Failure of this construction is a reason to change
the full representative or algebraic ansatz, not to repeat it with a larger
timeout or claim the alphabet cannot exist.

After all resident sectors are committed, FINAL_CHECK tests the complete
accepted prefix against the original ordered DE. If a core or tail remains
unresolved, retain its scoped evidence. Distinguish an actual FINAL_CHECK result
from a check that has not been run; do not predict its status from a core result.
Neither a flat raw DE nor epsilon-form diagonal blocks establish completion.
