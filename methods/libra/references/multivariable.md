# Multivariable capabilities and the bounded CANON route

Libra's `NewDSystem[ds,{x->Mx,y->My,...}]` stores a multivariable connection.
`Transform[ds,t]` updates every direction with its corresponding derivative
term, and `EFormQ[ds,eps]` checks all directions. CANON's default route uses
one variable. An explicit `direction_sequence` selects its multivariable
directional proposal.

`Fuchsify[ds,x]`, `FactorOut[ds,x,eps,mu]`, and visual balancing first construct
a transformation from the selected direction `ds[x]`. The bundled two-variable
tutorial applies `Fuchsify[ds,x]` and `Fuchsify[ds,y]` as needed, each followed
by `Transform[ds,t]` on the full system. It then combines samples of all
directions at common exact kinematic points for `FactorDependence` to find a
shared epsilon-factorization transformation. The bundled three-variable
presentation combines directional `VisBalancing`, single-direction `FactorOut`,
and `BlockTriangularToFuchsian`, then partially specializes each matrix only
in its own differential variable before `FactorDependence`. These examples
demonstrate multivariable use of the components; the presentation also lists
more systematic multivariable treatment as future work.

CANON takes a finite caller-selected directional sequence; it does not implement
the tutorials' interactive operations or a variable-order search. Each
transformation updates the entire symbolic connection. Empty, partial and
repeated sequences are allowed, but every direction must be Fuchsian at the
endpoint, including infinity.

Shared factorization uses the public `FactorDependence` equation template with
`Solve->False,Sort->False`. For all directional matrices, let
`S_a=A_a/eps`. It seeks one kinematically constant rational `F` satisfying

```text
S_a(x,eps) F(eps) = F(eps) S_a(x,mu)  for every a.
```

The adapter clears denominators and equates coefficients in all declared
kinematic variables. It removes exact numeric content and proportional
duplicates, retaining symbolic factors and first-occurrence order, then calls
public `GaussSolve` once. Selected solutions still satisfy the original
coefficient equations and all directional identities. The exact reference
`mu` defaults to `1/2` and must be nonsingular. Unsolved parameters default to
all ones, with an explicit bounded deterministic policy available. An invertible
solution gives `F^-1 A_a F = eps S_a(x,mu)` simultaneously. The search is
limited to this constant-kinematics factorization space after the selected
Fuchsification sequence. There is no sampling, epsilon-zero substitution,
automatic spectrum normalization, or unbounded search over free-parameter choices.
See the [reference and free-parameter contract](advanced-controls.md#exact-reference-and-finite-parameter-policy)
for exact JSON values, finite points, validation and retained evidence.
The card's [optional controls and cost](../SKILL.md#optional-controls-and-cost)
summarize these choices. Coefficient extraction remains a separate cost even
when deduplication substantially reduces the solver input.

This complements CANONICA's rational multivariable ansatz construction. It
does not add a new class of coefficient domains, a UT seed finder, or a
lower-sector tail solver. Failed endpoints and budget limits are evidence about
this finite proposal, not mathematical nonexistence.

The complete original variable list, cumulative transformation and transformed
matrices use the existing `core_candidates` contract. Independent `CHECK_CORE`
recomputes the exact gauge, invertibility, flatness and regulator factorization.
Libra's endpoint Fuchsian flags belong to provider evidence. Full-prefix dlog
acceptance still belongs to `CHECK_CANONICAL` and `FINAL_CHECK` after completion.
`tests/test_libra_multivariable.py` covers fixed exact systems and the complete
existing workflow handoff.

`EFormQ[ds,eps]` only checks that dividing each connection matrix by `eps`
removes its `eps` dependence. It does not establish membership in a dlog
alphabet. Multivariable canonical acceptance also needs CANON's independent
multivariable dlog decomposition checks.

## Limits and diagnostics

| Option | Default | Scope |
|---|---:|---|
| `factorization_max_equations` | 4096 | Positive integer cap on raw nonzero monomial coefficients before deduplication; exceeding it stops before solving. |
| `max_wall_seconds` | 60 | Finite positive time limit shared by the whole multivariable proposal. |

These two controls require `direction_sequence`. Equations are never truncated.
Numeric-content deduplication reduces solve work but leaves the raw budget and
coefficient-extraction cost unchanged. The summary reports raw
`factorization_equation_count` and post-deduplication
`factorization_solver_equation_count` (`null` until extraction and deduplication
finish). No sampling or regulator-zero specialization replaces the symbolic solve;
the selected exact reference must be defined.

A stopped attempt retains `libra_diagnostic`: the last cumulative transformation,
connection and local-step trace. The summary records stage, limits and counts.
`TIME_BUDGET` with `timed_out=true` routes to operational recovery; it certifies
an unfinished attempt. The diagnostic is evidence, not an accepted core or resume
interface. This route requires no UT seeds, declared alphabet or full kinematic
transformation ansatz, and changes no lower-sector basis.
