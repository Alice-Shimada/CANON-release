---
name: canon-check-canonical
description: "Check the full current-sector transformation and classify a failure as core or tail. Use when an agent is assigned the CHECK_CANONICAL workflow step."
---

<!--
Placeholder skill: keep the scientific check empty for now.

Responsibility:
- Read the CHECK_CANONICAL task packet.
- Run mma/CheckCanonical.wls.
- Preserve the script's exact PASS or failure classification.

Input payload:
- full_sector_de
- sector_transform
- accepted_prefix, or null for the first sector

Output:
- PASS/CANONICAL_PASS with artifact canonical_sector_de
- FAIL/CORE_FAIL
- FAIL/TAIL_FAIL

Boundary:
- Mathematica, not Python, classifies CORE_FAIL versus TAIL_FAIL.
- This historical scientific scaffold declares no state transition; current research
  state is governed only by `statemng` under root `AGENTS.md` and `README.md`.
-->
