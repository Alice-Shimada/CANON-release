---
name: canon-search-core
description: Find current-sector transformations from reduced integral candidates or the raw DE.
---

# Current-sector core search

Use the resident `sector_basis` and `sector_cut_de`. A complete DlogBasis pool
is not a prerequisite for DE methods. Select CANONICA for multivariable rational
DEs, or the existing Libra card for a single variable. Their `core_candidates`
include `source_basis` and `full_new_basis_rows` for the same full-prefix builder.
For a rational DE regular at epsilon zero, `methods/epsilon-zero/run.wls` can
instead search homogeneous horizontal rows with algebraic prefactors from the
trace and `declared_alphabet`. It also attempts a two-dimensional epsilon-singular
completion. Its finite polynomial ansatz remains a provisional core proposal.

When using DlogBasis-refine, first reduce the individual candidate combinations
with `ReduceCandidateIBP.wls`, then call `RouteCoreCandidates.wls` with
`prepared_family`, `sector_basis`, `sector_cut_de`, and `candidate_ibp_bridge`.
It selects a basis of the reduced current-sector rows and independent single-row
exchanges. Proper-subsector coefficients remain in the full rows. The required
rank is the actual sector master count. No full subset enumeration is performed.

Pass each provider's `core_candidates` to `CheckSectorCore.wls`. Rank shortage or
failure of the selected candidate space can route directly to CANONICA; neither
requires exhausting every numerator/dot ansatz. A bounded search failure is not
proof that a canonical form does not exist. On CORE_PASS continue with
BUILD_FULL_DE, SOLVE_TAIL, CHECK_CANONICAL, COMMIT_SECTOR, and NEXT_SECTOR.
After the final resident sector, run FINAL_CHECK on the original ordered DE and
cumulative transformation. The main Agent and statemng own the loop.
