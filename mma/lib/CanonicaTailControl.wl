(* Bounded CANONICA tail operations; accepted results still use CHECK_CANONICAL. *)
BeginPackage["CanonTailControl`"];
ReadOptions::usage = "ReadOptions[task] validates optional tail controls without changing legacy defaults.";
RunBackend::usage = "RunBackend[task,inputPath,fullDE,core,T,A,options] returns a complete backend map or a bound checkpoint.";
Begin["`Private`"];

bad[reason_] := Failure["INVALID_TAIL_OPTIONS", <|"reason" -> reason|>];
ReadOptions[task_Association] := Module[{o, values},
  o = Lookup[task["payload"], "method_options", <||>];
  If[!AssociationQ[o], Return[bad["method_options must be an object"]]];
  If[Complement[Keys[o], {"package_entry", "tail_strategy", "d_delta_numerator_degree",
      "max_wall_seconds", "max_subsector_steps", "max_ansatz_terms"}] =!= {},
    Return[bad["unknown tail method_options"]]];
  values = Join[<|"tail_strategy" -> "monolithic", "d_delta_numerator_degree" -> 0,
    "max_wall_seconds" -> 60, "max_subsector_steps" -> 64, "max_ansatz_terms" -> 256|>, o];
  If[!MemberQ[{"monolithic", "subsector"}, values["tail_strategy"]] ||
      !IntegerQ[values["d_delta_numerator_degree"]] || values["d_delta_numerator_degree"] < 0 ||
      !NumberQ[values["max_wall_seconds"]] || !TrueQ[values["max_wall_seconds"] > 0] ||
      !And @@ (IntegerQ[values[#]] && values[#] > 0 & /@
        {"max_subsector_steps", "max_ansatz_terms"}), Return[bad["invalid tail strategy or finite budget"]]];
  If[values["tail_strategy"] =!= "subsector" &&
      (KeyExistsQ[task["payload"], "d_ansatz"] || KeyExistsQ[task["payload"], "tail_checkpoint"] ||
        KeyExistsQ[o, "max_subsector_steps"]),
    Return[bad["D ansatz, checkpoints and step budgets require tail_strategy=subsector"]]];
  values
];

partitionQ[b_, n_] := ListQ[b] && b =!= {} &&
  And @@ (MatchQ[#, {_Integer, _Integer}] && 1 <= #[[1]] <= #[[2]] <= n & /@ b) &&
  First[b][[1]] === 1 && Last[b][[2]] === n &&
  And @@ MapThread[#1[[2]] + 1 === #2[[1]] &, {Most[b], Rest[b]}];
triangularQ[a_, b_] := And @@ Flatten[Table[
  CanonMethodCard`ZeroMatrixQ[m[[block[[1]] ;; block[[2]], block[[2]] + 1 ;; Length[m]]]],
  {m, a}, {block, Most[b]}]];
loadCheckpoint[task_, inputPath_] := Module[{descriptor, path, hash, value},
  descriptor = Lookup[task["payload"], "tail_checkpoint", None];
  If[descriptor === None, Return[None]];
  If[!AssociationQ[descriptor] || Lookup[descriptor, "type", None] =!= "mathematica-expression" ||
      !StringQ[Lookup[descriptor, "path", None]] ||
      !StringMatchQ[Lookup[descriptor, "sha256", ""], RegularExpression["[0-9a-fA-F]{64}"]],
    Return[Failure["INVALID_CHECKPOINT", <|"reason" -> "checkpoint descriptor requires path and sha256"|>]]];
  path = CanonMethodCard`ResolveInputPath[inputPath, descriptor["path"]];
  If[FileType[path] =!= File, Return[Failure["INVALID_CHECKPOINT", <|"reason" -> "checkpoint is missing"|>]]];
  hash = FileHash[path, "SHA256", "HexString"];
  If[ToLowerCase[descriptor["sha256"]] =!= ToLowerCase[hash],
    Return[Failure["INVALID_CHECKPOINT", <|"reason" -> "checkpoint hash mismatch"|>]]];
  value = CanonMethodCard`LoadArtifact[task, inputPath, "tail_checkpoint"];
  If[FailureQ[value], value, Join[value, <|"input_checkpoint_sha256" -> hash|>]]
];

RunBackend[task_, inputPath_, full_, core_, baseT_, matrices_, options_] := Module[
  {package, entry, entryHash, variables, regulator, lower, dim, dependencies, active,
   activeLower, n, bounds, lowerBounds, backend, binding, identity, ansatz, terms = {},
   ansatzInfo = <||>, checkpoint, previousD, columns, completed, stage, result, lifted,
   embedding, fullBounds, normalized, started, seconds, diagnostics = {}, steps = 0,
   checkpointValue, inputContextPath = $ContextPath, failure, record,
   rationalMatrixQ, checkedResultQ, backendFailure, normalizationMatrices},
  failure[reason_, error_:False, extra_:<||>] := Join[<|"success" -> False,
    "reason" -> reason, "input_error" -> error, "diagnostics" -> diagnostics|>, extra];
  package = CanonMethodCard`ResolveMethodPackage[task, inputPath, "CANONICA`"];
  If[FailureQ[package], Return[failure["canonica_package_unavailable", True,
    <|"error_code" -> If[package[[1]] === "METHOD_PACKAGE_UNAVAILABLE",
      "TOOL_UNAVAILABLE", package[[1]]]|>]]];
  entry = package["entry"]; entryHash = FileHash[entry, "SHA256", "HexString"];
  If[!TrueQ[Quiet @ Check[Get[entry]; True, False]] ||
      DownValues[CANONICA`TransformOffDiagonalBlock] === {} ||
      DownValues[CANONICA`TransformDlogToEpsForm] === {},
    Return[failure["missing_public_tail_API", True, <|"error_code" -> "TOOL_ERROR"|>]]];
  variables = full["variables"]; regulator = full["regulator"];
  backendFailure[reason_, callStage_, initial_, positions_, callBounds_,
      callMatrices_, callOptions_, heldReturn_] := failure[reason, False, <|
    "backend_stage" -> callStage,
    "failure_artifact" -> <|"schema" -> "canon-neu/tail-backend-failure/v1",
      "stage" -> callStage, "candidate_id" -> core["candidate_id"],
      "package_entry" -> entry, "backend_return" -> heldReturn,
      "call" -> <|"variables" -> variables, "regulator" -> CANONICA`eps,
        "active_positions" -> positions, "sector_boundaries" -> callBounds,
        "initial_transformation" -> initial, "matrices" -> callMatrices,
        "options" -> callOptions|>|>|>];
  rationalMatrixQ[value_, expectedDimensions_] := ListQ[value] &&
    Dimensions[value] === expectedDimensions && And @@
      (CanonMethodCard`DeclaredCoefficientDomainQ[#, Append[variables, CANONICA`eps]] & /@
        Flatten[value]);
  (* Provider-result verification shares the same finite attempt budget. In
     particular, a large symbolic determinant cannot escape the solver limit. *)
  checkedResultQ[value_, expectedDimensions_, determinantQ_, requestedStage_, block_] := Module[{check},
    check = CanonCANONICAControl`CaptureStage[
      rationalMatrixQ[value, expectedDimensions] &&
        (!TrueQ[determinantQ] || Together[Det[value]] =!= 0),
      requestedStage, block, seconds[], ansatzInfo];
    If[check["result"] === False,
      check["diagnostics"] = Join[check["diagnostics"],
        <|"diagnostic_classes" -> {"invalid_provider_result"}|>]];
    AppendTo[diagnostics, check["diagnostics"]];
    TrueQ[check["result"]]
  ];
  lower = full["block_boundaries", "lower_dimension"]; dim = Length[baseT];
  dependencies = Table[Union @@ (Flatten[Position[#[[i]], z_ /; z =!= 0,
    {1}, Heads -> False]] & /@ matrices), {i, dim}];
  active = FixedPoint[Union[#, Flatten[dependencies[[#]]]] &, Range[lower + 1, dim]];
  activeLower = Count[active, i_ /; i <= lower]; n = Length[active];
  backend = matrices[[All, active, active]] /. regulator -> CANONICA`eps;
  bounds = If[activeLower === 0, {{1, n}}, {{1, activeLower}, {activeLower + 1, n}}];
  If[options["tail_strategy"] === "subsector" && activeLower > 0,
    If[!NameQ["CANONICA`CalculateNextSubsectorD"] || !NameQ["CANONICA`SectorBoundariesFromDE"],
      Return[failure["missing_public_subsector_API", True]]];
    lowerBounds = CANONICA`SectorBoundariesFromDE[backend[[All, 1 ;; activeLower, 1 ;; activeLower]]];
    If[!partitionQ[lowerBounds, activeLower] || !triangularQ[
        backend[[All, 1 ;; activeLower, 1 ;; activeLower]], lowerBounds],
      Return[failure["invalid_inferred_lower_partition", True]]];
    bounds = Append[lowerBounds, {activeLower + 1, n}]
  ];
  identity = <|"sector" -> full["sector"], "family_id" -> full["family_id"],
    "current_basis_id" -> full["current_basis_id"], "accepted_prefix_id" -> full["accepted_prefix_id"],
    "candidate_id" -> core["candidate_id"], "source_basis" -> full["source_basis"],
    "source_de_sha256" -> FileHash[CanonMethodCard`ResolveInputPath[inputPath,
      task["payload", "full_sector_de", "path"]], "SHA256", "HexString"],
    "regulator" -> regulator|>;
  If[KeyExistsQ[task["payload"], "d_ansatz"],
    ansatz = Block[{$ContextPath = inputContextPath},
      CanonCANONICAControl`LoadFiniteAnsatz[task, inputPath, "d_ansatz",
      <|"kind" -> "D", "identity" -> identity,
        "scope" -> <|"block_bounds" -> {activeLower + 1, n}|>, "variables" -> variables|>,
      options["max_ansatz_terms"]]];
    If[FailureQ[ansatz], Return[failure["invalid_d_ansatz", True, <|"detail" -> ToString[ansatz, InputForm]|>]]];
    terms = ansatz["terms"];
    ansatzInfo = KeyTake[ansatz["provenance"],
      {"path", "sha256", "kind", "scope", "term_count", "max_terms"}]
  ];
  binding = <|"identity" -> identity, "variables" -> variables,
    "entry_sha256" -> entryHash, "active_rows" -> active, "boundaries" -> bounds,
    "backend_sha256" -> Hash[backend, "SHA256", "HexString"],
    "base_transformation_sha256" -> Hash[baseT, "SHA256", "HexString"]|>;
  checkpoint = Block[{$ContextPath = inputContextPath}, loadCheckpoint[task, inputPath]];
  If[FailureQ[checkpoint], Return[failure["invalid_tail_checkpoint", True,
    <|"detail" -> ToString[checkpoint, InputForm]|>]]];
  previousD = Table[{}, {n - activeLower}]; completed = 0;
  If[checkpoint =!= None,
    If[Lookup[checkpoint, "schema", None] =!= "canon-neu/canonica-tail-checkpoint/v1" ||
        Lookup[checkpoint, "binding", None] =!= binding,
      Return[failure["tail_checkpoint_source_mismatch", True]]];
    previousD = Lookup[checkpoint, "previous_d", None] /. regulator -> CANONICA`eps;
    completed = Lookup[checkpoint, "completed_lower_blocks", None];
    If[!ListQ[previousD] || Length[previousD] =!= n - activeLower ||
        !And @@ (ListQ /@ previousD) || Length[Union[Length /@ previousD]] =!= 1 ||
        !And @@ (CanonMethodCard`ExactRationalExpressionQ /@ Flatten[previousD]) ||
        Complement[DeleteDuplicates[Cases[previousD, _Symbol, Infinity]],
          Append[variables, CANONICA`eps]] =!= {} ||
        !IntegerQ[completed] || !(0 <= completed <= Length[bounds] - 1),
      Return[failure["tail_checkpoint_shape_or_domain", True]]];
    columns = Length[First[previousD]];
    If[columns =!= activeLower - If[completed === Length[bounds] - 1, 0,
        bounds[[Length[bounds] - completed - 1, 2]]],
      Return[failure["tail_checkpoint_partition_mismatch", True]]]
  ];
  started = AbsoluteTime[];
  seconds[] := Max[0, options["max_wall_seconds"] - (AbsoluteTime[] - started)];
  checkpointValue[] := <|"schema" -> "canon-neu/canonica-tail-checkpoint/v1",
    "binding" -> binding, "previous_d" -> (previousD /. CANONICA`eps -> regulator),
    "completed_lower_blocks" -> completed, "attempted_ansatz" -> ansatzInfo,
    "diagnostics" -> diagnostics|>;
  If[options["tail_strategy"] === "subsector",
    While[completed < Length[bounds] - 1,
      If[steps >= options["max_subsector_steps"] || seconds[] <= 0,
        Return[failure["subsector_budget_exhausted", False, <|"checkpoint" -> checkpointValue[]|>]]];
      stage = Length[bounds] - completed - 1;
      record = CanonCANONICAControl`CaptureStage[
        CANONICA`CalculateNextSubsectorD[backend, variables, bounds, previousD, terms,
          CANONICA`DDeltaNumeratorDegree -> options["d_delta_numerator_degree"],
          CANONICA`VerbosityLevel -> 1], "off_diagonal_subsector", bounds[[stage]], seconds[], ansatzInfo];
      AppendTo[diagnostics, record["diagnostics"]]; result = record["result"]; steps++;
      If[!ListQ[result] || MatchQ[result, {False, ___}] || !checkedResultQ[result, {n - activeLower,
          activeLower - If[stage === 1, 0, bounds[[stage - 1, 2]]]}, False,
          "off_diagonal_subsector_result_check", bounds[[stage]]],
        Return[failure["subsector_no_transformation", False, <|"checkpoint" -> checkpointValue[]|>]]];
      previousD = result; completed++
    ];
    lifted = IdentityMatrix[n];
    If[activeLower > 0, lifted[[activeLower + 1 ;; n, 1 ;; activeLower]] = previousD],
    record = CanonCANONICAControl`CaptureStage[
      CANONICA`TransformOffDiagonalBlock[variables, bounds, IdentityMatrix[n], backend,
        CANONICA`DDeltaNumeratorDegree -> options["d_delta_numerator_degree"],
        CANONICA`VerbosityLevel -> 1], "off_diagonal", Last[bounds], seconds[], ansatzInfo];
    AppendTo[diagnostics, record["diagnostics"]]; result = record["result"];
    If[!ListQ[result] || Length[result] < 2 || First[result] === False ||
        !checkedResultQ[result[[1]], {n, n}, True,
        "off_diagonal_result_check", Last[bounds]],
      Return[backendFailure["backend_no_transformation", "TransformOffDiagonalBlock",
        IdentityMatrix[n], active, bounds, backend,
        {CANONICA`DDeltaNumeratorDegree -> options["d_delta_numerator_degree"],
          CANONICA`VerbosityLevel -> 1},
        Extract[OwnValues[result], {1, 2}, HoldComplete]]]];
    lifted = result[[1]]
  ];
  embedding = IdentityMatrix[dim][[active]];
  lifted = IdentityMatrix[dim] + Transpose[embedding].(lifted - IdentityMatrix[n]).embedding;
  If[seconds[] <= 0, Return[failure["epsilon_normalization_budget_exhausted", False,
    If[options["tail_strategy"] === "subsector", <|"checkpoint" -> checkpointValue[]|>, <||>]]]];
  fullBounds = If[lower === 0, {{1, dim}}, {{1, lower}, {lower + 1, dim}}];
  normalizationMatrices = CanonMethodCard`GaugeTransform[
    matrices /. regulator -> CANONICA`eps, variables, lifted];
  record = CanonCANONICAControl`CaptureStage[
    CANONICA`TransformDlogToEpsForm[variables, fullBounds, lifted,
      normalizationMatrices,
      CANONICA`VerbosityLevel -> 1], "epsilon_normalization", Last[fullBounds], seconds[], ansatzInfo];
  AppendTo[diagnostics, record["diagnostics"]]; normalized = record["result"];
  If[!ListQ[normalized] || Length[normalized] < 2 || First[normalized] === False ||
      !checkedResultQ[normalized[[1]], {dim, dim}, True,
        "epsilon_normalization_result_check", Last[fullBounds]],
    Return[Join[backendFailure["epsilon_normalization_no_transformation",
      "TransformDlogToEpsForm", lifted, Range[dim], fullBounds, normalizationMatrices,
      {CANONICA`VerbosityLevel -> 1},
      Extract[OwnValues[normalized], {1, 2}, HoldComplete]],
      If[options["tail_strategy"] === "subsector", <|"checkpoint" -> checkpointValue[]|>, <||>]]]];
  <|"success" -> True, "backend_transformation" -> (normalized[[1]] /. CANONICA`eps -> regulator),
    "diagnostics" -> diagnostics, "tail_strategy" -> options["tail_strategy"],
    "boundaries" -> bounds, "active_rows" -> active,
    "completed_lower_blocks" -> completed, "steps_this_attempt" -> steps,
    "resumed" -> (checkpoint =!= None), "entry_sha256" -> entryHash, "ansatz" -> ansatzInfo|>
];
End[];
EndPackage[];
