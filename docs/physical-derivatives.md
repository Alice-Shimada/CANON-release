# Physical kinematic derivatives

For a new family, agents declare momenta, routing, squared masses, variables and
the external kinematics. The standard generator computes the derivative records.
Agents must not write those records or replace the generator with a task-local
mathematical script.

The parameterization component's `PREPARE` generates `prepared-derivatives.wl`
automatically. It embeds a relative reference in `prepared-family.wl` and returns
the derivative descriptor as a separate artifact for explicit downstream binding.
Its new-family spec does not accept a supplied `prepared_derivatives` file.
Previously validated artifacts and the legacy typed-source binder remain usable
through their existing consumer contracts; they need no replay.

For an already parameterized symbolic family, the standalone request is:

```json
{
  "schema": "canon-neu/script-input/v1",
  "task_id": "physical-derivatives",
  "step": "PREPARE_DERIVATIVES",
  "sector": null,
  "payload": {
    "family_data": {
      "type": "mathematica-expression",
      "path": "prepare/family-data.wl"
    }
  }
}
```

```sh
python3 run_step.py derivatives.json derivatives-output
```

Carry the task's complete ordered `--components` selection when present.
`PASS/PHYSICAL_DERIVATIVES_READY` returns `prepared_derivatives` in the existing
`canon.prepared-derivatives/v2` format. Bind it explicitly in
`PREPARE_REDUCTION_TARGETS`, `REDUCE_CANDIDATE_IBP` and `BUILD_CUT_DE`; this also
avoids stale embedded references after moving an artifact.

For `REDUCE_CANDIDATE_IBP`, set
`payload.derivative_operator_selection` to `"prepared-affine"`. The generator
copies the declared protected propagator slots into
`exact_strategy.propagator_slots`; the bridge then uses the physical affine
records and differentiates candidate prefactors itself. Enhanced Baikov
operators remain a separate provider and are not implied by this metadata.

The pure Wolfram API is:

```wolfram
Get["mma/lib/PhysicalDerivative.wl"];
derivatives = CANON`PhysicalDerivative`PreparePhysicalDerivatives[family];
```

`family` is the symbolic `family_data` from the parameterization component.
The core performs only algebra and returns data or `Failure`. It has no reducer,
filesystem, process, state-manager or master-basis dependency.

## Construction and conventions

For the independent external momenta, form `G[i,j]=p[i].p[j]`. For each coordinate
`x`, solve the exact linear system

\[
\partial_x p_i=\sum_j (C_x)_{ij}p_j,
\qquad C_xG+GC_x^{\mathsf T}=\partial_xG.
\]

Row reduction chooses a deterministic particular solution with free columns zero.
The remaining freedom preserves the Gram matrix and acts through Lorentz
invariance on scalar integrals. This is the external-momentum differentiation
used in the differential-equation method; see Sections 2–3 of
[Gehrmann and Remiddi](https://arxiv.org/abs/hep-ph/9912329). The implementation
solves the Gram equations directly rather than requiring a nonsingular inverse.

Loops and the raw integration measure are held fixed. Routing coefficients and
squared masses are differentiated along with external momenta. For
`D_i=r_i^2-m_i^2`, the generator computes the full chain rule and solves

\[
\partial_xD_i=c_i+\sum_j A_{ij}D_j.
\]

It checks the Gram and denominator identities exactly before returning records.
For G3447, this automatically gives the physical `s` flow `dp/ds=p/s, dl/ds=0`
and reproduces all five corrected nonzero slots, including
`dD11/ds=-1+(D12-D4)/s`. No G3447 formula is embedded in the implementation.

The symbolic chart is used before `point_rules`; numeric reduction points never
turn these derivatives into zero. Indexed coordinates are preserved. The selected
downstream provider retains its own coordinate-encoding capabilities.

The supported input is the parameterization component's linear momentum routing,
squared-mass convention and full propagator/ISP order, with an exact rational
affine derivative. A missing affine span, unsupported Gram variation, nonlinear
routing, inexact geometry or nonrational result produces a named failure. Supply
the missing family data or use a provider with the required capability. Such a
failure does not authorize hand-written derivative records.

The output describes raw integral differentiation with a kinematics-independent
loop measure. Apply external normalization/prefactor derivatives through the
existing candidate/basis interfaces. Reduction closure, physical homogeneity,
DE flatness and UT/canonical acceptance remain separate gates.

## Verification

```sh
wolframscript -file tests/RunPhysicalDerivativeUnitTests.wls /path/to/CANON checks.json
python3 tests/test_physical_derivatives.py --canon /path/to/CANON --work /path/to/fresh-test
```

The tests cover physical G3447 routing, bubble and squared-mass derivatives,
kinematics-dependent routing, indexed coordinates before point substitution,
fixed null Gram data, and explicit failure for an incomplete ISP span. Public
preparation/target/DE calls are also tested with analytic rules and relocation.
An optional G3447 input manifest supplies the existing 34-master rules for a
full symbolic DE regression; no native reduction is launched.
