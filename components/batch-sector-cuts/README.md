# Batch resident-sector cuts

`SLICE_CUT_DE_BATCH` takes the standard `ordered_master_de` and `sector_manifest`
descriptors in a `canon-neu/script-input/v1` request. No `sector` is required.
The full ordered DE is loaded through `LoadArtifact` and validated through
`ValidateOrderedMasterDE` once. The manifest is loaded once. Each sector uses the
existing `CurrentSectorRecord` and `SectorDEArtifacts` construction.

Select this manifest after the caller's complete component stack. The runner
supplies `{canon}` to the command; `CANON_WOLFRAMSCRIPT` supplies the installed
runtime. No machine path, dependency build or process/thread count is inferred.

The batch requires unique manifest ids/masks and complete resident-master
coverage. Valid nonresident records remain part of the existing proper-subsector
metadata but emit no empty cut. Sector entries are ordered by
`(propagator_count,id)`; every sector keeps the original resident master order.
No input hash or rational-matrix validation is bypassed or cached across calls.

PASS/BATCH_SLICED writes standard `canon-neu/sector-basis/v1` and
`canon-neu/sector-cut-de/v1` files in `sectors/S<id>/`, plus
`sector-index.json` (`canon-neu/sector-cut-de-batch/v1`). Its direct entries
carry positions, counts and hash-bound basis/cut descriptors. Its source
descriptors retain the original input identity and are relative to that index.
The result also exposes `sector_basis_<id>` and `sector_cut_de_<id>` for
ordinary PREPARE_REQUEST bindings. Use a fresh output directory.

The supplementary batch-timing.json records same-kernel SessionTime[] differences
for ordered loading (including the declared hash check), its single validation,
and all-sector binding/projection/writing. Kernel startup and library loading are
excluded; no scientific artifact is altered by these operational measurements.

This step certifies the same exact quotient construction as SLICE_CUT_DE.
It does not discover masters, rebuild derivatives/IBP, select a candidate,
check canonicality, establish UT normalization or close a full-family gate.

Focused tests use a tiny exact rational connection with nontrivial lower tails,
noncontiguous resident positions and a multi-master sector. They compare
standard single-sector output bytes and independently specified expressions,
then exercise single-sector and malformed/hash-rejection boundaries. No physical
family input is included. See `tests/test_batch_sector_cuts.py` for explicit
checkout, component, workspace and runtime arguments.

Run the focused test as `python3 tests/test_batch_sector_cuts.py --config
CALLER.json --work FRESH_DIR`. The caller JSON supplies `project_root`, the
complete `complete_components` list including this package, `wolframscript`,
`environment`, `cpu`, `rss_bytes`, `fixture_timeout_seconds`, `cleanup_seconds`
and `collection_seconds`. The configured runtime may be a native wolframscript
or an argv-compatible caller adapter. Tests use the selected local-jobs owner
for cancellation and collection and Linux /proc RSS sampling; no runtime path
or CPU assignment is encoded in package source.
