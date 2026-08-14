---
name: canon-build-cut-de
description: "Build the current-sector cut basis and cut differential equation. Use when an agent is assigned the BUILD_CUT_DE workflow step."
---

<!--
Placeholder skill: keep the scientific procedure empty for now.

Responsibility:
- Read the BUILD_CUT_DE task packet for the current sector.
- Run mma/BuildSectorCutDE.wls.
- Return the cut objects as opaque artifacts.

Input payload:
- prepared_family
- master_basis
- sector_manifest

PASS output:
- code: OK
- artifacts: sector_basis, sector_cut_de

Boundary:
- Do not interpret or serialize Mathematica expressions in Python.
- This historical scientific scaffold declares no state transition; current research
  state is governed only by `statemng` under root `AGENTS.md` and `README.md`.
-->
