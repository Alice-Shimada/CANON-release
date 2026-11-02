---
name: canon-build-full-de
description: Build the exact lower-prefix-plus-current-sector DE and declared full-row completions without rebuilding the ordered master DE.
---

# Build the full prefix DE

Run `BUILD_FULL_DE` through `python3 run_step.py INPUT.json OUTPUT_DIR` with `ordered_master_de`, `sector_cut_de`,
`core_candidates`, `core_transform`, `declared_alphabet`, and `accepted_prefix`.
The first sector uses `accepted_prefix -> null`.

`ordered_master_de` is the full result already written by `BUILD_CUT_DE`.
Never rerun Kira or DEBuilder.  For a nonempty accepted prefix use its explicit
raw `source_basis` and `old_source_basis = transformation . accepted_basis`.
For a reused prefix, take that source vector from the saved transformation's
producer, preserving its actual integral order. The reducer's master-file order
may differ; this step maps the explicit source entries into `ordered_master_de`.
For every declared core group use its complete reduced `full_new_basis_rows`;
embed these rows by their explicit source-basis order, using zero coefficients
for raw masters absent from a DE provider's source basis.

With `old_lower = Tlower.new_lower`, form the mixed source using
`T0 = diag(Tlower,Icurrent)`.  For reduced rows `[Rlower,Rcurrent]`, publish
`Tfull = Inverse[{{I,0},{Rlower.Tlower,Rcurrent}}]` under the repository
convention `old_prefix_basis = Tfull . candidate_prefix_basis`.

PASS writes one `full_sector_de` descriptor whose sole schema is
`canon-neu/full-prefix-candidates/v1`: one source matrix list, block
boundaries, and one completion for every declared core group. Use
`declared_alphabet -> null` for pole-factor and supported quadratic-root letter
inference in SOLVE_TAIL, or
supply a `canon-neu/declared-alphabet/v1` artifact with exact rational or
algebraic letters.  This step makes no canonical or tail-solvability claim.

For an observed general-construction normalization bottleneck, the optional
`method_options.normalization_backend = "finiteflow"` selects installed
`FFTogether` through a hash-bound arithmetic runtime configuration. Read
[construction arithmetic](../../docs/construction-arithmetic.md) for its exact
coefficient domain, resource settings and failure contract. The default remains
`"together"`; independent scientific checks are unchanged.
