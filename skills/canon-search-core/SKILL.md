---
name: canon-search-core
description: Choose a bounded unresolved-sector proposal from geometry and current evidence, then adapt dots, Gram, DlogBasis or direct-DE methods using independent checks.
---

# Select one core method

First apply the completion rule in [canon-workflow](../canon-workflow/SKILL.md).
This skill is for an unresolved sector with `sector_basis` and `sector_cut_de`.
Reuse an untested candidate or a passing core before generating another.

The method choices here describe the default components. Use `run_step.py`
with the task's component package, and read its selected instruction file before
choosing an implementation. A user-declared replacement follows its own bounded
method and the same scientific input/output contract. An unqualified custom
`SEARCH_CORE` is called without a built-in `--method` choice.

## 1. Choose a bounded hypothesis

Apply this list in order. Stop at the first matching item.

1. **The user explicitly requested DE-only work or a particular method:** follow
   that request within the method's input contract. This scope is set by the
   user's request; worker assignments specify only their local operations.
2. **Only a DE was supplied and the physical family cannot be recovered from
   available inputs:** use the direct-DE choices in section 3. State which
   physical definition is unavailable.
3. **A bounded route already has a recorded scientific or capability limitation:**
   retain its input, bounds and actual result, then change the failing hypothesis.
   Rank shortage can motivate new integral directions; a failed diagonal core
   calls for different same-sector rows or normalization; a passing core with
   failed lower couplings calls for a full representative or tail correction.
   Choose an untried applicable integral proposal below or a direct-DE method
   in section 3. An absent field identifies preparation to perform. A bridge
   limitation requires an attempted construction and its specific failure.
4. **Otherwise, choose the smallest informative proposal supported by the
   family geometry and available inputs.** Use the choices below. A rational
   DE does not by itself require or prohibit an integral search.

| Evidence or geometry | Reasonable first proposal |
|---|---|
| Simple subloop structure, known scaling, or a small master block suggests a low-cost integral basis | A finite set of undotted integrals, selected dots and natural prefactors; retain exact integral definitions and normalization hypotheses. |
| Gram geometry, dimensional continuation, numerator directions or contact terms suggest a concrete construction | A small complete bundle using the [Gram card](../../methods/gram/SKILL.md); an earlier DlogBasis failure is not required. |
| No sufficiently specific small construction is available, or leading-singularity information would guide the next attempt | A bounded search using the [DlogBasis card](../../methods/dlogbasis/SKILL.md). |
| The goal and available cut DE favor a transformation construction | An applicable direct-DE method in section 3; retain its canonical/UT claim boundary. |

These are selection heuristics, not a fixed ladder or guarantees. Explain the
chosen construction and its finite bounds before computing. Do not cycle
through every provider, or infer that a complicated graph always needs Gram.
DlogBasis-refine is available as a general search, not a prerequisite for dots,
Gram constructions or every rational-DE calculation.

If the required provider genuinely cannot be made available within the remaining
resources, record that operational condition and let the coordinator choose an
available alternative or report the block. Input errors return to preparation.
No exhaustive numerator/dot enumeration is required.

## 2. Prepare and execute the integral route in order

Run each operation as soon as its own inputs are ready.

| Current state | Immediate action |
|---|---|
| Physical family is defined; the chosen method's family or kinematic inputs need encoding | Prepare those inputs from the supplied definition. Use the [DlogBasis card](../../methods/dlogbasis/SKILL.md) when that provider is selected. |
| A finite dot/normalization or Gram bundle is specified mathematically | Encode its exact definitions as `integral-candidates/v1` input data; preserve bounds, normalization and actual provenance. This introduces no new solver or acceptance test. |
| A DlogBasis search is selected and its inputs and tools are ready, with or without `prepared_derivatives.exact_strategy` | Run `PROPOSE_INTEGRAL_CANDIDATES` through `run_step.py`. This proposal is independent of `exact_strategy`. |
| A DlogBasis search is selected, and package loading and `CreateDlogFamily` are complete | Run the bounded provider search. |
| Integral candidates exist; derivative/IBP inputs are incomplete | Save the candidates, prepare the missing inputs using the [IBP skill](../canon-reduce-ibp/SKILL.md), then reduce these same candidates. |
| Candidate bridge exists | Run `ROUTE_CORE_CANDIDATES`, then CHECK_CORE, through `run_step.py`. |
| The bounded route gives no usable core | Record its result and limits; use section 1 to choose a changed integral hypothesis or an applicable direct-DE method. |

Include the chosen method's card in the worker's `required_skills`. For dots,
declare the selected propagators, added powers, prefactors, epsilon factors and
candidate count; dimension and singularity counting motivate a proposal but do
not establish UT. For DlogBasis, declare loop order/dimensions, numerator/dot
bounds, candidate count and applicable execution budget. Its card invokes
`DlogBasisSearch`; loading the package alone is not that invocation. Do not
attribute manually constructed candidates to a search that did not occur.

For DlogBasis, justify the initial numerator/dot bounds from the sector geometry
and distinguish the integral lattice and automatic chart work from the cap on
returned directions. Unless the caller fixed the bounds, start with the smallest
justified bounds and enlarge one at a time based on saved results. Use the
[method card's lattice formula and chart semantics](../../methods/dlogbasis/SKILL.md#choose-the-search-cost-before-launch); do not silently
change the caller's bounds, chart, loop order or dimensions.

After an interrupted search, retain `dlogbasis-progress.jsonl` and distinguish
entered from returned phases before extending the budget. The public search
boundary does not locate an internal hotspot, and an absent result or log does
not establish mathematical exhaustion. Pass that precise operational limit to
the coordinator together with the unchanged request.

The candidate chain is (explicit dot/Gram input data enter at the first artifact):

```text
PROPOSE_INTEGRAL_CANDIDATES
  -> integral_candidates
  -> prepare any missing candidate derivative/IBP data
  -> REDUCE_CANDIDATE_IBP
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

## 3. Select an applicable direct-DE method

Choose an applicable construction or changed bounded attempt using section 1's
goal, geometry, input evidence and remaining budget. Honor an explicitly requested
method within its contract. The table lists applicability, not execution order; no CANONICA
failure is required before Libra or INITIAL. Do not repeat an unchanged completed
attempt. For Libra's controls and cost tradeoffs, use its
[capability and cost hierarchy](../../methods/libra/SKILL.md#capability-and-cost-hierarchy).

| Condition | Method |
|---|---|
| One or a few normalized UT seeds have explicit evidence and full reduced rows, a rational one-variable cut, a declared alphabet, and a finite derivative allocation | [INITIAL](../../methods/initial/SKILL.md), `SEARCH_CORE` at `methods/initial/run.wls`. |
| A rational/horizontal construction failed scientifically, or an argument based on epsilon=0 is being used to exclude an epsilon form; no diagnosis exists for this input | Run `DIAGNOSE_CORE` using the [residue-balance card](../../methods/residue-balance/SKILL.md), then select from its actual result. |
| Diagnosis identifies one essential variable, possibly after exact homogeneous-scale separation, and residue-balance is untried | [residue-balance](../../methods/residue-balance/SKILL.md); allow regulator-singular transformations and check all original variables. |
| CANONICA `nonrationalinv` is recorded, residue-balance is exhausted or outside scope, and the DE is regular at epsilon zero | [epsilon-zero](../../methods/epsilon-zero/SKILL.md), with finite polynomial/prefactor bounds |
| A rational cut with a justified CANONICA core attempt | [CANONICA](../../methods/canonica/SKILL.md); retain the recursive or directed-block ansatz and bounds. |
| A rational one-variable cut, especially a small block or supported integer-offset normalization hypothesis | [Libra](../../methods/libra/SKILL.md); explicitly enable bounded normalization for the integer offsets. |
| An already Fuchsian rational multivariable cut, or a justified finite directional proposal | [Libra](../../methods/libra/SKILL.md#explicit-multivariable-direction-sequence); explicitly use `direction_sequence: []` for joint factorization alone, or the selected finite sequence. |
| The rational cut DE is regular at epsilon zero and epsilon-zero is untried | [epsilon-zero](../../methods/epsilon-zero/SKILL.md) |
| These choices are exhausted or inapplicable | Return exact failures and remaining scope to the coordinator; reconsider a changed integral hypothesis under section 1. |

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
An epsilon-form transformation alone does not fix kinematics-independent UT
normalization; preserve the evidence distinctions in the [method catalog](../../methods/README.md#result-meanings).

### Scope of an obstruction

Before treating an argument as a no-go result, state the admissible coefficient
field and transformation class, its hypotheses and its quantified conclusion.
The default rational gauge may be meromorphic in epsilon: require `Det[T] != 0`
as a rational function, not a finite invertible `T(0)`. Nonzero or nilpotent
epsilon-zero residues, nontrivial monodromy at that specialization, logarithmic
horizontal solutions, and failure of a finite polynomial ansatz do not by
themselves exclude that class. See the explicit counterexample in the
[residue-balance card](../../methods/residue-balance/SKILL.md).

Recomputing a residue or repeating the same IBP rules cannot verify a theorem's
missing hypothesis. A review must test the claimed implication against the
allowed transformation class. A matching exact CORE_PASS is a positive witness;
reuse it and continue the full tail. Keep an unproved obstruction as a scoped
diagnostic, never a reason to require a different family or extra masters.

## 4. Continue from the result

- `PASS/CORE_PASS`: BUILD_FULL_DE, SOLVE_TAIL, then CHECK_CANONICAL. The core is
  not the complete sector. Follow the [main route](../canon-workflow/SKILL.md).
- Missing fields, bad paths, incomplete kinematic rules or unreduced integrals:
  repair the named input/runtime/coverage problem and resume the affected step.
  These do not consume a method's scientific attempt.
- Rank shortage, CORE_FAIL or METHOD_EXHAUSTED: first apply the main route's
  [result routing](../canon-workflow/SKILL.md#5-result-routing), which separates
  timeout/cancellation from scientific limits. Retain completed failures and
  choose a changed hypothesis or another applicable construction.
- Passing core but unresolved full tail: use [canon-solve-tail](../canon-solve-tail/SKILL.md).
  Reconsider a full integral representative when indicated instead of repeating
  an unchanged tail solve.

Before every new assignment, the coordinator applies the main route to the
current scope. Reuse accepted sectors. Matching FINAL_CHECK ALL_PASS leads to
submission, review, acceptance and delivery, then ends scientific work for that
scope.

## 5. Retain useful method experience

Record a compact decision note with the family/sector and input references,
geometric reason for the proposal, exact bounds, reduction rank, core/full-prefix
results, cost, and the next changed hypothesis. Distinguish an input/runtime
failure from a rejected mathematical ansatz. Reuse successful heuristics for
comparable geometry while retaining failures and scope limits. A single success
or failure is evidence for that construction, not a universal selection rule.
Update workflow guidance when the evidence supports a reusable decision; never
weaken the acceptance gates to accommodate a preferred method.
