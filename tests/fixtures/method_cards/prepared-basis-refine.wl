<|
  "schema" -> "canon-neu/prepared-basis/v1",
  "identity" -> <|
    "preparation_id" -> "fixture-prepared-basis-v1",
    "family_id" -> "fixture-family",
    "basis_id" -> "fixture-current-basis-v1",
    "variables" -> {x},
    "regulator" -> eps
  |>,
  "current_basis" -> <|
    "basis_id" -> "fixture-current-basis-v1",
    "basis" -> {j1, j2}
  |>,
  "frozen_lower_prefix" -> <|
    "present" -> True,
    "accepted" -> True,
    "prefix_id" -> "fixture-accepted-prefix-v1",
    "basis" -> {l1}
  |>,
  "candidates" -> {
    <|
      "candidate_id" -> "fixture-candidate-a",
      "definition" -> <|"basis" -> {j1, j2}, "source" -> "fixture-generator"|>,
      "normalization" -> "leading-singularity-normalized",
      "rank" -> 1,
      "selected" -> True,
      "suspicious" -> True
    |>,
    <|
      "candidate_id" -> "fixture-candidate-b",
      "definition" -> <|"basis" -> {j1, 2 j2}, "source" -> "fixture-generator"|>,
      "normalization" -> "leading-singularity-normalized",
      "rank" -> 2,
      "selected" -> False,
      "suspicious" -> False
    |>
  },
  "quality" -> <|
    "diagonal" -> "CANONICAL",
    "off_diagonal" -> "DEFECT",
    "localized_defect" -> <|
      "present" -> True,
      "block" -> "lower-to-current",
      "signature" -> <|"kind" -> "epsilon-factorization", "row" -> 1, "column" -> 2|>
    |>
  |>,
  "ut_evidence_references" -> {
    <|
      "reference_id" -> "fixture-initial-evidence-a",
      "provider" -> "INITIAL",
      "candidate_id" -> "fixture-candidate-a",
      "verification_status" -> "AWAITING_INDEPENDENT_VERIFICATION"
    |>
  },
  "search_history" -> <|
    "plateau" -> False,
    "pool_exhausted" -> False,
    "alternatives_remaining" -> 1,
    "attempted_candidate_ids" -> {"fixture-candidate-a"}
  |>,
  "remaining_problem" -> <|
    "classification" -> "LOCALIZED_RATIONAL_DEFECT",
    "candidate_selection_complete" -> False,
    "rational_transformation_expected" -> True
  |>
|>
