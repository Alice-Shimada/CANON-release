---
name: canon-search-core
description: "Produce bounded current-sector core candidates through an assigned provider. Use when an agent is assigned the SEARCH_CORE workflow step."
---

<!--
Historical scientific scaffold: it does not define current agent delegation or state
transitions. Keep all transformation-generation algorithms empty for now.

Responsibility:
- Read the SEARCH_CORE task packet.
- Invoke one explicitly selected post-reduction transformation provider under the
  `SEARCH_CORE` contract.
- Preserve the provider's typed `canon-neu/script-result/v1` result for an independent
  `CHECK_CORE` invocation.

Allowed provider scripts:
- methods/libra/run.wls
- methods/canonica/run.wls
- a role-specialized instance of methods/method-card-template/run.wls

Input payload:
- prepared_family
- sector_basis
- sector_cut_de
- method_options

Output:
- PROVISIONAL/CANDIDATE_TRANSFORMATION with artifact core_candidates
- INCONCLUSIVE/OUT_OF_SCOPE or INCONCLUSIVE/METHOD_EXHAUSTED
- concrete ERROR codes

Boundary:
- Integral/dlog candidate generators use the earlier
  `PROPOSE_INTEGRAL_CANDIDATES` contract, not this step.
- Providers cannot publish PASS/FAIL or accept their own transformation.
- Current research state is governed only by `statemng` under root `AGENTS.md` and
  `README.md`; this scaffold declares no state transition.
-->
