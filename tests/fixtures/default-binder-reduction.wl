(* The legacy binder's explicit integral_head "Q" declares Global`Q.
   Keep those heads explicit when the common data reader loads the rules. *)
<|"masters" -> {Global`Q[1,1]}, "rules" -> {
  Global`Q[0,2] -> 0, Global`Q[1,2] -> -(d-3)/u Global`Q[1,1]}|>
