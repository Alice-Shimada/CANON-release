---
name: canon-canonica-core
description: Propose rational current-sector core transformations with CANONICA for a flat rational DE in one or more variables after selecting a direct-DE route.
---

# CANONICA recursive candidate route

## Trigger and scope

Use compatible CANONICA 1.0.3 to propose a rational gauge transformation for the
current sector's cut differential system. CANON does not install or register
CANONICA and does not assume a particular tool workspace layout.

This card supports rational DE matrices in one or more kinematic variables,
with an explicit, fixed basis order, a flat connection, and sector boundaries
supplied by the artifact or inferred by CANONICA. Algebraic transformations,
elliptic systems, large ansatz tuning, and physical boundary conditions are
outside its scope. Before this card, apply the direct-DE permission rules in
[core selection](../../skills/canon-search-core/SKILL.md). Select this route from
the user's method request, a supplied DE with unavailable physical family, or
a recorded bounded integral-route limitation. Defined-family proposal and
candidate derivative preparation follow the input stages in that skill.

A rational DE need not admit a rational gauge transformation. For example,
`A = (1/(2 x) + eps/x) dx` requires `old = Sqrt[x] new` to obtain
`B = eps dx/x`. On `nonrationalinv`, identify the required algebraic
normalization. This does not imply an invalid DE or the absence of a canonical
form. Removing a private rationality check does not extend the rational
algorithms in stock CANONICA.

Choose the next hypothesis from the evidence. If the rational core is regular
at epsilon zero, consider the finite [epsilon-zero ansatz](../epsilon-zero/SKILL.md).
If the integral geometry suggests a normalization or numerator, return to
integral candidates; see the [Gram card](../gram/SKILL.md) when applicable.
Transform every differential direction only when an actual rationalizing
coordinate chart is available; declaring `q^2 = Q(x)` alone is not a
rationalization. See [normalization and tails](../../skills/canon-search-core/references/normalization-and-tails.md)
for gauge conventions, root derivatives, and tail completion. These are
conditional choices, not an exhaustive fallback sequence.

## Inputs and invocation

From `project_root`, run
`python3 run_step.py INPUT.json OUTPUT_DIR --method canonica`
with the standard `SEARCH_CORE` input,
`sector_basis`, `sector_cut_de`, and an available Wolfram kernel. Supply CANONICA
through either:

1. `method_options.package_entry`, resolved relative to `input.json` when it
   is not absolute; or
2. a standard Wolfram `$Path` installation resolved by `FindFile["CANONICA`"]`.

The card records the resolved entry, resolution source, entry SHA-256, and
Wolfram `$Version`/`$SystemID`. It does not require a machine-specific fixed
hash; independent checkers decide scientific acceptance.

The runner resolves, hashes, loads, and checks the package's public symbols
before evaluating `sector_cut_de`. This avoids creating ``Global`eps`` from the
input before package loading and triggering ``CANONICA`eps::shdw``. If both
the tool and input fail, the specific `ERROR/TOOL_*` takes precedence. Only
after that boundary passes can invalid or nonflat input return
`ERROR/INVALID_DIFFERENTIAL_SYSTEM`. This order is not provider fallback.

## Result and next action

Success writes `canon-neu/core-candidates/v1` using
`old_basis = transformation . new_basis`, with the entry, supplied or inferred
sector boundaries, alphabet, and provider epsilon-form result.
`mma/CheckSectorCore.wls` independently recomputes the acceptance conditions.
Provider success is `PROVISIONAL/CANDIDATE_TRANSFORMATION`; exhausted stages
return `INCONCLUSIVE/METHOD_EXHAUSTED`; invalid or nonflat input returns
`ERROR/INVALID_DIFFERENTIAL_SYSTEM`. The card never returns `PASS` or a
mathematical rejection `FAIL`. Exhaustion concerns this method, not the family.

This card performs no IBP reduction, sector reordering, off-diagonal lower-sector
tail solve, or modification of `accepted_prefix`. It cannot accept its own
candidates. It calls neither Libra nor INITIAL and is not a fixed fallback
after Libra. After `CHECK_CORE` passes, continue with `BUILD_FULL_DE`,
`SOLVE_TAIL`, and `CHECK_CANONICAL`; use `FINAL_CHECK` when the stated scope is
complete. On exhaustion, return the specific failed stage to the workflow entry.
