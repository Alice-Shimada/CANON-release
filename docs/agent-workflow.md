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
Follow skills/canon-workflow/SKILL.md to select each next action. Limit this run to
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

## Execute or resume the workflow

Read [canon-workflow](../skills/canon-workflow/SKILL.md). It is the single
scientific routing entry: identify the current artifact/result, take the first
matching action, then read only that step's skill. Method cards describe how to
execute the selected method; they do not define a second coordinator loop.

The route distinguishes successful intermediate results, provisional candidates,
method exhaustion and operational failure. In particular:

- A defined-family UT/canonical search starts with a bounded DlogBasis-refine
  proposal. Candidate derivative data are prepared for the subsequent IBP bridge;
  the proposal uses its own family and provider inputs. See the ordered
  [core-selection rules](../skills/canon-search-core/SKILL.md).
- A passing core continues through the full DE and tail; it is not a final result.
- An absent alphabet is a supported input. The solver proposes pole factors and
  supported quadratic-root letters, then checks the resulting span exactly.
- An unsupported algebraic tail does not go to a rational backend by default.
- FINAL_CHECK runs only after all resident sectors are committed.
- Matching FINAL_CHECK ALL_PASS ends scientific work for that scope. The worker
  submits; the coordinator reviews, accepts and delivers. The delivery describes
  the methods used and any unmet applicable workflow requirements. Further
  computation addresses only unresolved requested scope or changed inputs.

The coordinator uses `statemng` and the persistent-research skill to dispatch and
accept tasks. Scientific scripts return artifacts and receipts; they do not
change persistent task status. Include the last result code/reason, exact input
references, changed hypothesis, applicable skills and remaining budget in each
continuation task. A new worker should not need the full conversation to know
its next step.

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
