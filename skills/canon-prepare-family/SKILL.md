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

The caller supplies every scientific source path and owns the fresh output
directory. The script does not copy the project, run Kira, or update research
state; register retained output only through `statemng`.
