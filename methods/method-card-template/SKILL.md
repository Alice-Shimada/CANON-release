# MethodCard template

## Purpose

Define one bounded provider role without assuming that every method card transforms a
post-reduction differential system.

## Required interaction

An instantiated card must declare exactly one stage and role, then use that stage's
contract in `../../INTERFACES.md`:

- pre-reduction integral generator: `PROPOSE_INTEGRAL_CANDIDATES` and
  `PROVISIONAL/INTEGRAL_CANDIDATES`;
- post-reduction transformation generator: `SEARCH_CORE` and
  `PROVISIONAL/CANDIDATE_TRANSFORMATION`;
- evidence provider or checker: its separately documented contract and authority.

## Boundary

Fill in the scientific method only when this MethodCard is instantiated. Do not mix
pre-reduction integral definitions with post-reduction transformations, add workflow
state or scheduling, or let a provider publish `PASS`/`FAIL`.
