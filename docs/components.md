# Scientific components

Each workflow step is an independent command with the same file interface:

```text
COMMAND INPUT.json OUTPUT_DIR
```

The input and `OUTPUT_DIR/result.json` use the envelopes in
[INTERFACES.md](../INTERFACES.md). Artifacts passed to built-in consumers keep
their existing WL schemas, basis order, conventions and acceptance scope. A component can be
implemented in Wolfram Language, Python or another executable language; it owns
its internal algorithm and files.

## Calling a step

From the CANON checkout:

```sh
python3 run_step.py INPUT.json OUTPUT_DIR
python3 run_step.py INPUT.json OUTPUT_DIR --method epsilon-zero
python3 run_step.py INPUT.json OUTPUT_DIR --components /path/to/package/components.json
python3 run_step.py INPUT.json OUTPUT_DIR --components /path/to/first/components.json \
  --components /path/to/second/components.json
python3 run_step.py INPUT.json OUTPUT_DIR --defaults
```

The request's `step` selects the entry. `SEARCH_CORE` has several existing
methods, selected explicitly with `--method canonica`, `libra` or `epsilon-zero`.
There is no default search method or automatic fallback. A component package may
also supply a single `SEARCH_CORE` entry, invoked without `--method`.

`--describe` prints the resolved command, component selection, instruction file
and package workflow instructions without executing. `--list` lists every entry:

```sh
python3 run_step.py --list
python3 run_step.py INPUT.json OUTPUT_DIR --describe --method libra
```

An entry may include an `interface` object listing required `inputs`,
`optional_inputs`, `outputs`, input `alternatives` and its `scope`. The runner
reports the selected provider's metadata unchanged. It is a description for
callers, not another schema validator or automatic compatibility decision.

[components/default.json](../components/default.json) binds all existing steps
and runnable method cards to their current implementations. All defaults are
active until a custom package is explicitly selected. Direct `.wls` invocation
remains a low-level entry and bypasses component selection.

Selection is read afresh for each call. Repeated `--components` arguments compose
packages in the given order; later definitions override earlier ones. An explicit
selection replaces the inherited selection. `--defaults` ignores it entirely.
No optional directory is scanned or imported by default. Remove a package from
the selection to detach it; subsequent steps use the remaining definitions.
Already started calculations keep their resolved invocation. Finish or cancel
them before removing or editing their implementation files.

## A component package

A package is a directory containing a manifest, its commands and their scientific
instructions. The manifest lists only the steps it implements. For example, a
future middle-stage package could declare:

```json
{
  "schema": "canon-neu/components/v1",
  "workflow": "WORKFLOW.md",
  "steps": {
    "BUILD_FULL_DE": {
      "command": ["{python}", "{package}/build_full.py"],
      "instructions": "BUILD_FULL_DE.md"
    },
    "SOLVE_TAIL": {
      "command": ["{wolframscript}", "-file", "{package}/SolveTail.wls"],
      "instructions": "SOLVE_TAIL.md"
    }
  }
}
```

These paths illustrate the interface.
Entries override the same named defaults in full. Other entries continue to use
CANON's defaults. A package can supply several consecutive steps, or add a named
method such as `SEARCH_CORE/my-method`. Multiple entries may call the same
program, which branches on the input `step`.

A manifest can compose packages through a relative `extends` list:

```json
{
  "schema": "canon-neu/components/v1",
  "extends": ["../kinematics/components.json", "../reconstruction/components.json"],
  "steps": {}
}
```

Parents load in the stated order, followed by this manifest's own entries.
An inherited entry keeps its original `{package}` base. Paths in `extends`,
`instructions` and optional `workflow` are relative to their declaring manifest.
Moving the package tree preserves these references; no install or global registry
is involved. Optional packages depend on CANON's declared common interface and
their explicit inputs, not another optional package's private directory layout.
Shared adapter packages are explicit manifest dependencies and move with the
packages that reference them.

## Select an implementation for each phase

A profile can reference one entry from a package without adopting its other
steps. Parameterization, master discovery, reduction and direct DE construction
are independent choices:

```json
{
  "schema": "canon-neu/components/v1",
  "steps": {
    "PREPARE": {"from": "../parameterization/components.json"},
    "DISCOVER": {"from": "../reducers/kira/components.json"},
    "REDUCE_IBP": {"from": "../reducers/fire7/components.json"},
    "BUILD_CUT_DE": {"from": "../reducers/blade/components.json"}
  }
}
```

This is the supplied [mixed profile](../components/profiles/mixed-reducers.json).
It selects interfaces; each request still supplies the chosen installation,
backend configuration and required scientific inputs. It does not install those
programs or invent missing native capabilities. The
[custom-parameterization/Kira profile](../components/profiles/custom-kira.json)
uses Kira for discovery and reduction and retains the ordinary DE builder.

`from` resolves from the profile file. Optional `step` selects another entry name,
for example `"step": "SEARCH_CORE/libra"`; otherwise the current key is used.
The command retains its provider's `{package}` base. An optional `instructions`
overrides the instruction file relative to the profile. `--describe` reports
the actual command provider, binding manifest and relevant workflows. Missing
referenced operations and reference cycles are errors, with no silent fallback.

Direct `command` entries and `from` references are alternative entry forms.
Later selections can replace either one. A package providing three operations
need not be selected for all three.

`command` is an argv array, never shell text. The runner appends the absolute
input and output paths. Its substitutions are:

| Token | Meaning |
|---|---|
| `{package}` | Directory containing this entry's manifest |
| `{canon}` | Current CANON checkout |
| `{python}` | Python executable running `run_step.py` |
| `{wolframscript}` | `CANON_WOLFRAMSCRIPT`, or `wolframscript` on PATH |

`instructions` is relative to the manifest directory. It describes the module's
inputs, method options, mathematical scope, outputs and next checker. Read this
file for the selected implementation; built-in method details do not constrain a
user-declared replacement algorithm.

`workflow` is optional and describes the package's scientific route, repair
decisions and completion criterion. Read it alongside the selected step's
instructions before applying the default route table. New step names are
supported without editing the runner. This field describes agent decisions; it
does not execute a second scheduler or change research task states.

CLI paths are relative to the caller's working directory. Paths in the scientific
request remain relative to that request. Component selection never copies or
rewrites the request or scientific artifacts.

## Composition and handoff

Supported research workflows combine named steps, mathematical input files and
JSON settings. Use existing native programs for preparation, solving and export;
the shared native adapter accepts a finite ordered `commands` list when these
are separate executables. See its [command contract](../components/reducers/native-adapter/README.md).
An absent algorithm or exporter is component development with its own tests and
documented interface, rather than a new scientific program written inside each
research attempt.

For each consumer, supply the descriptors produced by its upstream steps. A
middle-stage package must return the public artifacts expected at its outgoing
boundary, including the complete cumulative map and lower-sector normalization.
Its internal algorithms can differ completely from the defaults. A package that
computes several steps together may retain its intermediate files and expose
them through those steps' existing contracts; CANON does not introduce another
pipeline scheduler or internal object model.

When a package replaces both a producer and its consumer, their internal
artifact may use a package-specific schema documented by those two components.
At an edge returning to a built-in consumer, provide that consumer's published
format. For example, a family intake for master discovery can precede the first
master list and derivative operators; it must identify that limited preparation
scope rather than pretend to be a complete default `prepared_family`.

Set `--components` on each independent workflow call, or set `CANON_COMPONENTS`
to a manifest path or JSON array of manifest paths for that task's process
environment. The explicit flags win. The runner passes the complete selection
and its Python executable to child
processes. In particular, default `REDUCE_CANDIDATE_IBP` calls `REDUCE_IBP`
through the same runner, so replacing the reducer also affects the candidate
bridge. `CANON_PYTHON` carries that interpreter for nested calls.

Both IBP steps now take the common envelope and produce `result.json`:

| Step | Payload | Output artifact |
|---|---|---|
| `REDUCE_IBP` | Selected adapter's `backend` config descriptor, neutral family/target/master descriptors; the default also accepts the legacy `reduction` object | `ibp_reduction` |
| `REDUCE_CANDIDATE_IBP` | `integral_candidates`, `prepared_family`, `master_basis`, `prepared_derivatives`, plus `backend` and needed neutral family descriptors; legacy `reduction` is still accepted by the default adapter | `candidate_ibp_bridge`, `reduction_targets` |

Their scientific WL contents are unchanged. The previous positional IBP CLI is
replaced by this common interface; see the
[request example](../interfaces/ibp-request.example.json). Reducer configuration
inside legacy `reduction` belongs to the default Kira module. The candidate
bridge compiles a neutral target artifact and dispatches the selected reducer;
it never copies a native project or chooses its target-file format. Backend
config files resolve their own paths. The old inline Kira config is passed by
reference to its original request file, preserving that path base. A custom
reducer documents its own options while preserving `ibp_reduction` at the
outgoing boundary.

The runner performs command selection only. It does not inspect scientific
artifacts, add acceptance checks, retry a method or update research state.
Providers remain provisional; the declared independent checkers retain their
acceptance roles. Use the existing scientific gates for changed implementations.
Passing unchanged results need no replay merely because a new component package
is available. The coordinator records the selected manifest and instructions in
worker assignments and continues to manage research through `statemng`.

New artifact references should be relative to the file declaring them. Wolfram
components can use ``CanonMethodCard`RelativeArtifactPath[declaringFile, target]``
when saving a reference, and `ResolveInputPath` when opening it. Move referenced
inputs and outputs together. Tool installations remain caller-supplied runtime
dependencies; execution receipts may record the actual absolute paths used.

## Binding requests without a glue program

`PREPARE_REQUEST` turns a JSON template into an ordinary request. For example,
its own payload can be `{"template":{"type":"json","path":"build.template.json"}}`.
Inside that template's payload, use
`{"from_result":"../reduce/result.json","artifact":"ibp_reduction"}` to copy a
named artifact descriptor. PASS and PROVISIONAL producers are usable; a binding
does not promote their scientific status. Literal `path` descriptors resolve
from the template and all artifact paths are rebased to the generated request.
Keep native options in the backend's separately referenced config file.

Call the generated request through the runner with the same component selection.
There is no pipeline language or hidden execution. Separately registered state
artifacts can be passed directly using their returned paths; `from_result` needs
the producer's original result/artifact layout. See the
[binding contract](../skills/canon-prepare-request/SKILL.md).

For a symbolic DE from masters and affine derivatives, the named production
sequence is `PREPARE` → `DISCOVER` → `PREPARE_REDUCTION_TARGETS` → `REDUCE_IBP`
→ `BUILD_CUT_DE`, followed by `SLICE_CUT_DE` for later sectors. The selected
parameterization, discovery and reducer can differ at each phase. Candidate and
point/frame derivative workflows retain their own preparation steps.

The [scalar workflow templates](../interfaces/examples/scalar-workflow/README.md)
give a concrete sequence and document its supplied analytic fixture scope.

## Internal library layout

Public Wolfram entry files load explicit adjacent fragments, keeping their
existing contexts and APIs. Distribute the whole library directory with them.

| Entry | Responsibilities |
|---|---|
| `mma/lib/MethodCardCore.wl` | `method-card/`: artifact IO, contracts, prepared-basis routing, sectors, gauge checks, dlog algebra and structured repair |
| `mma/lib/SectorDE.wl` | Prepared derivative loading/normalization, construction and slicing input boundaries |
| `mma/lib/TailCompletion.wl` | Explicit algebraic completion and backend inputs; `mma/SolveTail.wls` handles CLI loading and artifact publication |
| `components/reducers/native-adapter/NativeAdapter.wl` | `lib/`: scientific inputs/encoding, basis conversion, discovery, reduction, DEs and normalization dispatch |

External input checks belong at each callable boundary. Internal helpers consume
those checked inputs and do not repeat checks implied by their construction.
`SectorDEArtifacts` is the shared pure slicing function used by both default DE
steps and native DE import. Exact gauge, flatness and final scientific checks
retain their separate acceptance roles.

## Optional sampled reconstruction and local execution

- [point-de](../components/point-de/README.md): derivative preparation, reduced
  point DE construction with an explicit frame, and a sample-set index.
- [dlog-reconstruction](../components/dlog-reconstruction/README.md): fit raw
  analytic letters to training DE samples and verify against independent samples.
  The output declares its finite-sample validation scope; it does not use the
  default exact-global-gauge `ALL_PASS` claim.
- [local-jobs](../components/local-jobs/README.md): detached local execution,
  collection, cancellation and completion-only notification through a supplied
  callback command. It does not change scientific acceptance or research state.

Select only the packages needed for a task. Their manifests and instructions
remain usable outside this checkout. No remote execution or agent-specific
callback transport is required by the runner.

For example, compose the three independent packages for a local sampled-DE
task, keeping the same selection on each subsequent call:

```sh
python3 run_step.py INPUT.json OUTPUT_DIR \
  --components components/point-de/components.json \
  --components components/dlog-reconstruction/components.json \
  --components components/local-jobs/components.json
```

The point package produces a `de_sample_set` artifact; pass that descriptor as
the reconstruction request's `sample_set`, alongside separately supplied raw
letters. Job collection returns a descriptor for the original scientific
result. Resolve each relative descriptor from the file that declares it when
writing the next request.

The [cross-package test](../tests/test_sampled_components.py) uses a small
analytic bubble with supplied reduction rules. It constructs actual point DEs,
collects two training samples and one held-out sample, moves the package and
artifact tree, then reconstructs and independently checks the known dlog form.
It also runs one point as a local job and tests a fake callback. Run it with a
fresh output directory and the configured Wolfram runtime:

```sh
python3 tests/test_sampled_components.py --canon . --work /path/to/fresh-test-work
```

The test uses one kernel at a time and starts no physical reduction campaign or
live host callback. Package-specific tests and supported mathematical scope are
documented in each package's README.

## Parameterization and reduction boundaries

[parameterization](../components/parameterization/README.md) supplies `PREPARE`
for user-defined vector or scalar-product charts. Twistor coordinates are one
possible input. It preserves symbolic family data and exports a neutral
`reducer_family` view, optionally evaluated at a declared point. It emits no
native reducer files, executable choice, seeds or jobs.

The [Kira adapter](../components/reducers/kira/README.md) owns its YAML, seeds,
jobs, native execution and result imports. Its manifest contains `DISCOVER` and
`REDUCE_IBP`, with no `PREPARE`. The caller chooses the executable, including
whether that installation is Kira 2 or Kira 3.

[Blade](../components/reducers/blade/README.md),
[FIRE7](../components/reducers/fire7/README.md) and
[NeatIBP](../components/reducers/neatibp/README.md) adapters document their native
setup/export boundaries and standard result conversion. Use their declared
operation capabilities and distinguish importing a saved native output from
running a new native calculation. Equation generation alone is not completed
reduction. Their shared adapter dependency is explicit in the manifests.

The ordinary `BUILD_CUT_DE` consumes full symbolic normalized reductions and
prepared derivative data from any producer. Fixed-point reductions belong to
`BUILD_POINT_DE`, with their explicit kinematics binding. A backend with its own DE engine can instead implement
that step directly, returning the same complete ordered DE and sector artifacts.
Different native integral encodings are normalized explicitly. A changed master
set needs a declared basis conversion; reordering identical masters is distinct
from changing the basis.

The old [twistor-kira3](../components/twistor-kira3/README.md) name is retained only
as a migration profile. Its former coupled implementation is replaced by these
independent packages; new requests keep chart and backend configuration separate.

The [default binder regression](../tests/test_default_binder.py) checks preparation
without Kira settings, actual discovery-to-DE handoff after relocation, and
compatibility with the older integral-symbol context. It uses supplied analytic
rules and runs no reducer:

```sh
python3 tests/test_default_binder.py --canon . \
  --inputs tests/fixtures/default-binder-inputs.json --output /path/to/fresh-test-work
```

The [cross-backend test](../tests/test_reducer_interchange.py) uses the actual
neutral producer and discovered masters, then compares FIRE-normalized rules in
the generic DE builder with a Blade-format DE import. Requests are bound from
the checked-in JSON templates through `PREPARE_REQUEST`; derivative targets come
from `PREPARE_REDUCTION_TARGETS`. It also checks shared sector slicing, Neat rule
imports and equations-only rejection using the same unchanged family. The source,
input and output tree moves before discovery and downstream calls:

```sh
python3 tests/test_reducer_interchange.py --canon . --work /path/to/fresh-test-work
```

Its discovery process and native-format exports are bounded analytic fixtures;
this test does not run native Kira, FIRE, Blade or NeatIBP engines. The Kira
package documents its separate opt-in native smoke test.
