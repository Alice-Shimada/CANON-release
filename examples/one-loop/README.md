# One-loop sector 5

This small example has one master in sector 5 of the massless one-loop triangle
family. It is a two-propagator subfamily, not a claim of completing every sector
of the triangle family. The recorded calculation used `d = 2 - 2 eps` and obtained

```text
J = (1 + 2 eps) s/2 tri[1,0,1],
dJ/ds = -eps J/s.
```

## Input

- [Typed family specification](../../interfaces/family-spec.example.wl)
- [PREPARE request](../../interfaces/prepare.example.json)
- [Propagators and kinematics](../../tests/fixtures/kira-one-loop-triangle-sector-5/family.wl)
- [Frozen Kira inputs and derivatives](../../tests/fixtures/kira-one-loop-triangle-sector-5)

The spec and request are the release's concrete starting templates. To start a
new calculation, ask an agent to follow [the workflow guide](../../docs/agent-workflow.md).
The existing [live-test script](../../tests/RunEndToEndWorkflowLiveTest.wls)
documents the original end-to-end route; running it starts a new calculation.

## Read the saved result

With the checkout as the working directory, in a fresh Wolfram session:

```wl
basis = Get["examples/one-loop/canonical-basis.wl"];
de = Get["examples/one-loop/canonical-de.wl"];
basis["basis"]
de["matrices"]
```

The full input-order transformation is `I = basis["transformation"] . J`.
[result.json](result.json) is the original `PASS/ALL_PASS` record.

## Original evidence

The 2026-09-08 audit records 12/12 workflow acceptance items, using Wolfram 14.3,
DlogBasis-refine, FiniteFlow, and Kira 3.0 with one thread. Its final checker used
exact gauge, symbolic flatness, epsilon separation, and constant dlog residues.
See [the dated audit](../../docs/scientific-audit-20260908.md) and
[source-record.json](source-record.json). The saved outputs have not been recomputed
or rechecked for this release preparation.
