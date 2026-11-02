(* A flat connection gauged by I + (xy+x+y) E12. Both directions
   need pole-order reduction, followed by one shared regulator factor. *)
<|"schema" -> "canon-neu/sector-cut-de/v1",
  "sector" -> <|"id" -> 6, "propagator_count" -> 2|>,
  "family_id" -> "fixture-libra-multivariable", "basis_id" -> "raw/6",
  "basis" -> {j1, j2}, "coefficient_domain" -> "exact-rational-functions",
  "variables" -> {x, y}, "regulator" -> eps,
  "matrices" -> {
    {{eps/x, eps^2/x + y + 1 - eps (x y + x + y)/x}, {0, 0}},
    {{eps/y, eps^2/y + x + 1 - eps (x y + x + y)/y}, {0, 0}}},
  "sector_boundaries" -> Automatic|>
