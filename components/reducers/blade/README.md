# Blade adaptation package

This optional package exposes separately selectable `DISCOVER`, `REDUCE_IBP`
and `BUILD_CUT_DE`. It explicitly depends on the sibling
[native-adapter package](../native-adapter/README.md) and CANON's common WL
library. Read that contract for backend paths, integral encodings, exact rule
closure, source basis conversions and result routing.

Imports use the declared `BL[family,{indices}]` encoding. Masters are a WL list;
`blade-rules` is a list of solved rules; `blade-de-triple` is the actual
`{masters,variables,matrices}` result of `BLDifferentialEquation`. The normalizer
restores requested variable/master order and rejects missing directions and
incompatible bases. Importing these files does not launch Blade.

For configured native execution, `native.wls` calls `BLFamilyDefine`,
`BLReduce[target,preferred,key,...]` and
`BLDifferentialEquation[variables,preferred,key,...]`. Discovery reduces caller
seed targets and exports the resulting masters; it does not label maximal-cut
masters as a completed full reduction. Geometry, masses, scalar products and
dimension come from the neutral reducer_family. This compact native template
supports one declared top-level sector. Settings contain only native method
options and optional discovery targets. A broader family/setup can use an
explicit caller driver with the same export contract.

The backend config additionally supplies `package_entry`, `settings` (WL),
`software_revision` and `threads`; all paths resolve from that JSON. A minimal
settings file is `<|"reduce_options" -> {}, "de_options" -> {}|>`. Native command
argv is `["{wolframscript}","-file","{package}/native.wls","{context}"]`.
Configure the encoding head as ``Blade`BL`` and the exact native family symbol.
The driver records the declared revision and actual entry/settings hashes.
Its exports are `masters.wl`/`rules.wl` or `de.wl` in the native output directory.

These calls and output shapes were verified in Blade's primary source and its
[reduction](https://gitlab.com/multiloop-pku/blade/-/blob/main/example/1_spanning_reduce/run.wl)
and [DE example](https://gitlab.com/multiloop-pku/blade/-/blob/main/example/1_differential_equations/run.wl).
The inspected entry declares version 2024-05-23. Loading Blade requires its
installed FiniteFlow/native dependencies; a source directory alone is insufficient.
This package's bounded fixture validation does not run a native Blade campaign.
