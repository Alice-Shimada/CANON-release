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

Keep runtime state, logs, native build products, machine-local launchers, and
personal configuration out of contributions. For a deliberate example addition,
include the selected result files and a short description of their source and
scope. Retain the provenance and licenses of external sources recorded in
[external/sources.json](external/sources.json).

Agent contributors follow [AGENTS.md](AGENTS.md). Its persistent-research rules
apply when conducting research; ordinary documentation and distribution edits do
not require creating research tasks.
