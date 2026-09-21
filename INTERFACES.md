# Mathematica script interfaces

This document defines interfaces, not algorithms, internal functions, or implementation
details. The first part describes the typed method-card envelope. The direct IBP/DE
interfaces at the end are a stateless scientific adapter layer; they do not accept
that envelope or define another research state machine.

## Common invocation

```text
wolframscript -file <script.wls> <input.json> <output_dir>
```

Implemented scripts must write the common result format to `<output_dir>/result.json`.
Use `.wl` for scientific artifacts where possible; Python passes their paths without
reading their contents.

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
`INCONCLUSIVE`, `PROVISIONAL`, `FAIL`, or `PASS`. Providers may emit only codes
allowed by their cards within the first three categories; they cannot emit `PASS`
or `FAIL`. Independent checkers retain final `PASS`/`FAIL` authority. Artifact
paths are relative to the directory containing `result.json` and are resolved by
the method-card caller. `statemng` neither parses scientific `result.json` files
nor automatically advances the scientific stage graph based on their codes.

## Skills, payloads, and outputs by step

| step | SKILL | script | payload keys | artifact keys |
|---|---|---|---|---|
| `PREPARE` | `canon-prepare-family` | `mma/PrepareFamily.wls` | `family_spec` | `prepared_family` |
| `PROPOSE_INTEGRAL_CANDIDATES` | `canon-dlogbasis-integral-candidates` | `methods/dlogbasis/run.wls` | `family_identity`, `sector_identity`, `prepared_family`, `dimension_policy`, `numerator_or_power_counting_policy`, `candidate_budget`, `candidate_unit`, `normalization_policy`, `method_options` | `integral_candidates` |
| `DISCOVER` | `canon-discover-sectors` | `mma/DiscoverSectors.wls` | `prepared_family` | `sector_manifest`, `master_basis` |
| `BUILD_CUT_DE` | `canon-build-cut-de` | `mma/BuildSectorCutDE.wls` | `prepared_family`, `master_basis`, `sector_manifest`, `ibp_reduction` | `sector_basis`, `sector_cut_de`, `ordered_master_de` |
| `SLICE_CUT_DE` | `canon-build-cut-de` | `mma/SliceSectorCutDE.wls` | `ordered_master_de`, `sector_manifest` | `sector_basis`, `sector_cut_de` |
| `ROUTE_CORE_CANDIDATES` | `canon-search-core` | `mma/RouteCoreCandidates.wls` | `prepared_family`, `sector_basis`, `sector_cut_de`, `candidate_ibp_bridge` | `core_candidates` |
| `SEARCH_CORE` | `canon-search-core` | `methods/*/run.wls` | `prepared_family`, `sector_basis`, `sector_cut_de`, `method_options` | `core_candidates` |
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

`SEARCH_CORE` is a provider step and does not use the authoritative `PASS`/`FAIL`
statuses below. It emits `PROVISIONAL/CANDIDATE_TRANSFORMATION` when candidates
have been generated, `INCONCLUSIVE/OUT_OF_SCOPE` or `INCONCLUSIVE/METHOD_EXHAUSTED`
when the scope or method has not been established, and a specific `ERROR/*` for
input or tool failures. Other method-card providers follow the same single typed
protocol in `methods/README.md`.

| step | PASS | Failed or unsolved |
|---|---|---|
| `PREPARE` | `OK` | None |
| `DISCOVER` | `SECTORS_READY` | None |
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

## Direct IBP/DE interfaces

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
choice = ChooseDerivativeOperator[prepared, variable];
```

`prepared` supplies both an affine denominator operator and bounded
enhanced-Baikov membership data. These are inputs to candidate derivative
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
and apply the declared kinematic/fixed-scale rules consistently. Both selector
branches require these family-derived Gram expressions and a nonnegative search
degree. The bounded membership calculation determines which branch applies.

An exact zero-growth solution returns:

```wl
<|"kind" -> "enhanced-baikov", "cofactors" -> {...}, "f_cofactor" -> ...|>
```

Finding no solution within the declared degree is not an error; it returns:

```wl
<|"kind" -> "affine-fallback", "operator" -> prepared["operators", variable]|>
```

A missing or malformed `exact_strategy` returns a preparation failure; a valid
bounded search with no enhanced solution returns `affine-fallback`. For a
preparation failure, retain the integral candidates, supply the required fields
and resume their bridge.

The package does not generate Kira targets, run IBP, or construct DEs. Conversion
from cofactors to reducer targets belongs to the replaceable preparation interface
supplied by collaborators.

### Candidate derivatives and IBP bridge

```text
wolframscript -file mma/ReduceCandidateIBP.wls \
  INTEGRAL-CANDIDATES.wl PREPARED-FAMILY.wl MASTER-BASIS.wl \
  PREPARED-DERIVATIVES.wl REQUEST.json RESULT.wl
```

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

The direct CANONICA/Libra providers use the same `source_basis`,
`full_new_basis_rows`, and `member_candidate_ids`; their source basis may contain
only current-sector masters. `BuildFullSectorDE.wls` embeds rows into the raw
prefix using the explicit source-basis mapping, with zero coefficients for
missing columns. It reuses the full `ordered_master_de` without repeating IBP or
DE construction.

If `old_lower=Tlower.accepted_lower`, first use `T0=diag(Tlower,I)` to obtain the
mixed prefix DE. The full candidate rows are
`{{I,0},{Rlower.Tlower,Rcurrent}}`, whose inverse is `Tfull`. Output retains
`canon-neu/full-prefix-candidates/v1`, including `source_matrices`,
`block_boundaries`, and candidate completions. `declared_alphabet` must explicitly
provide a descriptor or `null`; the latter leaves SOLVE_TAIL to propose pole-factor
and supported quadratic-root letters. Explicit `letters` may include Wolfram
radical expressions.

`SolveTail.wls` consumes only `full_sector_de`, `core_transform`, and
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
wolframscript -file mma/ReduceIBP.wls REQUEST.json RESULT.wl
```

The request must have exactly seven fields:

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
The candidate IBP bridge uses the same rules; the result file path on the command
line remains relative to the caller's working directory.

See `interfaces/ibp-request.example.json` for an example. The adapter trusts the
collaborator's prepared project and Kira output, copies the project, runs the two
argv jobs in order, and directly reads ordered `masters.final` and exported rules.
The caller's positive scientific tests check exact target coverage, master order,
and RHS closure.

The successful result contains only:

```wl
<|"masters" -> orderedMasters, "rules" -> fullyReducedRules|>
```

The adapter does not probe versions, compute hashes, save logs/provenance/sector
manifests, or change research state. Master order preserves Kira's `masters.final`
unchanged.

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
