# Kira backend

This independent component implements `DISCOVER` and `REDUCE_IBP`. It has no
`PREPARE` entry and does not choose coordinates or construct family geometry.
It consumes the neutral `canon-neu/reducer-family/v1` JSON view from the selected
parameterization producer. Symbolic invariant charts and exact numeric points
use the same interface. No native executable or thread count is assumed.

The implementation uses Python's standard library, the selected Wolfram
executable, and the explicitly supplied CANON common API through `{canon}`.
Discovery uses `CanonMethodCard`FormatMasterArtifacts` to retain standard sector
ordering and within-sector native order. It imports no optional package.
Local process ownership requires POSIX groups and `waitid(WNOWAIT)`.
On macOS, an `EPERM` during cleanup is ignored only after a successful process
table inspection confirms that the unreaped leader's group has no live members.
Permission errors for live groups remain operational failures.

Select this manifest for either phase through the runner, or use per-step
`from` bindings to combine it with another parameterization or reducer:

```sh
python3 /path/to/CANON/run_step.py request.json output --components /path/to/kira/components.json
```

## Requests and configuration

Both common-envelope requests contain `payload.reducer_family` and
`payload.backend` JSON descriptors. Paths are relative to the request file.
The backend descriptor references this adapter's separate JSON configuration:

```json
{
  "schema": "canon-neu/kira-backend/v1",
  "executable": "kira3",
  "options": ["--parallel=1"],
  "reduction_engine": "firefly",
  "seed": {"r": 3, "s": 0, "d": 1},
  "timeout_seconds": 90,
  "cancel_grace_seconds": 1
}
```

`kira3` is an example runtime value. Any caller-selected compatible executable
or path may be supplied. Executable paths containing a separator resolve from
the backend JSON directory; bare command names use PATH. `options` is an argv
array passed verbatim, without a shell. Paths inside arbitrary argv options
are not guessed; give those arguments the native command's intended path base.
Optional `environment` supplies explicit process overrides. Ordinary inherited
environment, including an installed `FERMATPATH` when needed, remains available.

### Default reduction engine: FireFly

Automatic `REDUCE_IBP` jobs default to FireFly. The generated job enables
`run_initiate: true` and `run_firefly: true`, followed by `kira2math` export.
Set `reduction_engine: "firefly"` explicitly when recording the chosen engine;
omitting it has the same behavior. A compatible Kira build with FireFly support
is required. There is no automatic fallback to symbolic Fermat reduction after
a FireFly failure.

Use `reduction_engine: "fermat"` only when that symbolic route is explicitly
selected. It enables `run_triangular: true` and `run_back_substitution: true`
instead of `run_firefly`. Unknown automatic reduction engines are rejected.
Caller-supplied `jobs` retain their own engine settings and are copied unchanged;
their reduction job should enable `run_firefly` for the default FireFly route.
`DISCOVER` remains master initiation with `run_initiate: masters`; it does not
perform either full reduction route.

`--parallel=N` controls parallel Fermat instances or FireFly black-box
evaluators. Choose `N` from the assigned IBP resource budget; it is not the
operating-system thread count of the Kira process. Keep completed native
reconstruction, exported exact rules, import/coverage checks and UT acceptance
as separate stages.

Automatic jobs require explicit nonnegative `seed.r` and `seed.s`, with optional
`seed.d`. Derive their necessary coverage bounds from the union of requested
targets and preferred masters. For indices `a`, use `r = sum(max(a_i, 0))`,
`s = sum(max(-a_i, 0))` and `d = sum(max(a_i - 1, 0))`, then take each maximum
over that union. Candidate derivatives can require more dots or numerator powers
than the candidates themselves. The optional `d` bound independently restricts
subsector seeds as well. These bounds establish target coverage; enough IBP
relations to close on the requested master basis may require larger seeds.
When extra native masters appear, compare the seed and existing reduction
evidence before revising the declared source basis.

The three wall-time budgets are independent:

| Backend field | When omitted | Explicit `null` | Positive finite number |
|---|---|---|---|
| `prepare_timeout_seconds` | 120 seconds | No preparation deadline | Input-preparation limit in seconds |
| `timeout_seconds` | No native deadline | No native deadline | Total native limit across this invocation's jobs |
| `import_timeout_seconds` | 120 seconds | No import deadline | Final Wolfram-import limit in seconds |

Zero, negative, nonfinite and nonnumeric values are rejected. To disable all
automatic phase deadlines, set all three fields to `null`. Explicit cancellation
still stops owned child groups; `cancel_grace_seconds` remains the separate
positive cleanup duration. The adapter never expands a seed, retries a failed
reduction or falls back to another backend.

After native reduction finishes but import is incomplete, use a fresh output and a
new backend file with the same family/target/master inputs:

```json
{
  "schema": "canon-neu/kira-backend/v1",
  "import_from": "../previous-output",
  "import_timeout_seconds": 600
}
```

Call the ordinary `REDUCE_IBP` request through `run_step.py` with the complete
component selection. `import_from` resolves relative to this backend file and
must identify the original output that owns the completed native project. This
mode needs no native executable or job/seed settings and never executes Kira.
It checks the prior successful job receipts, saved family/config hashes and
family/basis/point identities. It regenerates only the checked preparation
sidecars and two integral lists, requires the same target/source-basis/point
binding, and reads native masters/rules in place. No native project or cache tree
is copied. Recorded preparation/export hashes are checked when available;
older receipts are supported using their saved sidecars and native integral lists.
The same Interop mathematical checks determine the new result. The original
result is unchanged; the new receipt references it and records inherited native
execution separately from this import's completion and empty native command list.

For an existing native job design, supply `jobs` instead of automatic seeds:

```json
{
  "schema": "canon-neu/kira-backend/v1",
  "executable": "kira",
  "options": ["--parallel=1"],
  "jobs": ["jobs/reduce.yaml", "jobs/export.yaml"],
  "files": [{"path": "custom-selection", "destination": "aux/selection"}],
  "native_masters": "results/bubble/masters.final",
  "native_rules": "results/bubble/kira_targets.m"
}
```

Job source paths and `files[].path` resolve from the backend JSON. Jobs are copied
by basename and invoked in the declared order from the generated project root.
Extra `files[].destination` paths are project-relative. They cannot overwrite
the generated kinematics, `targets`, or `preferred-masters`. Job basenames must
be distinct. Caller jobs must perform the required native reduction and export;
an initiation-only job cannot complete `REDUCE_IBP`.

Native result paths are project-relative. Defaults are
`results/<topology>/masters` for discovery,
`results/<topology>/masters.final` for reduction, and
`results/<topology>/kira_targets.m` for exported rules. Native job options and
paths belong solely to this backend file; no parameterization field selects Kira.

## Neutral family and native project

The family supplies its identities, canonical `integral_head`, native `topology`
label, index order, physical propagator slots and top-level sectors; independent
loop/external momentum names; propagator momentum/mass-squared expression
strings; complete scalar-product rules; declared invariant names and integer
mass dimensions; dimension symbol, variables, regulator and exact point rules.
The producer already applies declared external momentum relations. The adapter
does not assume a four-dimensional vector chart or infer invariant dimensions.
Unqualified scientific names are parsed in the WL ``CANON`DEData` `` context,
matching the common scientific artifact reader and writer. This includes native
coefficient symbols, declared kinematics and the dimension symbol. Explicitly
qualified names retain their declared context.

The adapter writes `config/integralfamilies.yaml` and `config/kinematics.yaml`
inside fresh `output/kira/`. Native identifiers must be simple Kira-compatible
names. Expressions are quoted YAML strings. Numeric points normally have no
remaining invariants. The point binding is retained in the run receipt and a
`reduction_kinematics` WL artifact. All saved artifact references are relative;
resolved command/executable metadata describes the execution environment.

## Master discovery

An automatic `DISCOVER` job uses the supplied seed and
`run_initiate: masters`. It returns `PASS/SECTORS_READY` only after a successful
native exit, nonempty valid native master output, and common sector formatting.
Artifacts are the standard `master_basis`, `sector_manifest`, and point
kinematics. `master_basis.topology` is the canonical integral head (for example
`B`); the native label (for example `bubble` or `bubble_family`) remains explicit
in the neutral family and run receipt. Native topology underscores are handled
as names, not Wolfram pattern syntax.

This is master initiation within the declared native setup. It is not a completed
reduction/export, global basis proof, UT result or DE.
Nonzero subsectors need not each have a distinct resident master; symmetry or
IBP rules can close them on the reported basis. Keep the declared physical slots
and top sectors when probing a specific closure question. Making auxiliary
indices positive changes the integral scope.

## IBP reduction

`REDUCE_IBP` additionally takes `payload.reduction_targets`, a WL Association:

```wl
<|"schema" -> "canon-neu/reduction-targets/v1",
  "family_ref" -> "one-loop-bubble", "basis_ref" -> "bubble-source",
  "targets" -> {B[2,1], B[1,2]}, "masters" -> {B[1,1]}, "point" -> {}|>
```

Optional `payload.master_basis` is the standard WL artifact and must match the
declared identities and source order. Without it, the ordered `masters` in the
target artifact is authoritative. Legacy `canon-neu/point-targets/v1` inputs are
also explicitly accepted; their master/head/point data undergo the same checks.
For a numeric family point, targets must carry that exact binding. Symbolic
families use an absent or empty point. Integral heads must match the family's
explicit `integral_head`; native export maps that head to the declared
`topology`, without guessing aliases.

The complete target union, including preferred source masters, is written to
`targets`; source order is written to `preferred-masters`. Automatic jobs use
that list for mandatory selection, request initiation, FireFly reconstruction
(or the explicitly selected symbolic Fermat route), and `kira2math` export.
The import reads native masters and
Wolfram-format rules, maps the declared native head back, and checks:

- native masters belong to the requested set; an export may omit source masters
  unused by the target list, while the full requested source order is retained;
- all requested targets reduce to the reported native masters, and every
  requested source master remains an identity;
- every result is linear in that basis and uses only declared coefficient symbols.

Nonpassing output checks return `FAIL/IBP_CHECK_FAILED`. `summary.reason_code`
and the diagnostic details identify a missing export, native master mismatch,
unreduced target or invalid expression. For a different native basis, provide an
explicit conversion before advancing; the adapter does not relabel another
basis. A nonpassing check publishes no normalized reduction. On success,
`PASS/IBP_REDUCED` exposes standard
`ibp_reduction` containing only `masters` and `rules`, plus
`reduction_kinematics` and the run receipt. Preserve the dimension symbol until
the downstream DE builder applies its regulator rule.
The summary reports the full requested `masters` count and `native_master_count`
separately; an unused-master omission does not change the outgoing source basis.

## Failures and cancellation

The adapter owns a separate native process group. TERM/INT are forwarded and
recorded; an interrupted child that exits zero still cannot complete a phase.
After the configured grace interval, remaining group members are killed while
the parent still owns the group leader PID. Timeouts, nonzero exits, missing
exports, identity/basis/coverage failures retain logs and never report completion.
An interrupted outer Wolfram import also remains incomplete. An uncatchable
adapter crash does not imply a completed reduction.

For `REDUCE_IBP`, failures have two categories: execution errors use `ERROR`
(including timeout and interruption), while a normally returned native result
that does not pass checking uses `FAIL/IBP_CHECK_FAILED`. Specific execution
codes and output-check reasons remain available for diagnosis. Neither category
is method exhaustion or a proof about the existence of a reduction. `DISCOVER`
retains its separate initiation contract.

`backend-run.json` records exact selected commands, executable hash, separate
neutral/config references, point binding, effective phase budgets (including
`null` for no deadline), logs and phase-completion flags. The
tests distinguish a fake executable writing real native-format fixture files
from an actual installed Kira run; merely having external source directories is
not native execution evidence.

## Bounded tests

```sh
python3 /path/to/kira/tests/run.py --canon /path/to/CANON --work /path/to/fresh-test-run
python3 /path/to/kira/tests/run.py --canon /path/to/CANON --work /path/to/fresh-native-run --native-kira /path/to/installed/kira3
```

Tests use one Wolfram kernel/reducer at a time. The optional native case is a
small symbolic one-loop bubble under a 90-second native deadline, never a
physical multiloop campaign. Existing accepted results and other backend suites
are not replayed. Supplying `--native-kira` runs only that native smoke, without
repeating the fixture suite.

The files in `examples/` are a small neutral scalar-product bubble input with
an explicitly supplied source master and targets. Copy them into a writable
run directory, set `backend.json` to the intended installed executable/options,
and call its `discover.json` or `reduce.json` through this manifest. Production
inputs normally come from the independently selected parameterization producer.
