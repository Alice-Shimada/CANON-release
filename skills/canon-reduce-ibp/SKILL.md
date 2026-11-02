---
name: canon-reduce-ibp
description: Reduce declared targets through the selected adapter and preserve the source master basis; the default adapter uses a prepared Kira project.
---

# Reduce IBP

Work in the workspace assigned by the research task. Both IBP steps use the
common request/result envelope. Set `step` to `REDUCE_IBP` and carry the task's
component selection. New adapters use a `payload.backend` config descriptor and
their declared neutral family, target and master inputs. The default adapter
also accepts the existing seven-field Kira config in `payload.reduction`:

```text
python3 run_step.py INPUT.json OUTPUT_DIR
```

Read `result.json` and its `ibp_reduction` descriptor. A successful call returns
`PASS/IBP_REDUCED`; its WL artifact contains `masters` and `rules`.
Preserve the declared source master order. When no source basis was supplied,
the default adapter retains the native order. In the task's positive scientific check, compare
every requested target with the master/rule left sides and require every rule
right-hand side to contain only those ordered masters.

For symbolic master derivatives, obtain the target artifact through
[PREPARE_REDUCTION_TARGETS](../canon-prepare-reduction-targets/SKILL.md), then
bind it into this request. That step uses the same prepared derivative source as
`BUILD_CUT_DE`. Candidate derivatives continue through `REDUCE_CANDIDATE_IBP`;
a separate point/frame consumer is needed for specialized fixed-point data.

The `reduction` fields `project`, `output` and executable paths containing a separator are
resolved relative to the request JSON. A bare executable name is found on PATH;
`jobs` are relative to the copied Kira project. Pass the thread budget in
`options`, and configure Fermat through `FERMATPATH`. Source installation
instructions are in `external/README.md`.

When the selected backend is `components/reducers/kira`, default to FireFly:
automatic jobs use `reduction_engine: "firefly"` (the omitted-field default),
and caller-supplied reduction jobs enable `run_initiate: true` plus
`run_firefly: true`. Symbolic Fermat reduction is an explicit alternative,
not an automatic fallback after a failed FireFly attempt. `DISCOVER` remains
master initiation. Pass the assigned IBP evaluator budget with `--parallel=N`;
this controls Fermat/FireFly evaluators, not Kira's OS thread count. Follow the
selected component's README and workflow for its exact configuration.

Before enlarging a seed, identify the missing target or changed coverage
hypothesis and check that its positive powers, dots and numerator degree fit
the configured bounds. A two-dot probe with a one-dot seed is not a master-count
test. Report requested, reduced and unresolved target counts separately.

For `NATIVE_BASIS_MISMATCH`, compare the exact ordered native/exported list with
the declared source list and the closure of the requested targets. A local
current-sector list, its lower-sector closure and the family's full list have
different sizes. Counts such as 3, 19 and 34 alone do not imply extra or missing
masters. Preserve the adapter's rejection until its declared import/rebase
contract is satisfied; do not bypass the basis check or label raw exports a pass.
If a bounded complete reduction agrees exactly with existing rules and supplies
no new direction, return that evidence to core selection. A failed gauge ansatz
or epsilon-zero monodromy argument alone does not justify further IBP expansion.

The request must pass argv items, never a shell command string. The script does
not choose a reducer, probe versions, build DEs, or mutate research state. If the
result is a deliverable, the Agent registers its WL artifact through the state
manager after inspection.

For a `canon-neu/integral-candidates/v1` artifact, set `step` to
`REDUCE_CANDIDATE_IBP`. Its payload carries the `integral_candidates`,
`prepared_family`, `master_basis`, and `prepared_derivatives` descriptors plus
`backend` and the selected adapter's required neutral input descriptors. Legacy
`reduction` remains supported by the default adapter. Use the same invocation:

```text
python3 run_step.py INPUT.json OUTPUT_DIR
```

To reuse an existing normalized symbolic reduction, supply
`payload.ibp_reduction: {"path": "rules.wl"}` instead of reducer configuration.
The bridge compiles the same targets, loads that artifact through the common
data reader, and checks ordered masters, optional family/basis identities,
unchanged source masters and complete linear target closure in one substitution.
The artifact contains `masters` and distinct explicit `rules`; source masters do
not need identity rules. Its scientific provenance and the truth of its rules
remain supplied inputs. A passing reuse call launches no reducer. Missing or
unreduced targets return `INCONCLUSIVE/INCOMPLETE_REDUCTION` with readable target
diagnostics; incompatible inputs return an explicit `ERROR`. Both retain the
current `reduction_targets` and never silently dispatch a replacement reduction.
The same checks apply to an artifact returned by the selected reducer, including
its optional SHA-256. A child `PASS` does not bypass the bridge's source-basis and
target-closure contract. Missing, incompatible or incomplete returned data cannot
publish `CANDIDATES_REDUCED`.

The result is `PASS/CANDIDATES_REDUCED` with `candidate_ibp_bridge` and
`reduction_targets` descriptors. The bridge compiles targets and forwards config
references; native project copying and target/export syntax belong to the adapter.
Pass the task's `--components` manifest to either call. The candidate bridge's
nested `REDUCE_IBP` call inherits it, so the selected reducer is used throughout.
A custom module's instruction file describes its own reduction configuration.
Per-step profile bindings can select a discovery backend, another reducer, and a
third direct DE producer. Identical masters in another order can be aligned;
a different master basis requires an explicit conversion before downstream work.

Before this candidate bridge, read the
[derivative input contract](../../INTERFACES.md#derivative-operator-selection).
By default `derivative_operator_selection` is `"enhanced-first"`: the selector
requires affine `operators` and a family-derived `exact_strategy`. An explicit
`payload.derivative_operator_selection: "prepared-affine"` uses the supplied
exact affine records without the enhanced search. That mode also requires
`exact_strategy.propagator_slots` for target metadata, but does not consume or
validate unused enhanced-search fields. Its operator evidence records
`kind: "prepared-affine"` and `enhanced_search_attempted: false`; this is not
search exhaustion. Unknown choices fail before target/reducer dispatch.

For records generated by the
[physical derivative module](../canon-prepare-derivatives/SKILL.md), explicitly
select `"prepared-affine"`. The generator supplies the protected slots and
physical affine records; it does not supply enhanced Baikov strategy data.
Prepare missing affine derivatives through `PREPARE_DERIVATIVES`, never through
a task-local derivative program.

Follow this order:

1. Keep the returned candidate file and its IDs unchanged.
2. If an input needed by the selected derivative mode is missing, prepare it from the declared family
   in the run workspace. The contract lists the fields and Gram-polynomial
   construction. Rebind changed sources with PREPARE; reuse unchanged masters,
   rules and scientific results as their contracts permit.
3. For the default mode, let `ChooseDerivativeOperator` perform its bounded search. A valid search
   with no enhanced solution returns `affine-fallback`, which is supported.
   Missing or malformed metadata returns a preparation failure, resolved by
   supplying the family-derived fields required by the contract.
4. Run the bridge on the saved candidates and reduce its required targets.
   Continue with ROUTE_CORE_CANDIDATES and CHECK_CORE.

If a concrete bounded preparation attempt cannot supply the needed construction,
report the attempted operation, exact missing object and remaining resources to
the coordinator. That evidence can justify another route under
[core selection](../canon-search-core/SKILL.md). An absent `exact_strategy`
identifies bridge preparation to perform. The earlier DlogBasis proposal is
independent of this field.

The bridge must use
the explicitly prepared affine, affine-fallback, or enhanced-Baikov operator exactly, retain proper-subsector
tails and signed numerator indices, and return candidate-ID-keyed reduced
expressions and derivatives. This is an IBP closure artifact, not a UT or
canonical-basis certificate.
