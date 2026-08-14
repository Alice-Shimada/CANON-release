<|
  "schema" -> "canon-neu/ut-evidence/v1",
  "source_task_id" -> "T-FIXTURE-INITIAL-EVIDENCE",
  "family_id" -> "initial-official-massless-3l4p",
  "candidate_id" -> "official-planar-ladder-26x26",
  "basis_id" -> "initial-2.1-massless-3l4p-ladder-basis-26",
  "basis_order" -> "initial_basis_ladder.m:official-order",
  "normalization" -> "D=4-2 eps;x=t/s",
  "reference_id" -> "INITIAL-2.1:massless_3L4P/TMatrix_ladder_to_UT.m",
  "coefficient_domain" -> "exact-rational-functions",
  "dimension" -> 26,
  "basis" -> Join[
    {G[2, {1, 1, 1, 1, 1, 1, 1, 1, 1, 1, -1, 0, 0, 0, 0}]},
    Table[G[1, {index}], {index, 2, 26}]
  ],
  "variable" -> x,
  "regulator" -> eps,
  "alphabet" -> {x, 1 + x},
  "ut_seed" -> G[2, {1, 1, 1, 1, 1, 1, 1, 1, 1, 1, -1, 0, 0, 0, 0}],
  "take_row" -> 1,
  "convention" -> "old_basis = transformation . new_basis",
  "source_matrix" -> ConstantArray[0, {26, 26}],
  "transformation" -> ConstantArray[0, {26, 26}],
  "transformed_matrix" -> ConstantArray[0, {26, 26}],
  "method" -> <|
    "id" -> "initial-2.1-official-massless-3l4p-ladder",
    "tool" -> "INITIAL",
    "initial_identity" -> "INITIAL 2.1; 63d8f813ac415f82f7ef945ee7e3f78a242fae49",
    "finiteflow_identity" -> "FiniteFlow; 278344c169010b74e791af8c5604c8cb9cd8df11"
  |>,
  "provider_evidence" -> <|
    "exact_reference_match" -> True,
    "invertible" -> True,
    "exact_gauge" -> True,
    "epsilon_independent_after_division" -> True,
    "declared_dlog_alphabet" -> True,
    "verified" -> True
  |>,
  "verification_status" -> "AWAITING_INDEPENDENT_VERIFICATION"
|>
