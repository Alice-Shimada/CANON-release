---
name: canon-prepare-family
description: Run the replaceable one-loop preparation demo when a small prepared Kira project is needed for interface testing.
---

# Prepare family demo

This is not the production collaborator interface. In the assigned workspace,
run:

```text
wolframscript -file mma/PrepareFamily.wls FRESH_OUTPUT_DIR
```

The result prints only the copied Kira project and prepared-family paths. Do not
add a task envelope, reducer discovery, version probe, manifest, hash, or
natural-language compiler. The Agent, not this script, registers any retained
artifact with the state manager. Research state is governed only by `statemng`;
the demo does not create or update task state.
