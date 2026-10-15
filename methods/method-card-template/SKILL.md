---
name: canon-method-card-template
description: Define a bounded method card with an explicit scientific role, routing boundary, and matching input, output, and acceptance authority.
---

# MethodCard template

## Purpose

Define one bounded scientific operation that the workflow can select from
its inputs and evidence. The card's boundary follows that operation, not the
package name or number of internal function calls. This directory is an
interface template, not a scientific method or runnable provider.

## Required contract

An instantiated card uses its stage's contract from
[INTERFACES.md](../../INTERFACES.md) and declares:

- **Role / stage:** the operation and exact script step, or instruction-only
  guidance with no runner.
- **Activation:** applicability under the existing selector or opt-in contract;
  examples and cost heuristics do not require an earlier provider trial.
- **Boundary:** required artifacts, identities and basis order, supported
  variables/coefficient domain, writable outputs, and objects held fixed.
- **Attempt:** finite search/ansatz or algorithm stages, supported options,
  execution budget, and the condition that returns control to the coordinator.
- **Handoff:** output schema, result authority, next checker or operation,
  and distinct scope, exhaustion, input and tool failures.

Choose the appropriate role rather than imposing provider output on every card:

| Role | Existing example and authority |
|---|---|
| Integral provider | `PROPOSE_INTEGRAL_CANDIDATES` returns `PROVISIONAL/INTEGRAL_CANDIDATES`; reduction and core checks follow |
| Transformation provider | `SEARCH_CORE` returns `PROVISIONAL/CANDIDATE_TRANSFORMATION`; `CHECK_CORE` follows |
| Evidence provider | `PROVIDE_UT_EVIDENCE` returns provisional evidence for its independent checker |
| Router | `ROUTE_PREPARED_BASIS` proposes a route; it does not execute or certify the selected method |
| Screen / checker | State the exact claim and bounded pool or input being checked; `PASS` / `FAIL` apply only to those checks |
| Instruction-only guidance | State how to produce the existing typed artifacts and their next gates; no executable capability is implied |

An executable card supplies `run.wls` using the existing script envelope. An
instruction-only card need not have a runner. Keep substantial conditional
guidance in linked references when it is not needed for ordinary selection.

## Limits

Keep pre-reduction integral definitions distinct from post-reduction
transformations. A provider cannot publish scientific `PASS` / `FAIL` or accept
its own proposal. A checker establishes only its named scientific conditions;
it does not accept a persistent research task. No card owns workflow state or
scheduling. A method's exhaustion does not establish nonexistence of a basis.

## Package entry

Declare the command and this instruction file in a
[component manifest](../../docs/components.md). The runner appends `INPUT.json`
and `OUTPUT_DIR` to the command. Existing scientific gates consume the returned
artifacts through their published contracts. A package may implement several
steps; each entry keeps its explicit stage and role.
