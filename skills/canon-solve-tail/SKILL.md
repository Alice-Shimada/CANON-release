---
name: canon-solve-tail
description: Solve the current sector's nonzero off-diagonal coupling and epsilon normalization.
---

# Solve the current tail

Run `mma/SolveTail.wls` with `full_sector_de`, `core_transform`, and
`method_options.package_entry` identifying CANONICA. Already canonical
completions need no package call. For an affine epsilon tail, the script first
extracts a common regulator factor and integrates the epsilon-zero block in all
variables, allowing algebraic primitives (arXiv:2206.04609, Eq. 78).
If that does not solve a multi-master current block, the script tries one
completion from its simplest current row and first derivatives in variable order.
An exact full-rank cut selects the rows and aligns the completion; a common
regulator-only factor targets epsilon order one. Only a full-direction exact
epsilon/shared-dlog result is retained. Opposite square-root radicands are
expressed in the source generators as a new candidate, with the source gauge
checked by CHECK_CANONICAL. This is a bounded candidate operation, not a
completeness claim.
Otherwise the script calls the public
`TransformOffDiagonalBlock` and `TransformDlogToEpsForm` on all directions,
then composes their transformation with the selected core completion.
The off-diagonal solve uses the current sector's dependency closure; epsilon
normalization uses the entire prefix to preserve incoming couplings outside it.

This solves new subsector corrections; no predeclared completion pool or dotted
replay is required. Epsilon normalization may also change the accepted lower
basis, so retain the complete returned prefix transformation. The previous
artifact is immutable; COMMIT_SECTOR publishes the new cumulative map.

`declared_alphabet -> null` at BUILD_FULL_DE requests pole-factor alphabet
inference. Explicit algebraic letters can instead be supplied as ordinary exact
Wolfram expressions. The resulting alphabet is carried by `sector_transform`.
`PASS/TAIL_READY` goes to CHECK_CANONICAL; an unsuccessful backend solve returns
`INCONCLUSIVE/TAIL_UNSOLVED` without a canonical claim.
