---
name: canon-check-canonical
description: Independently check the selected full-prefix transformation and classify a current-core or tail failure.
---

# Check the complete canonical prefix

Run `mma/CheckCanonical.wls` with `full_sector_de` and `sector_transform`.  The checker recomputes
the full gauge transformation from `source_matrices`; it does not trust the
declared transformed matrices.

`PASS/CANONICAL_PASS` requires the exact full gauge identity, flatness at one
deterministic exact-rational point, epsilon factorization, the constant-residue dlog alphabet carried by `sector_transform`, and a zero
upper-right block. The lower basis can be renormalized by the complete
transformation; it is checked as part of the full system.  Failure is `CORE_FAIL` exactly when the
current-current gauge, deterministic exact-rational-point flatness, epsilon, or dlog check fails.  If that complete
current block passes but a full-prefix condition fails, the code is
`TAIL_FAIL`.  A pass writes `canon-neu/canonical-sector-de/v1` from the
independently computed matrices.

This is the independent mathematical check of each new prefix. Main-Agent review
uses its inputs and result; it does not require a second clean run of candidate
generation, the IBP bridge, or the sector pipeline with unchanged inputs and code.
