---
name: canon-prepare-family
description: Bind one trusted typed family specification to immutable prepared-family source descriptors.
---

# Prepare family

In the assigned run workspace, invoke:

```text
wolframscript -file mma/PrepareFamily.wls INPUT.json FRESH_OUTPUT_DIR
```

`payload.family_spec` names a trusted Wolfram Association containing the stable
family/basis identity, topology, parameter/variable and integral-index orders, sector
convention, regulator, dimension rule, explicit Kira project/jobs, exact family
data, prepared derivatives, ordered masters, and `propagator_slots`. The script
preserves those identities and writes their paths and SHA-256 values to
`prepared-family.wl`; downstream code must not infer the regulator from a
symbol name.

Relative artifact paths are resolved from the input JSON directory; resource
paths inside the family spec are resolved from the spec directory. Kira config,
jobs and targets are relative to the declared Kira project. Use the current
checkout root for script locations and pass installed tool paths explicitly.

The caller supplies every scientific source path and owns the fresh output
directory. The script does not copy the project, run Kira, or update research
state; register retained output only through `statemng`.

A PREPARE pass binds source descriptors. Each subsequent operation uses its
own input contract. For a defined-family integral-basis search, prepare the
`Family` and kinematic rules required by the
[DlogBasis proposal](../../methods/dlogbasis/SKILL.md). Candidate derivative
`exact_strategy` is needed by the later [IBP bridge](../canon-reduce-ibp/SKILL.md).
The proposal can run without it. Retain generated candidates while preparing
the bridge inputs from the [derivative contract](../../INTERFACES.md#derivative-operator-selection).
