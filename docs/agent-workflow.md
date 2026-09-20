# Working toward a canonical basis with an agent

Give the coordinating agent a family, a scientific target, and a finite resource
budget. The agent prepares the required inputs, chooses methods from current
evidence, and reports either a checked result or the precise point at which work
stopped. The scientific contracts below are independent of the agent host or
model. Use the project's existing `statemng` infrastructure and agent roles for
persistence; host availability and setup are documented separately in
[the README](../README.md) and [the Codex guide](hosts/codex.md).

## What to provide

The minimum scientific request identifies the propagators and momentum routing,
masses and kinematic relations, the intended family or sector scope, and the
dimension and normalization conventions. Also provide a task name, available
tool installations, and limits on elapsed time, threads, memory where relevant,
and candidate searches. Point to existing masters, reductions, derivatives, or
accepted results when available. The agent can translate your definitions into
the existing formats; resolve a missing physical convention before calculations
that depend on it.

The current entry point requires the following preparation. These are concrete
inputs, not outputs inferred by `PREPARE`:

| Input | Responsibility |
|---|---|
| Family/basis identity, parameter and variable order, regulator and dimension rule | User supplies conventions; agent records them explicitly in the typed spec. |
| Full propagator/ISP index order and `propagator_slots` | Agent records the declared family; slots are one-based positions in the full index list. |
| Kira project, kinematics, reduction/export jobs and targets | Reuse supplied files or prepare them for the declared scope and installed Kira. |
| Ordered masters | Reuse the selected list or obtain it through the declared Kira preparation/reduction workflow before binding it. |
| Exact family data and derivatives for every independent variable | Reuse supplied data or prepare the existing affine-operator format and, where applicable, enhanced-Baikov data. |
| Tool entries and resource options | Resolve from task parameters, environment or Wolfram configuration; record actual entries in requests. |

Use the existing [IBP/DE interfaces](../INTERFACES.md) and
[preparation skill](../skills/canon-prepare-family/SKILL.md) for missing
preparation. `ChooseDerivativeOperator` selects from supplied derivative data;
it does not derive that data from a propagator list. `PrepareFamily.wls` binds
the typed sources and their hashes. `DiscoverSectors.wls` organizes supplied
masters; it does not discover an independent complete basis from the family.
There is currently no general propagator-only family compiler. If the available
definitions do not determine a required input, retain the completed preparation
and identify the specific missing convention or construction.

## Supplied prepared-input example

[family-spec.example.wl](../interfaces/family-spec.example.wl) is an evaluable
Wolfram Association accepted by `PrepareFamily.wls`.
[prepare.example.json](../interfaces/prepare.example.json) is its PREPARE
envelope. They reference the supplied
[triangle fixture](../tests/fixtures/kira-one-loop-triangle-sector-5/), with
`tri[1,0,1]` as the selected master, one variable `s`, and
`d = 2 - 2 eps`. The full index list is `{D1,D2,D3}`; sector 5 has bits
`{1,0,1}` and two positive propagators. This is the sector-5 scope of the
triangle family, not the three-propagator top sector.

Copy this prompt into a prepared host session:

```text
Use CANON to construct a canonical basis for the supplied triangle sector-5
example. Name the overall research task triangle-sector-5-example.
Start from interfaces/prepare.example.json and its referenced typed WL spec.
Keep its d = 2 - 2 eps, s, integral order and selected master scope.
Use the project's persistent research skill, statemng tools and installed
agent roles to initialize or resume the task and coordinate the work.
Resolve scientific tool entries from this checkout and the installed
configuration. Read the supplied fixture inputs without modifying them.
Choose an applicable method from the current evidence. Limit this run to
30 minutes total, one reducer thread, at most two provider calls and at most
two candidate directions per call. Do not expand these limits automatically.
Reuse accepted artifacts and existing checker results when their inputs and
implementation are unchanged. For new results, run the required scientific
gates. Stop and checkpoint when the budget is reached or a required input or
tool is unavailable. Return either the final checked basis, transformation,
canonical DE and alphabet, or the accepted prefix and exact unresolved gate.
```

The agent can invoke PREPARE from the checkout root as follows, placing output
in its assigned workspace:

```text
wolframscript -file mma/PrepareFamily.wls interfaces/prepare.example.json RUN_WORKSPACE/prepare
```

`RUN_WORKSPACE` denotes the workspace supplied to that agent. PREPARE only
binds inputs; it runs no reduction or basis search. The supplied example
contains preparation, not a newly computed result. Its scientific chain is
illustrated by the source of
[RunEndToEndWorkflowLiveTest.wls](../tests/RunEndToEndWorkflowLiveTest.wls);
running that regression is not a prerequisite for using the example.

## Coordinator loop

Load `persistent-scientific-research` for a multi-step research task and follow
[AGENTS.md](../AGENTS.md). Identify the overall task, initialize or resume it
through `statemng`, inspect unfinished runs, and create only the next necessary
tasks and dependencies. The assigned project workers claim and read their
tasks, use accepted dependencies read-only, and submit new artifacts. The
coordinator reviews and accepts them. A scientific script result does not itself
change persistent task status; only an accepted `completed` task satisfies a
dependency. Users do not operate the internal state CLI.

1. **Bind and order.** Run PREPARE and DISCOVER. Resident order is ascending
   `(propagator_count, sector_id)`; within a sector preserve the supplied Kira
   order. Sector bits follow the full index list, with ISP bits zero and `a1`
   least significant. Work on the first unresolved resident sector.
2. **Build the raw DE once.** Generate ordered-master derivative targets with
   `MasterDerivativeTargets`, and obtain missing rules through `ReduceIBP.wls`.
   Require target coverage and rule right-hand sides closed on the selected
   masters. `BuildSectorCutDE.wls` constructs the complete `ordered_master_de`
   and the first cut block; later sectors use `SliceSectorCutDE.wls`.
3. **Choose a current-sector hypothesis.** Use the evidence and method scope in
   the table below. Integral proposals pass through the existing candidate IBP
   bridge and `RouteCoreCandidates.wls`. Raw-DE providers need no integral
   proposal. Keep complete reduced rows, including proper-subsector tails.
4. **Check and complete the prefix.** Run CHECK_CORE. A passing core goes through
   BUILD_FULL_DE, SOLVE_TAIL and CHECK_CANONICAL. The cut gate alone does not
   certify the full dlog system. Tail solving may change lower-sector epsilon
   normalization; retain the complete returned prefix map and matrices.
5. **Accept and advance.** COMMIT_SECTOR records the new cumulative basis and
   transformation; NEXT_SECTOR computes the cursor from the manifest and trace.
   Register and accept the new result through `statemng` before dependent work.
6. **Close the stated scope.** After every resident sector is committed,
   FINAL_CHECK checks the cumulative transformation against the original
   ordered DE. Only `PASS/ALL_PASS` produces the final canonical artifacts.

Each new hypothesis has a finite declared domain: numerator/dot bounds,
coefficient or prefactor support, loop order/dimensions when relevant, candidate
count, and resources. Candidate-count truncation does not bound the runtime of
an external provider; the coordinator must also supervise the elapsed budget.

| Current evidence | Applicable next action |
|---|---|
| Rational cut DE in one or several variables | Consider the [CANONICA card](../methods/canonica/SKILL.md) within its rational-transformation scope. |
| Small rational cut DE in one variable | Consider the current automatic [Libra card](../methods/libra/SKILL.md). Its scope is narrower than Libra's full capabilities. |
| Rational DE regular at epsilon zero | Consider the finite polynomial [epsilon-zero proposal](../methods/epsilon-zero/SKILL.md), with its declared algebraic normalization. |
| Useful integrand/cut geometry | Use [DlogBasis-refine](../methods/dlogbasis/SKILL.md) for bounded integral candidates, then test the reduced full rows. |
| Gram-sensitive rank gap or a core that passes while its full tail fails | Use the [Gram guidance](../methods/gram/SKILL.md) for a concrete dimensional extension or contact-term hypothesis. It is guidance, not a separate executable provider. |

This is a choice among hypotheses, not a universal provider sequence. Do not
require exhaustion of every numerator or dot ansatz before a DE method or tail
solve. Consult a specialized card only when its actual scope matches the input.

## Responding to failures and limits

| Observation | Coordinator decision |
|---|---|
| Missing IBP targets or rules | Identify the missing targets and extend the existing reduction within budget. Reuse covered rules; an unreduced expression is not a failed canonical candidate. |
| Candidate rank below the current master count | Record the actual rank and sampled/ansatz scope. Try a bounded independent direction, a complete replacement bundle, or an applicable DE method. The router's single-row exchanges do not enumerate all bundles. |
| CHECK_CORE fails | Read its exact rejection signature and choose a new current-block hypothesis. A lower-sector-only repair cannot fix a failing current diagonal block. |
| `TAIL_UNSOLVED` or `TAIL_FAIL` | Inspect the offending coupling and epsilon dependence. Use the existing tail solver or a motivated change of full integral representative, preserving complete lower-prefix normalization. |
| `METHOD_EXHAUSTED`, `OUT_OF_SCOPE`, or a candidate budget limit | Record exactly which method/domain ended. Try another justified route only within the remaining user budget; otherwise checkpoint as inconclusive. |
| Timeout, memory pressure, missing installation or unresolved convention | Record the run, retained outputs and restart point. Pause dependent work and report the operational condition; no mathematical nonexistence claim follows. |

Provider output is provisional. A provider's exit code or self-reported epsilon
form is not acceptance. CHECK_CORE, CHECK_CANONICAL and FINAL_CHECK supply the
existing independent scientific gates; their symbolic flatness checks are
stronger than DEBuilder's recorded exact-point validity samples. A cut or
finite-field result must retain its own scope.

## Artifact ownership and delivery

Source inputs and installed tools remain read-only. Workers write new files in
their assigned workspaces. JSON-relative paths are resolved from the declaring
JSON; spec-relative paths from the spec; Kira jobs/config/targets from the
declared project. If an input is relocated, update its references deliberately.
JSON paths do not expand `~` or environment variables. Output command-line
paths remain relative to the working directory.

Declare direct dependencies on shared preparation, raw DE/rules, and the latest
accepted prefix. Register each new or changed file separately and submit one
entry artifact or short index. Reuse prior artifact paths and hashes rather
than embedding old workspaces or dependency archives. A new prefix still
contains its full cumulative basis, transformation and matrices.

Review the current inputs, existing checker results and acceptance criteria.
Once these suffice, accept the result. Add a separate verification task only
for a specific unresolved issue, an input or implementation change, or a user
request. Do not repeat candidate generation, the IBP bridge, a clean replay, or
the whole family merely to duplicate existing evidence.

A successful delivery links `canonical_basis`, `canonical_de`, the final
accepted prefix and checker result, with the original source references. The
basis artifact includes the raw-to-canonical relation
`old_source_basis = transformation . accepted_basis` and sector/candidate trace.
The DE artifact includes all variable directions, active alphabet, shared
constant residue matrices and exact check scope. This establishes the checked
canonical form for the supplied master space; it does not independently prove
master completeness, uniform transcendentality, or a universal discovery
algorithm.

On a stop, return the accepted prefix, first unresolved sector and gate, failed
hypothesis/domain, consumed budget, and the concrete condition or next bounded
hypothesis needed to continue. Keep unaccepted proposals distinct from accepted
results. Budget exhaustion is a resumable incomplete result, not completion or
proof that no canonical basis exists.
