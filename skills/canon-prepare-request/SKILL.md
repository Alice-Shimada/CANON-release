---
name: canon-prepare-request
description: Bind existing scientific artifacts into a request using declarative JSON.
---

# Prepare a request

Call `python3 run_step.py INPUT.json FRESH_OUTPUT_DIR` with step
`PREPARE_REQUEST` and `payload.template` pointing to a JSON file. Carry the same
ordered component selection as the surrounding workflow.

The template is an ordinary `canon-neu/script-input/v1` request. Its payload may
reference a producer's artifact as:

```json
{"from_result": "../discovery/result.json", "artifact": "master_basis"}
```

The component reads that PASS or PROVISIONAL result, copies the named descriptor,
and resolves its path from the producer result. Literal artifact descriptors
resolve from the template. All resulting artifact paths are stored relative to
the new request. Lists and nested payload associations are supported. Within the
template payload, a dictionary containing `path` denotes an artifact descriptor.

Keep software-specific paths and options in the backend's own JSON file, referred
to by an ordinary descriptor. Literal options are copied as supplied; this tool
does not rewrite arbitrary argv strings or provider-specific inline path fields.
For separately registered state artifacts, supply their returned stored paths
directly as descriptors. A `from_result` reference requires the producer result's
declared artifact layout to remain available.

Success returns `PASS/REQUEST_READY` and the `request` artifact. Run that generated
JSON through `run_step.py`, carrying the selected components again. Preparation
does not run the target step, select a method, or accept a scientific result.
Producer hashes and descriptor metadata are preserved; the consuming scientific
component owns its input checks. A bounded tail continuation may bind the
`tail_checkpoint` from `SOLVE_TAIL` with `INCONCLUSIVE/TAIL_UNSOLVED` into the
direct `payload.tail_checkpoint` of another `SOLVE_TAIL` request. The descriptor
and budget remain unchanged; other artifacts from that unsuccessful result
remain unusable. The tail consumer checks its file hash, complete source binding,
partition and exact D shape/domain as usual.
Missing artifacts or unsuitable producer results
return `ERROR/REQUEST_BINDING_FAILED` without a partially bound request.
