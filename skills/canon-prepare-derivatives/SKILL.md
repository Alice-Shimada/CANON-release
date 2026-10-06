---
name: canon-prepare-derivatives
description: Generate physical affine kinematic derivatives from the declared family routing and external Gram matrix.
---

# Generate physical derivatives

Run `python3 run_step.py INPUT.json FRESH_OUTPUT_DIR`, carrying the task's complete
component selection. Set `step` to `PREPARE_DERIVATIVES` and supply a
`payload.family_data` descriptor for the symbolic parameterized family produced
by the parameterization component.

The program solves the external momentum chain rule, preserves the declared
loop variables and measure, differentiates routing coefficients and squared
masses, and expands the result into the full propagator/ISP order. It checks the
external Gram and denominator identities exactly before emitting
`canon.prepared-derivatives/v2`. Point substitutions are not applied before
differentiation. The public Wolfram function is
``CANON`PhysicalDerivative`PreparePhysicalDerivatives[family]``.

`PASS/PHYSICAL_DERIVATIVES_READY` returns `prepared_derivatives`. Bind this
descriptor explicitly in `PREPARE_REDUCTION_TARGETS`, candidate bridges and
`BUILD_CUT_DE`, especially after artifact relocation. The parameterization
component's `PREPARE` also calls this generator automatically.
For `REDUCE_CANDIDATE_IBP`, explicitly select
`payload.derivative_operator_selection: "prepared-affine"`; the emitted
`exact_strategy.propagator_slots` comes from the declared family. This module
does not prepare enhanced Baikov operators.

Agents supply routing, kinematic constraints, variables and configuration only.
Do not hand-write affine derivative records or solve momentum derivatives in a
task-local script. An unsupported Gram variation or missing ISP span is a named
capability/input failure; report it rather than substituting formal partials at
fixed loop–external projections.

This step does not reduce integrals, discover masters, or prove DE flatness or
UT behavior. Existing independent reduction and DE gates remain required.
