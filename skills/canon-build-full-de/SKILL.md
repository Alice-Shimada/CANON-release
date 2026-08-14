---
name: canon-build-full-de
description: "Build the full current-sector differential equation after the core passes. Use when an agent is assigned the BUILD_FULL_DE workflow step."
---

<!--
Placeholder skill: keep the scientific procedure empty for now.

Responsibility:
- Read the BUILD_FULL_DE task packet.
- Run mma/BuildFullSectorDE.wls.
- Return the full current-sector DE as an opaque artifact.

Input payload:
- prepared_family
- master_basis
- sector_manifest
- core_transform
- accepted_prefix, or null for the first sector

PASS output:
- code: OK
- artifact: full_sector_de

Boundary:
- Do not parse the DE in Python.
- This historical scientific scaffold declares no state transition; current research
  state is governed only by `statemng` under root `AGENTS.md` and `README.md`.
-->
