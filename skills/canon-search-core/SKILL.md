---
name: canon-search-core
description: Route one declared post-reduction candidate pool into independent current-sector core checking.
---

# Current-sector core candidates

For DlogBasis-refine candidates, run `mma/RouteCoreCandidates.wls` with the accepted
`prepared_family`, `sector_basis`, `sector_cut_de`, and `candidate_ibp_bridge`.
It preserves the adapter's eligible-group order; those groups are subsets of
the package's module-lift candidate directions with size fixed by the sector
manifest. For each group it takes only
the reduced coefficients of the resident current-sector basis,

```wl
newBasis = R . oldBasis; transformation = Inverse[R]
```

and emits `PROVISIONAL/CORE_CANDIDATES_ROUTED`.  Proper-subsector terms remain in
the bridge for the later full-prefix stage and never enter `R`.

Alternatively, an explicitly chosen `methods/libra/run.wls` or
`methods/canonica/run.wls` may emit
`PROVISIONAL/CANDIDATE_TRANSFORMATION`.  No provider result is a PASS.

Always pass the resulting `core_candidates` to `mma/CheckSectorCore.wls`.  The
checker follows declared order, records exact rejection signatures, and stops at
the first PASS.  `REPAIR_WITH_LIBRA` is eligible only when every declared group
was attempted and the upstream group pool is exactly exhausted; otherwise use
the existing `route-prepared-basis` refinement decision.  Do not run a retry,
fallback provider, parallel scheduler, or repair inside this step.
