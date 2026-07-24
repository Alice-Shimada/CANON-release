---
name: canon-solve-tail
description: "Solve the current-sector lower-tail transformation against the accepted prefix. Use when an agent is assigned the SOLVE_TAIL workflow step."
---

<!--
Placeholder skill: keep the ansatz and solver empty for now.

Responsibility:
- Read the SOLVE_TAIL task packet.
- Run mma/SolveTail.wls.
- Return the proposed sector transformation or a bounded failure.

Input payload:
- full_sector_de
- core_transform
- accepted_prefix, or null for the first sector
- tail_options

Output:
- PASS/TAIL_READY with artifact sector_transform
- FAIL/TAIL_UNSOLVED

Boundary:
- The agent and Mathematica own ansatz selection.
- Do not mutate state.json.
-->
