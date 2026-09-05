<|
  "schema" -> "canon.prepared-derivatives/v2", "topology" -> "tri",
  "variables" -> {CANON`DEData`s}, "denominator_count" -> 3,
  "operators" -> <|CANON`DEData`s -> {
    <|"constant" -> 0, "linear" -> {}|>,
    <|"constant" -> 0, "linear" -> {
      <|"denominator" -> 1, "coefficient" -> -1/(2 CANON`DEData`s)|>,
      <|"denominator" -> 2, "coefficient" -> 1/(2 CANON`DEData`s)|>}|>,
    <|"constant" -> 1/2, "linear" -> {
      <|"denominator" -> 1, "coefficient" -> -1/(2 CANON`DEData`s)|>,
      <|"denominator" -> 3, "coefficient" -> 1/(2 CANON`DEData`s)|>}|>
  }|>,
  "exact_strategy" -> <|
    "baikov_variables" -> {CANON`DEData`z1, CANON`DEData`z2, CANON`DEData`z3},
    "propagator_slots" -> {1, 3},
    "loop_count" -> 1, "independent_external_count" -> 2,
    "fixed_scale_substitutions" -> {},
    "external_gram_determinant" -> -CANON`DEData`s^2/4,
    "baikov_polynomial" -> -CANON`DEData`s (
      CANON`DEData`s CANON`DEData`z2 - CANON`DEData`z1 CANON`DEData`z2 +
      CANON`DEData`z2^2 + CANON`DEData`z1 CANON`DEData`z3 -
      CANON`DEData`z2 CANON`DEData`z3)/4,
    "search_max_total_degree" -> 1|>
|>
