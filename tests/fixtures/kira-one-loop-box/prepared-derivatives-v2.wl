<|
  "schema" -> "canon.prepared-derivatives/v2",
  "topology" -> "box",
  "variables" -> {s, t},
  "denominator_count" -> 4,
  "operators" -> <|
    s -> {
      <|"constant" -> 0, "linear" -> {}|>,
      <|
        "constant" -> -1/4,
        "linear" -> {
          <|"denominator" -> 1, "coefficient" -> -1/(4*s)|>,
          <|"denominator" -> 2, "coefficient" -> -1/(4*(4-s-t))|>,
          <|"denominator" -> 3, "coefficient" -> 1/(4*s)|>,
          <|"denominator" -> 4, "coefficient" -> 1/(4*(4-s-t))|>
        }
      |>,
      <|
        "constant" -> 1/2,
        "linear" -> {
          <|"denominator" -> 1, "coefficient" -> -1/(2*s)|>,
          <|"denominator" -> 3, "coefficient" -> 1/(2*s)|>
        }
      |>,
      <|
        "constant" -> -1/4,
        "linear" -> {
          <|"denominator" -> 1, "coefficient" -> -1/(4*s)|>,
          <|"denominator" -> 2, "coefficient" -> 1/(4*(4-s-t))|>,
          <|"denominator" -> 3, "coefficient" -> 1/(4*s)|>,
          <|"denominator" -> 4, "coefficient" -> -1/(4*(4-s-t))|>
        }
      |>
    },
    t -> {
      <|"constant" -> 0, "linear" -> {}|>,
      <|
        "constant" -> (s-4)/(4*t),
        "linear" -> {
          <|"denominator" -> 1, "coefficient" -> -1/(4*t)|>,
          <|"denominator" -> 2, "coefficient" -> (4-s-2*t)/(4*t*(4-s-t))|>,
          <|"denominator" -> 3, "coefficient" -> -1/(4*t)|>,
          <|"denominator" -> 4, "coefficient" -> (4-s)/(4*t*(4-s-t))|>
        }
      |>,
      <|"constant" -> 0, "linear" -> {}|>,
      <|
        "constant" -> (s-4)/(4*t),
        "linear" -> {
          <|"denominator" -> 1, "coefficient" -> -1/(4*t)|>,
          <|"denominator" -> 2, "coefficient" -> (4-s)/(4*t*(4-s-t))|>,
          <|"denominator" -> 3, "coefficient" -> -1/(4*t)|>,
          <|"denominator" -> 4, "coefficient" -> (4-s-2*t)/(4*t*(4-s-t))|>
        }
      |>
    }
  |>,
  "exact_strategy" -> <|
    "kind" -> "enhanced-baikov-membership",
    "baikov_variables" -> {z1, z2, z3, z4},
    "propagator_slots" -> {1, 2, 3, 4},
    "loop_count" -> 1,
    "independent_external_count" -> 3,
    "fixed_scale_substitutions" -> {m2 -> 1},
    "external_gram_determinant" -> -s*t*(s+t-4)/4,
    "baikov_polynomial" ->
      -s*t*(s+t-4)*(z1+1)/4 +
      (s+t)*(s+t-4)*((z2-z1-2)/2)^2/4 +
      t*(t-4)*((z3-z2-s+2)/2)^2/4 +
      s*(s-4)*((z4-z3+s-2)/2)^2/4 +
      t*(s+t-4)*((z2-z1-2)/2)*((z3-z2-s+2)/2)/2 +
      s*(s+t-4)*((z2-z1-2)/2)*((z4-z3+s-2)/2)/2 -
      s*t*((z3-z2-s+2)/2)*((z4-z3+s-2)/2)/2,
    "search_max_total_degree" -> 1,
    "monomial_order" -> "graded-reverse-lexicographic",
    "fallback" -> "operators"
  |>
|>
