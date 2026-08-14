<|
  "schema" -> "canon-neu/libra-structured-repair-candidate/v1",
  "provider_status" -> "PROVISIONAL/CANDIDATE_TRANSFORMATION",
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
  "transformation" -> {{1, 0, 0}, {0, 1, x}, {0, 0, 1}},
  "transformed_matrices" -> {
    {
      {eps/x, 0, 0},
      {0, eps/x, eps/(1 - x)},
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
  "method" -> <|
    "id" -> "libra-structured-repair-single-variable",
    "tool" -> "Libra",
    "tool_identity" -> "1.2",
    "package_source" -> "method_options.package_entry",
    "entry" -> "/Users/balth/Works/hep-tools/tools/libra/Source/Libra.m",
    "entry_sha256" -> "b3574e7f560951516a289a8141aafbaf23f0f5ae563e29d0fa077b17ba4d3eb4",
    "wolfram_version" -> "14.0.0 for Mac OS X ARM (64-bit) (December 13, 2023)",
    "system_id" -> "MacOSX-ARM64",
    "options" -> <|"use_fermatica" -> False, "factor_out_mu" -> 1/2|>,
    "stages" -> {
      "NewDSystem", "Fuchsify", "Transform", "FactorOut", "Transform",
      "OverallTransformation", "EFormQ"
    }
  |>,
  "provider_evidence" -> <|
    "epsilon_form" -> True,
    "authority" -> "NON_AUTHORITATIVE"
  |>
|>
