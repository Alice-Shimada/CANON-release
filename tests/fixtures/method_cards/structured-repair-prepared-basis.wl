<|
  "schema" -> "canon-neu/prepared-basis/v1",
  "identity" -> <|
    "preparation_id" -> "fixture-structured-repair-preparation-v1",
    "family_id" -> "fixture-libra-structured-repair",
    "basis_id" -> "fixture-libra-structured-basis-v1",
    "variables" -> {x},
    "regulator" -> eps
  |>,
  "current_basis" -> <|
    "basis_id" -> "fixture-libra-structured-basis-v1",
    "basis" -> {j1, j2}
  |>,
  "frozen_lower_prefix" -> <|
    "present" -> True,
    "accepted" -> True,
    "prefix_id" -> "fixture-libra-accepted-prefix-v1",
    "basis" -> {l1}
  |>,
  "candidates" -> {
    <|
      "candidate_id" -> "fixture-structured-candidate-a",
      "definition" -> <|"basis" -> {j1, j2}, "source" -> "fixture-generator"|>,
      "normalization" -> "leading-singularity-normalized",
      "rank" -> 1,
      "selected" -> True,
      "suspicious" -> True
    |>,
    <|
      "candidate_id" -> "fixture-structured-candidate-b",
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
      "block" -> "current-current",
      "signature" -> <|
        "kind" -> "epsilon-factorization",
        "row" -> 1,
        "column" -> 2
      |>
    |>
  |>,
  "ut_evidence_references" -> {},
  "search_history" -> <|
    "plateau" -> True,
    "pool_exhausted" -> True,
    "alternatives_remaining" -> 0,
    "attempted_candidate_ids" -> {
      "fixture-structured-candidate-a", "fixture-structured-candidate-b"
    }
  |>,
  "remaining_problem" -> <|
    "classification" -> "LOCALIZED_RATIONAL_DEFECT",
    "candidate_selection_complete" -> False,
    "rational_transformation_expected" -> True
  |>
|>
