---
name: canon-prepare-family
description: Bind one trusted typed family specification to immutable prepared-family source descriptors.
---

# Prepare family

In the assigned run workspace, invoke:

```text
python3 run_step.py INPUT.json FRESH_OUTPUT_DIR
```

`payload.family_spec` names a trusted Wolfram Association containing the stable
family/basis identity, topology, parameter/variable and integral-index orders, sector
convention, regulator, dimension rule, exact family data, prepared derivatives,
ordered masters, and `propagator_slots`. Legacy Kira project/jobs provenance is
optional. Native reducer configuration belongs to its selected adapter. The script
preserves those identities and writes their paths and SHA-256 values to
`prepared-family.wl`, with paths relative to that artifact; downstream code must not infer the regulator from a
symbol name.
The optional `operator_source_symbol_map` is preserved for derivative consumers.
Missing source files and failed output writes return an error without publishing
a usable prepared-family reference.

Relative artifact paths are resolved from the input JSON directory; resource
paths inside the family spec are resolved from the spec directory. Kira config,
jobs and targets are relative to the declared Kira project. Use the current
checkout root for script locations and pass installed tool paths explicitly.

The caller supplies every scientific source path and owns the fresh output
directory. The script does not copy the project, run Kira, or update research
state; register retained output only through `statemng`.

For user-defined vector or scalar-product charts, the optional parameterization
component provides its own PREPARE input contract. Choose that front end
independently of the DISCOVER/REDUCE_IBP backend; read its selected instructions.
It automatically generates physical derivatives using the
[standard module](../canon-prepare-derivatives/SKILL.md). For already parameterized
family data use `PREPARE_DERIVATIVES`; do not hand-write derivative records.
The typed-source binder above continues to support retained validated inputs.

A PREPARE pass binds source descriptors. Each subsequent operation uses its
own input contract. For a defined-family integral-basis search, prepare the
`Family` and kinematic rules required by the
[DlogBasis proposal](../../methods/dlogbasis/SKILL.md). Candidate derivative
`exact_strategy` is needed by the later [IBP bridge](../canon-reduce-ibp/SKILL.md).
The proposal can run without it. Retain generated candidates while preparing
the bridge inputs from the [derivative contract](../../INTERFACES.md#derivative-operator-selection).
