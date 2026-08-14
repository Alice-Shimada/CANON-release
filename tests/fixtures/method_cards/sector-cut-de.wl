<|
  "schema" -> "canon-neu/sector-cut-de/v1",
  "sector" -> <|"id" -> 3, "propagator_count" -> 2|>,
  "family_id" -> "fixture-libra-tutorial-1",
  "basis_id" -> "fixture-sector-3-basis-v1",
  "coefficient_domain" -> "exact-rational-functions",
  "basis" -> {j1, j2},
  "variables" -> {x},
  "regulator" -> eps,
  "matrices" -> {
    {
      {
        eps/x,
        1 - eps + eps/(1 - x) - x eps/(1 + x)
      },
      {0, -eps/(1 + x)}
    }
  },
  "sector_boundaries" -> Automatic
|>
