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
| `PROVISIONAL/CANDIDATE_TRANSFORMATION` | Run `CHECK_CORE` on the returned `core_candidates`. After CORE_PASS, follow BUILD_FULL_DE → SOLVE_TAIL → CHECK_CANONICAL and FINAL_CHECK for the completed scope. |
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

Use retained stage costs; dimension alone is not a cost threshold and needs no
trial solely to estimate it. Coefficient extraction and elimination can dominate.
A capability gap or measured bottleneck belongs to separately scoped development;
keep `GaussSolve` unless replacement evidence justifies a change. Record changed
hypotheses and allocations in the existing decision note, following the workflow's
[result and budget rules](../../skills/canon-workflow/SKILL.md#5-result-routing).

## Exact reference and free-parameter choices

Defaults are exact `reference_regulator=1/2` and `free_parameter_strategy="ones"`.
A `REFERENCE_EPSILON_SINGULAR` limit concerns the selected reference, not the
generic symbolic system. The caller may select another exact reference; there
is no automatic retry. JSON `0.5` is invalid: use an integer or an integer
numerator/denominator object.

A failed all-ones factor can motivate an explicit `bounded-rational-search`
proposal: ones, zeros, then unit points deterministically. `free_parameter_max_trials`
defaults to 64 and may be supplied only with that policy. Every accepted factor
must be exact rational and generically invertible; the route's symbolic identities
and independent CHECK_CORE still apply. Read the
[option, validation and evidence contract](references/advanced-controls.md#exact-reference-and-finite-parameter-policy)
when changing these controls. Neither control enlarges time or coefficient domains.

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

Each requested `Fuchsify` transformation updates all directions. At the endpoint,
every direction, including infinity, must be Fuchsian and epsilon factorized.
Shared factorization uses exact coefficient equations in all declared variables
and one `GaussSolve`; the factor must be kinematically constant, exact rational,
generically invertible and satisfy the original equations and every directional
identity. See [the multivariable construction](references/multivariable.md) for
the equation space and package context.

| Option | Default | Scope |
|---|---:|---|
| `factorization_max_equations` | 4096 | Positive integer cap on raw nonzero monomial coefficients before deduplication; exceeding it stops before solving. |
| `max_wall_seconds` | 60 | Finite positive time limit shared by the whole multivariable proposal. |

These two controls require `direction_sequence`. Equations are never truncated.
Numeric-content deduplication reduces solve work but leaves the raw budget and
coefficient-extraction cost unchanged. The summary reports raw
`factorization_equation_count` and post-deduplication
`factorization_solver_equation_count` (`null` until extraction and deduplication
finish). No sampling or regulator-zero specialization replaces the symbolic solve;
the selected exact reference must be defined.

A stopped attempt retains `libra_diagnostic`: the last cumulative transformation,
connection and local-step trace. The summary records stage, limits and counts.
`TIME_BUDGET` with `timed_out=true` routes to operational recovery; it certifies
an unfinished attempt. The diagnostic is evidence, not an accepted core or resume
interface. This route requires no UT seeds, declared alphabet or full kinematic
transformation ansatz, and changes no lower-sector basis.

## Explicit bounded normalization within SEARCH_CORE

Select `normalization_strategy="bounded"` only for a supported one-variable
integer-residue-offset hypothesis. It uses public `GetSubspaces`, `Projector`
and `Balance` before the same Fuchsify/FactorOut stages. Its domain requires
exact rational coefficients, epsilon-independent linear poles, a defined Fuchsian
connection at epsilon zero and provably integer residue intercepts. Multivariable
bounded normalization returns `INCONCLUSIVE/OUT_OF_SCOPE`.

Read the [bounded normalization contract](references/advanced-controls.md#bounded-single-variable-normalization)
when selecting it: that section defines the four finite budgets, subspace search,
exact gauge checks, pole-rank and progress conditions, endpoint conventions and
retained evidence. This remains an option of SEARCH_CORE with provisional output
and the same independent CHECK_CORE gate.
