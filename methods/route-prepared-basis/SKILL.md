# Prepared-basis deterministic router

## Purpose

This method card validates one `canon-neu/prepared-basis/v1` artifact and emits one
`canon-neu/route-decision/v1` artifact. It performs deterministic orchestration only:
it does not run a provider, alter candidates, accept a scientific claim, or inspect
provider installations.

Run `run.wls <input.json> <output_dir>` with a
`canon-neu/script-input/v1` envelope whose step is `ROUTE_PREPARED_BASIS` and whose
payload contains a `prepared_basis` Mathematica-expression descriptor. The result is
`PROVISIONAL/ROUTE_DECISION`; malformed or contradictory artifacts return
`ERROR/INVALID_PREPARED_BASIS` with a stable field and reason.

## Decisions, in precedence order

1. Canonical diagonal and off-diagonal quality with no remaining problem:
   `VERIFY_CANONICAL_DE`.
2. A suspicious selected candidate or localized defect, with alternatives remaining
   and no plateau: `REFINE_SECTOR_UT_CANDIDATES`.
3. A localized defect after a plateau or complete pool exhaustion:
   `REPAIR_WITH_LIBRA`.
4. A global rational defect after candidate selection is complete:
   `FIND_RATIONAL_CANONICAL_WITH_CANONICA`.
5. Every other valid state: `DIAGNOSE_OR_CHANGE_VARIABLES`.

`ut_evidence_references` are traceability data. Changing INITIAL or any other UT
evidence reference cannot select a backend, change the decision, or terminate the
route.

## Output boundary

The route artifact records the preparation/family/basis identity, selected candidate,
decision, stable reason, and the explicit fact that UT evidence does not control the
route. A route decision is not scientific acceptance, so this card never returns
`PASS` or `FAIL`.
