---
name: canon-discover-sectors
description: "Materialize exact sector metadata and the frozen ordered master basis from one prepared-family artifact."
---

# Discover sectors and masters

In the assigned run workspace, invoke:

```text
python3 run_step.py INPUT.json FRESH_OUTPUT_DIR
```

`payload.prepared_family` is the only scientific input. The script orders sectors
by ascending `(propagator_count, id)` and stably orders masters by that rank,
preserving the original source position within each sector. Derive each mask from
the declared `propagator_slots` and actual master indices. Bits use the full
integral-index order, with ISP slots zero; `a1` is the least significant bit.
The manifest includes `sector_bits` and `master_count`, with no literature
manifest or fixed propagator count.
With explicit `integral_head`, unqualified master names use the WL `Global`
context to match the neutral family and reduction artifacts. Old prepared
families without that field retain the historical ``"CANON`DEData`"`` context.

Success writes `sector-manifest.wl`, `master-basis.wl`, and `result.json` with
code `SECTORS_READY`. The script does not run master discovery or modify research
state; register retained output only through `statemng`.

A selected native discovery adapter replaces this operation and owns the native
job and master import. It can use the public `FormatMasterArtifacts` helper for
these standard outputs. Parameterization and the later reduction/DE providers
are separately selected; do not infer them from the discovery software.
