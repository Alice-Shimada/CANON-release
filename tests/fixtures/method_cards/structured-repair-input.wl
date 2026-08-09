<|
  "schema" -> "canon-neu/libra-structured-repair-input/v1",
  "preparation_id" -> "fixture-structured-repair-preparation-v1",
  "family_id" -> "fixture-libra-structured-repair",
  "basis_id" -> "fixture-libra-structured-basis-v1",
  "selected_candidate_id" -> "fixture-structured-candidate-a",
  "coefficient_domain" -> "exact-rational-functions",
  "basis" -> {l1, j1, j2},
  "variables" -> {x},
  "regulator" -> eps,
  "parameters" -> {},
  "repair_scope" -> "DIRECT_SUM_1X1_PREFIX_PLUS_2X2_TAIL_INTERNAL",
  "convention" -> "old_basis = transformation . new_basis",
  "original_matrices" -> {
    {
      {eps/x, 0, 0},
      {0, eps/x, 1 - eps + eps/(1 - x) - x eps/(1 + x)},
      {0, 0, -eps/(1 + x)}
    }
  },
  "frozen_prefix" -> <|
    "prefix_id" -> "fixture-libra-accepted-prefix-v1",
    "dimension" -> 1,
    "basis" -> {l1},
    "order" -> {1},
    "accepted_matrices" -> {{{eps/x}}},
    "accepted_blocks" -> {
      "prefix-prefix", "prefix-from-tail", "tail-from-prefix"
    },
    "forbidden_mixing" -> {"prefix-from-tail", "tail-from-prefix"}
  |>,
  "localized_target" -> <|
    "scope" -> "LOCALIZED_BLOCK",
    "prepared_block" -> "current-current",
    "prepared_signature" -> <|
      "kind" -> "epsilon-factorization", "row" -> 1, "column" -> 2
    |>,
    "full_entry" -> {2, 3},
    "failure_test" -> "REGULATOR_INDEPENDENT_TERM"
  |>,
  "alphabet" -> {x, 1 - x, 1 + x},
  "search_evidence" -> <|
    "plateau" -> True,
    "pool_exhausted" -> False,
    "alternatives_remaining" -> 1,
    "attempted_candidate_ids" -> {"fixture-structured-candidate-a"}
  |>
|>
