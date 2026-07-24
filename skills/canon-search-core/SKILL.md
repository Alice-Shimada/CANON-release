---
name: canon-search-core
description: "Produce bounded current-sector core candidates through an assigned provider. Use when an agent is assigned the SEARCH_CORE workflow step."
---

<!--
Placeholder skill: keep all candidate-generation algorithms empty for now.

Responsibility:
- Read the SEARCH_CORE task packet.
- Delegate the required candidate_route subtask with one allowed provider script.
- Register the provider result through subreport.
- Submit a canon-neu/script-result/v1 result for the parent task.

Allowed provider scripts:
- methods/dlogbasis/run.wls
- methods/gram-baikov/run.wls
- methods/method-card-template/run.wls

Input payload:
- prepared_family
- sector_basis
- sector_cut_de
- method_options

Output:
- PASS/CANDIDATE_READY with artifact core_candidates
- FAIL/NO_CANDIDATE

Boundary:
- Provider selection and scientific reasoning belong to the agent, not Python.
- Do not mutate state.json outside workflow.py commands.
-->
