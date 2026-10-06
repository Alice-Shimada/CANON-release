---
name: canon-final-check
description: "Run the global final canonical check after all sectors are committed. Use when an agent is assigned the FINAL_CHECK workflow step."
---

Run `FINAL_CHECK` through `python3 run_step.py INPUT.json OUTPUT_DIR` with `prepared_family`, `master_basis`,
`sector_manifest`, the original complete `ordered_master_de`, and the final
`accepted_prefix`.

Bind the final prefix to the original `ordered_master_de["basis"]` order before
submission. BUILD_FULL_DE can map a reused prefix's different source order, while
COMMIT_SECTOR retains that explicit order. To represent the same complete result
in resident order, apply the integral-by-integral permutation to both
`source_basis` and the rows of `transformation`, preserve the canonical basis and
matrices, and recompute the prefix hash with the standard artifact conventions.
Changing source labels alone breaks the gauge relation. Keep the original DE as
the final check's authority.

Enter this step after every resident sector is committed. Scalar/core epsilon
forms and a flat raw DE do not establish a full canonical system. If the tail
or a sector remains unresolved, report that scope. Record FINAL_CHECK as not
run when it has not been invoked; an intermediate calculation does not itself
constitute a final-check pass or failure.

The script independently verifies the cumulative accepted transformation against
the ordered source matrices. It requires exact resident source/master and sector
trace order, a complete cursor, the accepted prefix hash, invertibility, equality
to the committed matrices, exact symbolic flatness in every pair of variables,
and epsilon factorization. The dlog gate
solves one shared exact constant residue vector per matrix entry across
every differential direction, reconstructs all directions over the explicit
regulator-free letters, including exact Wolfram algebraic expressions, and
retains only letters with nonzero shared residue matrices. Alphabet inference
occurs in SOLVE_TAIL; final checking uses the accepted alphabet.

For large rational/algebraic systems, set `method_options.gauge_backend` to
`fermat` and `method_options.package_entry` to the Fermatica entry. `FERMATPATH`
must identify the Fermat executable. This explicitly selected backend proves
`A_i T - D_i T - T B_i = 0` in the algebraic quotient using exact polynomial
arithmetic; it is equivalent to the gauge check with the required invertible T.
The shared-residue gate is unchanged. The output records the loaded Fermatica
version, entry hash, and Fermat executable/version/hash.

Only `PASS/ALL_PASS` writes `canonical_basis` and `canonical_de`. This certifies
the exact canonical form within that stated scope; candidate dlog evidence remains
separate and does not prove a UT basis.

After `PASS/ALL_PASS`, finish the existing task: the worker registers the final
basis, DE and receipt, submits, and returns; the coordinator reviews, accepts
when the criteria are met, delivers, and stops this scope. Review uses the
existing receipt. Additional verification requires a specific unresolved check,
changed inputs or implementation, or a separate user request. Delivery records
the methods used and any unmet applicable workflow requirements; optional
methods need not be exhausted.
Apply the [workflow completion rule](../canon-workflow/SKILL.md) if only a subset
was requested/completed, the inputs changed, or the user separately requested
another deliverable.
