---
name: canon-reduce-ibp
description: Run the minimal Kira adapter from a collaborator-prepared project and obtain ordered masters plus fully reduced Wolfram rules.
---

# Reduce IBP

Work in the workspace assigned by the research task. Read the seven-field
request contract in `INTERFACES.md`, then run:

```text
wolframscript -file mma/ReduceIBP.wls REQUEST.json RESULT.wl
```

Require a zero exit code and a result with exactly `masters` and `rules`.
Preserve Kira's master order. In the task's positive scientific check, compare
every requested target with the master/rule left sides and require every rule
right-hand side to contain only those ordered masters.

Request `project`, `output` and executable paths containing a separator are
resolved relative to the request JSON. A bare executable name is found on PATH;
`jobs` are relative to the copied Kira project. Pass the thread budget in
`options`, and configure Fermat through `FERMATPATH`. Source installation
instructions are in `external/README.md`.

The request must pass argv items, never a shell command string. The script does
not choose a reducer, probe versions, build DEs, or mutate research state. If the
result is a deliverable, the Agent registers `RESULT.wl` through the state
manager after inspection.

For a `canon-neu/integral-candidates/v1` artifact, run:

```text
wolframscript -file mma/ReduceCandidateIBP.wls \
  INTEGRAL-CANDIDATES.wl PREPARED-FAMILY.wl MASTER-BASIS.wl \
  PREPARED-DERIVATIVES.wl REQUEST.json RESULT.wl
```

Before this candidate bridge, read the
[derivative input contract](../../INTERFACES.md#derivative-operator-selection).
The selector requires both the affine `operators` and a family-derived
`exact_strategy`. Follow this order:

1. Keep the returned candidate file and its IDs unchanged.
2. If either derivative input is missing, prepare it from the declared family
   in the run workspace. The contract lists the fields and Gram-polynomial
   construction. Rebind changed sources with PREPARE; reuse unchanged masters,
   rules and scientific results as their contracts permit.
3. Let `ChooseDerivativeOperator` perform its bounded search. A valid search
   with no enhanced solution returns `affine-fallback`, which is supported.
   Missing or malformed metadata returns a preparation failure, resolved by
   supplying the family-derived fields required by the contract.
4. Run the bridge on the saved candidates and reduce its required targets.
   Continue with ROUTE_CORE_CANDIDATES and CHECK_CORE.

If a concrete bounded preparation attempt cannot supply the needed construction,
report the attempted operation, exact missing object and remaining resources to
the coordinator. That evidence can justify another route under
[core selection](../canon-search-core/SKILL.md). An absent `exact_strategy`
identifies bridge preparation to perform. The earlier DlogBasis proposal is
independent of this field.

These two IBP adapters use positional arguments and write the requested WL
result; they do not use the common step envelope or emit `result.json`.
Do not pass a SEARCH_CORE or SOLVE_TAIL JSON request to them. The bridge must use
the selected affine or enhanced-Baikov operator exactly, retain proper-subsector
tails and signed numerator indices, and return candidate-ID-keyed reduced
expressions and derivatives. This is an IBP closure artifact, not a UT or
canonical-basis certificate.
