---
name: canon-final-check
description: "Run the global final canonical check after all sectors are committed. Use when an agent is assigned the FINAL_CHECK workflow step."
---

Run `mma/CheckFullSystem.wls` with `prepared_family`, `master_basis`,
`sector_manifest`, the original complete `ordered_master_de`, and the final
`accepted_prefix`.

The script independently verifies the cumulative accepted transformation against
the ordered source matrices. It requires exact resident source/master and sector
trace order, a complete cursor, the accepted prefix hash, invertibility, equality
to the committed matrices, flatness at one deterministic exact-rational point,
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
