(* Frozen-prefix repair input contracts and the minimal candidate publication gate.
   Loaded inside CanonMethodCard`Private` by MethodCardCore.wl. *)

repairFailure[field_String, message_String] :=
  Failure["INVALID_STRUCTURED_REPAIR_INPUT", <|"Field" -> field, "Message" -> message|>];

sameMatrixListsQ[left_List, right_List] := Length[left] === Length[right] &&
  And @@ MapThread[ZeroMatrixQ[Map[Together, #1 - #2, {2}]] &, {left, right}];

matrixBlocks[matrices_List, rows_, columns_] := (#[[rows, columns]] & /@ matrices);

zeroMatrixListQ[matrices_List] := And @@ (ZeroMatrixQ /@ matrices);

(* Binding, coefficient domain, prefix, target and search are separate input
   responsibilities. Later helpers consume the shapes checked earlier. *)
validateRepairBindings[prepared_Association, route_Association, request_Association] := Module[
  {identity, selected},
  identity = prepared["identity"];
  selected = First @ Select[prepared["candidates"], TrueQ[Lookup[#, "selected", False]] &];
  If[
    Lookup[route, "schema", None] =!= "canon-neu/route-decision/v1" ||
      Lookup[route, "decision", None] =!= "REPAIR_WITH_LIBRA",
    Return[repairFailure["route_decision.decision", "route decision must be exactly REPAIR_WITH_LIBRA"]]
  ];
  If[
    Lookup[route, "preparation_id", None] =!= identity["preparation_id"] ||
      Lookup[route, "family_id", None] =!= identity["family_id"] ||
      Lookup[route, "basis_id", None] =!= identity["basis_id"] ||
      Lookup[route, "selected_candidate_id", None] =!= selected["candidate_id"],
    Return[repairFailure["route_decision.identity", "route identity or selected candidate does not match the prepared basis"]]
  ];
  If[Lookup[request, "schema", None] =!= "canon-neu/libra-structured-repair-input/v1",
    Return[repairFailure["schema", "unexpected repair request schema"]]
  ];
  If[
    Lookup[request, "preparation_id", None] =!= identity["preparation_id"] ||
      Lookup[request, "family_id", None] =!= identity["family_id"] ||
      Lookup[request, "basis_id", None] =!= identity["basis_id"] ||
      Lookup[request, "selected_candidate_id", None] =!= selected["candidate_id"],
    Return[repairFailure["identity", "repair request identity or selected candidate mismatch"]]
  ];
  If[
    Lookup[request, "coefficient_domain", None] =!= "exact-rational-functions" ||
      Lookup[request, "convention", None] =!= "old_basis = transformation . new_basis",
    Return[repairFailure["convention", "repair request requires the exact rational domain and old_basis transformation convention"]]
  ];
  True
];

validateRepairSystem[identity_Association, request_Association] := Module[
  {variables, regulator, parameters, basis, matrices, dimension, allowedSymbols, alphabet},
  variables = Lookup[request, "variables", None];
  regulator = Lookup[request, "regulator", None];
  parameters = Lookup[request, "parameters", None];
  basis = Lookup[request, "basis", None];
  matrices = Lookup[request, "original_matrices", None];
  If[
    variables =!= {First[identity["variables"]]} || Length[identity["variables"]] =!= 1 ||
      !MatchQ[regulator, _Symbol] || parameters =!= {} || !ListQ[basis] || basis === {},
    Return[repairFailure["differential_system", "v1 requires one variable, one regulator, and parameters={} in an ordered basis"]]
  ];
  If[regulator =!= identity["regulator"],
    Return[repairFailure["differential_system.identity", "variables or regulator contradict the prepared basis"]]
  ];
  dimension = Length[basis];
  allowedSymbols = Join[variables, {regulator}, parameters];
  If[
    !matrixListShapeQ[matrices, Length[variables], dimension] ||
      !And @@ (DeclaredCoefficientDomainQ[#, allowedSymbols] & /@ Flatten[matrices]),
    Return[repairFailure["original_matrices", "full differential matrices must be exact rational square matrices in basis order"]]
  ];
  alphabet = Lookup[request, "alphabet", None];
  If[
    !ListQ[alphabet] || alphabet === {} ||
      !And @@ (DeclaredCoefficientDomainQ[#, allowedSymbols] & /@ alphabet) ||
      !FreeQ[alphabet, regulator],
    Return[repairFailure["alphabet", "declared alphabet must be nonempty, exact rational, and regulator independent"]]
  ];
  True
];

validateRepairPrefix[prepared_Association, request_Association] := Module[
  {prefix, variables, regulator, matrices, dimension, allowedSymbols, alphabet,
    frozen, prefixDimension, acceptedMatrices, prefixRows, tailRows, prefixDLog, acceptedBlocks},
  prefix = prepared["frozen_lower_prefix"];
  variables = request["variables"];
  regulator = request["regulator"];
  matrices = request["original_matrices"];
  dimension = Length[request["basis"]];
  allowedSymbols = Join[variables, {regulator}, request["parameters"]];
  alphabet = request["alphabet"];
  frozen = Lookup[request, "frozen_prefix", None];
  If[!AssociationQ[frozen], Return[repairFailure["frozen_prefix", "frozen-prefix contract is missing"]]];
  prefixDimension = Lookup[frozen, "dimension", None];
  acceptedMatrices = Lookup[frozen, "accepted_matrices", None];
  If[
    prefixDimension =!= 1 || dimension =!= 3 || Length[prepared["current_basis"]["basis"]] =!= 2 ||
      Lookup[request, "repair_scope", None] =!= "DIRECT_SUM_1X1_PREFIX_PLUS_2X2_TAIL_INTERNAL" ||
      Lookup[frozen, "prefix_id", None] =!= prefix["prefix_id"] ||
      Lookup[frozen, "basis", None] =!= prefix["basis"] ||
      Lookup[frozen, "order", None] =!= Range[prefixDimension] ||
      prefixDimension =!= Length[prefix["basis"]] ||
      request["basis"] =!= Join[prefix["basis"], prepared["current_basis"]["basis"]] ||
      !matrixListShapeQ[acceptedMatrices, Length[variables], prefixDimension] ||
      !And @@ (DeclaredCoefficientDomainQ[#, allowedSymbols] & /@ Flatten[acceptedMatrices]),
    Return[repairFailure["frozen_prefix", "v1 requires a direct-sum 1x1 accepted prefix plus an ordered 2x2 tail"]]
  ];
  prefixRows = 1 ;; prefixDimension;
  tailRows = prefixDimension + 1 ;; dimension;
  If[
    !sameMatrixListsQ[matrixBlocks[matrices, prefixRows, prefixRows], acceptedMatrices] ||
      !zeroMatrixListQ[matrixBlocks[matrices, prefixRows, tailRows]] ||
      !zeroMatrixListQ[matrixBlocks[matrices, tailRows, prefixRows]],
    Return[repairFailure["frozen_prefix.source_blocks", "v1 source must be the declared 1x1 prefix direct-summed with a 2x2 tail"]]
  ];
  (* The contract already restricts this prefix to one variable. The dlog gate
     includes epsilon factorization, so no duplicate regulator check is needed. *)
  prefixDLog = DLogConnectionQ[acceptedMatrices, variables, regulator, alphabet];
  If[!TrueQ[prefixDLog],
    Return[repairFailure[
      "frozen_prefix.accepted_matrices",
      "accepted 1x1 prefix must be flat, epsilon-factorized without residual regulator dependence, and in the declared dlog alphabet"
    ]]
  ];
  acceptedBlocks = Lookup[frozen, "accepted_blocks", None];
  If[
    Sort[acceptedBlocks] =!= Sort[{"prefix-prefix", "prefix-from-tail", "tail-from-prefix"}],
    Return[repairFailure["frozen_prefix.accepted_blocks", "v1 fixes all direct-sum prefix and cross blocks"]]
  ];
  If[
    Sort[Lookup[frozen, "forbidden_mixing", {}]] =!= Sort[{"prefix-from-tail", "tail-from-prefix"}],
    Return[repairFailure["frozen_prefix.forbidden_mixing", "v1 forbids both cross-block transformation mixings"]]
  ];
  True
];

validateRepairTarget[prepared_Association, request_Association] := Module[
  {target, signature, expectedFullEntry},
  target = Lookup[request, "localized_target", None];
  If[
    !AssociationQ[target] || Lookup[target, "scope", None] =!= "LOCALIZED_BLOCK" ||
      Lookup[target, "prepared_block", None] =!= "current-current" ||
      prepared["quality"]["localized_defect"]["block"] =!= "current-current" ||
      Lookup[target, "prepared_signature", None] =!= prepared["quality"]["localized_defect"]["signature"] ||
      !MatchQ[Lookup[target, "full_entry", None], {_Integer, _Integer}] ||
      Lookup[target, "failure_test", None] =!= "REGULATOR_INDEPENDENT_TERM",
    Return[repairFailure["localized_target", "localized target does not match the prepared defect signature"]]
  ];
  signature = target["prepared_signature"];
  If[
    Lookup[signature, "kind", None] =!= "epsilon-factorization" ||
      !IntegerQ[Lookup[signature, "row", None]] || !IntegerQ[Lookup[signature, "column", None]] ||
      !Between[signature["row"], {1, 2}] || !Between[signature["column"], {1, 2}],
    Return[repairFailure[
      "localized_target.prepared_signature",
      "v1 target must be an epsilon-factorization defect inside the 2x2 current-current tail"
    ]]
  ];
  expectedFullEntry = request["frozen_prefix"]["dimension"] + {signature["row"], signature["column"]};
  If[target["full_entry"] =!= expectedFullEntry,
    Return[repairFailure["localized_target.full_entry", "full_entry must equal prefix_dimension + prepared current-current coordinates"]]
  ];
  True
];

validateRepairSearch[prepared_Association, request_Association] := Module[{search},
  search = Lookup[request, "search_evidence", None];
  If[search =!= prepared["search_history"],
    Return[repairFailure["search_evidence", "repair search evidence must exactly match the validated prepared basis"]]
  ];
  If[!TrueQ[search["pool_exhausted"]],
    Return[repairFailure["search_evidence.pool_exhausted", "repair requires complete candidate-pool exhaustion"]]
  ];
  (* A validated exhausted history already has zero alternatives and all IDs attempted. *)
  True
];

ValidateStructuredRepairInput[
  prepared_Association, route_Association, request_Association
] := Module[{check},
  check = ValidatePreparedBasis[prepared];
  If[FailureQ[check],
    Return[repairFailure["prepared_basis", "prepared basis did not pass canon-neu/prepared-basis/v1 validation"]]
  ];
  check = validateRepairBindings[prepared, route, request];
  If[FailureQ[check], Return[check]];
  check = validateRepairSystem[prepared["identity"], request];
  If[FailureQ[check], Return[check]];
  check = validateRepairPrefix[prepared, request];
  If[FailureQ[check], Return[check]];
  check = validateRepairTarget[prepared, request];
  If[FailureQ[check], Return[check]];
  check = validateRepairSearch[prepared, request];
  If[FailureQ[check], Return[check]];
  request
];

StructuredRepairPublicationGate[
  request_Association,
  candidate_Association
] := Module[
  {
    variables, regulator, parameters, allowedSymbols, basis, original, frozen, target, dimension,
    prefixDimension, prefixRows, tailRows, transformation, declared, shape,
    exactDomain, invertible, prefixIdentity, forbiddenMixing, identityMatch,
    providerStatus, reasons
  },
  variables = request["variables"];
  regulator = request["regulator"];
  parameters = request["parameters"];
  allowedSymbols = Join[variables, {regulator}, parameters];
  basis = request["basis"];
  original = request["original_matrices"];
  frozen = request["frozen_prefix"];
  target = request["localized_target"];
  dimension = Length[basis];
  prefixDimension = frozen["dimension"];
  prefixRows = 1 ;; prefixDimension;
  tailRows = prefixDimension + 1 ;; dimension;
  identityMatch =
    Lookup[candidate, "schema", None] === "canon-neu/libra-structured-repair-candidate/v1" &&
      Lookup[candidate, "preparation_id", None] === request["preparation_id"] &&
      Lookup[candidate, "family_id", None] === request["family_id"] &&
      Lookup[candidate, "basis_id", None] === request["basis_id"] &&
      Lookup[candidate, "selected_candidate_id", None] === request["selected_candidate_id"] &&
      Lookup[candidate, "basis", None] === basis &&
      Lookup[candidate, "variables", None] === variables &&
      Lookup[candidate, "regulator", None] === regulator &&
      Lookup[candidate, "parameters", None] === parameters &&
      Lookup[candidate, "repair_scope", None] === request["repair_scope"] &&
      Lookup[candidate, "coefficient_domain", None] === request["coefficient_domain"] &&
      Lookup[candidate, "convention", None] === request["convention"] &&
      Lookup[candidate, "original_matrices", None] === original &&
      Lookup[candidate, "frozen_prefix", None] === frozen &&
      Lookup[candidate, "localized_target", None] === target;
  providerStatus = Lookup[candidate, "provider_status", None] ===
    "PROVISIONAL/CANDIDATE_TRANSFORMATION";
  transformation = Lookup[candidate, "transformation", None];
  declared = Lookup[candidate, "transformed_matrices", None];
  shape = MatrixQ[transformation] && Dimensions[transformation] === {dimension, dimension} &&
    ListQ[declared] && Length[declared] === Length[variables] &&
    And @@ (MatrixQ[#] && Dimensions[#] === {dimension, dimension} & /@ declared);
  exactDomain = TrueQ[shape] &&
    And @@ (DeclaredCoefficientDomainQ[#, allowedSymbols] & /@ Flatten[transformation]) &&
    And @@ (DeclaredCoefficientDomainQ[#, allowedSymbols] & /@ Flatten[declared]);
  invertible = TrueQ[exactDomain] && TrueQ[Together[Det[transformation]] =!= 0];
  prefixIdentity = TrueQ[invertible] && ZeroMatrixQ[
    Map[Together, transformation[[prefixRows, prefixRows]] - IdentityMatrix[prefixDimension], {2}]
  ];
  forbiddenMixing = TrueQ[invertible] &&
    (!MemberQ[frozen["forbidden_mixing"], "prefix-from-tail"] ||
      ZeroMatrixQ[transformation[[prefixRows, tailRows]]]) &&
    (!MemberQ[frozen["forbidden_mixing"], "tail-from-prefix"] ||
      ZeroMatrixQ[transformation[[tailRows, prefixRows]]]);
  reasons = Pick[
    {
      "identity_or_order_mismatch", "forged_provider_status", "candidate_shape_invalid",
      "coefficient_domain_invalid", "singular_transformation", "frozen_prefix_modified",
      "forbidden_prefix_mixing"
    },
    {
      !TrueQ[identityMatch], !TrueQ[providerStatus], !TrueQ[shape], !TrueQ[exactDomain],
      !TrueQ[invertible], !TrueQ[prefixIdentity], !TrueQ[forbiddenMixing]
    }
  ];
  <|
    "pass" -> (reasons === {}),
    "reasons" -> reasons,
    "identity_and_order" -> TrueQ[identityMatch],
    "provider_status_provisional" -> TrueQ[providerStatus],
    "invertible" -> TrueQ[invertible],
    "frozen_prefix_identity" -> TrueQ[prefixIdentity],
    "forbidden_mixing_zero" -> TrueQ[forbiddenMixing]
  |>
];
