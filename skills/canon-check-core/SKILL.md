---
name: canon-check-core
description: "Check whether current-sector core candidates pass the cut-level criterion. Use when an agent is assigned the CHECK_CORE workflow step."
---

<!--
Placeholder skill: keep the scientific check empty for now.

Responsibility:
- Read the CHECK_CORE task packet.
- Run mma/CheckSectorCore.wls.
- Report the script result without independently overriding it.

Input payload:
- sector_basis
- sector_cut_de
- core_candidates

Output:
- PASS/CORE_PASS with artifact core_transform
- FAIL/CORE_FAIL with an optional diagnostic artifact

Boundary:
- Mathematica decides pass or fail.
- This historical scientific scaffold declares no state transition; current research
  state is governed only by `statemng` under root `AGENTS.md` and `README.md`.
-->
