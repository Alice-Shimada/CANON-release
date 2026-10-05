# Saved examples

These examples are existing successful calculations selected for distribution.
The release preparation copied their saved results and read their original
reports; it did **not** rerun IBP, DE construction, canonical checks, or benchmarks.

| Example | Size | Format and original evidence |
| --- | --- | --- |
| [One-loop sector 5](one-loop/README.md) | 1 master, 1 sector, 1 variable | Current-format outputs; 2026-09-08 `ALL_PASS` |
| [Massless planar 2l5p](2l5p/README.md) | 61 masters, 46 sectors, 5 variables | Current-format outputs; 2026-09-05 `ALL_PASS`, original exact-point flatness scope |
| [Unpublished three-loop family](unpublished-40/README.md) | 40 masters, 28 sectors, 2 variables | Earlier resident CANON format; `ALL_SECTORS_ACCEPTED` and saved dlog decomposition |

Reading any example requires only Wolfram Language, not Kira, FiniteFlow, an
agent host, or an active research session. Each README gives the physical input,
result convention, and the corresponding reader. The included `source-record.json`
identifies copied files; their original bytes, including historical evidence
metadata, are retained. Old absolute paths in those metadata are not loaded by
the readers and need not exist on the reader's machine.

For a new calculation, use the [agent guide](../docs/agent-workflow.md) and
[installation guide](../docs/installation.md). These saved examples do not run
automatically as tests, and success with a historical workflow does not establish
that the current version reproduces it without further work.

## Reference validation

[INITIAL official ladder](initial-official-ladder/README.md) contains an opt-in
reference provider/checker and their compatibility contract, rather than saved
full-family results. Executing it needs the declared INITIAL/FiniteFlow runtime;
reading it does not execute anything. Ordinary INITIAL core search uses the
[main interface](../methods/initial/SKILL.md).
