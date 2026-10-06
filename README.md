# CANON

**Agent-assisted construction of canonical differential equations for Feynman integrals.**

CANON combines scientific reasoning with explicit Wolfram Language interfaces:
prepare an integral family, obtain IBP reductions and differential equations,
propose basis transformations, repair lower-sector couplings, and check the
complete result. An agent chooses and revises the approach; the scientific
scripts compute and check the algebra.

The workflow and method cards are independent of the agent host and model.
They do not require a particular GPT model. Persistent research uses the local
`statemng` MCP server and the host's native workers. The repository includes a
working Codex integration; other hosts can use the documented MCP contract, but
their native integrations have not been validated in this release.

## Start here

- [Installation and minimum dependencies](docs/installation.md)
- [Agent workflow and input preparation](docs/agent-workflow.md)
- [Scientific components and custom packages](docs/components.md)
- [Automatic physical derivatives](docs/physical-derivatives.md)
- [Next-action routing for agents](skills/canon-workflow/SKILL.md)
- [Saved examples](examples/README.md)
- [Reading a basis, transformation, DE, and alphabet](docs/results.md)
- [Codex setup](docs/hosts/codex.md), for that host only

After configuring a host, give its main agent a request such as:

```text
Work in this CANON checkout. Read AGENTS.md and skills/canon-workflow/SKILL.md.
Create a research task named triangle-demo using
interfaces/family-spec.example.wl. Use the installed tools and resource
budget I provide. Carry the family through the canonical workflow and
return the basis, transformation, DE, alphabet, and result summary.
Reuse accepted inputs and checker results when continuing the task.
```

The [typed family example](interfaces/family-spec.example.wl) and its
[PREPARE request](interfaces/prepare.example.json) use the supplied one-loop
fixture. The user specifies the scientific problem and resources; the agent
handles internal task commands and scientific files.

For a first look without running a calculation, read a saved result in a fresh
Wolfram session, with the checkout as the working directory:

```wl
basis = Get["examples/one-loop/canonical-basis.wl"];
de = Get["examples/one-loop/canonical-de.wl"];
{basis["basis"], de["alphabet"], de["matrices"]}
```

## Scientific scope

The current default prepared input consists of a family specification, ordered
masters, and derivative operators for each variable. Native reducer projects or
driver settings belong to the selected backend configuration. The agent can
prepare these using available tools and explicit conventions; `PrepareFamily.wls`
itself binds the supplied files. It is not a general compiler from an arbitrary
list of propagators. Physical definitions, known masters/rules, and existing DEs
should be supplied when available; see the [input guide](docs/agent-workflow.md).

Each step is selected through the [component manifest](components/default.json).
An optional package can replace any subset of steps while keeping the published
scientific inputs and outputs. The default scientific route is:

```text
PREPARE → DISCOVER → IBP and ordered DE
  → sector core proposal → CHECK_CORE → full-prefix construction and tail repair
  → CHECK_CANONICAL → COMMIT_SECTOR → next sector → FINAL_CHECK
```

For integral-basis discovery from a family (UT or canonical), choose a small
proposal from the geometry and current evidence: selected dots and normalization,
a justified Gram construction, or a bounded DlogBasis-refine search. Integral
proposals continue through candidate IBP reduction and the same checks.
CANONICA supplies rational DE transformations and Libra the implemented
single-variable route when a direct-DE approach is justified. A supplied-DE-only
task can start there. With explicitly normalized UT seeds, a declared alphabet
and a rational one-variable cut, [INITIAL](methods/initial/SKILL.md) also supplies
a bounded core candidate through `methods/initial/run.wls` with explicit
`SEARCH_CORE`. Its original fixed official ladder flow is retained as
[reference validation and compatibility](examples/initial-official-ladder/README.md).
Optional Libra normalization and CANONICA finite T/D ansatz controls extend the
existing core/tail nodes; subsector tail checkpoints can resume bounded work.
The [routing skill](skills/canon-workflow/SKILL.md) explains when
to change routes and retain useful method experience; an exhaustive numerator/dot search is not required. The
[method cards](methods/README.md) describe their actual scopes.

A successful final check returns a canonical basis and DE in the declared
integral space and dlog alphabet. Current checks include the exact gauge identity,
symbolic flatness, epsilon factorization, and shared constant residue matrices.
The tail solver proposes pole factors and supported quadratic-root letters from
the DE; an input alphabet is optional. Explicit algebraic letters can also be
declared as exact Wolfram expressions. A bounded search
failure means that the selected search did not find a solution.

The implementation does not guarantee a canonical basis for every family,
complete automatic algebraic-letter discovery, master completeness, or physical
boundary constants. A canonical DE alone does not fix all UT normalizations.
The [scientific audit](docs/scientific-audit-20260908.md) gives the detailed scope.

## Examples

| Example | Masters / sectors | Included result |
| --- | --- | --- |
| [One-loop sector 5](examples/one-loop/README.md) | 1 / 1 | Small prepared input and saved canonical output |
| [Massless planar 2l5p pentabox](examples/2l5p/README.md) | 61 / 46 | Complete five-variable basis, DE, and 24 active letters |
| [Unpublished three-loop family](examples/unpublished-40/README.md) | 40 / 28 | Complete two-variable system and residues for `{s,u,1-u}` |

These are existing successful results, packaged with their historical method and
check records. They were not rerun for this release preparation. In particular,
the 2l5p record uses its original flatness scope, and the 40-master example comes
from the earlier resident CANON workflow and keeps its original export schema.

## Interfaces and extension

Science lives in `mma/`, proposals in `methods/`, and step instructions in
`skills/`. [INTERFACES.md](INTERFACES.md) documents the request/result contracts.
The runner selects one component from the request's `step`. A stateless call is:

```sh
python3 run_step.py interfaces/prepare.example.json runs/triangle-prepare
```

Use a fresh output directory. Relative artifact paths are resolved from their
declaring JSON; family-spec resources are resolved from the spec. Supply tool
entries and thread budgets through the documented task parameters or environment.
Use `--components /path/to/package/components.json` for a custom package, and
`--method libra` (for example) when selecting a `SEARCH_CORE` method.

Supported workflows compose these interfaces with mathematical inputs and JSON
settings. `PREPARE_REQUEST` binds producer artifacts into consumer requests;
`PREPARE_REDUCTION_TARGETS` prepares symbolic derivative targets for the chosen
reducer. Native setup, solve and export programs can be listed as ordered argv
commands. See [composition](docs/components.md#binding-requests-without-a-glue-program)
and the [scalar JSON workflow example](interfaces/examples/scalar-workflow/README.md).

`--describe` shows the chosen command and instructions without executing it.
Repeat `--components` to compose packages, or use a manifest's relative `extends`
list. `--defaults` restores the original selection. Packages are reread at each
step invocation and may live outside this checkout. Their optional `workflow`
instructions describe additional routes and scoped completion checks.
The [parameterization package](components/parameterization/README.md) supports
user-defined vector and scalar-product charts, including twistor coordinates,
independently of the selected reducer. A profile can select `DISCOVER`,
`REDUCE_IBP` and `BUILD_CUT_DE` from different providers with per-step `from`
references. See the [mixed profile](components/profiles/mixed-reducers.json) and
the [Kira adapter](components/reducers/kira/README.md); Blade, FIRE7 and NeatIBP
adaptation packages document their own native execution/export requirements.
Optional [point-DE](components/point-de/README.md),
[dlog reconstruction](components/dlog-reconstruction/README.md), and
[local execution/notification](components/local-jobs/README.md) packages can be
selected independently. All original scientific components remain the defaults.

The agent owns planning and acceptance. `statemng` stores research tasks and
artifacts in `.state-management/<task-name>/`; it does not choose scientific
methods. See [AGENTS.md](AGENTS.md) and the
[persistent-research skill](.agents/skills/persistent-scientific-research/SKILL.md).

External source snapshots and their own licenses are in [external/](external/README.md),
with revisions in [sources.json](external/sources.json). Install only the programs
needed by the selected route. Historical architecture notes are under
[docs/history/](docs/history/README.md).

## Citation and development

Authors, in alphabetical order by family name: Dongshan Jian, Yuanche Liu,
Yanqing Ma, Boxuan Shi, Yu Wu, Zihao Wu, and Yang Zhang.

Use [CITATION.cff](CITATION.cff) and identify the version or commit used. Author
identifiers and method references are listed in [CREDITS.md](CREDITS.md).
CANON-owned code and documentation use the [MIT license](LICENSE); external
components retain their own licenses.

See [CONTRIBUTING.md](CONTRIBUTING.md) for reporting problems and proportionate
checks, and [CHANGELOG.md](CHANGELOG.md) for the release draft. The saved examples
are not an automatic test suite.
