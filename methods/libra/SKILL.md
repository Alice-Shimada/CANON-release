---
name: canon-libra-core
description: Propose a rational core using the single-variable Libra route or an explicit finite multivariable direction sequence with shared regulator factorization.
---

# Libra rational-DE core candidates

## Routing contract

Libra is a transformation provider for `SEARCH_CORE`, selected through
[core selection](../../skills/canon-search-core/SKILL.md). It reads the ordered
current-sector cut and proposes a rational gauge without changing the lower
basis. Its `core_candidates` go directly to `CHECK_CORE`.

## Inputs, invocation, and dependent rows

From `project_root`, run:

```text
python3 run_step.py INPUT.json OUTPUT_DIR --method libra
```

Carry the task's ordered `--components` selection. Use the standard `SEARCH_CORE`
envelope with matching `sector_basis` and `sector_cut_de`, an available Wolfram
kernel, and the caller's Libra installation. Set `payload.method_options.package_entry`
to the package entry, relative to the input JSON if needed, or let
`FindFile["Libra`"]` resolve it on Wolfram `$Path`. CANON does not install Libra
or read hep-tools machine state. Provenance records the resolved entry, SHA-256,
resolution source, reported Libra version and Wolfram `$Version`/`$SystemID`.

**Normal single-variable call:** no method-specific options are needed when Libra
is on `$Path`. The provider runs `Fuchsify` and one automatic `FactorOut`, using
exact reference `1/2` and all-ones free parameters. `normalization_strategy` is
`none` and `dependent_row_strategy` is `automatic` by default. No hierarchy
artifact is required. Select `sector-de-closure` only with a justified explicit
hierarchy; its [input and mask budget contract](references/advanced-controls.md#explicit-dependent-row-hierarchy)
applies to that option.

## Trigger and scope

The default route accepts one kinematic variable and an exact rational square
cut small enough for headless `Fuchsify` and `FactorOut`. Multivariable input
requires an explicit [direction sequence](#explicit-multivariable-direction-sequence);
omitting it returns `INCONCLUSIVE/OUT_OF_SCOPE` before loading the package.

The runner uses ``Libra`$LibraUseFermat = False``. Fermatica,
`BirkhoffGrothendieck`, interactive visual operations, algebraic roots and physical
boundary conditions are outside this card's scope. `EFormQ` checks epsilon
factorization; dlog alphabet membership belongs to the independent canonical
checks.

## Result and next action

Read `result.json`; the provider never returns a scientific `PASS` or `FAIL`.

| Result | Next action |
|---|---|
| `PROVISIONAL/CANDIDATE_TRANSFORMATION` | Pass `core_candidates` to `CHECK_CORE`, then follow the main workflow for the remaining scope. |
| `INCONCLUSIVE/METHOD_EXHAUSTED` | Read the stopped stage and evidence. Change the bounded hypothesis when warranted; exhaustion does not establish nonexistence of a canonical basis. |
| `INCONCLUSIVE/OUT_OF_SCOPE` | Select a supported construction or report the scoped capability gap. |
| `ERROR/INVALID_OPTIONS` or `ERROR/INVALID_DIFFERENTIAL_SYSTEM` | Repair the named option, identity, shape or nonflat input before retrying. |

The candidate retains the exact cumulative transformation, complete transformed
matrix list and provider `EFormQ`. CHECK_CORE independently verifies the candidate;
there is no literal package-version equality gate. Optional-control evidence
records the actual strategy, input hashes, bounds and attempts. No stopped route
silently switches provider or rewrites the lower basis.

## Capability and cost hierarchy

The ordinary call above is sufficient within its scope. Use optional controls
only for the corresponding hypothesis or recorded failure; they add no workflow
steps and have no mandatory order.

| Need | Existing control |
|---|---|
| Supported integer residue offsets in one variable | [Bounded normalization](#explicit-bounded-normalization-within-search_core) before the same core stages |
| A finite multivariable Fuchsification proposal, or joint factorization of an already Fuchsian connection | [Explicit direction sequence](#explicit-multivariable-direction-sequence) |
| Singular reference specialization or failed all-ones factor selection | [Exact reference and finite parameter policy](#exact-reference-and-free-parameter-choices) |

Coefficient extraction and elimination can dominate; use retained costs and the
chosen hypothesis rather than dimension alone to select a bounded attempt.

## Exact reference and free-parameter choices

Defaults are exact `reference_regulator=1/2` and `free_parameter_strategy="ones"`.
A singular reference concerns that frame, not the generic symbolic system.
Exact reference changes and bounded free-parameter choices follow the
[option and evidence contract](references/advanced-controls.md#exact-reference-and-finite-parameter-policy).
They share the selected attempt's bounds; there is no automatic retry.

## Explicit multivariable direction sequence

For a rational cut with `variables={x,y}`, a finite proposal can use these
`payload.method_options`, alongside `package_entry` when needed:

```json
{"direction_sequence": [1, 2], "factorization_max_equations": 4096,
 "max_wall_seconds": 60}
```

Indexes are one-based positions in the ordered variables; this option requires
at least two distinct kinematic variables and a separate regulator. Subsets,
repeated directions and `[]` are allowed. An empty sequence requests shared
factorization alone for an already Fuchsian connection. The provider neither adds
directions nor retries a different order.

Every transformation updates all directions. The endpoint must be Fuchsian,
including infinity, and admit one exact shared epsilon factorization. The
[construction, limits and diagnostics](references/multivariable.md) describe
that finite proposal. A stopped diagnostic is not an accepted core or a resume
interface; timeout evidence follows the workflow's operational recovery.

## Explicit bounded normalization within SEARCH_CORE

Select `normalization_strategy="bounded"` for a supported one-variable
integer-residue-offset hypothesis. The
[normalization contract](references/advanced-controls.md#bounded-single-variable-normalization)
defines its exact domain, budgets, public balance operations and evidence.
Multivariable normalization remains outside scope. This option returns the
same provisional core for independent CHECK_CORE.
