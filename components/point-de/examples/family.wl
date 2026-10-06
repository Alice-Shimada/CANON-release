(* Synthetic derivative fixture; no reducer is run by this example. *)
<|"schema" -> "canon-neu/twistor-family/v1", "family_ref" -> "synthetic-bubble",
  "integral_head" -> "B", "variables" -> {x}, "dimension" -> d, "regulator" -> eps,
  "dimension_rule" -> (d -> 4 - 2 eps), "metric" -> {1, -1, -1, -1},
  "loop_momenta" -> {l}, "external_momenta" -> {p1, p2, p3, p4},
  "external_basis" -> {1, 2, 3, 4},
  "vectors" -> x {{1, 1, 0, 0}, {1, -1, 0, 0}, {1, 0, 1, 0}, {1, 0, 0, 1}},
  "propagators" -> {l^2, (l-p1-p2)^2, (l-p1)^2, (l-p3)^2, (l-p4)^2}|>
