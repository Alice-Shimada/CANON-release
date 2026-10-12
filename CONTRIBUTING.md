# Contributing

Use the repository's [issue tracker](https://github.com/Alice-Shimada/CANON/issues)
for bugs and usage questions, and pull requests for proposed changes.

For a bug report, include the CANON revision, the relevant input or a small
reproducer, the command or agent action, and the expected and observed behavior.
Include the Wolfram and external-tool versions when they affect the issue. Remove
private data and personal installation paths before sharing files.

Keep changes focused on the reported problem. Preserve the stated mathematical
conventions and input/output contracts; explain a necessary contract change in
the same contribution. For scientific changes, state the input and method range
covered by the result. A candidate, a sampled check, and an accepted full-system
check provide different evidence.

Keep public entry files short and split internal work into named routines by
responsibility. Check external input at the callable boundary; internal routines
should use that checked shape. Remove a repeated guard only when the same call's
earlier checks and construction imply it. Preserve independent mathematical
checks such as exact gauge identities and flatness. Prefer a reusable component
interface over a scientific glue script specific to one research run.

Run the existing tests relevant to the changed part and report the result. Add a
small regression case when it captures a scientific or behavioral error. State
which checks were not run and which dependencies they require. Documentation-only
edits need a review of their paths, examples, and interface descriptions; they do
not require scientific reruns. Republishing unchanged historical examples does
not require regenerating IBP reductions or differential equations.

For state-management implementation changes, run its tests from
`state-management/`:

```sh
python3 -m unittest discover -s tests -p 'test_*.py' -v
```

For a scientific implementation change, select the corresponding existing
`tests/Run*UnitTests.wls` entry. For example, from the checkout root:

```sh
wolframscript -file tests/RunFullSystemUnitTests.wls
```

Live Kira/provider tests are separate scripts with explicit installation and
output arguments. Run them only when the change needs that evidence; the
[installation guide](docs/installation.md) lists their dependency configuration.

For algebraic tail epsilon normalization, run
`wolframscript -file tests/RunDLogNormalizationUnitTests.wls` and
`python3 -m unittest discover -s tests -p test_algebraic_dlog_tail.py -v` with a
declared `CANON_WOLFRAM_KERNEL`. These cover exact sparse residue equations and
the unchanged public sector workflow through `FINAL_CHECK`, using synthetic
connections with independent known gauges. Also run the shared dlog regressions
in `tests/RunDLogRegularSampleUnitTests.wls` and the existing full-sector tail tests.

For component selection and command interfaces, run
`python3 -m unittest discover -s tests -p 'test_components.py' -v` and
`PYTHONPATH=. python3 -m unittest discover -s tests -p 'test_prepare_request.py' -v`.
The existing
`tests/RunKiraIBPUnitTests.wls` covers the reducer interface;
`tests/RunEndToEndWorkflowLiveTest.wls` exercises the default component chain.
See [component contracts](docs/components.md) before adding a component package.

Keep runtime state, logs, native build products, machine-local launchers, and
personal configuration out of contributions. For a deliberate example addition,
include the selected result files and a short description of their source and
scope. Retain the provenance and licenses of external sources recorded in
[external/sources.json](external/sources.json).

Agent contributors follow [AGENTS.md](AGENTS.md). Its persistent-research rules
apply when conducting research; ordinary documentation and distribution edits do
not require creating research tasks.
