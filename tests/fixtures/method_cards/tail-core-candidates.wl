<|
  "schema" -> "canon-neu/core-candidates/v1",
  "sector" -> <|"id" -> 5, "propagator_count" -> 2|>,
  "family_id" -> "fixture-candidate-first-tail",
  "basis_id" -> "fixture-sector-5-basis-v1",
  "coefficient_domain" -> "exact-rational-functions",
  "basis" -> {j1},
  "variables" -> {x},
  "regulator" -> eps,
  "convention" -> "old_basis = transformation . new_basis",
  "method" -> <|"id" -> "two-candidate-fixture", "tool" -> "none"|>,
  "candidates" -> {
    <|
      "candidate_id" -> "fixture-plain-candidate",
      "transformation" -> {{1}},
      "transformed_matrices" -> {{{eps/(1 - x)}}},
      "provider_evidence" -> <|"claim" -> "core-valid but bad full-prefix tail"|>
    |>,
    <|
      "candidate_id" -> "fixture-completed-candidate",
      "transformation" -> {{1}},
      "transformed_matrices" -> {{{eps/(1 - x)}}},
      "provider_evidence" -> <|"claim" -> "same cut core with a good lower-sector completion"|>
    |>
  }
|>
