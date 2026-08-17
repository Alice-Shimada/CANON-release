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
Preserve Kira's master order. Treat a missing target classification, a residual
non-master integral, malformed Wolfram output, or a nonzero Kira exit as failure.

The request must pass argv items, never a shell command string. The script does
not choose a reducer, probe versions, build DEs, or mutate research state. If the
result is a deliverable, the Agent registers `RESULT.wl` through the state
manager after inspection.
