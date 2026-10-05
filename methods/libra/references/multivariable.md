# Multivariable capabilities and the runner's limit

Libra's `NewDSystem[ds,{x->Mx,y->My,...}]` stores a multivariable connection.
`Transform[ds,t]` updates every direction with its corresponding derivative
term, and `EFormQ[ds,eps]` checks all directions. The one-variable restriction
belongs to this runner, not to Libra as a whole.

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

A noninteractive sequence of directional `Fuchsify` calls would therefore be
a bounded design based on those APIs, not an already validated capability of
this card. Such an implementation would need explicit variable traversal and
revisit rules, deterministic nonsingular sample choices, and saved samples.
Partial or full specialization can propose candidates but cannot certify them.
Acceptance still requires joint exact gauge, directional Fuchsianity, flatness,
and epsilon-factorization checks on the unspecialized full symbolic system.
Until that loop is implemented and validated, the runner returns
`INCONCLUSIVE/OUT_OF_SCOPE` for multivariable input, without a mathematical
rejection of the candidate.

`EFormQ[ds,eps]` only checks that dividing each connection matrix by `eps`
removes its `eps` dependence. It does not establish membership in a dlog
alphabet. Multivariable canonical acceptance also needs CANON's independent
multivariable dlog decomposition checks.
