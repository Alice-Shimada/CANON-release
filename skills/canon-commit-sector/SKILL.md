---
name: canon-commit-sector
description: "Merge one checked sector into the accepted CANON prefix. Use when an agent is assigned the COMMIT_SECTOR workflow step."
---

<!--
Placeholder skill: keep the scientific merge empty for now.

Responsibility:
- Read the COMMIT_SECTOR task packet.
- Run mma/CommitSector.wls.
- Return a new accepted prefix as one opaque artifact.

Input payload:
- previous_accepted_prefix, or null for the first sector
- sector_basis
- sector_transform
- canonical_sector_de

PASS output:
- code: OK
- artifact: accepted_prefix

Boundary:
- Do not merge Mathematica expressions in Python.
- This historical scientific scaffold declares no state transition; current research
  state is governed only by `statemng` under root `AGENTS.md` and `README.md`.
-->
