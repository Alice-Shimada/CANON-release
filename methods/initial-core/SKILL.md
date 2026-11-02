---
name: canon-initial-seeded-core
description: Produce a rational single-variable core transformation from explicitly sourced normalized UT seeds through one bounded INITIAL attempt.
---

# INITIAL seeded core

- **Role / stage:** direct-DE transformation provider, `SEARCH_CORE`.
- **Activation:** selected under [core selection](../../skills/canon-search-core/SKILL.md) or by explicit request, with
  one or a few already normalized UT seeds and a declared rational alphabet.
- **Scope:** one variable, finite exact rational cut DE, independent selected
  seed projections and a full-rank derivative matrix for the stated allocation.
- **Attempt:** one `INITIAL` `TCalc` call with explicit threads, iteration,
  reconstruction degree/prime and time budgets. No seed selection, alphabet
  inference, automatic retry or normalization search.
- **Handoff:** `PROVISIONAL/CANDIDATE_TRANSFORMATION` with standard
  `core_candidates` to `mma/CheckSectorCore.wls` (`CHECK_CORE`). The independent
  gate decides acceptance; provider diagnostics never establish a core pass.

Use the stable [INITIAL entry](../initial/SKILL.md) at `methods/initial/run.wls`
with `SEARCH_CORE`. The direct `methods/initial-core/run.wls` address remains
the same scientific contract. The original fixed official validation lives in
[the example directory](../../methods/initial/reference/README.md), with
legacy `PROVIDE_UT_EVIDENCE`/`CHECK_UT_EVIDENCE` compatibility addresses.
This provider has no reference-equality
gate. It covers rational systems, not elliptic epsilon forms or multivariable
systems. A failed allocation, degree condition or reconstruction is a method
limit and is never a proof that a seed is non-UT.

## Input artifacts

Use `canon-neu/script-input/v1`, step `SEARCH_CORE`, and the resident `sector`.
All artifact descriptors carry `path` and may carry `sha256`. Relative paths
resolve from the declaring JSON. A supplied hash must match; actual hashes are
always recorded. Files are read in place.

`payload.sector_basis` and `payload.sector_cut_de` use the ordinary main-pipeline
schemas and must agree on sector, family, basis ID and ordered basis. The cut
declares `coefficient_domain -> "exact-rational-functions"`, one distinct
symbolic variable, and a separate symbolic regulator.

`payload.seed_request` is a WL Association with schema
`canon-neu/initial-seed-request/v1`. It binds the cut's exact `sector`,
`family_id`, `basis_id`, `basis`, `variables`, and `regulator`, and declares:

```wl
"seed_ids" -> {"normalized-seed"},
"derivative_counts" -> {n},
"letters" -> {x, 1+x}
```

IDs are nonempty and unique. Counts are positive integers with total equal to
the cut dimension; each count is the number of derivatives starting at the
first derivative of that seed, as in INITIAL's Psi convention. Seeds are used
in the exact requested order. The finite list can contain up to `n` seeds.

Declare the ansatz using either `seed_request.letters` or
`payload.declared_alphabet`, an ordinary WL Association with `letters`; the two
are mutually exclusive. Letters must be distinct, nonzero, nonconstant exact
rational functions of the variable and must not contain the regulator. The
provider passes `D[letter,x]/letter` to INITIAL without inferring missing letters.

Choose exactly one seed source:

1. `payload.seed_rows`: schema `canon-neu/initial-seed-rows/v1`, the same six
   identity/order fields as `seed_request`, an explicit unique `source_basis`
   containing every current master, and `seeds`. Each seed record has `id`,
   `full_new_basis_row` (exact rational coefficients in `source_basis` order),
   and `normalization_evidence`. Extra source columns may be proper-subsector
   masters. They are retained through composition and `BUILD_FULL_DE`.
2. `payload.candidate_ibp_bridge` plus `payload.prepared_family`: ordinary
   `canon-neu/candidate-ibp-bridge/v1` and `canon-neu/prepared-family/v1`
   artifacts. `prepared_family.family_ref` must equal the cut's `family_id`;
   the bridge and prepared family must agree on `family_ref`, `basis_ref`,
   variables and regulator. For each requested seed ID, the provider substitutes
   `prepared_family.dimension_rule` into `reduced_expression` and extracts a
   full linear coefficient row in `bridge.masters` order, rejecting residual
   unreduced or nonlinear terms. `seed_request.normalization_evidence` must be
   an Association keyed by every requested seed ID. An ordinary Dlog candidate
   or finite-cut rank statement alone does not establish a normalized UT seed.

Every selected normalization record has this explicit evidence contract:

```wl
<|"status" -> "established", "kind" -> "official-reference",
  "statement" -> "The supplied full row uses the cited UT normalization.",
  "source" -> <|"path" -> "normalization-receipt.wl", "sha256" -> "64 hex digits"|>|>
```

Allowed kinds are `official-reference`, `integrand-dlog-leading-singularities`,
`independent-initial-picard-fuchs`, and `weight-graded-boundary-lower-sector`.
The source is a real immutable evidence file, with its hash checked. Its path
resolves from `seed_rows` or `seed_request`, according to where the evidence is
declared. This is a caller's explicit established-normalization premise; the
adapter does not turn a provisional candidate into a proved UT integral.

## Runtime options and command

`payload.method_options` requires all these explicit fields:

```json
{
  "package_entry": "path/to/INITIAL.m",
  "finite_flow_package_file": "path/to/FiniteFlow.m",
  "finite_flow_library": "path/to/fflowmlink-native-library",
  "initial_identity": "declared INITIAL revision",
  "finiteflow_identity": "declared FiniteFlow revision",
  "threads": 4,
  "timeout_seconds": 300,
  "max_iterations": 20,
  "max_degree": 1000,
  "max_primes": 150
}
```

Paths resolve from the input JSON. Identities must be nonempty; they describe
the caller's declared installation rather than being inferred from CANON's Git
HEAD. Actual component entry/native hashes, runtime identity, seed and basis
hashes, evidence sources, source rows, options and input artifact hashes are
stored in candidate provenance. All counts/budgets must be positive integers.
Unknown option keys return `ERROR/INVALID_OPTIONS`; there is no default thread
count or hidden increase of bounds.

```bash
python3 run_step.py INPUT.json NEW_OUTPUT_DIR --method initial
```

The output must be new, its parent existing and writable, and outside component
and referenced-input/evidence directories. Unsafe locations are rejected
before any result writer touches them. Protection covers physical file targets
and directory aliases; a malformed evidence hash cannot enable output in its
declared source directory. INITIAL and FiniteFlow installations
are read-only. The declared native library is explicitly located and its
actual loaded path checked. Computation works in the output directory.

The shared [INITIAL runtime loader](../../mma/lib/InitialRuntime.wl) recognizes
the exact INITIAL 2.1 source hash documented in [INTERFACES](../../INTERFACES.md)
and repairs its empty first training batch by assigning rank zero in memory.
Unknown or already-changed sources load directly from their original path.
No source file, thread count or finite budget is changed. Candidate provenance
`method.initial_runtime` and diagnostics record the original source hash
and adapter id/path/hash/applied flag. The native official isomorphic regression
sets one thread explicitly to cover this defect; CHECK_CORE remains independent.

## Algebra, result and limits

The selected seed cut projections are completed with resident identity rows
to an invertible `R_cut`; completion rows have zero lower-sector coefficients
in `R_full`. The provider constructs

```wl
A_seed = (D[R_cut,x] + R_cut.A).Inverse[R_cut];
T_core = Inverse[R_cut].T_initial;
full_new_basis_rows = Inverse[T_initial].R_full;
```

INITIAL `TakeRow` is `1` for one seed and `{{1,k1},{2,k2},...}` for several
seeds, referring to intermediate row numbers rather than coefficient vectors.
The exact Psi matrix must have rank `n` before the tool is called. The full rows
are checked against `Inverse[T_core]` on current columns. No lower column is
discarded or renormalized by the provider.

A regular exact rational point with rank `n` is a certificate that the symbolic
determinant is not identically zero. Failed finite points do not establish rank
deficiency; the provider then attempts symbolic rank within the same budget.
FiniteFlow `FFInvMatMul` reconstructs `Inverse[T_initial].R_full`, which is
proved by the exact identity `T_initial.full_new_basis_rows == R_full` and both
inverse identities on current columns. This avoids a large symbolic inverse
without weakening the composition or full-row check.

Publication requires exact source and intermediate gauge identities,
invertibility, epsilon factorization and dlog membership in the declared
alphabet. The output is one ordered core candidate with a stable ID derived
from its explicit seed source and alphabet; it still awaits `CHECK_CORE`.

Invalid identity/order, rows, reduction, normalization evidence or hashes return
specific `ERROR` codes. Multivariable scope is `INCONCLUSIVE/OUT_OF_SCOPE`.
Dependent seed projections, deficient Psi, exhausted time/degree/reconstruction
bounds or failed publication checks return `INCONCLUSIVE/METHOD_EXHAUSTED`.
Diagnostics record the failure stage, exact ranks where available, degree and
prime bounds, capped package messages and reconstruction state. The provider
never outputs mathematical `PASS` or `FAIL`, calls another method, or retries.
Headless display messages, including INITIAL's monitor warnings, are diagnostic;
they do not replace return-shape and exact-matrix publication checks.
