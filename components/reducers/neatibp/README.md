# NeatIBP adaptation package

This package explicitly depends on the sibling
[native-adapter package](../native-adapter/README.md) and CANON's common WL
library. The native integral encoding is declared as `G[a1,...]` with
`layout:"indices"`; the canonical scientific head can differ.

`DISCOVER` can import `results/MI_all.txt`. `REDUCE_IBP` requires a genuinely
solved rule table, with `source_format:"neatibp-solved-rules"`. In the inspected
NeatIBP/Kira interface this is
`results/Kira_reduction_results/reduced_IBP_Table.txt`. `IBP_all.txt`, shortened
equations, numeric rank checks and successful equation generation are not
reduced rules and cannot return `IBP_REDUCED`.

`export.py` reads an existing solved NeatIBP output without modifying it. Supply
`solved_output`, `software_revision`, and an explicit solver record such as
`{"kind":"Kira","completed":true}`. It copies only the native master list and
solved rule table into this invocation's output; mathematical closure and target
coverage are then checked by the shared normalizer. Its receipt explicitly says
that no new equation generation or reduction was executed. Use argv
`["{python}","{package}/export.py","{context}"]`.

For new native generation, `prepare.wls` is a separate input driver. It consumes
the neutral family/targets and backend `generic_point`, `generic_dimension`
(exact WL-expression strings), and `native_config` (a caller-supplied config.txt).
It writes `kinematics.txt`, `targetIntegrals.txt` and `config.txt` in the native
output directory. Configure Singular, SpaSM, solver executables and resource
settings in that native config. Then a caller-controlled driver runs the actual
NeatIBP generator and selected solver and produces completed exports. The adapter
does not infer completion from a background launch. Existing inputs and package
trees are never rewritten or recursively copied.

The current upstream entry `interfaces/Kira/interface/ReadKiraReductionResults.wl`
reads completed Kira data and writes the reduced table; it does not solve the
equations. An operator can invoke it in its writable native run after Kira has
finished. This adapter deliberately does not call it on a read-only predecessor
output directory.

`BUILD_CUT_DE` accepts an explicit exact full-DE export via
`exact-de-association`, or a separately selected DE component. A native NeatIBP
equation generator alone does not provide this operation; the bundled export
driver rejects it.

The file conventions and API scope were verified in the primary
[NeatIBP README](https://github.com/yzhphy/NeatIBP) and
[Kira readback source](https://github.com/yzhphy/NeatIBP/blob/main/interfaces/Kira/interface/ReadKiraReductionResults.wl).
Inspected version: 1.1.0.6. Bounded tests validate import/normalization and native
input preparation; they do not run a new NeatIBP/Singular/Kira campaign.
