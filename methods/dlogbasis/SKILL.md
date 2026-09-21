---
name: canon-dlogbasis-integral-candidates
description: Prioritize DlogBasis-refine for UT or canonical integral-basis discovery from a defined family and propose bounded constant-LS candidates with dimensional continuation.
---

# DlogBasis-refine integral candidates before reduction

## Trigger and command

This card implements only `PROPOSE_INTEGRAL_CANDIDATES`. It calls
``DlogBasis`DlogBasisSearch`` before candidate IBP reduction and neither
constructs nor accepts a canonical basis.

For integral-basis discovery from a defined family, whether requested as
"UT integrals" or a "canonical basis", start with a small, declared, bounded
search on the unresolved sector. Reuse suitable existing candidates and
already checked sectors. From `project_root`, run
`wolframscript -file methods/dlogbasis/run.wls INPUT.json OUTPUT_DIR` with the
`PROPOSE_INTEGRAL_CANDIDATES` input shown in the
[request example](../../interfaces/integral-candidate-input.example.json).
Loading the package or calling `CreateDlogFamily` prepares the family; an
actual `DlogBasisSearch` call is required to attempt a candidate search.
The [core-selection skill](../../skills/canon-search-core/SKILL.md) defines the
direct-DE exceptions. Use finite numerator/dot bounds and apply this card only
to unresolved scope.

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
remain `False`. Record the declared package revision and actual loader SHA-256.
Provisional output is not a UT result, and `METHOD_EXHAUSTED` is not evidence
that the family has no UT basis. Return the search bounds and stopped gate to
the workflow entry for the next assigned step.
