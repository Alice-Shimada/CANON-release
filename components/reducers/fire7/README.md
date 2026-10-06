# FIRE7 adaptation package

This package explicitly depends on the sibling
[native-adapter package](../native-adapter/README.md) and CANON's common WL
library. It supports independent master discovery, reduced-rule import and
declared exact full-DE import. It does not select a parameterization.

FIRE master files contain `{problem,{indices}}` pairs: select
`masters_format:"family-index-pairs"`. Converted rules use an explicitly declared
head, typically `G[problem,{indices}]`, with `layout:"family-list"`. Use
`source_format:"fire7-rules"` for `tables2rules` output. Native compressed or
finite-field `.tables` files are not interpreted as rational solved rules.
The normalizer preserves the requested source basis and rejects unresolved targets.

`native.py` is a small driver for the documented FIRE7 CLI. It needs caller paths
`executable`, `tables2rules`, a matching `start_file`, `software_revision`, explicit
`threads`, `fthreads`, and ordered `variables`. `options` is an optional list of
extra configuration lines. It writes target/preferred lists in FIRE format from
the neutral target artifact, copies only the supplied start file, writes one
local config and calls `FIRE7 --config reduction`. Reduction then calls
`tables2rules reduction.tables rules.wl`.

Discovery uses the documented `#masters` forward-only mode. Native master-file
naming differs across releases/configurations, so `master_export` explicitly
declares `{ "base":"output", "path":"generated-file.masters" }`; reduction
may instead import an already fixed master list with `base:"backend"`. That
list is checked against every target RHS. It is not assumed that `#preferred`
forces the requested master basis. For discovery, use a newly generated output
master file. Discovery targets may be supplied as a separate `discovery_targets`
WL path when no reduction_targets descriptor is present.

Command argv is `["{python}","{package}/native.py","{context}"]`. Executables
with path separators and start/master paths resolve from the backend JSON;
bare executable names use PATH. The supplied start file and optional native
configuration are backend setup, separate from neutral parameterization data.
The driver records its source hash and execution scope. All resource counts are
caller supplied; no MPI campaign or automatic reconstruction is started.

FIRE7 does not implement a native DE algorithm in this template. Its
`BUILD_CUT_DE` entry imports an explicit `exact-de-association`, or the caller
selects another DE producer (for example Blade or the generic builder). Calling
the bundled FIRE driver for this step fails explicitly.

CLI syntax, `.masters` encoding, `#masters` and `tables2rules` were verified in
the primary [FIRE7 manual, sections 3–5](https://arxiv.org/html/2510.07150v1).
No installed FIRE7 executable was assumed or a native reduction run during the
bounded adapter tests.
