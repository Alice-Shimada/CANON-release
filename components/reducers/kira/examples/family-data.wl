(* Supplied neutral scalar-product bubble example, independent of any backend. *)
<|"schema" -> "canon-neu/parameterized-family/v1", "family_ref" -> "massless-bubble-example",
  "basis_ref" -> "bubble-source", "topology" -> "bubble", "integral_head" -> "B",
  "chart_type" -> "scalar-products", "dimension" -> d, "variables" -> {s}, "regulator" -> eps,
  "dimension_rule" -> (d -> 4-2 eps), "loop_momenta" -> {l}, "external_momenta" -> {p},
  "propagator_momenta" -> {l,l-p}, "propagator_masses_squared" -> {0,0},
  "scalar_products" -> {{p,p} -> s}, "point_rules" -> {}|>
