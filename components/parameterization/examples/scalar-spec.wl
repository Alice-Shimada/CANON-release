(* One independent external momentum; no vector or four-dimensional chart is required. *)
<|"schema" -> "canon-neu/parameterization-spec/v1", "chart_type" -> "scalar-products",
  "family_ref" -> "scalar-bubble", "basis_ref" -> "scalar-bubble-master", "chart_id" -> "invariant-u",
  "topology" -> "scalar_bubble", "integral_head" -> "Q", "variables" -> {u},
  "dimension" -> d, "regulator" -> eps, "dimension_rule" -> (d -> 4 - 2 eps),
  "loop_momenta" -> {k}, "external_momenta" -> {q}, "momentum_rules" -> {r -> -q},
  "scalar_products" -> {{q,q} -> u}, "propagator_momenta" -> {k,k+r},
  "propagator_masses_squared" -> {0,0}, "index_order" -> {"D1","D2"},
  "propagator_slots" -> {1,2}, "top_level_sectors" -> {3},
  "invariants" -> {<|"name" -> u, "mass_dimension" -> 2|>},
  "ordered_masters" -> "scalar-masters"|>
