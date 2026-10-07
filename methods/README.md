# Method cards: capabilities and I/O

Start at [the workflow entry](../skills/canon-workflow/SKILL.md) to choose the
next operation. This page catalogs method capabilities and their contracts;
it does not define another routing order. The
[workflow guide](../docs/agent-workflow.md) describes the complete study, and
[INTERFACES.md](../INTERFACES.md) defines script envelopes and scientific I/O.

For integral-basis discovery from a defined family, choose from its geometry
and current evidence. Small dot/normalization bundles, Gram constructions and
bounded DlogBasis-refine searches share the same downstream acceptance gates;
none is a prerequisite for every sector. The workflow entry also describes
direct-DE choices. When DlogBasis is selected, package loading or
`CreateDlogFamily` alone is preparation, not a `DlogBasisSearch` attempt.
Retain the bounds and results that motivate later choices, and reuse accepted
sectors.

## Main methods

| Card | Trigger and operation | Required input | Output and next gate |
|---|---|---|---|
| [Dot/normalization proposal](../skills/canon-search-core/SKILL.md#2-prepare-and-execute-the-integral-route-in-order) | A small geometry-motivated integral bundle | Exact index order, selected dots, prefactors and epsilon normalization with finite bounds | Manually encoded `integral_candidates`; same IBP/core/full-prefix gates. No standalone runner |
| [DlogBasis-refine](dlogbasis/SKILL.md) | Defined-family integral proposals; `PROPOSE_INTEGRAL_CANDIDATES` | `prepared_family`, family/sector identities, dimension and power-counting policies, budget, normalization, installed tool options | `integral_candidates`; candidate IBP bridge, `RouteCoreCandidates.wls`, then `CHECK_CORE` |
| [Gram/off-cut guidance](gram/SKILL.md) | Supported Gram/numerator construction, cut/IBP rank mismatch, dimensional continuation, or off-cut correction | Actual family geometry, bounded numerator/contact hypothesis, and existing failure report when available | Manually constructed `integral_candidates`; same IBP/core/full-prefix gates. No standalone runner |
| [CANONICA](canonica/SKILL.md) | Rational core transformation in one or more variables; `SEARCH_CORE` | `sector_basis`, `sector_cut_de`, package entry or Wolfram installation | `core_candidates`; `CHECK_CORE` |
| [Libra](libra/SKILL.md) | Small rational one-variable core; `SEARCH_CORE` | `sector_basis`, `sector_cut_de`, package options; optional explicit dependent-row hierarchy | `core_candidates`; `CHECK_CORE` |
| [Epsilon-zero polynomial](epsilon-zero/SKILL.md) | Rational core regular at epsilon zero, with the card's finite polynomial ansatz; `SEARCH_CORE` | `sector_cut_de`, optional `declared_alphabet` and reconstruction prime | `core_candidates`; `CHECK_CORE` |
| [Residue balances](residue-balance/SKILL.md) | One essential rational variable, optionally after exact homogeneous-scale separation; `DIAGNOSE_CORE`, `SEARCH_CORE` | `sector_basis`, `sector_cut_de`, optional finite bounds | Provisional `core_diagnosis` or `core_candidates`; candidates require `CHECK_CORE` |

Every successful proposal is provisional. `CHECK_CORE` verifies the current
cut's invertibility, exact gauge relation, flatness, and epsilon factorization.
A passing cut does not establish full-prefix canonical form: continue through
`BUILD_FULL_DE`, `SOLVE_TAIL`, and `CHECK_CANONICAL`; finish the stated scope
with `FINAL_CHECK`. Use the corresponding [workflow skills](../skills/) for
these operations. General tail solving uses `mma/SolveTail.wls` and does not
require the optional screen or Libra repair below.

## Specialized opt-in cards

These cards apply only when a task explicitly requests their contracts.
They are not prerequisites or automatic fallbacks for the main methods.

| Card | Prerequisites and operation | Output and next action |
|---|---|---|
| [Prepared-basis router](route-prepared-basis/SKILL.md) | Valid `prepared_basis`; `ROUTE_PREPARED_BASIS` | Provisional `route_decision`; invoke the selected operation within its contract. It does not execute a provider or select `REPAIR_WITH_LIBRA` |
| [Full-prefix tail screen](full-prefix-tail-screen/SKILL.md) | Exact rational one-variable pool, explicit alphabet, frozen accepted lower prefix, one completion per core ID; `SCREEN_TAIL` | `TAIL_SCREEN_PASS` or exact bounded-pool results; never invokes repair. Its exhaustion-based repair eligibility belongs only to this contract |
| [Libra structured repair](libra-structured-repair/SKILL.md) | Explicit `REPAIR_WITH_LIBRA` route and exhausted declared pool; exact one-variable direct sum of accepted `1x1` prefix and `2x2` tail, no mixing | Provisional `repair_candidate`; independent `CheckStructuredRepair.wls` |
| [INITIAL official ladder evidence](initial/SKILL.md) | Fixed INITIAL 2.1 official 26-element massless planar 3L4P ladder, seed, normalization, reference, and alphabet; `PROVIDE_UT_EVIDENCE` | Provisional `ut_evidence`; independent `CheckUTEvidence.wls` |
| [MethodCard template](method-card-template/SKILL.md) | Implementing a new bounded role with one declared stage | Interface template only; no scientific method or runnable provider |

The INITIAL card is fixed reference evidence, not a general search, repair, or
candidate-ranking service. The Libra structured repair is confined to its
direct-sum tail; it is not the general off-diagonal tail backend. The screen's
`CANDIDATE_BUDGET_EXHAUSTED` means untested candidates remain; its
`CANDIDATE_POOL_EXHAUSTED` requires complete coverage and failure of every
declared completion. Neither result establishes that the family has no
canonical or UT basis.

## Artifact conventions and examples

Scientific artifacts are Wolfram Language Associations written with `Put`
and read with `Get`. JSON carries descriptors. Keep exact IDs, schemas, basis
orders, variables, regulator, and coefficient domains from the declared input.
The following existing fixtures illustrate the shapes; they are examples of
the interfaces, not scientific evidence for another family.

| Artifact | Shape/example and essential constraint |
|---|---|
| `integral_candidates` | [Request](../interfaces/integral-candidate-input.example.json), [artifact](../tests/fixtures/method_cards/integral-candidates.wl), and [contract](../INTERFACES.md#integral-candidatesv1); stable IDs, exact definitions, dimension/power bounds, normalization, budget, pool state, evidence, and provenance |
| `sector_basis` | [Example](../tests/fixtures/method_cards/sector-basis.wl); basis exactly matches the cut basis |
| `sector_cut_de` | [Example](../tests/fixtures/method_cards/sector-cut-de.wl); square matrices in declared variable order, with `D[basis, variable[[i]]] == matrices[[i]].basis` |
| `core_candidates` | [Example](../tests/fixtures/method_cards/tail-core-candidates.wl); stable candidate IDs, exact transformations, transformed matrices, and source rows where required by the production full-prefix route |
| `libra-dependent-row-hierarchy/v1` | [Example](../tests/fixtures/method_cards/libra-dependent-row-hierarchy.wl) and [card](libra/SKILL.md); `n×n` binary mask in cut order, unit diagonal, cycles permitted, exact identity/order, source hash, `mapped_sectors -> False`, and positive `max_mask_nonzeros` |
| `prepared_basis` | [Example](../tests/fixtures/method_cards/prepared-basis-refine.wl) and [router](route-prepared-basis/SKILL.md); consistent identities, accepted lower prefix when present, unique consecutive ranks, one selected candidate, and consistent quality/search history |
| `accepted_prefix` | [Production example](../tests/fixtures/final-check/accepted-prefix.wl); complete cumulative source/basis relation, transformation, matrices, and alphabet. The [screen example](../tests/fixtures/method_cards/tail-accepted-prefix.wl) illustrates the smaller frozen-prefix input |
| `full_prefix_candidates` | [Example](../tests/fixtures/method_cards/tail-full-prefix-candidates.wl); lower basis before current basis, source matrices, declared alphabet, and candidate-specific full transformations |
| `libra-structured-repair-input/v1` | [Example](../tests/fixtures/method_cards/structured-repair-input.wl) and [card](libra-structured-repair/SKILL.md); exact identity/order/domain/convention, frozen prefix, forbidden blocks, localized target, and pool-exhaustion evidence |
| `ut_evidence` | [Fixed request](../tests/fixtures/method_cards/initial-evidence-input.json) and [card](initial/SKILL.md); official scope and hashes, A/T/B, `verification_status -> "AWAITING_INDEPENDENT_VERIFICATION"` |

Core transformations use `old_basis = transformation . new_basis`. For each
variable and `T = transformation`,

```wl
Bi == Inverse[T].(Ai.T - D[T, variable])
```

For reduced integral rows, `new_basis = R.old_basis` and `T = Inverse[R]`.
The core columns follow resident `sector_basis["basis"]` order. Proper-subsector
coefficients stay out of the cut quotient but remain in `full_new_basis_rows`
against the full `source_basis`. Never discard them before `BUILD_FULL_DE`.
The current router chooses an independent row basis and single-row exchanges,
not every subset; submit a complete ordered bundle when several rows must
change together. Candidate IDs stay stable after pool reordering; list indices
describe only that run's attempt order.

`BUILD_CUT_DE` records matrix row boundaries as `{{1,n}}`; `proper_subsectors`
separately lists the strict subsectors discarded by the quotient.
`BUILD_FULL_DE` exposes `canon-neu/full-prefix-candidates/v1` through its
`full_sector_de` descriptor. The optional screen freezes the lower prefix;
general `SOLVE_TAIL` may update lower epsilon normalization and returns the
complete cumulative map. Preserve that map for the subsequent canonical and
final checks.

## Result meanings

All results use `canon-neu/script-result/v1`.

| Status | Meaning |
|---|---|
| `ERROR` | Input, environment, tool, or computation failed; no mathematical conclusion |
| `INCONCLUSIVE` | The input is outside the method's scope or its bounded domain is exhausted |
| `PROVISIONAL` | A proposed integral, transformation, route, or evidence item awaits its next gate |
| `FAIL` | An independent checker rejected a scientific claim within its stated scope |
| `PASS` | The named step succeeded; only its stated checks are established |

For example, `TAIL_READY` reports a completed tail proposal; CHECK_CANONICAL
and FINAL_CHECK still decide canonical acceptance.

Integral generation returns `PROVISIONAL/INTEGRAL_CANDIDATES`; transformation
providers return `PROVISIONAL/CANDIDATE_TRANSFORMATION`; INITIAL returns
`PROVISIONAL/EVIDENCE_AWAITING_VERIFICATION`. Providers do not publish `PASS`
or mathematical `FAIL`. `OUT_OF_SCOPE` and `METHOD_EXHAUSTED` are inconclusive;
errors need specific codes, not `ERROR/ERROR`. Provider checks and process exit
code zero never replace independent scientific gates.

`DIAGNOSE_CORE` returns `PROVISIONAL/CORE_DIAGNOSIS` for structural applicability,
with `nonexistence_proved: false`. Epsilon-zero residues constrain only gauges
with the required specialization properties; they cannot alone exclude the
default epsilon-meromorphic class. See [obstruction scope](../skills/canon-search-core/SKILL.md#scope-of-an-obstruction).

Finite-cut residue rank, d-dimensional IBP rank, full epsilon form,
dlog/alphabet membership, and UT normalization are separate evidence layers.
Epsilon form alone cannot fix kinematics-independent normalization, including
epsilon-dependent factors. A UT claim needs applicable integrand dlog/LS,
independent INITIAL/Picard–Fuchs evidence, or weight-graded boundary/lower-sector
information. Bare numerical agreement is insufficient.

## Invocation and dependency provenance

Each runnable card takes an input JSON and a new output directory in the
assigned workspace. Invoke it through `python3 run_step.py INPUT.json OUTPUT_DIR`
with the task's `--components` selection. Default `SEARCH_CORE` cards additionally
use `--method canonica`, `libra`, `epsilon-zero` or `residue-balance`. Other cards have distinct step
names. Use `--describe` to find the selected implementation and its instructions;
a replacement's method details supersede this catalog's defaults. The
[component contract](../docs/components.md) describes packaging and composition.
Keep tool installations read-only. Relative artifact/package paths resolve
from the declaring JSON; see [external dependencies](../external/README.md).
Use supplied executable paths and resource budgets, not a personal layout.

Generic external-package cards resolve `method_options.package_entry` or use
the documented Wolfram `$Path` lookup. Fixed-component cards such as INITIAL
require explicit component paths. Record actual entry, SHA-256, resolution
source, options, diagnostics, runtime, and available tool identity. DlogBasis-refine
also needs its declared dependency revision; CANON's outer Git HEAD is not that
revision. Bundled source does not prove native dependencies are installed.

CANONICA loads and checks its package before evaluating the cut DE to avoid
the ``Global`eps``/``CANONICA`eps::shdw`` load-order issue. Thus a specific
`ERROR/TOOL_*` precedes `ERROR/INVALID_DIFFERENTIAL_SYSTEM` when both fail.
Keep this error classification distinct from scientific fallback.
