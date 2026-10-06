# Explicit native export adapters

This shared adapter package is an explicit dependency of the sibling `blade`,
`fire7` and `neatibp` component packages. Install/move it beside those packages.
Their manifests invoke its command directly with their adapter identity and
original package directory. It imports declared native master/rule/DE files;
software-specific native setup stays in the selected backend config and driver.
No parameterization package is imported. The other explicit dependency is CANON's
`MethodCardCore.wl`, including `FormatMasterArtifacts`, `GaugeTransform` and
`SectorDEArtifacts`. Keep the adjacent `lib/` directory with `NativeAdapter.wl`;
the public `CanonNativeAdapter` context and its `NormalizeStep`/`DriverInputs`
entry points are unchanged.

Select any of the three operations independently through `run_step.py` and the
desired component manifest, or compose `from`/`step` references. Each request
uses the ordinary script-input envelope and a `payload.backend` descriptor for a
JSON config file. Paths in that config resolve from the config, while scientific
payload descriptors resolve from the request. No adapter consumes the legacy
seven-field Kira reduction request.

## Backend config

```json
{
  "schema":"canon-neu/native-backend/v1",
  "adapter":"blade",
  "encoding":{"head":"Blade`BL", "layout":"family-list", "family":"box"},
  "masters_format":"integrals",
  "binding":{
    "family_ref":"my-family", "basis_ref":"my-source-basis",
    "index_order":["D1","D2"],
    "coefficient_domain":"exact-rational-functions", "point":[]
  },
  "operations":{
    "DISCOVER":{"mode":"import", "source_format":"native-masters",
      "exports":{"masters":"saved/masters.wl"}},
    "REDUCE_IBP":{"mode":"import", "source_format":"blade-rules",
      "exports":{"masters":"saved/masters.wl", "rules":"saved/rules.wl"}},
    "BUILD_CUT_DE":{"mode":"import", "source_format":"blade-de-triple",
      "exports":{"de":"saved/de.wl"}}
  }
}
```

`encoding.head` is an explicit WL symbol name. `family-list` means
`head[family,{a1,...}]`; `indices` means `head[a1,...]`. The optional `family`
value is an exact WL expression string or JSON integer. No topology/head aliases
are guessed. The scientific head comes from the neutral family's `integral_head`.
For FIRE's master files, use `masters_format:"family-index-pairs"` to read
`{{problem,{indices}},...}`; rules still use their declared integral head.

WL files are trusted evaluated inputs. They are read in the Global context with
System on the context path; use explicitly qualified heads in the file and config
when needed. The supplied Blade driver writes qualified `Blade` symbols.

For execution, set an operation's mode to `command` and provide exactly one of
`argv` (one command) or `commands` (a nonempty ordered list of argv lists):

```json
{"mode":"command",
 "argv":["{wolframscript}","-file","{package}/native.wls","{context}"],
 "source_format":"blade-rules",
 "exports":{"masters":"masters.wl","rules":"rules.wl"}}
```

The equivalent one-command list is `"commands":[[...]]`. For separate native
input, solve and export programs, put each argv list in its execution order.
Both forms bind once to one internal list. The runner waits for each command;
a nonzero exit or launch failure stops later commands and export normalization.
There is no branching, retry or scheduler. Arguments remain literal argv data,
never shell text. Available tokens are `{python}`,
`{wolframscript}`, `{package}`, `{backend_dir}`, `{context}`, `{input}` and
`{output}`. Relative executable paths resolve from the backend config; use
`{backend_dir}` explicitly for file arguments. Every command runs in `OUTPUT/native`;
command export paths resolve there and must remain inside it. Import export
paths resolve from the backend config. A successful launch alone is insufficient:
all requested exports must exist and pass normalization. Unsupported operations
require an explicit exporter; there is no fallback, retry, project copy or solver
installation. Output directories must be fresh.

`normalization-run.json` records the bound `commands` and `command_results`
(index, argv and exit_code) after each attempt, including failed sequences.
A command that could not start has `exit_code:null` and an error. The legacy
`argv` field is retained for a single command and is empty for a sequence;
`driver_executed` means at least one command ran. `native-driver.log` records
command boundaries and combined output. Arbitrary successful commands do not
establish the native engine or a new reduction. `new_reduction_executed` is true
only when explicitly claimed by the configured driver's receipt, still without
an independent reduction proof.

Each command may use the same `canon-neu/native-call/v1` JSON containing the request and
backend paths, selected adapter, CANON/common-package paths, native output
directory, step and executable. WL drivers can load the explicitly named common
dependency and call ``CanonNativeAdapter`DriverInputs[contextFile]`` for bound
family data and encoded targets/source masters. A driver may write
`driver-receipt.json` with `new_reduction_executed`; normalization preserves this
execution claim separately from its own checks. Merely running an export driver
does not establish that a native solver ran.

## Data-only operation examples

The files below are operation objects: insert one under `operations.REDUCE_IBP`
in a backend with the existing scientific binding and integral encoding.

- [FIRE preparation, solve and export](examples/fire7-sequence-operation.json)
  composes this package's existing `fire7/prepare.wls`, an installed FIRE7 binary
  and `tables2rules`. Replace the two `installed/FIRE7/bin` paths with the caller's
  installation. Supply `reduction.config` beside the backend; FIRE's `-c` value
  omits `.config`. Configure its start file, variable order and resource counts
  explicitly, with `targets.m`, `preferred.m` and `reduction.tables` resolved in
  this invocation's native directory. The final master list is the requested
  `preferred.m` written by preparation. Normalization requires every rule to
  close on it; this example neither discovers a new basis nor proves that FIRE
  obeyed the preferred list. The native invocation and conversion syntax follow
  the primary [FIRE7 manual, sections 4.2 and 5.1](https://arxiv.org/html/2510.07150v1).
- [NeatIBP saved-result export](examples/neatibp-export-operation.json) uses the
  existing `neatibp/export.py`. Configure `solved_output`, `software_revision`
  and `solver:{"kind":"Kira","completed":true}` in the backend. This single
  command reads the completed solver files and records that no new reduction
  ran. It can be the last command after caller-declared synchronous native
  programs; their arguments, installation, output location and resource budget
  belong to that backend.

These examples add no glue program and have not executed a native campaign.
All exports are still checked against the declared family, point and source basis.

## Scientific inputs and checks

Supply `reducer_family` (`canon-neu/reducer-family/v1` JSON) or a WL
`prepared_family` carrying the same identity, index/head, variable, dimension and
regulator metadata. Native driver templates require the neutral JSON geometry;
the prepared-family alternative supports importing saved exports. `binding`
must match `family_ref`, `basis_ref` and `index_order` exactly. Only reconstructed
exact rational-function coefficients in declared variables/parameters are
accepted. Finite-field or approximate exports are rejected. Indexed variables
are treated as declared coefficient atoms.

`DISCOVER` imports native masters and calls the shared standard formatter. It
returns `master_basis` and `sector_manifest`, ordered by ascending sector rank
with native source order retained within a sector. `SECTORS_READY` identifies
the imported master catalogue; it does not independently establish IBP rank.

`REDUCE_IBP` requires neutral `reduction_targets` and ordered source masters,
usually also supplied as `master_basis`. The targets artifact has schema
`canon-neu/reduction-targets/v1`, `family_ref`, `basis_ref`, `targets`, `masters`,
and optional exact `point`. A legacy `point-targets/v1` is accepted only with an
explicit matching master_basis. Backend `binding.point` is a JSON list of
`{variable,value}` WL-expression strings and must match the target point exactly.
When `reducer_family` JSON is supplied, its actual `point` is decoded the same
way and must also match exactly, including empty symbolic scope. Saved-output
imports through `prepared_family` retain their explicit backend/target point
scope; an undeclared neutral point cannot be treated as symbolic geometry.
Native rules must already be solved, linear, and closed on the declared native
masters. Missing targets, unknown integral heads/families, extra unresolved
masters, contradictory native-master rules, nonlinear terms and unlisted coefficient variables are rejected. The
standard output is exactly the ordered `masters` and fully reduced `rules` for
the requested target list. Existing source masters reduce by identity.

Different native master order is handled by permutation, without changing the
requested output order. A genuinely different basis requires a `basis_conversion`
WL descriptor with schema `canon-neu/master-basis-conversion/v1`, matching
family_ref/basis_ref, exact `native_masters` and `masters` in their respective
orders, `matrix`, and convention `native_masters = matrix . masters`.
The matrix must be square, invertible, and rational in declared parameters.
This is a supplied mathematical input, not an IBP relation proved by the adapter.

`BUILD_CUT_DE` requires `master_basis`, `sector_manifest`, the requested sector,
and a full symbolic DE export. `blade-de-triple` is the native
`{masters,variables,matrices}` result. `exact-de-association` contains those fields,
`coefficient_domain:"exact-rational-functions"`, empty `point`, and convention
`D[basis, variables[[i]]] = matrices[[i]] . basis`. All matrices and variable
directions must exist. Both row/column order and variable order are restored.
For an explicit conversion C, the adapter applies
`Inverse[C].(A.C-D[C,x])`, then retains the complete ordered DE and the requested
sector cut. Dimension substitution uses the neutral family's `dimension_rule`.
Point-only DEs cannot be promoted to this symbolic artifact. Outputs retain all
proper-subsector metadata and do not claim flatness, a gauge proof against an
original DE, UT, canonical form or `ALL_PASS`.

## Routing

- `SECTORS_READY`: pass the imported source order to the selected next component.
- `IBP_REDUCED`: use its normalized rules for the declared targets; import mode
  does not represent a newly executed reduction.
- `OK` from direct DE import: use the full/cut artifacts in their exact stated
  scope, then run the existing scientific checkers required by the next step.
- Missing/unresolved targets: extend the actual solver/export coverage.
- Native basis mismatch: supply a valid conversion or regenerate in the requested
  basis. Do not change basis labels to hide the mismatch.
- Equations-only, finite-field, point-only or incomplete DE data: complete the
  missing solve/reconstruction/derivation upstream before normalizing again.
- Native driver failure: inspect its log and supplied installation/configuration.
  No other software is selected automatically.

## Runnable synthetic example and tests

```sh
wolframscript -file components/reducers/native-adapter/examples/make-example.wls /path/to/example
python3 run_step.py /path/to/example/neatibp-DISCOVER.json /path/to/example/discovered --components components/reducers/neatibp/components.json
python3 run_step.py /path/to/example/fire7-REDUCE_IBP.json /path/to/example/reduced --components components/reducers/fire7/components.json
python3 run_step.py /path/to/example/blade-BUILD_CUT_DE.json /path/to/example/de --components components/reducers/blade/components.json
```

Append `alternate` to the generator command for a second rational coordinate
chart. These files are synthetic native-format fixtures, not native program
results or physical reductions. The same scientific family is independent of
adapter selection. The bounded tests invoke scientific steps through `run_step`:

```sh
python3 components/reducers/native-adapter/tests/test_adapters.py --canon . --work /path/to/fresh-work
```

The focused sequence checks run with:

```sh
python3 components/reducers/native-adapter/tests/test_sequences.py --canon . --work /path/to/fresh-sequence-work
```

The shared WL implementation is grouped into input/encoding helpers (`Inputs.wl`),
exact coefficient and basis maps (`Basis.wl`), three import operations
(`Discovery.wl`, `Reduction.wl`, `DifferentialEquations.wl`) and common receipt
publication (`Normalization.wl`). Reduction output is built from already checked
linear coefficients and an exact rational map, so it needs no second linearity
scan. The final DE domain check remains necessary for supplied dimension rules
and differentiation expressions. Sector artifacts use the shared CANON slicer.

Tests use at most one Wolfram kernel and one configured driver at a time. Native
end-to-end validation is reported separately; source/API inspection and converter
fixtures do not establish that a user's native dependencies are installed.
