<|"schema" -> "canon-neu/sector-cut-de/v1",
  "sector" -> <|"id" -> 3, "propagator_count" -> 2|>,
  "family_id" -> "initial-core-algebra", "basis_id" -> "initial-core-algebra/3",
  "coefficient_domain" -> "exact-rational-functions", "basis" -> {j1,j2},
  "variables" -> {x}, "regulator" -> eps,
  "matrices" -> {With[{r = {{x,1},{0,1}}, t = {{1,0},{x,1}},
      b = eps {{1/x,1/(1+x)},{0,2/x}}},
    With[{aSeed = Map[Together, t.b.Inverse[t] + D[t,x].Inverse[t], {2}]},
      Map[Together, Inverse[r].(aSeed.r-D[r,x]), {2}]]]}|>
