(* A regulator-singular gauge is allowed: diag(1,eps,eps^2). *)
<|"schema" -> "canon-neu/sector-cut-de/v1",
  "sector" -> <|"id" -> 6, "propagator_count" -> 2|>,
  "family_id" -> "fixture-libra-multivariable", "basis_id" -> "raw/6",
  "basis" -> {j1, j2, j3}, "coefficient_domain" -> "exact-rational-functions",
  "variables" -> {x, y}, "regulator" -> eps,
  "matrices" -> {{{0, 1/x, 0}, {0, 0, 1/x}, {0, 0, 0}},
    {{0, 1/y, 0}, {0, 0, 1/y}, {0, 0, 0}}},
  "sector_boundaries" -> Automatic|>
