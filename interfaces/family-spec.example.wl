(* Trusted input for the supplied triangle sector-5 fixture.
   Resource paths are relative to this file. This scope uses d = 2 - 2 eps.
   The full family has three propagator slots; sector 5 selects slots 1 and 3. *)
<|
  "schema" -> "canon-neu/family-spec/v1",
  "family_ref" -> "massless-one-loop-triangle-sector-5",
  "basis_ref" -> "kira3-triangle-sector-5-master-1",
  "topology" -> "tri",
  "parameters" -> {CANON`DEData`d, CANON`DEData`s},
  "variables" -> {CANON`DEData`s},
  "regulator" -> CANON`DEData`eps,
  "dimension_rule" -> (CANON`DEData`d -> 2 - 2 CANON`DEData`eps),
  "index_order" -> {"D1", "D2", "D3"},
  "propagator_slots" -> {1, 2, 3},
  "sector_convention" ->
    "Sector = Sum[Boole[a_i > 0] 2^(i-1), {i,1,3}]",
  "kira" -> <|
    "project" -> "../tests/fixtures/kira-one-loop-triangle-sector-5",
    "integral_families" -> "config/integralfamilies.yaml",
    "kinematics" -> "config/kinematics.yaml",
    "jobs" -> {"jobs.yaml", "export-math.yaml"},
    "targets" -> "targets"
  |>,
  "family_data" ->
    "../tests/fixtures/kira-one-loop-triangle-sector-5/family.wl",
  "prepared_derivatives" ->
    "../tests/fixtures/kira-one-loop-triangle-sector-5/prepared-derivatives-v2.wl",
  "ordered_masters" ->
    "../tests/fixtures/kira-one-loop-triangle-sector-5/preferred-masters"
|>
