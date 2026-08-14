---
name: canon-prepare-family
description: "Prepare the normalized family artifact for CANON_neu. Use when an agent is assigned the PREPARE workflow step."
---

<!--
Placeholder skill: keep the scientific procedure empty for now.

Responsibility:
- Read the PREPARE task packet and its script input.
- Run mma/PrepareFamily.wls.
- Return one canon-neu/script-result/v1 report.

Input payload:
- family_spec

PASS output:
- code: OK
- artifact: prepared_family

Boundary:
- This historical scientific scaffold declares no state transition; current research
  state is governed only by `statemng` under root `AGENTS.md` and `README.md`.
- Do not add a second workflow or persistent Mathematica session.
-->
