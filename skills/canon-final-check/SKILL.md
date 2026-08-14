---
name: canon-final-check
description: "Run the global final canonical check after all sectors are committed. Use when an agent is assigned the FINAL_CHECK workflow step."
---

<!--
Placeholder skill: keep the global scientific check empty for now.

Responsibility:
- Read the FINAL_CHECK task packet.
- Run mma/CheckFullSystem.wls.
- Return the final basis and differential equation only after the script passes.

Input payload:
- prepared_family
- master_basis
- sector_manifest
- accepted_prefix

PASS output:
- code: ALL_PASS
- artifacts: canonical_basis, canonical_de

Boundary:
- Do not declare DONE without the script result.
- This historical scientific scaffold declares no state transition; current research
  state is governed only by `statemng` under root `AGENTS.md` and `README.md`.
-->
