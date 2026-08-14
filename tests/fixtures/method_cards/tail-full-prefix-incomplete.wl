<|
  "schema" -> "canon-neu/full-prefix-candidates/v1",
  "sector" -> <|"id" -> 5, "propagator_count" -> 2|>,
  "family_id" -> "fixture-candidate-first-tail",
  "current_basis_id" -> "fixture-sector-5-basis-v1",
  "accepted_prefix_id" -> "fixture-lower-prefix-v1",
  "coefficient_domain" -> "exact-rational-functions",
  "lower_basis" -> {l1},
  "current_basis" -> {j1},
  "variables" -> {x},
  "regulator" -> eps,
  "alphabet" -> {x, 1 - x},
  "convention" -> "old_prefix_basis = full_transformation . candidate_prefix_basis",
  "source_matrices" -> {
    {
      {eps/x, 0},
      {1 + eps (1/x - x/(1 - x) + 1), eps/(1 - x)}
    }
  },
  "candidates" -> {
    <|
      "candidate_id" -> "fixture-plain-candidate",
      "full_transformation" -> IdentityMatrix[2],
      "transformed_matrices" -> {
        {
          {eps/x, 0},
          {1 + eps (1/x - x/(1 - x) + 1), eps/(1 - x)}
        }
      }
    |>
  }
|>
