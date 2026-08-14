<|
  "schema" -> "canon-neu/core-candidates/v1",
  "sector" -> <|"id" -> 99, "propagator_count" -> 2|>,
  "family_id" -> "fixture-libra-tutorial-1",
  "basis_id" -> "fixture-sector-3-basis-v1",
  "coefficient_domain" -> "exact-rational-functions",
  "basis" -> {j1, j2},
  "variables" -> {x},
  "regulator" -> eps,
  "convention" -> "old_basis = transformation . new_basis",
  "method" -> <|"id" -> "wrong-sector-fixture", "tool" -> "none"|>,
  "candidates" -> {
    <|
      "transformation" -> {{1, x}, {0, 1}},
      "transformed_matrices" -> {
        {
          {eps/x, eps/(1 - x)},
          {0, -eps/(1 + x)}
        }
      },
      "provider_evidence" -> <|"claim" -> "correct matrix, wrong sector"|>
    |>
  }
|>
