(* Exact supplied vector chart; x[1] is an arbitrary coordinate name. *)
<|"schema" -> "canon-neu/parameterization-spec/v1", "chart_type" -> "vectors",
  "family_ref" -> "synthetic-bubble", "basis_ref" -> "bubble-master", "chart_id" -> "indexed-scale",
  "topology" -> "bubble", "integral_head" -> "B", "variables" -> {x[1]},
  "dimension" -> d, "regulator" -> eps, "dimension_rule" -> (d -> 4 - 2 eps),
  "loop_momenta" -> {l}, "external_momenta" -> {p1,p2,p3,p4}, "external_basis" -> {1,2,3,4},
  "metric" -> {1,-1,-1,-1},
  "vectors" -> x[1] {{1,1,0,0},{1,-1,0,0},{1,0,1,0},{1,0,0,1}},
  "propagator_momenta" -> {l,l-p1-p2,l-p1,l-p3,l-p4},
  "propagator_masses_squared" -> {0,0,0,0,0},
  "index_order" -> {"D1","D2","D3","D4","D5"}, "propagator_slots" -> {1,2},
  "top_level_sectors" -> {3}, "point" -> {x[1] -> 2}, "invariants" -> {}|>
