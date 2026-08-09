# Gram-Baikov pre-reduction integral-candidate route

## Purpose

Provisionally define a `PROPOSE_INTEGRAL_CANDIDATES` route for a future
D-dimensional Gram/Baikov ansatz generator. It does not produce a post-reduction
transformation.

## Required interaction

The interface is exactly the pre-reduction `canon-neu/integral-candidates/v1`
contract in `../../INTERFACES.md`. It must not consume `sector_basis` or
`sector_cut_de`.

## Boundary

No primary Gram-Baikov API or CANON adapter is selected or implemented. The card must
keep dimension, numerator/power-counting, budget/exhaustion, candidate unit, and
normalization separate, and cannot publish `PASS`, `FAIL`, or a UT/canonical claim.
