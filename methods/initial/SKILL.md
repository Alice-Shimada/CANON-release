---
name: canon-initial-official-ladder-evidence
description: Produce UT evidence awaiting independent verification for the fixed INITIAL 2.1 official massless 3L4P ladder candidate, without candidate search, ranking, replacement, or repair.
---

# INITIAL official ladder UT evidence

## Trigger and fixed scope

Use this opt-in evidence card only when the task explicitly requests the
official ladder contract below. It is not a prerequisite for general tail
solving or canonical acceptance.

This card accepts only the INITIAL 2.1 official `massless_3L4P` planar
three-loop four-point ladder: the official 26-element basis order, first UT seed
`G[2,{1,1,1,1,1,1,1,1,1,1,-1,0,0,0,0}]`, `D=4-2 eps`, `x=t/s`, alphabet
`{x,1+x}`, and `TakeRow -> 1`. Any change to the family, candidate, basis,
order, normalization, reference, seed, or alphabet returns
`INCONCLUSIVE/OUT_OF_SCOPE` before calling the tool or triggering another
workflow action.

## Inputs and command

Supply `method_options.package_entry` (INITIAL.m), `finite_flow_package_file`
(FiniteFlow.m), `finite_flow_library` (the locally built fflowmlink native
library), and `reference_directory` (official `examples/massless_3L4P`), plus
the exact identities `INITIAL 2.1; 63d8f813ac415f82f7ef945ee7e3f78a242fae49`
and `FiniteFlow; 278344c169010b74e791af8c5604c8cb9cd8df11`. Relative paths
resolve from the input JSON directory. Use a WolframKernel compatible with
the installed native library:

```bash
"${CANON_WOLFRAM_KERNEL:-WolframKernel}" \
  -noinit -noprompt -script methods/initial/run.wls input.json NEW_OUTPUT_DIR
```

`NEW_OUTPUT_DIR` must not exist; its parent must exist and be writable, and
the output must be outside the tool component directories. The caller may
supply a positive integer `threads` (default 1). The runner explicitly loads
the declared FiniteFlow native library and INITIAL entry, then runs the
official template's `TCalc` and `basisChange`. It does not call Libra, CANONICA,
or candidate search, ranking, replacement, repair, or routing logic.

## Result and next action

Successful computation returns only `PROVISIONAL/EVIDENCE_AWAITING_VERIFICATION`
with a `canon-neu/ut-evidence/v1` artifact. Provider reference, gauge,
epsilon-form, or dlog checks are not final acceptance. Only an independent
`mma/CheckUTEvidence.wls` run that rereads the official A, basis, and reference
and recomputes every exact condition can return `PASS/VERIFIED_EVIDENCE`.

The checker accepts the same `package_entry`, `finite_flow_package_file`, and
`reference_directory` in `checker_options`; it does not load the native library.
Source is distributed in `external/INITIAL` and `external/FiniteFlow`; see
[installation instructions](../../external/README.md).

Keep result categories distinct. Unsupported scope returns
`INCONCLUSIVE/OUT_OF_SCOPE`. Configuration, component, identity, loading, or
computation errors return a specific `ERROR/TOOL_*`. Unestablished provider
reference, gauge, epsilon, or dlog evidence returns
`INCONCLUSIVE/METHOD_EXHAUSTED`. The provider never writes `PASS` or `FAIL`;
only the independent checker issues `PASS/VERIFIED_EVIDENCE` or
`FAIL/EVIDENCE_REJECTED`.
