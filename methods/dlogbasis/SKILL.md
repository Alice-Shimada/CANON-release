---
name: canon-dlogbasis-integral-candidates
description: Use a selected bounded DlogBasis-refine search to propose constant-LS integral candidates with dimensional continuation.
---

# DlogBasis-refine integral candidates before reduction

## Trigger and command

This card implements only `PROPOSE_INTEGRAL_CANDIDATES`. It calls
``DlogBasis`DlogBasisSearch`` before candidate IBP reduction and neither
constructs nor accepts a canonical basis.

When the [core-selection skill](../../skills/canon-search-core/SKILL.md) selects
DlogBasis-refine for integral-basis discovery, start with a small, declared,
bounded search on the unresolved sector. Reuse suitable existing candidates and
already checked sectors. From `project_root`, run
`python3 run_step.py INPUT.json OUTPUT_DIR` with the
`PROPOSE_INTEGRAL_CANDIDATES` input shown in the
[request example](../../interfaces/integral-candidate-input.example.json).
Loading the package or calling `CreateDlogFamily` prepares the family; an
actual `DlogBasisSearch` call is required to attempt a candidate search.
The core-selection skill also permits explicit dot/normalization, Gram and
direct-DE proposals without first calling this provider. Use finite
numerator/dot bounds and apply this card only to unresolved scope.

## Inputs and finite bounds

The file at `prepared_family["family_data","path"]` must return an Association
containing `"Family"`. The runner expands the requested sector ID into a mask
in the full propagator/ISP index order; it does not read a literature manifest.

The proposal uses the family and provider inputs listed here. It is independent
of `prepared_derivatives` and `exact_strategy`, which belong to the subsequent
candidate IBP bridge. Run the search when its inputs are ready; retain returned
candidates while preparing any remaining derivative data.

The momentum representation and `KinematicRules` in `Family` must reduce all
external scalar products used to the declared `KinematicVariables`. Eliminate
dependent momenta by momentum conservation or provide the full required scalar
product relations. Separate derivative data used by the DE does not complete
this object. If Singular input still contains unresolved momentum dot products,
correct the family data; larger numerator/dot bounds cannot fix that input.

Supply these `method_options`:

- `package_entry`: the distributed `external/DlogBasis-refine/DlogBasis.wl`
  or the caller's installed entry;
- `finite_flow_package_file`: `FiniteFlow.m`;
- `loop_order`: one-based positions in `Family["LoopMomenta"]`, such as `{2,1}`;
- `loop_dimensions`: integer `D0_i` values in that same order; the calculation
  uses `D0_i-2 epsilon`;
- optional `package_revision`: the declared dependency source revision;
  the runner records `null` when it is unavailable;
- optional `numerator_positions`, `residual_backend`, and
  `singular_executable` (default: `Singular` on PATH).

Relative package and FiniteFlow paths resolve from the input JSON directory.
For bundled source, use the revision in `external/sources.json`; never infer
the dependency revision from CANON's outer Git HEAD. This card uses
DlogBasis-refine. FiniteFlow and the Singular used
for module lifting must be available where Wolfram executes. Omitting
`singular_executable` selects that environment's PATH lookup, not a dependency-free
mode. Bundled source directories do not establish that native dependencies are
built; see [installation details](../../external/README.md).

The total numerator degree and total added-dot bounds come from
`numerator_or_power_counting_policy.definition.numerator_degree` and
`max_added_dots`. For the ordinary supported request, set
`max_dots_per_propagator` equal to `max_added_dots`.

The exact supported inequality is:

```text
max_dots_per_propagator >= max_added_dots
```

The package enforces only the total added-dot bound. It cannot enforce a tighter
per-propagator cap. For example, a total bound of two is represented by:

```json
{"numerator_degree": 1, "max_added_dots": 2, "max_dots_per_propagator": 2}
```

Setting `max_dots_per_propagator` to 1 with `max_added_dots` set to 2 is
unsupported; changing the total bound would change the requested search.

## Choose the search cost before launch

When the caller has not fixed the bounds, start with the smallest numerator/dot
bounds justified by the sector geometry and intended representatives. Explain
the loop order and attach each base dimension to its loop momentum. Increase
one bound at a time only when the saved result motivates that change and the
remaining budget permits it. Preserve caller-specified bounds; any change is a
new declared request. There is no universal loop order or base dimension for
all families.

For `a` active slots, `b` inactive slots, total dot bound `d` and numerator bound
`n`, the provider enumerates
`Binomial[a+d,a] * Binomial[b+n,b]` integral index vectors. For example, eight
active and three inactive slots with `n=1,d=2` already give `45*4=180` vectors.
Simultaneously starting with degree one and two dots is therefore not a small
search merely because the returned-candidate budget is small. The lattice size
does not estimate symbolic runtime or the number of final directions.

`numerator_positions` omitted means `Automatic`. At positive numerator degree,
the provider first completes a search on the reduced chart, then repeats the
search for each singleton position missing from that chart. Each call performs
lattice enumeration, Baikov chart construction and mapping, dimensionally
regulated generalized cuts and finite residual signatures, then a module lift
when those earlier stages permit it. The result selects one chart by its
returned directions/coverage; it does not combine all chart spans. An explicit
position list changes the chart experiment and must be justified and recorded.
The returned-candidate cap is applied only after these searches return.

Use a fresh output directory and an explicit elapsed-time/cancellation budget.
`dlogbasis-progress.jsonl` is operational evidence separate from `result.json`.
It records the request and input hashes, declared revision, loader and sibling
`Kernel/*.wl` hashes, and `entered`/`returned` boundaries for package/family
loading, the public search and candidate conversion. The implementation list is
the installed source snapshot, not a trace of every file loaded at runtime.
Each record is closed on disk; after a hard interruption ignore an incomplete
last line and retain the prior complete records. Distinguish invocations by
`invocation_id` if an output directory was reused.

An entered phase without its returned record locates an interrupted boundary;
it does not establish a failed mathematical ansatz. A `dlogbasis_search` entry
does not identify a particular internal chart, residue or module-lift hotspot.
Inspect that evidence and the declared lattice/chart scope before extending time
or bounds. With no phase records, retain the stage as unknown. Package/family
loading alone still does not establish that the provider search was invoked.

## Result and next action

Each `CandidateCombinations` element is one constant-LS candidate direction.
The runner maps ``DlogBasis`DlogIntegral[hash,{a1,...}]`` to CANON's
`j[topology,a1,...]` and normalizes projectively by the first integral's
coefficient. This card accepts only `NORMALIZED_LINEAR_COMBINATION` and
`first-integral-coefficient-outside-definition`; the budget unit is
`PROVIDER_CANDIDATE`. The budget truncates returned directions, not provider
runtime, so also declare and supervise an elapsed-time limit.

On `PROVISIONAL/INTEGRAL_CANDIDATES`, pass the exact candidates through the
existing candidate IBP bridge. `RouteCoreCandidates` then selects an independent basis and single-row
exchanges using the actual master rank; it does not enumerate every subset.
Run `CHECK_CORE`, then `BUILD_FULL_DE`, `SOLVE_TAIL`, and `CHECK_CANONICAL`;
use `FINAL_CHECK` when the stated scope is complete.
Retain `ScientificStatus`, finite affine coverage, and all four certification
flags. Even when candidates exist, `ConstantLeadingSingularityCertifiedQ`,
`UniformTranscendentalityCertifiedQ`, and `CanonicalBasisCertifiedQ` generally
remain `False`. Record the declared package revision and actual loader and
executable Kernel SHA-256 values; the loader alone does not identify the implementation.
Provisional output is not a UT result, and `METHOD_EXHAUSTED` is not evidence
that the family has no UT basis. Return the search bounds and stopped gate to
the workflow entry for the next assigned step.
