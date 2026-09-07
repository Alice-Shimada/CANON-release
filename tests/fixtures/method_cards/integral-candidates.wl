<|
  "schema" -> "canon-neu/integral-candidates/v1",
  "proposal_id" -> "fixture-integral-proposal-v1",
  "family_identity" -> <|
    "family_id" -> "fixture-family", "family_spec_id" -> "fixture-family-spec-v1"
  |>,
  "sector_identity" -> <|
    "sector_id" -> "fixture-sector-7", "id" -> 7, "propagator_count" -> 3
  |>,
  "dimension_policy" -> <|
    "spacetime_dimension" -> D, "per_loop_policy" -> "provider-declared"
  |>,
  "numerator_or_power_counting_policy" -> <|
    "policy_id" -> "fixture-power-counting-v1",
    "definition" -> HoldComplete[powerCounting[L1, L2]]
  |>,
  "candidate_budget" -> <|
    "maximum" -> 2, "consumed" -> 2, "unit" -> "PROVIDER_CANDIDATE"
  |>,
  "pool_exhausted" -> True,
  "candidate_pool" -> <|
    "available" -> 2, "remaining" -> 0, "pool_exhausted" -> True
  |>,
  "candidate_unit" -> "INDIVIDUAL_G_INTEGRAL",
  "normalization_policy" -> <|
    "convention" -> "explicit-rational-prefactor", "factors" -> <||>
  |>,
  "candidates" -> {
    <|
      "candidate_id" -> "fixture-integral-candidate-a",
      "exact_definition" -> HoldComplete[j[fixtureFamily, 1, 1, 1, 0]],
      "candidate_unit" -> "INDIVIDUAL_G_INTEGRAL",
      "normalization" -> <|
        "convention" -> "explicit-rational-prefactor", "factor" -> 1
      |>
    |>,
    <|
      "candidate_id" -> "fixture-integral-candidate-b",
      "exact_definition" -> HoldComplete[j[fixtureFamily, 1, 1, 1, -1]],
      "candidate_unit" -> "INDIVIDUAL_G_INTEGRAL",
      "normalization" -> <|
        "convention" -> "explicit-rational-prefactor", "factor" -> 1
      |>
    |>
  },
  "method_evidence" -> <|
    "method_id" -> "fixture-pre-reduction-generator", "evidence" -> {}
  |>,
  "tool_provenance" -> <|
    "tool" -> "fixture-tool", "tool_revision" -> "fixture-revision",
    "entry" -> "fixture-entry", "entry_sha256" -> StringRepeat["0", 64],
    "runtime" -> "fixture-runtime"
  |>
|>
