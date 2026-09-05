---
name: canon-check-core
description: Independently check a declared ordered current-sector candidate pool.
---

# Exact current-sector check

Run `mma/CheckSectorCore.wls` with `sector_basis`, `sector_cut_de`, and
`core_candidates`.  In declared candidate order it checks only:

- reduction-rank invertibility;
- the exact gauge identity for `old_basis = T . new_basis`;
- flatness at one deterministic exact-rational point;
- epsilon factorization.

The first passing candidate returns `PASS/CORE_PASS` and `core_transform`; later
candidates are not checked.  A rejected candidate records its stable ID and exact
rejection signature.  Exhausting an upstream-complete pool returns
`FAIL/CORE_FAIL` with `repair_eligible -> True`; exhausting only the current
budget is `INCONCLUSIVE/CANDIDATE_BUDGET_EXHAUSTED`. Failure publishes
`preferred_next_route -> "FIND_RATIONAL_CANONICAL_WITH_CANONICA"`; DE search
is available without exhausting the numerator/dot ansatz. The checker never
invokes a provider itself. Candidate group exhaustion is scoped to the declared
rank basis and single-row exchanges, not every possible integral representative.
