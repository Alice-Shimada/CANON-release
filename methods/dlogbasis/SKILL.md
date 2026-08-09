# DLogBasis pre-reduction integral-candidate route

## Purpose

Propose pre-reduction integral/dlog candidates through
`PROPOSE_INTEGRAL_CANDIDATES`. This card does not produce a master-basis
transformation.

## Required interaction

The interface is exactly the `PROPOSE_INTEGRAL_CANDIDATES` and
`canon-neu/integral-candidates/v1` contract in `../../INTERFACES.md`. A future runner
may consume family/sector identity and the separately declared dimension,
power-counting, budget, candidate-unit, and normalization policies. It must not consume
`sector_basis` or `sector_cut_de`.

## Boundary

No CANON DLogBasis adapter is implemented. `LeadingSingularitiesPortable.tar.gz` is
the only self-contained tracked bundle; `LS_modified.zip` is not self-contained.
Upstream `IntegrandAnsatz` documentation describes its optional argument as a
numerator power order, while the tracked implementation uses `dim_:4` in power-counting
formulae. An adapter must resolve that discrepancy and may not conflate dimension,
power counting, or candidate budget. This card cannot publish `PASS`, `FAIL`, or a
UT/canonical claim.
