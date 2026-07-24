---
name: canon-discover-sectors
description: "Report the sector metadata and master basis for CANON_neu. Use when an agent is assigned the DISCOVER workflow step."
---

<!--
Placeholder skill: keep the scientific procedure empty for now.

Responsibility:
- Read the DISCOVER task packet and its script input.
- Run mma/DiscoverSectors.wls.
- Report sector ids and propagator counts without sorting them.

Input payload:
- prepared_family

PASS output:
- code: SECTORS_READY
- artifacts: sector_manifest, master_basis
- summary.sectors: [{"id": integer, "propagator_count": integer}, ...]

Boundary:
- Python, not this skill, sorts sectors.
- Do not mutate state.json.
-->
