# Optional CANONICA tail controls and backend evidence

Read this contract when configuring a bounded backend attempt, continuing its
checkpoint, or inspecting a backend failure. The ordinary SOLVE_TAIL call runs
its built-in completions automatically; see [the tail skill](../SKILL.md).
These options apply to the default component. A selected replacement follows
its own instructions and the same outgoing acceptance scope.

## Options, finite D ansatz and continuation

The default backend uses `tail_strategy="monolithic"`. Core-card options do not
configure this node. Its separate `payload.method_options` contract is:

| Option | Default | Meaning |
|---|---:|---|
| `package_entry` | Wolfram package lookup | CANONICA entry for a needed backend call |
| `tail_strategy` | `monolithic` | `monolithic` or explicit `subsector` |
| `d_delta_numerator_degree` | 0 | Nonnegative integer degree increment for D |
| `max_wall_seconds` | 60 | Positive shared time limit for backend D stages and epsilon normalization |
| `max_subsector_steps` | 64 | Positive per-attempt step budget; explicit option requires `subsector` |
| `max_ansatz_terms` | 256 | Positive integer limit for a supplied finite D ansatz |

Unknown options and invalid budgets return `ERROR/INVALID_OPTIONS`. Built-in
algebraic and affine proposals run as before. If their rational remainder needs
the backend, `subsector` infers contiguous blocks from the actual transformed
active lower DE using CANONICA's public sector API, checks their triangularity,
and calls `CalculateNextSubsectorD` once per remaining lower block. Trace entry
counts are not matrix widths. The completed D is lifted into the full prefix,
then full-prefix epsilon normalization runs. Stage messages, block bounds,
timing, attempted ansatz and stopped reason are retained in `summary.backend`.

For a directed attempt, provide `payload.d_ansatz`, a SHA-256 descriptor for
`canon-neu/canonica-rational-ansatz/v1`, with `kind -> "D"`. Its `identity`
binds `sector`, `family_id`, `current_basis_id`, `accepted_prefix_id`,
`candidate_id`, `source_basis`, `regulator`, and `source_de_sha256` (the input
full-DE file's byte hash). Its `scope` is
`<|"block_bounds" -> {activeLowerDimension+1,activeDimension}|>`, its
`variables` match the full DE, and its nonempty `terms` contain only exact
rational functions of those kinematic variables. Regulator-dependent terms,
roots, unknown symbols, wrong source/block, or too many terms are rejected.
The artifact is a rational-function basis for each D solve, not a matrix of
preselected coefficients. Explicit D input requires `subsector`.

When a bounded subsector attempt stops, `TAIL_UNSOLVED` can include a hashed
`tail_checkpoint` artifact. Pass that descriptor as `payload.tail_checkpoint`
with `tail_strategy="subsector"` to continue the remaining blocks. Validation
binds the complete source, selected candidate, base transformation, active rows,
partition and package entry hash; it also checks the partial D's shape and
rational domain. Changed sources or malformed checkpoints return input errors.
Checkpoint progress establishes no canonical claim. A resumed complete result
still goes through CHECK_CANONICAL and FINAL_CHECK. The step budget is local to
the new attempt; no automatic resume or budget increase occurs.

## Retained backend failure

For a backend failure, `summary.backend_stage` is `TransformOffDiagonalBlock`
(off-diagonal completion on the active closure) or `TransformDlogToEpsForm`
(full-prefix epsilon normalization). The `backend_failure` descriptor points to
`backend-failure.wl`, a `canon-neu/tail-backend-failure/v1` Association. It records
the stage, candidate, resolved package entry, and immediate call context:
variables, backend regulator, active positions, sector boundaries, initial
transformation, matrices, and explicit options. `backend_return` contains the
actual saved return under `HoldComplete`, so loading the artifact keeps that
return inert. Wrong-sized, singular or inexact backend transformations are
also retained as failed backend returns. The diagnostic makes no additional backend call. It preserves
`INCONCLUSIVE/TAIL_UNSOLVED` and the bounded backend failure reason; a returned `False`
does not identify a finer cause or prove that every ansatz is exhausted.
Non-backend unsolved results omit these backend-specific fields and artifacts.
