---
name: canon-search-core
description: Choose the next unresolved-sector core method, distinguishing DlogBasis search inputs from later candidate-reduction inputs and allowing only evidence-based direct-DE exceptions.
---

# Select one core method

First apply the completion rule in [canon-workflow](../canon-workflow/SKILL.md).
This skill is for an unresolved sector with `sector_basis` and `sector_cut_de`.
Reuse an untested candidate or a passing core before generating another.

## 1. Decide whether the integral search comes first

Apply this list in order. Stop at the first matching item.

1. **The user explicitly requested DE-only work or a particular method:** follow
   that request within the method's input contract. This scope is set by the
   user's request; worker assignments specify only their local operations.
2. **Only a DE was supplied and the physical family cannot be recovered from
   available inputs:** use the direct-DE choices in section 3. State which
   physical definition is unavailable. When propagators, momenta, masses and
   kinematic relations are available, generate the required family files from
   those definitions and continue with the integral route.
3. **A bounded integral route already has an applicable, recorded limitation:**
   use section 3. Examples are no candidates within the stated search bounds,
   insufficient reduced rank, rejected cores, or an unresolved bridge
   construction after a concrete bounded preparation attempt. Retain its input,
   attempted operation and result. A preparation limitation requires an attempted
   construction and its specific failure. An absent field identifies preparation
   to perform.
4. **Otherwise, run one bounded DlogBasis-refine search for the unresolved
   sector.** This is also the route when a rational DE is available and when
   candidate derivative metadata still needs preparation.

If the required provider genuinely cannot be made available within the remaining
resources, record that operational condition and let the coordinator choose an
available alternative or report the block. Input errors return to preparation.
No exhaustive numerator/dot enumeration is required.

## 2. Prepare and execute the integral route in order

Run each operation as soon as its own inputs are ready.

| Current state | Immediate action |
|---|---|
| Physical family is defined; `Family` or its kinematic rules need encoding | Prepare that object from the supplied definition using the [DlogBasis card](../../methods/dlogbasis/SKILL.md). |
| Search inputs and tools are ready, with or without `prepared_derivatives.exact_strategy` | Run `methods/dlogbasis/run.wls` with `PROPOSE_INTEGRAL_CANDIDATES`. The proposal is independent of `exact_strategy`. |
| Package loading and `CreateDlogFamily` are complete | Run the bounded provider search. |
| Integral candidates exist; derivative/IBP inputs are incomplete | Save the candidates, prepare the missing inputs using the [IBP skill](../canon-reduce-ibp/SKILL.md), then reduce these same candidates. |
| Candidate bridge exists | Run `mma/RouteCoreCandidates.wls`, then CHECK_CORE. |
| The bounded route gives no usable core | Record its result and limits; select the next applicable untried method in section 3. |

Include `methods/dlogbasis/SKILL.md` in the worker's `required_skills`. Declare
loop order/dimensions, numerator/dot bounds, candidate count and wall time. The
card invokes `DlogBasisSearch`; loading the package alone is not that invocation.

The candidate chain is:

```text
PROPOSE_INTEGRAL_CANDIDATES
  -> prepare any missing candidate derivative/IBP data
  -> ReduceCandidateIBP.wls
  -> ROUTE_CORE_CANDIDATES
  -> CHECK_CORE
```

The coordinator may split this chain between workers. Pass the saved candidates,
required inputs and exact unfinished operation to the next worker. Assign any
needed derivative/IBP preparation as part of this chain.
If a worker lacks the assignment or resources to prepare it, the coordinator
assigns that preparation or records the actual exhausted budget/limitation.

Keep full reduced rows, including proper-subsector coefficients. The required
rank is the sector's actual master count. The router selects a rank basis and
independent single-row exchanges. A geometry-motivated simultaneous row
replacement is a new complete proposal; exhaustive subset search is not required.

## 3. Select a direct-DE method only after section 1 allows it

Select one applicable untried method using the current evidence and remaining
budget. The table gives useful triggers, not a mandatory provider chain. A
particular method explicitly requested by the user retains priority within its
contract. Keep section 1's bounded integral-search priority for defined families.

| Condition | Method |
|---|---|
| One or a few normalized UT seeds have explicit evidence and full reduced rows, a rational one-variable cut, a declared alphabet, and a finite derivative allocation | [INITIAL](../../methods/initial/SKILL.md), `SEARCH_CORE` at `methods/initial/run.wls`. A small credible seed set makes this a direct candidate alongside CANONICA, Libra and epsilon-zero; it need not wait for CANONICA failure. |
| A rational-transformation obstruction such as CANONICA `nonrationalinv` is recorded, and the rational DE is regular at epsilon zero | [epsilon-zero](../../methods/epsilon-zero/SKILL.md), with finite polynomial/prefactor bounds |
| The cut DE is rational and CANONICA has not failed on this input | [CANONICA](../../methods/canonica/SKILL.md) |
| The rational cut DE has one variable and Libra is applicable and untried | [Libra](../../methods/libra/SKILL.md); explicitly enable bounded normalization when integer residue offsets obstruct epsilon factorization. |
| The rational cut DE is regular at epsilon zero and epsilon-zero is untried | [epsilon-zero](../../methods/epsilon-zero/SKILL.md) |
| These choices are exhausted or inapplicable | Return exact failures and remaining scope to the coordinator. Use the [Gram card](../../methods/gram/SKILL.md) only with a concrete new Gram/contact-term or dimensional-extension hypothesis. |

A direct-DE provider returns `core_candidates`; run CHECK_CORE directly, without
an additional integral-candidate IBP bridge. INITIAL consumes already reduced
seed rows or an existing bridge; preserve their full lower-sector coefficients.
An unnormalized candidate, numerical match or finite-cut rank alone is not a
credible UT seed. Prepare missing seed evidence or choose another applicable
method rather than silently declaring it established. INITIAL's fixed official
reference validation is a compatibility/example contract outside core selection.
Its `VERIFIED_EVIDENCE` is not a general UT proof or an automatic normalization
promotion for another seed. A core provider failure does not call that validator;
return the failed hypothesis and budget to the coordinator.

CANONICA can target one declared block with a hashed finite T ansatz, recording
the failed stage and messages. Changing a diagnosed finite ansatz is a new
bounded attempt; increasing time without changing a refuted hypothesis is not.
A rational DE may require an algebraic
transformation; see [normalization and tails](references/normalization-and-tails.md).
Do not repeat a refuted rational transformation or reinstall a working provider
because its scientific ansatz failed.

## 4. Continue from the result

- `PASS/CORE_PASS`: BUILD_FULL_DE, SOLVE_TAIL, then CHECK_CANONICAL. The core is
  not the complete sector. Follow the [main route](../canon-workflow/SKILL.md).
- Missing fields, bad paths, incomplete kinematic rules or unreduced integrals:
  repair the named input/runtime/coverage problem and resume the affected step.
  These do not consume a method's scientific attempt.
- Rank shortage, CORE_FAIL or METHOD_EXHAUSTED: preserve the measured scope and
  select the next applicable untried branch. Failure of one method is not a ban
  on other methods, and one sector's failure does not reject an entire family.
- Passing core but unresolved full tail: use [canon-solve-tail](../canon-solve-tail/SKILL.md).
  Reconsider a full integral representative when indicated instead of repeating
  an unchanged tail solve.

Before every new assignment, the coordinator applies the main route to the
current scope. Reuse accepted sectors. Matching FINAL_CHECK ALL_PASS leads to
submission, review, acceptance and delivery, then ends scientific work for that
scope.
