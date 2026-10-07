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

When a time allowance is supplied, record its start and absolute deadline with
timezone. Keep per-step execution caps, cancellation/collection reserves, tool
wait limits and mathematical search bounds separate. Record each cap's source
and enforcing layer in the task context; recalculate remaining time from system
time on launch and resume. See the
[execution budget and recovery rules](../skills/canon-workflow/SKILL.md#6-execution-budgets-and-operational-recovery)
for adjustment, cancellation and collection. These rules add no universal step
timeout; the user's resource limits govern the allocation.

The default entry point requires the following preparation. These are concrete
inputs, not outputs inferred by the default `PREPARE` component:

| Input | Responsibility |
|---|---|
| Family/basis identity, parameter and variable order, regulator and dimension rule | User supplies conventions; agent records them explicitly in the typed spec. |
| Full propagator/ISP index order and `propagator_slots` | Agent records the declared family; slots are one-based positions in the full index list. |
| Backend configuration, native jobs/drivers and targets | Supply them to the selected reducer, independently of the parameterization. Legacy Kira provenance in a default family spec is optional. |
| Ordered masters | Reuse the selected list or obtain it through the explicitly selected discovery adapter before binding it. |
| Exact family data and derivatives for every independent variable | Declare geometry and call automatic parameterization `PREPARE` or `PREPARE_DERIVATIVES`. Reuse validated derivatives; agents do not write operators. Enhanced-Baikov strategy data remain separate. |
| Tool entries and resource options | Resolve from task parameters, environment or Wolfram configuration; record actual entries in requests. |

When reusing a saved transformation, recover its exact source integral vector
from the same artifact or producer record. Match integral tuples and powers,
including their order, against the current DE. A reducer master list can contain
the same integrals in a different order. Preserve the saved matrix's source order
in `source_basis` and let the consumer map those explicit entries, or apply one
recorded permutation to the corresponding matrix axis and labels together.
Matching family names, dimensions or sector counts alone does not establish this
binding. Convert the saved transformation convention exactly once.

Use the existing [IBP/DE interfaces](../INTERFACES.md) and
[preparation skill](../skills/canon-prepare-family/SKILL.md) for missing
preparation. `ChooseDerivativeOperator` selects from supplied derivative data;
it does not derive that data from a propagator list. The
[physical derivative module](physical-derivatives.md) generates affine data from
the declared external kinematics and routing. `PrepareFamily.wls` binds
the typed sources and their hashes. `DiscoverSectors.wls` organizes supplied
masters; it does not discover an independent complete basis from the family.
Family definitions still require explicit external kinematics and index orders.
The parameterization front end compiles those definitions and their physical
derivatives; master discovery and reduction follow the selected backend's
contract. If an input is not determined, retain the completed preparation and
identify the specific missing convention or construction.

The optional [parameterization](../components/parameterization/README.md) package
retains user-defined vector or scalar-product charts and supplies a neutral
family view and physical derivatives. Select the discovery/reduction adapter
independently; the front end does not write native reducer jobs.
The [point-DE package](../components/point-de/README.md)
constructs point derivatives for its declared vector geometry and supplied
integral candidates. The [reconstruction package](../components/dlog-reconstruction/README.md)
consumes point DEs with explicit training/validation roles. These packages have
their own input scope and do not change the preparation requirements above for
default consumers.

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
python3 run_step.py interfaces/prepare.example.json RUN_WORKSPACE/prepare
```

`RUN_WORKSPACE` denotes the workspace supplied to that agent. PREPARE only
binds inputs; it runs no reduction or basis search. The supplied example
contains preparation, not a newly computed result. Its scientific chain is
illustrated by the source of
[RunEndToEndWorkflowLiveTest.wls](../tests/RunEndToEndWorkflowLiveTest.wls);
running that regression is not a prerequisite for using the example.

## Execute or resume the workflow

For supported operations, prepare mathematical objects and JSON settings, then
call named interfaces and existing programs. Use `PREPARE_REQUEST` to bind
existing result descriptors into a request, and `PREPARE_REDUCTION_TARGETS` for
symbolic master derivatives before reduction. These steps replace per-task
scientific glue scripts. If an algorithm or native exporter is missing, identify
that capability and implement it as a separate reusable component development
task with bounded tests before resuming research.

Read [canon-workflow](../skills/canon-workflow/SKILL.md). It is the single
scientific routing entry: identify the current artifact/result, take the first
matching action, then read only that step's skill. Method cards describe how to
execute the selected method; they do not define a second coordinator loop.

For a task with custom component packages, carry the ordered manifests in every
worker assignment and repeat `--components PATH` on each `run_step.py` call.
Per-step `from` references can select different providers for discovery,
reduction and cut-DE construction. Preserve that profile during nested candidate
reduction; do not replace it with a single whole-backend selection.
Use `--list` or `--describe` to find the selected instructions and any package
workflow. Its algorithm
and implementation-specific options replace the built-in instructions; the
public artifact conventions and acceptance roles still apply. See
[component packages](components.md). If the package supplies an unqualified
`SEARCH_CORE` entry, call that entry without selecting a built-in `--method`.
The package workflow defines its own additional steps, repair routes and scoped
completion checks. Unselecting a package restores the remaining definitions;
`--defaults` ignores the whole inherited selection. The runner loads packages
only when selected, so optional code can live outside the checkout.

The route distinguishes successful intermediate results, provisional candidates,
method exhaustion and operational failure. In particular:

- For a defined-family UT/canonical search, select a small proposal from the
  geometry and existing evidence: dots and normalization for suitable simple
  sectors, Gram constructions for a concrete numerator/dimensional/contact
  hypothesis, or DlogBasis-refine when a general bounded search is useful.
  Candidate derivative data are prepared for the subsequent IBP bridge.
  DlogBasis is optional; the independent gates are unchanged. Retain tested
  choices and their limits using the [core-selection rules](../skills/canon-search-core/SKILL.md).
- A passing core continues through the full DE and tail; it is not a final result.
- A failed epsilon-zero construction or a proposed monodromy obstruction goes
  through the [core selection rules](../skills/canon-search-core/SKILL.md#scope-of-an-obstruction).
  `DIAGNOSE_CORE` and the bounded residue-balance provider handle supported
  rational systems, including exact homogeneous-scale separation. Regulator
  poles in a transformation are allowed; diagnostic failure is not nonexistence.
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
continuation task. For operational recovery, record the interrupted stage
(unknown without phase evidence), current result or its absence, saved job/output
references and the changed runtime setting instead of claiming an exhausted
mathematical ansatz. A new worker should not need the full conversation to know
its next step.

For an explicitly selected [local job](../components/local-jobs/README.md), record
its immutable job/watch handles and let the worker return `DEFERRED` while the
research task stays `running`. The completion monitor executes only the declared
checkpoint check and callback. A configured host adapter requests continuation
in the bound session; on resumption, the coordinator collects the existing run
and performs normal review/acceptance. Callback acknowledgment records delivery,
not execution of a model turn. A launched process, a terminal receipt, and an
accepted scientific result are separate events. Do not turn ordinary detached
waiting into a failed research attempt.

## Artifact ownership and delivery

Source inputs and installed tools remain read-only. Workers write new files in
the workspace returned by `task_show`; dependency `stored_path` values resolve
from its returned `project_root`. JSON-relative paths are resolved from the
declaring JSON; spec-relative paths from the spec; Kira jobs/config/targets from the
declared project. If an input is relocated, update its references deliberately.
JSON paths do not expand `~` or environment variables. Output command-line
paths remain relative to the working directory.

Keep generated receipts byte-exact under their original references. Correct
inputs or bindings in new files, use `PREPARE_REQUEST` where applicable, and
register the new result separately. A copied old receipt is not a new attempt's
result; apply the workflow's recovery rules when a stopped stage wrote none.

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
