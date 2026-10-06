# Mathematica script interfaces

This document defines interfaces, not algorithms, internal functions, or implementation
details. All executable workflow steps, including IBP, use the same envelope.
The mathematical library functions at the end operate directly on WL expressions.

## Common invocation

```text
python3 run_step.py <input.json> <output_dir> [--components PACKAGE.json] [--method NAME]
```

Implemented scripts must write the common result format to `<output_dir>/result.json`.
Use `.wl` for scientific artifacts where possible; Python passes their paths without
reading their contents.

The request's `step` selects an implementation from
[`components/default.json`](components/default.json), optionally overridden by a
user component package. `--method` selects a named implementation of a step, such
as `SEARCH_CORE/libra`. See [component packages](docs/components.md) for package
layout and command resolution. The built-in `.wls` files also accept the same
input/output pair directly.

## Common input

For a request ready to use with `PREPARE`, see
[`interfaces/prepare.example.json`](interfaces/prepare.example.json). Its scientific
input is the Wolfram Association in
[`interfaces/family-spec.example.wl`](interfaces/family-spec.example.wl).
See the [agent guide](docs/agent-workflow.md) for input preparation and the
[workflow skill](skills/canon-workflow/SKILL.md) for scientific routing.

```json
{
  "schema": "canon-neu/script-input/v1",
  "task_id": "T0006-CHECK_CORE",
  "step": "CHECK_CORE",
  "sector": {
    "id": 7,
    "propagator_count": 3
  },
  "payload": {}
}
```

For global steps, `sector` is `null`.

### Wolfram artifact symbol contexts

The common artifact reader interprets unqualified non-System symbols in
``CANON`DEData` `` with only ``System` `` on the context path. This applies uniformly
to integral heads, dimension and regulator symbols, kinematic variables, and
Association keys. Explicitly qualified symbols retain their declared contexts;
symbols from different contexts are never identified by name. Direct data-file
consumers can use ``CanonMethodCard`ReadWLData[path]`` for the same interpretation.
Prepared derivative files and unqualified names in `operator_source_symbol_map`
use this data context too; explicitly qualified map names remain exact.

`WriteWLArtifact` serializes under the same fixed data context, independently of
the caller's context path. Canonical data symbols may be unqualified on disk;
other contexts remain explicit so a write/read round trip preserves them.
These routines load data, not Wolfram package definitions.

## Common output

```json
{
  "schema": "canon-neu/script-result/v1",
  "task_id": "T0006-CHECK_CORE",
  "step": "CHECK_CORE",
  "status": "PASS",
  "code": "CORE_PASS",
  "artifacts": {
    "core_transform": {
      "type": "mathematica-expression",
      "path": "core-transform.wl"
    }
  },
  "summary": {}
}
```

`status` follows the single typed method-card protocol and is one of `ERROR`,
`INCONCLUSIVE`, `PROVISIONAL`, `FAIL`, or `PASS`. Candidate providers may emit only codes
allowed by their cards within the first three categories; they cannot emit `PASS`
or `FAIL`. Independent checkers retain final `PASS`/`FAIL` authority. Artifact
paths are relative to the directory containing `result.json` and are resolved by
the method-card caller. `statemng` neither parses scientific `result.json` files
nor automatically advances the scientific stage graph based on their codes.
Read `status` and `code` even when the process exits zero: a structured scientific
failure may be returned normally. A nonzero exit is an operational failure and
cannot establish scientific completion from a saved `PASS` alone; preserve any
more specific failure result for diagnosis.

## Skills, payloads, and outputs by step

The table describes the built-in scientific contracts. A package replacing
several connected steps may document a distinct internal intake schema; artifacts
returned to built-in consumers must satisfy the corresponding contracts below.
See [component composition](docs/components.md#composition-and-handoff).

| step | SKILL | default script | payload keys | artifact keys |
|---|---|---|---|---|
| `PREPARE_REQUEST` | `canon-prepare-request` | `prepare_request.py` | `template` (JSON descriptor) | `request` |
| `PREPARE` | `canon-prepare-family` | `mma/PrepareFamily.wls` | `family_spec` | `prepared_family` |
| `PROPOSE_INTEGRAL_CANDIDATES` | `canon-dlogbasis-integral-candidates` | `methods/dlogbasis/run.wls` | `family_identity`, `sector_identity`, `prepared_family`, `dimension_policy`, `numerator_or_power_counting_policy`, `candidate_budget`, `candidate_unit`, `normalization_policy`, `method_options` | `integral_candidates` |
| `DISCOVER` | `canon-discover-sectors` | `mma/DiscoverSectors.wls` | `prepared_family` | `sector_manifest`, `master_basis` |
| `PREPARE_DERIVATIVES` | `canon-prepare-derivatives` | `mma/PrepareDerivatives.wls` | `family_data` | `prepared_derivatives` |
| `PREPARE_REDUCTION_TARGETS` | `canon-prepare-reduction-targets` | `mma/PrepareReductionTargets.wls` | `prepared_family`, `master_basis`; optional `prepared_derivatives` | `reduction_targets` |
| `REDUCE_IBP` | `canon-reduce-ibp` | `mma/ReduceIBP.wls` | Legacy `reduction`, or `backend` config; optional `reduction_targets` and `master_basis` | `ibp_reduction` |
| `REDUCE_CANDIDATE_IBP` | `canon-reduce-ibp` | `mma/ReduceCandidateIBP.wls` | `integral_candidates`, `prepared_family`, `master_basis`, `prepared_derivatives`; existing `ibp_reduction`, or selected `backend` plus required neutral descriptors, or legacy `reduction` | `candidate_ibp_bridge`, `reduction_targets` |
| `BUILD_CUT_DE` | `canon-build-cut-de` | `mma/BuildSectorCutDE.wls` | `prepared_family`, `master_basis`, `sector_manifest`, `ibp_reduction`; optional `prepared_derivatives` | `sector_basis`, `sector_cut_de`, `ordered_master_de` |
| `SLICE_CUT_DE` | `canon-build-cut-de` | `mma/SliceSectorCutDE.wls` | `ordered_master_de`, `sector_manifest` | `sector_basis`, `sector_cut_de` |
| `ROUTE_CORE_CANDIDATES` | `canon-search-core` | `mma/RouteCoreCandidates.wls` | `prepared_family`, `sector_basis`, `sector_cut_de`, `candidate_ibp_bridge` | `core_candidates` |
| `SEARCH_CORE` | `canon-search-core` | Selected direct-DE card's `run.wls` | `sector_cut_de`; `sector_basis` for CANONICA/Libra/INITIAL; card-specific `method_options` and optional artifacts | `core_candidates` |
| `DIAGNOSE_CORE` | `canon-residue-balance-core` | `methods/residue-balance/run.wls` | `sector_basis`, `sector_cut_de`; optional `method_options` | `core_diagnosis` |
| `CHECK_CORE` | `canon-check-core` | `mma/CheckSectorCore.wls` | `sector_basis`, `sector_cut_de`, `core_candidates` | `core_transform` |
| `BUILD_FULL_DE` | `canon-build-full-de` | `mma/BuildFullSectorDE.wls` | `ordered_master_de`, `sector_cut_de`, `core_candidates`, `core_transform`, `declared_alphabet`, `accepted_prefix` | `full_sector_de` |
| `SOLVE_TAIL` | `canon-solve-tail` | `mma/SolveTail.wls` | `full_sector_de`, `core_transform`, `method_options` | `sector_transform` |
| `CHECK_CANONICAL` | `canon-check-canonical` | `mma/CheckCanonical.wls` | `full_sector_de`, `sector_transform` | `canonical_sector_de` |
| `COMMIT_SECTOR` | `canon-commit-sector` | `mma/CommitSector.wls` | `previous_accepted_prefix`, `sector_basis`, `sector_transform`, `canonical_sector_de` | `accepted_prefix` |
| `NEXT_SECTOR` | `canon-commit-sector` | `mma/NextSector.wls` | `sector_manifest`, `accepted_prefix` | `sector_cursor` |
| `FINAL_CHECK` | `canon-final-check` | `mma/CheckFullSystem.wls` | `prepared_family`, `master_basis`, `sector_manifest`, `ordered_master_de`, `accepted_prefix` | `canonical_basis`, `canonical_de` |

`canon-build-de`, `canon-build-cut-de`, `canon-build-full-de`,
`canon-solve-tail`, `canon-check-canonical`, `canon-commit-sector`, and
`canon-final-check` document the current direct scientific implementations.
Historical steps that remain unimplemented must not be treated as complete merely
because the table contains placeholder interfaces for them.

For the first sector, `accepted_prefix` or `previous_accepted_prefix` is `null`.

### Specialized method-card handoffs

These operations retain their opt-in scopes in [the method catalog](methods/README.md).
They are not additional mandatory stages of the canonical workflow. Each input
artifact uses the common `mathematica-expression` descriptor. Package options
are per card; options for one use of a package do not configure another operation.

| step | script | payload keys | successful artifact and authority |
|---|---|---|---|
| `ROUTE_PREPARED_BASIS` | `methods/route-prepared-basis/run.wls` | `prepared_basis` | `route_decision`; `PROVISIONAL/ROUTE_DECISION`, no solver invocation |
| `SCREEN_TAIL` | `methods/full-prefix-tail-screen/run.wls` | `sector_basis`, `sector_cut_de`, `core_candidates`, `accepted_prefix`, `full_prefix_candidates`, optional `screen_options` | `screened_candidate`; `PASS/TAIL_SCREEN_PASS` within the declared pool and frozen-prefix scope |
| `REPAIR_WITH_LIBRA` | `methods/libra-structured-repair/run.wls` | `prepared_basis`, `route_decision`, `repair_request`, `method_options` | `repair_candidate`; `PROVISIONAL/CANDIDATE_TRANSFORMATION` |
| `CHECK_STRUCTURED_REPAIR` | `mma/CheckStructuredRepair.wls` | `prepared_basis`, `route_decision`, `repair_request`, `repair_candidate`, `checker_options` | `verified_structured_repair`; `PASS/VERIFIED_STRUCTURED_REPAIR` |

The checker options supply authoritative component paths/identity independently
of the proposal; they are not inferred from a provider's success claim. INITIAL's
fixed reference request is documented separately below. For repair, use the
[request artifact](tests/fixtures/method_cards/structured-repair-input.wl) and
[repair contract](methods/libra-structured-repair/SKILL.md). A specialized check
does not replace `CHECK_CANONICAL` or `FINAL_CHECK` for a full-family claim.

### Official validation compatibility

The original INITIAL official ladder flow is outside the selectable method
catalog. Its implementation is the
[reference validation example](examples/initial-official-ladder/README.md).
Existing clients retain these explicit contracts and all v1 artifact schemas:

| Step | Compatibility address → implementation | Required payload | Output / scope |
|---|---|---|---|
| `PROVIDE_UT_EVIDENCE` | `methods/initial/run.wls` → `examples/initial-official-ladder/run.wls` | Fixed `candidate`, `method_options` | Provisional `ut_evidence`; fixed official reference only |
| `CHECK_UT_EVIDENCE` | `mma/CheckUTEvidence.wls` → `examples/initial-official-ladder/check.wls` | Fixed `candidate`, `provider_task_id`, `ut_evidence`, `checker_options` | `PASS/VERIFIED_EVIDENCE` or scoped rejection; `verified_ut_evidence` |

The [existing request fixture](tests/fixtures/method_cards/initial-evidence-input.json)
retains fixed basis/seed/normalization/alphabet and declared tool identities.
Result summaries and new artifacts have `interface` metadata identifying the
compatibility lifecycle, fixed official verification scope,
`core_selection_eligible=false` and `workflow_action="none"`. Existing artifacts
without this metadata remain readable. The checker derives its scope from
validated inputs and exact reference checks, not an artifact's policy flags.

Strict reference equality detects changes to that fixture; a different constant
gauge or basis permutation can fail this test while remaining a valid candidate.
`VERIFIED_EVIDENCE` is agreement with the official normalized reference, not a
general UT proof, CORE_PASS, CANONICAL_PASS or an automatic route selection.
Referencing a receipt cannot automatically establish another seed's normalization.

### Direct-DE options and CHECK_CORE boundary

CANONICA, Libra and seeded INITIAL need matching task sector, family/basis
identities and basis order in `sector_basis` and `sector_cut_de`. CANONICA and
Libra do not need `prepared_family`; INITIAL needs it only for the bridge seed
source described below.
For CANONICA, `method_options` accepts `package_entry` and optional nonnegative
integer `t_delta_numerator_degree`, `t_delta_denominator_degree`, and
`d_delta_numerator_degree`. Each defaults to zero and configures one recursive
attempt. `max_wall_seconds` defaults to 60 and `max_ansatz_terms` to 256;
they require a positive time and positive integer term limit. The effective values are recorded as `ansatz_options` in the candidate's
method provenance and result summary, including unsuccessful attempts after
option validation. Optional `payload.t_ansatz` selects one directed diagonal
block instead of the default recursive attempt, with the hashed finite artifact
contract below. Diagnostics retain message tags, requested/failed stages, block,
timing, timeout/abort flags and attempted ansatz, with raw package messages and
the complete attempt list. They do not change `SOLVE_TAIL` options.

Libra retains `package_entry` and `dependent_row_strategy`; its explicit
hierarchy input is described in [the card](methods/libra/SKILL.md). Explicit
`normalization_strategy="bounded"` adds finite public subspace/projector/balance
normalization before Fuchsify/FactorOut. The default `none` preserves the legacy
route. Positive integer budgets `normalization_max_steps`,
`normalization_max_projectors`, `normalization_max_dimension`, and
`normalization_max_seconds` default to 8, 64, 8, and 30 and are valid only with
`bounded`. The epsilon-zero connection must be Fuchsian with decidable integer
residue intercepts and regulator-independent linear poles. Each candidate must
preserve the exact source gauge, avoid increasing generic pole ranks and
strictly decrease total integer offsets. Its trace, bounds and stopped stage
describe that finite route; they never certify all possible bases.

Unknown options in these core cards and the official compatibility provider return
`ERROR/INVALID_OPTIONS`; they are not silently ignored. The official provider
validates positive integer `threads` (legacy default 1) before loading components.
Requests to write INITIAL
output into an existing directory, a component/reference directory, or beneath
a missing parent exit without writing there, including an error result.
Configured component parent directories and reference locations remain protected
when a component is missing; both declared paths and existing symlink targets are
covered.

### INITIAL seeded SEARCH_CORE

`methods/initial/run.wls` is the stable INITIAL entry. Explicit `SEARCH_CORE`
delegates to `methods/initial-core/run.wls`, whose direct address remains usable
with identical scientific semantics. Explicit `PROVIDE_UT_EVIDENCE` delegates
only to official compatibility validation. Malformed envelopes or other steps
exit before output creation. Input `step` selects a contract, not a scientific
fallback; a core failure never invokes official validation. The active core
interface accepts a rational one-variable cut,
`seed_request`, and exactly one source: `seed_rows`, or
`candidate_ibp_bridge` together with `prepared_family`. Descriptors can declare
hashes, which are checked; actual hashes and complete source rows are retained.

`canon-neu/initial-seed-request/v1` binds `sector`, `family_id`, `basis_id`,
`basis`, `variables`, and `regulator`. It declares unique `seed_ids`, positive
`derivative_counts` summing to the cut dimension, and `letters` (or instead a
`payload.declared_alphabet` descriptor). `canon-neu/initial-seed-rows/v1` has
the same identity/order fields, `source_basis`, and `seeds` records with `id`,
`full_new_basis_row`, and `normalization_evidence`. The bridge alternative uses
`prepared_family.dimension_rule` and keeps all lower-sector coefficients.

Each selected normalization record requires `status="established"`, a statement,
one of `official-reference`, `integrand-dlog-leading-singularities`,
`independent-initial-picard-fuchs`, or `weight-graded-boundary-lower-sector`, and
an evidence source path with SHA-256. This is an explicit input premise; a
provisional Dlog candidate or finite-cut rank alone cannot satisfy it.

Required `method_options` are `package_entry`, `finite_flow_package_file`,
`finite_flow_library`, nonempty `initial_identity` and `finiteflow_identity`,
and positive integer `threads`, `timeout_seconds`, `max_iterations`,
`max_degree`, and `max_primes`. There is no implicit thread count, automatic
retry, seed search or alphabet inference. The adapter binds the native library
and protects input/component directories from output writes.

Both INITIAL providers use `mma/lib/InitialRuntime.wl`. For the exact INITIAL
2.1 source SHA-256
`4b4fe726f45484f31b909dc34eef85d77068b3d6dfaf3404163f8f706fc3888c`,
the loader assigns zero rank to an empty first training batch in `equStep`.
The first sample is reserved for validation; a single-thread batch therefore
needs the existing loop to collect further training rows. The unique source
fragment is adapted only in memory and loaded expression by expression with
`Get[stream]`. Other source hashes use ordinary `Get[entry]`. External sources
and installations remain unchanged; caller threads, bounds, single-attempt
behavior and independent checkers are preserved.

`initial_runtime` contains the original source `path`/`sha256` and adapter
`id`/`path`/`sha256`/`applied`. Core candidates retain it in
`method.initial_runtime` and `method.diagnostics.initial_runtime`;
provider result diagnostics retain it too. Official evidence retains it in
`method.initial_runtime` and the provider result summary. These file hashes
identify the original input and CANON implementation, not a patched upstream
file. Native official regressions explicitly use one thread.

Seed rows complete an invertible `R_cut`, with corresponding full `R_full`.
The intermediate source is `(D[R_cut,x]+R_cut.A).Inverse[R_cut]`; INITIAL's
`TakeRow` is `1` or explicit `{{row,count},...}`. The derivative Psi must have
full rank. Final `T=Inverse[R_cut].T_initial` and
`full_new_basis_rows=Inverse[T_initial].R_full` undergo source-gauge,
invertibility, epsilon and declared-alphabet publication checks. Output remains
`PROVISIONAL/CANDIDATE_TRANSFORMATION` and goes to CHECK_CORE. Degree,
reconstruction, rank or time limits are `INCONCLUSIVE/METHOD_EXHAUSTED`, with
no claim that a seed is non-UT. Its result summaries and method provenance carry
`interface.role="core-candidate-provider"`, `lifecycle="active"`,
`next_gate="CHECK_CORE"`, and `reference_equality_required=false`. These fields
describe the provider's contract; independent checks and applicable normalization
evidence establish the scientific claims. See [the card](methods/initial-core/SKILL.md).

### Finite CANONICA ansatz artifact

`payload.t_ansatz` (SEARCH_CORE) or `payload.d_ansatz` (subsector SOLVE_TAIL)
requires a `mathematica-expression` descriptor with a verified byte SHA-256.
The WL artifact uses schema `canon-neu/canonica-rational-ansatz/v1`, `kind`
(`"T"` or `"D"`), exact `identity`, `scope`, ordered `variables`, and a
nonempty finite list of `terms`. Terms are exact rational functions of declared
kinematic variables only; regulator terms, roots, approximate coefficients and
undeclared symbols are rejected before solving.

For T, identity contains `sector`, `family_id`, `basis_id`, `source_basis`
(the cut basis), `regulator`, and `source_de_sha256` (cut file bytes); scope
contains the explicit `block_index` and its exact `block_bounds`.
For D, identity contains `sector`, `family_id`, `current_basis_id`,
`accepted_prefix_id`, `candidate_id`, `source_basis`, `regulator`, and
`source_de_sha256` (full-DE file bytes); scope is the active current
`block_bounds`. These artifacts supply finite rational-function bases for a
bounded solve, not transformation matrices. Core T and tail D contracts and
budgets remain separate.

`CHECK_CORE` binds the task, basis, cut and candidate identities, ordered basis,
variable order, regulator and transformation convention before checking the
mathematics. Candidate IDs and pool counts must describe the supplied ordered
pool consistently. Incorrect bindings are input errors, not mathematical
rejections. This boundary preserves the production route's algebraic transforms
and complete `source_basis` with lower-sector columns; it does not reduce those
rows to the cut basis or impose the direct-DE providers' rational-only scope.
The checker may independently certify a supplied inverse by both exact matrix
identities and use the equivalent exact source equation `A.T-D[T]-T.B=0`.
Flatness and epsilon checks remain unchanged; the determinant/inverse path is
retained when no inverse certificate is established.

`PREPARE_REQUEST` accepts a normal request template whose payload can contain
`{"from_result":"../producer/result.json","artifact":"master_basis"}`.
It copies the named descriptor from a PASS or PROVISIONAL result and rebases its
path into the generated request. Literal artifact paths resolve from the template;
backend settings remain in their own referenced file. It returns
`PASS/REQUEST_READY`, without executing or checking the target scientific step.
See [request binding](skills/canon-prepare-request/SKILL.md).

`PREPARE_DERIVATIVES` returns `PASS/PHYSICAL_DERIVATIVES_READY` with standard
v2 affine records generated from routing and the physical external Gram chain
rule. The parameterization component's PREPARE calls the same core automatically.
Agents supply family definitions, not derivative records. See
[physical derivatives](docs/physical-derivatives.md) for conventions and scope.

`PREPARE_REDUCTION_TARGETS` returns `PASS/REDUCTION_TARGETS_READY` with a
`canon-neu/reduction-targets/v1` artifact containing `family_ref`, `basis_ref`,
the ordered derivative-target union, source `masters`, and symbolic `point: {}`
(WL empty list). It accepts the same affine derivatives as `BUILD_CUT_DE`.
For both steps, an explicit `prepared_derivatives` descriptor resolves from the
request; otherwise the source resolves from `prepared_family`. Point/frame
preparation retains the optional package's `PREPARE_POINT` interface.

`DISCOVER/PASS` must also provide:

```json
{
  "summary": {
    "sectors": [
      {"id": 7, "propagator_count": 3}
    ]
  }
}
```

Scripts stably sort masters by sector manifest rank; within a sector they preserve
the original Kira positions.

## Minimum result codes

`PROPOSE_INTEGRAL_CANDIDATES` is an optional candidate route before reduction.
Raw DE construction and DE providers do not depend on it. The current provider
expands the sector ID into a bit mask in full index order, calls
``DlogBasis`DlogBasisSearch``, and truncates candidate directions to the candidate
budget. The normalization convention requires
`normalization.factor ReleaseHold[exact_definition]` to reconstruct the package
combination exactly. Nonempty output is `PROVISIONAL/INTEGRAL_CANDIDATES`; no
candidates gives `INCONCLUSIVE/METHOD_EXHAUSTED`. `method_options` retains explicit
`loop_order`, `loop_dimensions`, `package_entry`, `finite_flow_package_file`, and
the existing numerator/backend options. Relative package and FiniteFlow file
paths are resolved from the input JSON directory. Optional `package_revision`
records the caller's declared source revision and is `null` when omitted. The
actual entry file's SHA-256 is always recorded.

After IBP, `ROUTE_CORE_CANDIDATES` selects an independent row basis and single-row
exchanges using the current sector's actual master rank, returning
`PROVISIONAL/CORE_CANDIDATES_ROUTED`. It does not enumerate every subset of that rank.
The sector basis must match the cut basis and occur in the bridge's source
masters with identical symbols. Declared bridge/family variables and the family
regulator must agree with the cut. A mismatch returns
`ERROR/SOURCE_BASIS_MISMATCH` before row routing. A compatible but rank-deficient
candidate pool still returns a valid empty routed pool.

`SEARCH_CORE` is a provider step and does not use the authoritative `PASS`/`FAIL`
statuses below. It emits `PROVISIONAL/CANDIDATE_TRANSFORMATION` when candidates
have been generated, `INCONCLUSIVE/OUT_OF_SCOPE` or `INCONCLUSIVE/METHOD_EXHAUSTED`
when the scope or method has not been established, and a specific `ERROR/*` for
input or tool failures. Other method-card providers follow the same single typed
protocol in `methods/README.md`.

`DIAGNOSE_CORE` returns `PROVISIONAL/CORE_DIAGNOSIS` with a
`canon-neu/core-diagnosis/v1` WL artifact: exact input identities, original
variables/regulator, active variable, scale rows, finite poles, Fuchsian status
when needed, epsilon-zero regularity, permitted transformation class and bounds.
Its structural applicability does not guarantee candidate construction.
`nonexistence_proved` is always false. Unsupported inputs return
`INCONCLUSIVE/OUT_OF_SCOPE`; a bounded construction failure returns
`INCONCLUSIVE/METHOD_EXHAUSTED`. Both retain a `method_limit` artifact naming the
reason/stage; malformed inputs return `ERROR/*`. No diagnostic claims PASS.
The [residue-balance card](methods/residue-balance/SKILL.md) defines the rational
gauge domain and exact reference-pair encoding. Its `SEARCH_CORE` output uses
the ordinary candidate contract and independent CHECK_CORE gate.

| step | PASS | Failed or unsolved |
|---|---|---|
| `PREPARE` | `OK` | None |
| `DISCOVER` | `SECTORS_READY` | None |
| `REDUCE_IBP` | `IBP_REDUCED` | `ERROR/REDUCTION_FAILED` |
| `REDUCE_CANDIDATE_IBP` | `CANDIDATES_REDUCED` | `ERROR/REDUCTION_FAILED`, or the reducer's unsolved result |
| `BUILD_CUT_DE` | `OK` | None |
| `CHECK_CORE` | `CORE_PASS` | `CORE_FAIL` |
| `BUILD_FULL_DE` | `OK` | None |
| `SOLVE_TAIL` | `TAIL_READY` | `INCONCLUSIVE/TAIL_UNSOLVED` |
| `CHECK_CANONICAL` | `CANONICAL_PASS` | `CORE_FAIL`, `TAIL_FAIL` |
| `COMMIT_SECTOR` | `OK` | None |
| `NEXT_SECTOR` | `OK` | None |
| `FINAL_CHECK` | `ALL_PASS` | None |

These codes define only the scientific method-card contract. `statemng` currently
records explicit research task states; it does not use these codes as transition
rules for an automatic scientific coordinator.

## `core-candidates/v1`

`CHECK_CORE` consumes a WL Association with the following fields. The production
IBP router and direct-DE providers share this boundary; their method domains
remain defined by their individual cards.

| Field | Constraint |
|---|---|
| `schema` | `canon-neu/core-candidates/v1` |
| `sector`, `family_id`, `basis_id`, `basis` | Match the sector cut and sector basis, including basis order; the task sector also matches |
| `variables`, `regulator` | Match the cut's ordered distinct variables and separate regulator |
| `coefficient_domain` | `exact-rational-functions` or `exact-algebraic-functions`; legacy v1 may omit it, in which case the checker infers the domain from the attempted candidate's entries |
| `convention` | `old_basis = transformation . new_basis` |
| `method` | Association with a nonempty string `id`; retain provider provenance |
| `source_basis` | Optional complete source-column order, defaulting to `basis`; unique and contains every current master, possibly with lower-sector masters |
| `candidate_group_pool` | Nonnegative integer `declared`, `eligible`, `remaining`, `unconsumed_candidates`, and Boolean `pool_exhausted` |
| `candidates` | Ordered list of candidate Associations; an empty list can report a bounded rank shortage |

Every candidate has a unique nonempty string `candidate_id` and
`construction_rejection -> None` or a nonempty string rejection signature. A rejected
construction need not provide matrices. Otherwise, `transformation` is an exact
finite square matrix in cut order and `transformed_matrices` supplies one matrix
of that size per variable. Optional `new_basis_rows` has the same square shape;
optional `full_new_basis_rows` has one row per current master and one column per
`source_basis` entry. Mathematical invertibility, gauge equality, flatness and
epsilon factorization remain the independent checker's responsibility.

The checker validates matrix shape and coefficient syntax only when it reaches
that candidate. Exact rational syntax, rational powers, algebraic numbers and
polynomial `Root` functions are supported; approximate numbers, transcendental
functions and symbolic exponents are not. A declared rational domain cannot
contain algebraic-only entries. Legacy domain inference is recorded in the
result summary and never supplies missing identities, order or pool metadata.

A malformed candidate records `input_valid -> False` and its reason, then the
checker continues in the same order. A later valid mathematical pass still
returns `CORE_PASS`; candidates after that pass are untouched. If no candidate
passes and any attempted candidate has an input error, the result is
`ERROR/INVALID_INPUT`, with `pool_exhausted -> False`,
`repair_eligible -> False` and `preferred_next_route -> "FIX_INPUT"`.
Only a fully valid exhausted pool can establish mathematical `CORE_FAIL` and
repair eligibility. The result retains invalid candidate IDs even on success.

The optional source fields describe the minimum `CHECK_CORE` input. Continuing
to `BUILD_FULL_DE` requires explicit `source_basis`, `full_new_basis_rows` and
`member_candidate_ids` for the selected candidate's full-prefix handoff.

`eligible` equals the supplied list length, and `declared` covers at least
`eligible + remaining`. `pool_exhausted -> True` requires zero upstream
`unconsumed_candidates`. That upstream count is distinct from supplied groups
not yet tested by `CHECK_CORE`: the checker stops at the first mathematical pass
and accounts for the remaining groups. Exhaustion concerns this bounded pool,
not the existence of a canonical basis in general.

[The core contract tests](tests/test_core_contract.py) contain a complete input
fixture and negative cases. The older
[tail-screen fixture](tests/fixtures/method_cards/tail-core-candidates.wl) omits
the pool and illustrates only `SCREEN_TAIL`, not a complete `CHECK_CORE` input.

## `integral-candidates/v1`

The WL artifact from `PROPOSE_INTEGRAL_CANDIDATES` has this form:

```wl
<|
  "schema" -> "canon-neu/integral-candidates/v1",
  "proposal_id" -> "stable-proposal-id",
  "family_identity" -> <|"family_id" -> "...", "family_spec_id" -> "..."|>,
  "sector_identity" -> <|
    "sector_id" -> "stable-sector-id", "id" -> 7, "propagator_count" -> 3
  |>,
  "dimension_policy" -> <|
    "spacetime_dimension" -> "D" | 4 | ..., "per_loop_policy" -> "..."
  |>,
  "numerator_or_power_counting_policy" -> <|
    "policy_id" -> "...", "definition" -> <|...|>
  |>,
  "candidate_budget" -> <|
    "maximum" -> nonNegativeInteger, "consumed" -> nonNegativeInteger,
    "unit" -> "PROVIDER_CANDIDATE"
  |>,
  "pool_exhausted" -> True | False,
  "candidate_pool" -> <|
    "available" -> n, "remaining" -> k, "pool_exhausted" -> True | False
  |>,
  "candidate_unit" -> "INDIVIDUAL_G_INTEGRAL" | "NORMALIZED_LINEAR_COMBINATION",
  "normalization_policy" -> <|"convention" -> "...", "factors" -> <|...|>|>,
  "candidates" -> {
    <|
      "candidate_id" -> "provider-stable-candidate-id",
      "exact_definition" -> HoldComplete[j[family, a1, ...]] | HoldComplete[...],
      "candidate_unit" -> "...",
      "normalization" -> <|"convention" -> "...", "factor" -> ...|>
    |>, ...
  },
  "method_evidence" -> <|"method_id" -> "...", "evidence" -> {...}|>,
  "tool_provenance" -> <|
    "tool" -> "...", "tool_revision" -> "...", "entry" -> "...",
    "entry_sha256" -> "...", "runtime" -> "..."
  |>
|>
```

The input envelope must bind the same family/sector through `family_identity`,
`sector_identity`, and top-level `sector`; output must preserve these stable
identities unchanged. `dimension_policy`, `numerator_or_power_counting_policy`,
`candidate_budget`, `pool_exhausted`, `candidate_unit`, and `normalization_policy`
are distinct fields: the provider must not silently infer one from another. The
provider treats each package `CandidateCombinations` direction as one candidate;
the candidate pool records only available directions and budget truncation. The
candidate IBP bridge preserves every ID, definition, and normalization. Groups
are generated by `BuildCoreCandidates` only after reduction and carry the scope
of their independent-row selection.

## Agent and state boundaries

`canon-neu/script-result/v1` describes only the result of a method-card call; it
does not define persistent research state or agent delegation. The `statemng`
rules in the root `AGENTS.md` and `README.md` define the sole current state
authority and handoff protocol. This interface does not create another state machine.

## Optional component routes

The default table above is unchanged. An explicitly selected manifest can expose
additional steps and a relative `workflow` instruction file. Compose manifests
with repeated `--components`, relative `extends`, or per-step `from` references;
`--describe` records the
resolved selection and instructions. These optional contracts do not convert
sampled evidence into the default exact-global-gauge acceptance scope.

| Package | Steps | Handoff |
|---|---|---|
| `parameterization` | `PREPARE` | Symbolic neutral family, reducer-family export view and prepared metadata; no native reducer project |
| `reducers/kira` | `DISCOVER`, `REDUCE_IBP` | Kira-owned project generation/execution/import, standard masters/sectors/rules |
| `reducers/blade`, `reducers/fire7`, `reducers/neatibp` | `DISCOVER`, `REDUCE_IBP`, `BUILD_CUT_DE` within the configured adapter capability | Declared native execution or saved-output import and normalization; solver/export requirements remain explicit |
| `point-de` | `PREPARE_POINT`, `BUILD_POINT_DE`, `COLLECT_DE_SAMPLES` | Prepared derivatives/targets, a full point connection and a sample-set index |
| `dlog-reconstruction` | `RECONSTRUCT_DLOG`, `PROPOSE_LETTERS`, `CHECK_RECONSTRUCTION` | Provisional constant residues and raw analytic letters; separate finite-sample verification |
| `local-jobs` | `SUBMIT_JOB`, `COLLECT_JOB`, `CANCEL_JOB`, `WATCH_COMPLETION`, `CANCEL_WATCH` | Operational job/watch handles, terminal checkpoints and callback events |

See each package's instructions under [components](docs/components.md) for
payloads, arithmetic options and method limits. Removing a package from the
selection removes its additional steps; no optional implementation is loaded
by default.

### Parameterization and backend interchange

Parameterization is selected independently of discovery, reduction and DE
construction. `family_data` is a WL `canon-neu/parameterized-family/v1` artifact:
scientific identities, canonical `integral_head`, ordered variables and slots,
dimension/regulator, symbolic routing and chart data. `reducer_family` is a JSON
`canon-neu/reducer-family/v1` export view. It contains loop/external momentum
names, propagator momentum and squared-mass expression strings, scalar products,
explicit remaining invariants and mass dimensions, and any exact point rules.
Its reference to the symbolic family is relative to the export file. A vector
chart is one possible input representation; a scalar-product chart does not
require external four-vectors. Twistor coordinates have no special backend role.

`prepared_family` keeps the standard metadata and relative scientific input
references. Available ordered masters and derivatives can be bound; an absent
input remains absent and must be produced before invoking a consumer that needs
it. Provider-specific data such as a DlogBasis `Family` still follow that
provider's documented contract. Default typed preparation accepts optional
legacy Kira provenance but does not require it.

Each backend consumes `payload.backend`, a JSON config descriptor. Its native
options and paths are defined by that adapter and resolved from that config
file. The scientific family producer does not store executables, native jobs or
backend choice. The legacy default reducer also accepts the existing inline
`reduction` object; a descriptor with `payload_key: "reduction"` can refer to
that object in its original request without changing its path base.

The shared WL target artifact is `canon-neu/reduction-targets/v1`, containing
`family_ref`, `basis_ref`, ordered `targets`, preferred `masters`, and optionally
the exact point. The candidate bridge writes this artifact, forwards public
descriptors and invokes the selected `REDUCE_IBP`. Native project copying,
target syntax and export conversion belong entirely to that adapter.

Discovery returns standard `master_basis` and `sector_manifest`. The public
``CanonMethodCard`FormatMasterArtifacts[prepared, masters, sourceHash]`` helper
groups sectors in their existing order and preserves source order inside each
sector. It uses the explicit canonical `integral_head` when present; a native
program's family identifier is a separate adapter mapping.
Neutral expression consumers and native importers interpret unqualified heads
and coordinates in the common ``CANON`DEData` `` context. The legacy default
discovery step still parses master text in ``Global` `` when `integral_head` is
declared; without it the reader uses ``CANON`DEData` ``. Use qualified WL names
in declarations and supplied expressions when an explicit context is required;
data readers preserve those names.

Reduction returns fully reduced `masters`/`rules`. When the consumer supplies a
source basis, reordered identical masters can be aligned, but a different basis
needs an explicit conversion. Unreduced target integrals, changed source basis
or equations without solved rules cannot count as completed reduction.

The generic `BUILD_CUT_DE` needs only prepared derivatives and full symbolic normalized rules,
independently of their reducer. Alternatively, a native DE adapter returns the
same complete `ordered_master_de`, `sector_basis` and `sector_cut_de` artifacts.
Keep all directions and the declared exact coefficient domain; finite-field
samples cannot be presented as a symbolic DE. Later independent scientific gates
retain their existing acceptance role.
Use fixed-point reductions with `BUILD_POINT_DE` and their explicit kinematics
binding; a constant coefficient at one point does not establish a symbolic rule.

### Point-DE and reconstruction handoff

A WL `canon-neu/de-sample/v1` Association contains `family_id`, `basis_id`,
`chart_id`, `frame_id`, an explicit `scope` Association, ordered `variables`,
`regulator`, exact `point` rules, and all directional `matrices`. Variables may
be indexed symbols such as `x[1]`. Matrices still include the regulator. The
convention is `D[basis, variables[[i]]] = matrices[[i]] . basis`. Root signs,
permutations and normalization belong to the declared basis/frame.

Point construction differentiates before specializing kinematics and includes
the derivative of a nonconstant frame: for `Jnew = R Jold`,
`Anew = (D[R] + R Aold) Inverse[R]`. Reduced targets must include candidate
projections, candidate derivatives and ordered-master derivatives. A point
reduction must identify that same point; globally symbolic rules are explicitly
declared separately. Discovery's initiate-only job is not a DE reduction job.

A WL `canon-neu/de-sample-set/v1` Association carries the shared identity,
scope, variable, regulator and convention fields plus `training`, `validation`
and optional `blind` lists. Each entry has an `id` and a `path` relative to this
index. Roles are disjoint, and different file names do not make the same
kinematic point independent. The index references samples without copying their
matrices.

`RECONSTRUCT_DLOG` reads training data and raw analytic letter definitions. Its
provisional artifact retains rational constant residues, explicit expressions,
arithmetic settings and source bindings. `CHECK_RECONSTRUCTION` independently
differentiates the original letters and checks the complete matrices in all
directions against original samples, including validation data. Its scoped
`PASS/RECONSTRUCTION_VALIDATED` is not `PASS/ALL_PASS`, an all-kinematics gauge
proof, a UT proof or an alphabet-completeness claim. Rank insufficiency and an
unrepresented residual return to the package's sampling/letter route.

### Detached execution handoff

`SUBMIT_JOB` returns `PROVISIONAL/JOB_SUBMITTED` and an immutable handle; the child
later writes the scientific step's own `result.json`. Collection references that
result without launching the calculation again. A valid zero-exit call can
contain a scientific `FAIL` or `INCONCLUSIVE`; the scientific result is preserved
and routed by its own code. Operational completion never grants acceptance.

Terminal checkpoints and completion events carry job/run identity. Watchers run
only declared checks and callbacks and keep a durable event/delivery record.
An acknowledged callback proves delivery only; it does not prove a model turn
executed or a scientific result passed. A coordinator may resume a deferred
worker with its existing run ID; only the normal state MCP review/acceptance
operations change the research task's status.

## Scientific input and library contracts

The following programs handle only mathematical inputs and ordinary files. The
calling agent runs them in its assigned workspace and registers results to retain
through `statemng`.

### Production typed family preparation

The `family_spec` for `PrepareFamily.wls` is a trusted Wolfram Association with
`family_ref`, `basis_ref`, `topology`, `parameters`, `variables`, `regulator`,
`dimension_rule`, `index_order`, `propagator_slots`, `sector_convention`, `kira`,
`family_data`, `prepared_derivatives`, and `ordered_masters`. Kira fields must
match the existing project/jobs; `family_data`, derivatives, and masters are
source file paths. Relative resource paths in the spec, including `kira.project`,
are based on the spec directory; Kira jobs/config/targets are relative to that
project. `propagator_slots` uses one-based positions in the full index list. The
new general interface does not read `sector_source` or literature basis indices.

`DiscoverSectors.wls` computes `sector_bits` in full index order from the ordered
master list, with ISP bits set to zero; `id = sector_bits . 2^Range[0,n-1]`.
Each sector reports both `propagator_count` and `master_count`. Sectors are sorted
by `(propagator_count,id)`, preserving the original relative master order within
each sector.

### Derivative operator selection

```wl
Get[FileNameJoin[{repoRoot, "mma", "lib", "BaikovDerivative.wl"}]];
choice = ChooseDerivativeOperator[prepared, variable]; (* default enhanced-first *)
affine = ChooseDerivativeOperator[prepared, variable, "prepared-affine"];
```

`prepared` supplies an affine denominator operator and, for the default
`"enhanced-first"` selection, bounded enhanced-Baikov membership data. These are inputs to candidate derivative
compilation, not inputs to `methods/dlogbasis/run.wls`.

The `operators` Association maps each declared variable to one record per
denominator/ISP slot, in the full index order. Each record has `constant` and
`linear`; each linear term has `denominator` (one-based slot) and `coefficient`.
Use the same symbol contexts, variable order and dimension convention as the
prepared family and reduction.

The `exact_strategy` Association supplies:

| Field | Value to prepare from the family |
|---|---|
| `baikov_variables` | One symbolic `z` variable per full propagator/ISP slot, in index order. |
| `propagator_slots` | The same protected slots declared by the prepared family. |
| `loop_count` | Number of independent loop momenta. |
| `independent_external_count` | Number of independent external momenta after momentum conservation. |
| `fixed_scale_substitutions` | The declared fixed-scale rules, or `{}` if no scale is fixed. |
| `external_gram_determinant` | The Gram determinant of those independent external momenta. |
| `baikov_polynomial` | The determinant of the Gram matrix of loop and independent external momenta, expressed in the declared `z` variables and kinematics. Use the full determinant convention of the bridge's measure below. |
| `search_max_total_degree` | A declared nonnegative integer bounding the cofactor search. |

To prepare the polynomial, solve the propagator/ISP definitions for the
loop-dependent scalar products, substitute them into that Gram determinant,
and apply the declared kinematic/fixed-scale rules consistently. The default
`"enhanced-first"` selection requires these family-derived Gram expressions and
a nonnegative search degree. Its bounded membership calculation determines
whether to return an enhanced operator or the affine fallback.

An exact zero-growth solution returns:

```wl
<|"kind" -> "enhanced-baikov", "cofactors" -> {...}, "f_cofactor" -> ...|>
```

Finding no solution within the declared degree is not an error; it returns:

```wl
<|"kind" -> "affine-fallback", "operator" -> prepared["operators", variable]|>
```

An explicit `"prepared-affine"` selection returns the supplied affine records
without calling the enhanced search:

```wl
<|"kind" -> "prepared-affine", "operator" -> prepared["operators", variable],
  "enhanced_search_attempted" -> False|>
```

The selector needs only the requested affine operator for this mode. Candidate
compilation also requires `exact_strategy.propagator_slots` for target metadata;
it does not consume or validate the unused enhanced-search polynomial, Gram,
or search-degree fields. This choice is not a failed or exhausted enhanced
search. An unknown selection returns `DERIVATIVE_OPERATOR_INVALID`.

For the default selection, a missing or malformed `exact_strategy` returns a preparation failure; a valid
bounded search with no enhanced solution returns `affine-fallback`. For a
preparation failure, retain the integral candidates, supply the required fields
and resume their bridge.

The package does not generate Kira targets, run IBP, or construct DEs. Conversion
from cofactors to reducer targets belongs to the replaceable preparation interface
supplied by collaborators.

### Candidate derivatives and IBP bridge

```text
python3 run_step.py INPUT.json OUTPUT_DIR
```

Set `step` to `REDUCE_CANDIDATE_IBP`. Its payload contains four WL descriptors:
`integral_candidates`, `prepared_family`, `master_basis`, and
`prepared_derivatives`, plus the selected reducer configuration or an existing
`ibp_reduction` descriptor as described below.
The optional `payload.derivative_operator_selection` is `"enhanced-first"`
(the default) or `"prepared-affine"`. It applies to all declared variables and is
recorded through the existing per-variable `operators` evidence. The WL compiler
accepts the same selection as its optional fifth argument. A selector preparation
failure, including an unknown selection or missing requested operator, returns
`ERROR/DERIVATIVE_OPERATOR_INVALID` before targets or a nested reducer request
are written.
The result exposes `candidate_ibp_bridge` in the common artifact map.
The default bridge calls `REDUCE_IBP` through the selected component package.

An optional `payload.ibp_reduction: {"path": "rules.wl"}` explicitly selects reuse
of an already normalized symbolic reduction. No backend configuration is needed
and no reducer is launched. The bridge still compiles and publishes the current
targets first. The supplied WL Association must contain `masters` in exactly the
declared source order and distinct explicit integral `rules`. Optional
`family_ref` and `basis_ref` must match when present. One rule substitution must
leave source masters unchanged and reduce every compiled non-master target to a
linear combination of those masters. Identity rules for masters are unnecessary;
rules requiring recursive back-substitution are not normalized inputs.

Incomplete closure returns `INCONCLUSIVE/INCOMPLETE_REDUCTION`, with
`unresolved_targets` and `target_images` as readable WL strings. Invalid rules or
incompatible identities/order return an explicit `ERROR`. Reuse failures retain
`reduction_targets`, produce no passing bridge, and never launch a fallback
reducer. Successful reuse returns the same `CANDIDATES_REDUCED` bridge/target
artifacts. These checks establish closure relative to the supplied rules; their
IBP truth and symbolic scope remain the caller's pinned scientific inputs.

Input candidates are the linear combinations of `j[family,a1,...,an]` supplied by
the DlogBasis-refine adapter. The bridge maps them to the declared Kira topology
head, preserving the overall rational prefactor, `candidate_id`, and signed
indices. For each variable it uses only the actual return value of
`ChooseDerivativeOperator`. The affine branch uses the declared denominator
derivative; the enhanced-Baikov branch sets

```wl
lambda = (d-L-E-1)/2; kappa = (E-d+1)/2;
v_i = If[MemberQ[propagatorSlots,i], z_i c_i, c_i];
weight = kappa D[Gext,x]/Gext + lambda cF +
  Sum[a_i v_i/z_i - D[v_i,z_i], {i,n}];
```

and applies `z^m I[a] = I[a-m]` term by term. Thus actual proper-subsector tails
from protected `z_i c_i` must not be removed before sector filtering. ISP indices
retain Kira's negative-sign convention unchanged. Candidate linear combinations
also include explicit `D[prefactor,x]` terms.

A successful `canon-neu/candidate-ibp-bridge/v1` carries only family/basis/topology
identities, slot order, sector convention, per-variable operator choices, ordered
masters, exact reducer targets for candidate derivatives and all ordered-master
affine derivatives, fully back-substituted rules, the candidate pool, and, for each
`candidate_id`, its original definition, topology expression, derivatives, target
metadata, reduced expression, and reduced derivatives. Target metadata has exactly
`integral`, `indices`, `sector_mask`, and `numerator_indices`. This artifact records
IBP closure; it does not establish that the candidates are UT, a canonical basis,
or a complete master basis.

### Core, full prefix, and tail

`RouteCoreCandidates.wls` consumes `prepared_family`, `sector_basis`,
`sector_cut_de`, and `candidate_ibp_bridge`. After IBP, candidate rows are first
projected onto resident current-sector masters; an independent basis and its
independent single-row exchanges are then selected. Lower-sector coefficients
remain in `full_new_basis_rows`, whose columns follow the top-level `source_basis`
order. Every group has `T=Inverse[R]` with `old_basis=T.new_basis`. This group pool
is a bounded selection space; exhausting it does not exhaust all integral representatives.

The direct CANONICA/Libra/INITIAL providers use the same `source_basis`,
`full_new_basis_rows`, and `member_candidate_ids`; their source basis may contain
only current-sector masters. `BuildFullSectorDE.wls` embeds rows into the raw
prefix using the explicit source-basis mapping, with zero coefficients for
missing columns. It reuses the full `ordered_master_de` without repeating IBP or
DE construction. The checked core binds the same cut identities and exactly
one selected candidate. Malformed unused proposals remain rejected completion
records with their original IDs and `full_transformation -> None`. The selected
proposal's full current-sector rows must be the exact inverse of its checked
transformation; an inconsistent row map is `ERROR/INVALID_CORE_COMPLETION`
and requires input repair. An inverse proposal ignored by CHECK_CORE does not
override the full integral-row definition.

If `old_lower=Tlower.accepted_lower`, first use `T0=diag(Tlower,I)` to obtain the
mixed prefix DE. The full candidate rows are
`{{I,0},{Rlower.Tlower,Rcurrent}}`, whose inverse is `Tfull`. Output retains
`canon-neu/full-prefix-candidates/v1`, including `source_matrices`,
`block_boundaries`, and candidate completions. `declared_alphabet` must explicitly
provide a descriptor or `null`; the latter leaves SOLVE_TAIL to propose pole-factor
and supported quadratic-root letters. Explicit `letters` may include Wolfram
radical expressions.

`SolveTail.wls` consumes `full_sector_de`, `core_transform`, and
`method_options.package_entry` when a CANONICA call is needed. Supported algebraic
primitives, scalar root repairs and multi-master derivative completions are
attempted internally. Remaining rational inputs can use `TransformOffDiagonalBlock`
and `TransformDlogToEpsForm`; unresolved algebraic inputs return a method-domain
reason. The [tail skill](skills/canon-solve-tail/SKILL.md) defines these scopes.
The solver composes the full transformation and requires neither candidate-pool exhaustion
nor a dotted replay. If solving produces no transformation, it returns
`INCONCLUSIVE/TAIL_UNSOLVED`; a resulting `sector_transform` goes to `CHECK_CANONICAL`.
An unresolved result includes `summary.reason` and `summary.diagnostics`:
`current_master_count`, `epsilon_factorized`, `affine_in_epsilon`,
`rational_coefficients`, and `alphabet_candidate_count`. These describe the
retained attempted matrices, not all possible representatives. Use the
[tail skill](skills/canon-solve-tail/SKILL.md) to choose the next bounded action.

Tail-specific `method_options` additionally accept `tail_strategy` (default
`"monolithic"`, optional `"subsector"`), nonnegative integer
`d_delta_numerator_degree` (0), positive `max_wall_seconds` (60), and positive
integer `max_subsector_steps` (64) and `max_ansatz_terms` (256). Unknown keys
are input errors. An explicit step budget, `d_ansatz` or `tail_checkpoint`
requires subsector strategy. In that strategy, public
`SectorBoundariesFromDE` partitions the actual active transformed lower matrix;
`CalculateNextSubsectorD` accumulates D one lower block at a time, then the
complete lifted transform undergoes full-prefix epsilon normalization.

`TAIL_UNSOLVED` can return a hashed
`canon-neu/canonica-tail-checkpoint/v1` artifact. It stores `binding`,
`previous_d`, `completed_lower_blocks`, `attempted_ansatz`, and `diagnostics`.
Its binding includes exact source identity/byte hash, variable order, package
entry hash, active rows and boundaries, transformed backend hash and base-map
hash. Resume with its `payload.tail_checkpoint` descriptor. Hash, source,
partition, row/column dimensions and rational domain are validated before
continuation. A different finite D ansatz can address remaining blocks on the
same source; partial progress has no independent canonical acceptance. The
complete resumed map still goes to CHECK_CANONICAL and FINAL_CHECK.

`CheckCanonical.wls` recomputes the full gauge transformation from
`source_matrices` and `sector_transform`, uses `sector_transform["alphabet"]`,
and checks epsilon factorization, shared constant residues, and prefix closure.
Lower-sector normalization changes are accepted as part of the full
transformation, with no separate freezing constraint. Flatness is checked using
exact symbolic curvature for every variable pair. When the full check fails,
failure of the current-current block distinguishes `CORE_FAIL` from `TAIL_FAIL`.

`CommitSector.wls` records `Taccepted=diag(Tlower,I).Tfull`, the complete new basis,
and the checked matrices; it does not force lower blocks back to their previous
values. Previous artifacts remain unchanged, and one entry is appended to the
sector/candidate trace. `NextSector.wls` computes the next item from the manifest
and trace; iteration and persistence remain the responsibility of the main agent
and `statemng`.

`CheckFullSystem.wls` recomputes the global gauge transformation from the original
full DE and cumulative transformation. It calls `DLogResidues`, shared with the
sector checker, to solve jointly for constant residues in all variables and
reconstruct exactly. Only `ALL_PASS` outputs `canonical_basis` and `canonical_de`.
Exact algebraic expressions use Wolfram differentiation, simplification, and
`SolveAlways` directly; no additional algebraic-field or branch-management layer
is constructed.

### IBP reduction

```text
python3 run_step.py INPUT.json OUTPUT_DIR
```

Set `step` to `REDUCE_IBP`. The default Kira component reads the following seven
fields from `payload.reduction` (also used by `REDUCE_CANDIDATE_IBP`):

| field | meaning |
|---|---|
| `executable` | Reducer executable or command name supplied by the collaborator |
| `project` | Prepared Kira project |
| `jobs` | Two project-relative job files in execution order |
| `topology` | Kira topology / Wolfram integral head name |
| `targets` | Project-relative target list |
| `output` | Kira working directory that does not yet exist |
| `options` | Individual argv entries passed to Kira, such as `--parallel=1`; the caller sets the thread count within its resource budget |

`project`, `output`, and an `executable` containing a path separator are resolved
relative to the request JSON directory. An `executable` supplied as a command name
alone is found on PATH. `jobs` and `targets` are relative to the Kira project.
The candidate IBP bridge uses the same rules; the output directory on the command
line remains relative to the caller's working directory.

See `interfaces/ibp-request.example.json` for an example. The adapter trusts the
collaborator's prepared project and Kira output, copies the project, runs the two
argv jobs in order, and directly reads ordered `masters.final` and exported rules.
The caller's positive scientific tests check exact target coverage, master order,
and RHS closure.

On success, `result.json` reports `PASS/IBP_REDUCED` and an `ibp_reduction`
descriptor. The referenced WL artifact contains only:

```wl
<|"masters" -> orderedMasters, "rules" -> fullyReducedRules|>
```

The adapter preserves Kira's `masters.final` order. It performs no additional
mathematical checks. The old positional IBP invocations are superseded by the
common envelope; the scientific WL contents remain the same.

### Differential equation construction

```wl
Get[FileNameJoin[{repoRoot, "mma", "lib", "DEBuilder.wl"}]];
result = BuildDifferentialEquations[family, masters, rules];
```

`family` must contain exactly the declared parameters and ordered affine operators:

```wl
<|
  "parameters" -> {d, x1, x2, ...},
  "operators" -> <|x1 -> C1, x2 -> C2, ...|>
|>
```

For integrals with `m` indices, each `Cx` must have dimensions `m x (m+1)`,
representing `d D_i/dx = Cx[[i,1]] + Sum_j Cx[[i,j+1]] D_j`. `masters` fixes matrix
order. Immediate `rules` must already be fully back-substituted to these masters,
with all coefficients in the declared rational-function field.

Matrices use `D[masters,x] == A_x . masters`. For each variable pair, symbolic
differentiation is performed first; the dimension and all kinematic variables are
then assigned at the single explicit exact point `{Prime[i]/Prime[i+1]}` in full
ordered-parameter order. There are no retries or alternative points, so this
establishes only the recorded exact-point samples.

Successful output contains only:

```wl
<|
  "matrices" -> <|x1 -> A1, x2 -> A2, ...|>,
  "validity" -> <|
    "scope" -> ..., "flat" -> True | False,
    "pairs" -> {<|"variables" -> {...}, "assignments" -> {...}, "zero" -> ...|>, ...}
  |>
|>
```

The DE core does not read or write files, run a reducer, generate targets, search
for operators, or produce path, hash, provenance, sector, or artifact information.

### Current-sector cut DE

```text
wolframscript -file mma/BuildSectorCutDE.wls INPUT.json FRESH_OUTPUT_DIR
```

`prepared_family` must explicitly carry `regulator` and `dimension_rule`; for
example, `eps` and `d -> 4 - 2 eps` for a two-loop five-point case. The script does
not infer them from symbol names. It converts accepted prepared derivative
records into the affine matrices above and calls `BuildDifferentialEquations`
exactly once with the original order of `master_basis["masters"]` and
`ibp_reduction["rules"]`. It applies `dimension_rule` only after constructing the
full DE.

The requested sector's positive-index bits are compared exactly with each
master's propagator bits. Matching positions preserve resident/Kira order and
select both matrix rows and columns:

```wl
masterBits = SectorBits[#, propagatorSlots] & /@ masters;
positions = Flatten @ Position[masterBits, currentBits];
cutMatrices = (#[[positions, positions]] & /@ orderedMatrices);
```

Thus all dots, numerators, and linear mixtures within the sector are retained.
Column projection quotients out only the strict proper-subsector tails declared
by the manifest. `proper_subsectors` explicitly lists these proper subsectors;
`sector_boundaries` is the row-index interval `{{1,n}}` of the current matrix.
Output is:

```wl
<|
  "schema" -> "canon-neu/sector-basis/v1",
  "sector" -> <|"id" -> ..., "propagator_count" -> ...|>,
  "family_id" -> familyRef,
  "basis_id" -> basisRef <> "/sector-" <> ToString[sectorID],
  "basis" -> currentSectorMasters
|>
```

along with `canon-neu/sector-cut-de/v1` carrying the same identity and basis. Its
ordered `variables`, explicit `regulator`, exact-rational `matrices`, and
`sector_boundaries` follow `D[basis,variable[[i]]] == matrices[[i]].basis`. The same
call also writes `canon-neu/ordered-master-de/v1`, retaining the full master basis,
matrices, and DEBuilder validity for direct reuse by `BUILD_FULL_DE`. This artifact
establishes only this quotient block and the exact validity scope recorded by
DEBuilder; it does not establish UT, canonical form, global IBP completeness, or
a full canonical system.

### Independent targets for the raw DE

```wl
Get[FileNameJoin[{repoRoot,"mma","lib","CandidateIBPBridge.wl"}]];
targets = CANON`CandidateIBPBridge`MasterDerivativeTargets[masters, preparedDerivatives];
```

This function generates the required derivative integrals using only masters
and existing affine operators, excluding terms already in the master basis.
Passing these targets to `ReduceIBP.wls` in the reducer's integral text format
provides `ibp_reduction` for `BUILD_CUT_DE` independently of LS candidates.
