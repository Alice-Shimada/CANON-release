# Installation

CANON separates scientific calculations from the agent host. You can read saved
results with Wolfram Language alone. To conduct a new multi-step study, also
configure an agent host that can call the local `statemng` MCP server and run the
scientific tools selected for that study.

## Scientific dependencies

Install the components needed for your route; the whole external tool collection
is not required for every task.

| Route | Components |
| --- | --- |
| Read saved basis and DE files | Mathematica or another licensed Wolfram Language kernel; see [Reading results](results.md) |
| Run CANON scientific scripts | A Wolfram installation providing `wolframscript` |
| Transform a supplied rational DE, or solve its off-diagonal tail | Wolfram Language and [CANONICA](../external/CANONICA/README), entry `external/CANONICA/src/CANONICA.m` |
| Use the single-variable Libra methods | Wolfram Language and [Libra](../external/Libra/Readme.md), entry `external/Libra/Source/Libra.m`; the current CANON providers use its Wolfram backend |
| Produce IBP reductions | An installed [Kira](../external/Kira/README.rst) executable and its selected backend dependencies; configure Fermat when required by that installation |
| Generate integral candidates | [DlogBasis-refine](../external/DlogBasis-refine/README.md), entry `external/DlogBasis-refine/DlogBasis.wl`, and a working [FiniteFlow](../external/FiniteFlow/README.md) Wolfram interface and native library; install [Singular](../external/Singular/README.md) when selecting its backend |
| Use Fermat-assisted exact algebra | [Fermatica](../external/Fermatica/README.md) and an installed [Fermat](../external/Fermat/README.md); provide `FERMATPATH` |
| Use the fixed INITIAL reference method | [INITIAL](../external/INITIAL/README.md), FiniteFlow, and the explicit reference/configuration files described in [external dependencies](../external/README.md) |

The directories in `external/` contain source snapshots for user installation,
including their licenses and upstream instructions. They are not prebuilt
installations. Build native components against the local Wolfram installation;
install their compiler and library dependencies using the corresponding upstream
instructions. Fermat source is not bundled; its acquisition instructions are
linked above.

Source revisions are recorded in [external/sources.json](../external/sources.json).
The Kira snapshot identifies itself as 3.1; Singular is pinned to
`Release-4-2-1p2`. These are bundled revisions, not an asserted compatibility range.
CANON does not yet publish a tested minimum Wolfram version or a complete version
matrix for all providers. Use the selected package's requirements and retain the
actual version in your run record. A dependency's version must come from that
dependency or an explicit declaration, not from CANON's outer Git revision.

## Paths and resources

The caller supplies installation paths and resource budgets in the existing
request fields. No personal installation directory is prescribed.

| Setting | Purpose |
| --- | --- |
| `PATH` | Installed commands such as `wolframscript`, `WolframKernel`, `kira`, and `Singular` |
| Wolfram `$Path`, `$LibraryPath` | Package lookup and native-library lookup, respectively |
| `method_options.package_entry` | Entry file for the selected method |
| `method_options.finite_flow_package_file` | FiniteFlow's Wolfram entry file |
| `method_options.singular_executable` | Singular command or executable path |
| Kira request `executable`, `options` | Reducer and resource options, for example `--parallel=1` |
| `FERMATPATH` | Installed Fermat executable |
| `CANON_WOLFRAM_KERNEL` | Kernel used by the Python scientific tests, otherwise found on `PATH` |

Relative paths inside a JSON request are resolved from that JSON file's directory.
Resources declared in a family specification are resolved from the specification's
directory. JSON strings do not expand environment variables or `~`; resolve those
in the caller before writing the request. Command-line output directories are
relative to the process working directory. See [INTERFACES.md](../INTERFACES.md)
for the complete request schemas.

Moving the source checkout does not rewrite absolute paths in old research
artifacts. Rebind the installation paths for new runs.

## Agent host requirements

The state-management server uses Python 3.10 or newer and only the Python standard
library. The current implementation uses POSIX facilities and supports macOS and
Linux; native Windows integration is not provided.

No particular model family or model provider is required by the scientific scripts
or MCP protocol. An agent host for the complete persistent workflow needs to:

1. Read the repository's [agent rules](../AGENTS.md) and
   [persistent-research skill](../.agents/skills/persistent-scientific-research/SKILL.md).
2. Connect to a local stdio MCP server, read its tool schemas and results, and
   execute local scientific commands with access to the selected inputs.
3. Create native worker agents, wait for them, and restrict their state tools to
   `statemng_task_claim`, `statemng_task_show`, `statemng_artifact_add`,
   `statemng_task_submit`, `statemng_task_block`, and `statemng_task_fail`.
4. Keep acceptance and reopening of blocked work with the main agent, and preserve
   the returned task/run identities and workspace boundaries.

The generic MCP server does not enforce worker roles by itself. The host must
provide that separation. A host that only launches the server has not yet
established the full persistent-workflow contract.

## Generic stdio MCP registration

For a host adapter, register the existing server as a local stdio process. This is
an illustrative registration; replace the paths and translate the enclosing
configuration keys to your host's syntax:

```json
{
  "mcpServers": {
    "statemng": {
      "command": "python3",
      "args": ["/absolute/path/to/CANON/state-management/mcp_server.py"]
    }
  }
}
```

Use an absolute Python executable if the host does not inherit the expected
`PATH`. The server determines the checkout from its own file location and runs
the internal CLI there, so it does not depend on the host's startup directory.
It exchanges newline-delimited JSON-RPC over stdin/stdout. It implements
`initialize`, `ping`, `tools/list`, and `tools/call`, and currently negotiates MCP
versions `2025-11-25`, `2025-06-18`, `2025-03-26`, and `2024-11-05`.

This process registration is for host integration. Users ask the agent to manage
research; they do not run the internal CLI or edit research-state JSON. All state
operations go through MCP. A read-only connection check is an actual
`statemng_project_list` tool call returning `isError: false` and
`structuredContent.ok: true`; an empty `task_names` list is valid.

| Host | Repository status |
| --- | --- |
| Codex | Implemented project configuration, installer, worker role, and runtime guard; follow the separate [Codex setup](hosts/codex.md), including its Local-session constraints |
| Claude Code | [Adapter protocol notes](../state-management/adapters/claude-code/ADAPTER.md) exist; a complete runnable integration and live validation are not supplied |
| Hermes | [Adapter protocol notes](../state-management/adapters/hermes/ADAPTER.md) exist; a complete runnable integration and live validation are not supplied |
| OpenCode and other MCP hosts | The stdio interface is available as an integration entry point; no implemented and validated adapter is claimed |

The generic registration is not a replacement for the Codex launcher. The Codex
launcher enables its host-specific guard and binds the correct checkout. Do not
use the generic process configuration to bypass that adapter's requirements.

The original design documents are available for adapter developers:
[state-management architecture](state-management/跨通用%20Agent%20的持续研究状态管理基础设施设计方案.md)
and [agent integration](state-management/持续研究状态管理的%20Agent%20接入补充方案.md).
