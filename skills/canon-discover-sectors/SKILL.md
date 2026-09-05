---
name: canon-discover-sectors
description: "Materialize exact sector metadata and the frozen ordered master basis from one prepared-family artifact."
---

# Discover sectors and masters

In the assigned run workspace, invoke:

```text
wolframscript -file mma/DiscoverSectors.wls INPUT.json FRESH_OUTPUT_DIR
```

`payload.prepared_family` is the only scientific input. The script orders sectors
by ascending `(propagator_count, id)` and stably orders masters by that rank,
preserving the original Kira position within each sector. Derive each mask from
the declared `propagator_slots` and actual master indices. Bits use the full
integral-index order, with ISP slots zero; `a1` is the least significant bit.
The manifest includes `sector_bits` and `master_count`, with no literature
manifest or fixed propagator count.

Success writes `sector-manifest.wl`, `master-basis.wl`, and `result.json` with
code `SECTORS_READY`. The script does not run master discovery or modify research
state; register retained output only through `statemng`.
