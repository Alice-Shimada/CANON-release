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

The request must pass argv items, never a shell command string. The script does
not choose a reducer, probe versions, build DEs, or mutate research state. If the
result is a deliverable, the Agent registers `RESULT.wl` through the state
manager after inspection.

For a `canon-neu/integral-candidates/v1` artifact, run the six-input
`mma/ReduceCandidateIBP.wls` command documented in `INTERFACES.md`. It must use
the selected affine or enhanced-Baikov operator exactly, retain proper-subsector
tails and signed numerator indices, and return candidate-ID-keyed reduced
expressions and derivatives. This is an IBP closure artifact, not a UT or
canonical-basis certificate.
