---
name: canon-route-prepared-basis
description: Validate and classify an explicitly supplied prepared-basis artifact without invoking a scientific provider or accepting a result.
---

# Deterministic prepared-basis router

## Trigger and inputs

Use only when a task explicitly supplies the prepared-basis routing contract.
The overall study starts at the [workflow entry](../../skills/canon-workflow/SKILL.md).

Validate a `canon-neu/prepared-basis/v1` artifact and produce
`canon-neu/route-decision/v1`. This card only performs deterministic routing:
it runs no provider, changes no candidate, accepts no scientific conclusion,
and does not check tool installations.

## Command and result

From `project_root`, run
`wolframscript -file methods/route-prepared-basis/run.wls INPUT.json OUTPUT_DIR`
with a
`canon-neu/script-input/v1` envelope, step `ROUTE_PREPARED_BASIS`, and a
`prepared_basis` Mathematica-expression descriptor in `payload`. Success is
`PROVISIONAL/ROUTE_DECISION`. Malformed or contradictory artifacts return
`ERROR/INVALID_PREPARED_BASIS` with a stable `field` and reason.

## Decisions in precedence order

1. Already canonical: `VERIFY_CANONICAL_DE`.
2. Suspicious selected candidate with alternatives remaining:
   `REFINE_SECTOR_UT_CANDIDATES`.
3. Canonical core with a `lower-to-current` coupling defect: `SOLVE_TAIL`.
4. Rational transformation expected: `FIND_RATIONAL_CANONICAL_WITH_CANONICA`.
5. Otherwise: `DIAGNOSE_OR_CHANGE_VARIABLES`.

The `SOLVE_TAIL` and CANONICA routes do not require candidate-pool exhaustion.
`ut_evidence_references` records provenance without controlling the decision.
General tail solving uses `mma/SolveTail.wls`. The specialized Libra direct-sum repair
remains a separate bounded method; this router does not select
`REPAIR_WITH_LIBRA`. For the earlier family-based method choice, follow the
[workflow entry](../../skills/canon-workflow/SKILL.md).

## Next action and limits

Invoke the selected operation only with its required inputs and within the
assigned task scope; this card does not execute the decision.

The route artifact records preparation/family/basis identity, the selected
candidate, decision, stable reason, and the explicit fact that UT evidence does
not control routing. A route is not scientific acceptance; this card never
returns `PASS` or `FAIL`.
