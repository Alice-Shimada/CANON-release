---
name: canon-commit-sector
description: Append one independently checked sector to the accepted CANON prefix and derive the next resident sector.
---

# Commit one checked sector

Run `mma/CommitSector.wls` only with a `canonical_sector_de` emitted by
`CHECK_CANONICAL`.  For `old_lower = Tlower.accepted_lower` and selected
`mixed_source = Tfull.new_prefix`, the cumulative raw transformation is

```wl
Taccepted = DiagonalBlock[Tlower, IdentityMatrix[currentDimension]].Tfull
```

and the accepted basis is `Inverse[Tfull].Join[acceptedLower, rawCurrent]`.
Use the entire new basis, cumulative map, and checked matrices, including any
normalization of earlier sectors. Keep earlier artifacts intact, append the
sector and candidate traces in resident order, and derive a stable
SHA-256 prefix ID from the complete accepted expression.

After a commit, `mma/NextSector.wls` reads only `sector_manifest` and the
nullable accepted prefix.  It drops `Length[sector_trace]` entries from the
resident manifest and publishes the remaining and next sector.  Calling this
pure artifact step after each commit advances one sector; the main Agent and
`statemng`, not this script, own iteration and persistence.
