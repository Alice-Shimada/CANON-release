# Scalar workflow through named interfaces

These JSON files connect the existing scalar-product bubble example through
`PREPARE_REQUEST`, neutral `PREPARE`, Kira `DISCOVER`,
`PREPARE_REDUCTION_TARGETS`, FIRE `REDUCE_IBP`, and either Blade or the generic
`BUILD_CUT_DE`. `SLICE_CUT_DE` reuses the generic ordered DE. A Neat rule import
uses the same neutral family and targets. The exact expected connection is
`d Q[1,1]/du = -eps/u Q[1,1]`, with `d -> 4 - 2 eps`.

The production request path consists of data and existing named components.
No per-task Wolfram target-generation program is needed. The target component
calls the existing mathematical helper; the request component rebases artifact
descriptors and preserves producer metadata. These files do not define a second
pipeline language or automatically select, retry, or accept a scientific step.

Use a writable copy of the repository layout. Keep this directory at
`interfaces/examples/scalar-workflow`, together with the selected packages and
their common libraries. `templates/` contains normal consumer requests;
`bind/` contains the corresponding `PREPARE_REQUEST` inputs. Producer links
refer to `outputs/<stage>/result.json`; the named binder writes ordinary
requests into `bindings/<stage>/request.json`. Those output directories must be
fresh. Moving the complete tree preserves its relative artifact references.

The family specification, derivatives, and supplied source-master reference
remain the existing files in `components/parameterization/examples/`. The
backends stay separate: the default mixed profile chooses parameterization,
Kira, FIRE and Blade independently. `profiles/generic.json` overrides only
`BUILD_CUT_DE`; `profiles/neat.json` overrides only `REDUCE_IBP`. Append an
override after the complete mixed selection, for both binding and execution.

## Runtime and evidence scope

`fixtures/` contains fixed analytic **test data** encoded in the native export
formats. The FIRE, Blade and Neat configurations import those files and do not
run those engines. The equations file is deliberately unsolved. These exports
are sufficient to test interchange; they are not a recorded native reduction.

Discovery requires `runtime/kira-backend.json`. For an installed Kira run,
copy `backends/kira.example.json` there and supply the actual executable and
resource settings. Its example budget is one thread and 30 seconds. Installed
Python and Wolfram commands come from the caller's environment;
`CANON_WOLFRAMSCRIPT` selects Wolfram when required. External source directories
are not evidence of a working native installation.

The reusable test supplies a tiny, explicitly synthetic discovery executable in
that runtime configuration. It invokes the actual Kira adapter, never Kira:

```sh
python3 tests/test_reducer_interchange.py --canon . --work /path/to/fresh-test-directory
```

The test moves its complete tree into a path with spaces before discovery. It
checks request rebasing, source identities and order, unchanged neutral hashes,
exact full/cut DE agreement, equations-only rejection and rejection of the
failed producer by the binder. Its executable fixture and independent readback
are test scaffolding. They are not part of the production request path. A
separate single `FINAL_CHECK` uses the repository's unchanged tiny two-master
fixture; its `ALL_PASS` scope belongs to that fixture, not to this scalar import
comparison.

For real native work, replace analytic exports with completed native results
or configure the selected adapter's documented `argv`/`commands` data. A new
coordinate/derivative model, unsupported native setup, unsolved Neat equations,
or missing reconstruction still requires the corresponding scientific input
or reusable component capability. This recipe does not infer that capability.

## Explicit invocation sequence

With the runtime backend already supplied, set paths to the writable copy:

```sh
canon_root=/path/to/CANON
recipe_root="$canon_root/interfaces/examples/scalar-workflow"
mixed_profile="$canon_root/components/profiles/mixed-reducers.json"
```

Run each binder, inspect its `PASS/REQUEST_READY`, then execute the returned
request. Inspect each scientific result before advancing; process exit alone
is insufficient.

```sh
python3 "$canon_root/run_step.py" "$recipe_root/bind/prepare.json" "$recipe_root/bindings/prepare" --components "$mixed_profile"
python3 "$canon_root/run_step.py" "$recipe_root/bindings/prepare/request.json" "$recipe_root/outputs/prepare" --components "$mixed_profile"
python3 "$canon_root/run_step.py" "$recipe_root/bind/discover.json" "$recipe_root/bindings/discover" --components "$mixed_profile"
python3 "$canon_root/run_step.py" "$recipe_root/bindings/discover/request.json" "$recipe_root/outputs/discover" --components "$mixed_profile"
python3 "$canon_root/run_step.py" "$recipe_root/bind/targets.json" "$recipe_root/bindings/targets" --components "$mixed_profile"
python3 "$canon_root/run_step.py" "$recipe_root/bindings/targets/request.json" "$recipe_root/outputs/targets" --components "$mixed_profile"
python3 "$canon_root/run_step.py" "$recipe_root/bind/fire.json" "$recipe_root/bindings/fire" --components "$mixed_profile"
python3 "$canon_root/run_step.py" "$recipe_root/bindings/fire/request.json" "$recipe_root/outputs/fire" --components "$mixed_profile"
python3 "$canon_root/run_step.py" "$recipe_root/bind/blade.json" "$recipe_root/bindings/blade" --components "$mixed_profile"
python3 "$canon_root/run_step.py" "$recipe_root/bindings/blade/request.json" "$recipe_root/outputs/blade" --components "$mixed_profile"
python3 "$canon_root/run_step.py" "$recipe_root/bind/generic.json" "$recipe_root/bindings/generic" --components "$mixed_profile" --components "$recipe_root/profiles/generic.json"
python3 "$canon_root/run_step.py" "$recipe_root/bindings/generic/request.json" "$recipe_root/outputs/generic" --components "$mixed_profile" --components "$recipe_root/profiles/generic.json"
python3 "$canon_root/run_step.py" "$recipe_root/bind/slice.json" "$recipe_root/bindings/slice" --components "$mixed_profile" --components "$recipe_root/profiles/generic.json"
python3 "$canon_root/run_step.py" "$recipe_root/bindings/slice/request.json" "$recipe_root/outputs/slice" --components "$mixed_profile" --components "$recipe_root/profiles/generic.json"
python3 "$canon_root/run_step.py" "$recipe_root/bind/neat.json" "$recipe_root/bindings/neat" --components "$mixed_profile" --components "$recipe_root/profiles/neat.json"
python3 "$canon_root/run_step.py" "$recipe_root/bindings/neat/request.json" "$recipe_root/outputs/neat" --components "$mixed_profile" --components "$recipe_root/profiles/neat.json"
```

The negative fixtures have explicit expected outcomes:

```sh
python3 "$canon_root/run_step.py" "$recipe_root/bind/equations.json" "$recipe_root/bindings/equations" --components "$mixed_profile" --components "$recipe_root/profiles/neat.json"
python3 "$canon_root/run_step.py" "$recipe_root/bindings/equations/request.json" "$recipe_root/outputs/equations" --components "$mixed_profile" --components "$recipe_root/profiles/neat.json"
python3 "$canon_root/run_step.py" "$recipe_root/bind/rejected-upstream.json" "$recipe_root/bindings/rejected-upstream" --components "$mixed_profile" --components "$recipe_root/profiles/generic.json"
```

The equations consumer must return `ERROR/UNSOLVED_NATIVE_EXPORT`. The final
binder must return `ERROR/REQUEST_BINDING_FAILED` and write no consumer request.
