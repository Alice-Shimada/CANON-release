---
name: canon-method-card-template
description: Define a new bounded method card with one explicit provider or checker role and the matching scientific I/O contract.
---

# MethodCard template

## Purpose

Define one bounded provider role. A method card need not transform a reduced
differential system.

## Required contract

An instantiated card declares one stage and role and uses that stage's
contract from [INTERFACES.md](../../INTERFACES.md):

- Integral generator before reduction: `PROPOSE_INTEGRAL_CANDIDATES` and
  `PROVISIONAL/INTEGRAL_CANDIDATES`.
- Transformation generator after reduction: `SEARCH_CORE` and
  `PROVISIONAL/CANDIDATE_TRANSFORMATION`.
- Evidence provider or checker: its separately documented contract and authority.

## Limits

Supply a scientific method only when instantiating this template. Keep
pre-reduction integral definitions distinct from post-reduction transformations.
Do not add workflow state or scheduling, or allow a provider to publish
`PASS`/`FAIL`.

## Package entry

Declare the command and this instruction file in a
[component manifest](../../docs/components.md). The runner appends `INPUT.json`
and `OUTPUT_DIR` to the command. Existing scientific gates consume the returned
artifacts through their published contracts. A package may implement several
steps; each entry keeps its explicit stage and role.
