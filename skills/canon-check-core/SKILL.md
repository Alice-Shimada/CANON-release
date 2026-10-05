---
name: canon-check-core
description: Independently check a declared ordered current-sector candidate pool.
---

# Exact current-sector check

Run `mma/CheckSectorCore.wls` with `sector_basis`, `sector_cut_de`, and
`core_candidates`.  In declared candidate order it checks only:

- reduction-rank invertibility;
- the exact gauge identity for `old_basis = T . new_basis`;
- exact symbolic flatness in every pair of variables;
- epsilon factorization.

When full/new basis rows provide a proposed inverse, independently verify both
`T.R=I` and `R.T=I` before using it. The exact equation
`A.T-D[T]-T.B=0` then determines the transformed DE uniquely; flatness and
epsilon checks still apply. This avoids redundant symbolic inversion for large
INITIAL candidates. Missing or unverified inverse proposals retain the legacy
determinant/inverse calculation; no provider success flag substitutes for a check.

The first passing candidate returns `PASS/CORE_PASS` and `core_transform`; later
candidates are not checked.  A rejected candidate records its stable ID and exact
rejection signature.  Exhausting an upstream-complete pool returns
`FAIL/CORE_FAIL` with `repair_eligible -> True`; exhausting only the current
budget is `INCONCLUSIVE/CANDIDATE_BUDGET_EXHAUSTED`. Failure publishes
`preferred_next_route -> "SELECT_CORE_METHOD"`; follow
[core selection](../canon-search-core/SKILL.md) using the rejection signature and
coefficient domain. A failure does not automatically justify a rational backend.
DE search is available without exhausting the numerator/dot ansatz. The checker
never invokes a provider itself. Candidate group exhaustion is scoped to the declared
rank basis and single-row exchanges, not every possible integral representative.

Before the mathematical check, bind the whole pool's identities, order and counts,
then validate each reached candidate's matrix shape and exact rational/algebraic
coefficient syntax. Legacy v1 candidates without `coefficient_domain` are classified
from their entries, with inference recorded in the result. Do not infer identities
or exhaustion metadata. Radical and polynomial `Root` inputs remain supported.

Candidate input errors are recorded and do not block a later passing candidate.
If no candidate passes and any reached candidate is malformed, return
`ERROR/INVALID_INPUT`, `preferred_next_route -> "FIX_INPUT"` and
`repair_eligible -> False`. Correct those inputs before treating the pool as
scientifically exhausted. Unused candidates after a pass are not prevalidated.
