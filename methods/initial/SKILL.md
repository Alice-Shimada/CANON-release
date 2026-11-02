---
name: canon-initial
description: Use INITIAL as a bounded seeded-core candidate provider; retain explicit official-reference requests only through the compatibility validation contract.
---

# INITIAL: seeded core interface

## Active scientific operation

- **Role / stage:** core candidate provider, `SEARCH_CORE`.
- **Entry:** `methods/initial/run.wls INPUT.json NEW_OUTPUT_DIR`.
- **Activation:** the coordinator selects INITIAL under
  [core selection](../../skills/canon-search-core/SKILL.md), with one or a few
  explicitly normalized UT seeds, a rational one-variable cut, a declared
  alphabet, and finite resource/derivative bounds.
- **Input:** matching `sector_basis`, `sector_cut_de`, `seed_request`, and either
  full `seed_rows` or an existing `candidate_ibp_bridge` plus `prepared_family`.
- **Output:** `PROVISIONAL/CANDIDATE_TRANSFORMATION`, standard `core_candidates`;
  independent CHECK_CORE, BUILD_FULL_DE, SOLVE_TAIL, CHECK_CANONICAL and FINAL_CHECK
  establish their respective claims.

Read the complete [seed, normalization, algebra and budget contract](../initial-core/SKILL.md)
before execution. The active interface does not require official ladder IDs,
26-dimensional input, a fixed basis order, an official T matrix, or exact
reference equality. Its installed package and host must support the requested
operation; the generic interface does not widen a machine's validated capability.

## Inputs and command

Use the seed and package configuration declared by the active core contract.
`CANON_WOLFRAMSCRIPT` selects a Wolfram installation compatible with FiniteFlow.

```text
python3 run_step.py INPUT.json NEW_OUTPUT_DIR --method initial
```

The step is explicit; a missing or unsupported step is rejected before output
creation. No scientific fallback occurs inside this entry. A failed core attempt
returns its bounded result to the coordinator; it never launches official ladder
validation or treats the seed as proved non-UT. The direct
`methods/initial-core/run.wls` address remains usable with the same SEARCH_CORE
contract and results.

Both provider implementations share the read-only
[INITIAL runtime loader](../../mma/lib/InitialRuntime.wl). It adapts the known
INITIAL 2.1 empty-training rank defect only for the exact source hash specified
in [INTERFACES](../../INTERFACES.md); other packages retain file-loading semantics.
The original source and CANON adapter hashes, with an `applied` flag, are recorded
in result/artifact provenance. Caller threads and finite bounds are passed
unchanged, with no automatic retry. Native official regressions run with one
thread through this loader and retain their independent checkers.

## Official reference compatibility

The original fixed 26-element official ladder implementation lives in
[the official validation example](../../methods/initial/reference/README.md).
It is a reference regression and normalization benchmark, not a selectable
SEARCH_CORE method or a prerequisite for independent core/full-system checks.

Existing explicit requests remain compatible:

| Existing step / address | Preserved result | Scope |
|---|---|---|
| `PROVIDE_UT_EVIDENCE` at `methods/initial/run.wls` | `ut_evidence`, provisional evidence | Fixed official ladder representation |
| `CHECK_UT_EVIDENCE` at `mma/CheckUTEvidence.wls` | `verified_ut_evidence`, independently verified reference evidence | That same fixed representation and normalization |

These are compatibility entries. They retain existing schemas, IDs, reference
requirements and scientific checks. Their result and artifact `interface` metadata
records `lifecycle="compatibility"`, `core_selection_eligible=false`,
`workflow_action="none"`, and the fixed official verification scope.
A `VERIFIED_EVIDENCE` result is agreement with the declared official normalized
reference, not a general UT proof, a core pass, a full-prefix pass, or a route
selection. There is no automatic promotion of that artifact to a new seed's
normalization premise. Explicitly bind the applicable source and full seed row
when supplying normalization evidence to the active interface.
