#!/usr/bin/env wolframscript

$HistoryLength = 0;
repoRoot = DirectoryName[DirectoryName[ExpandFileName[$InputFileName]]];
Get[FileNameJoin[{repoRoot, "mma", "lib", "MethodCardCore.wl"}]];
Get[FileNameJoin[{repoRoot, "mma", "lib", "TailCompletion.wl"}]];
Get[FileNameJoin[{repoRoot, "mma", "lib", "CanonicaTailControl.wl"}]];
Get[FileNameJoin[{repoRoot, "methods", "canonica", "Control.wl"}]];

publishUnsolved[task_, outputDir_, fullDE_, candidateID_, solution_, reason_] := Module[
  {artifacts = <||>, details = <||>, failure, path},
  If[KeyExistsQ[solution, "backend_failure"],
    failure = solution["backend_failure"];
    path = CanonMethodCard`WriteWLArtifact[failure, outputDir, "backend-failure.wl"];
    artifacts = <|"backend_failure" -> <|"type" -> "mathematica-expression",
      "path" -> FileNameTake[path]|>|>;
    details = <|"backend_stage" -> failure["stage"]|>
  ];
  CanonMethodCard`WriteResult[task, outputDir, "INCONCLUSIVE", "TAIL_UNSOLVED", artifacts,
    Join[<|"candidate_id" -> candidateID, "method" -> solution["method"],
      "reason" -> reason, "diagnostics" -> CanonTailCompletion`TailDiagnostics[fullDE, solution],
      "builtin_completion" -> solution["builtin_completion"]|>,
      details]]
];

{inputPath, outputDir} = ExpandFileName /@ CanonMethodCard`ScriptArguments[];
task = CanonMethodCard`ReadTask[inputPath, "SOLVE_TAIL"];
If[AnyTrue[{"result.json", "canonica-tail-messages.log"},
    FileExistsQ[FileNameJoin[{outputDir, #}]] &],
  Print["OUTPUT_ERROR: use a fresh output directory."]; Quit[1]];
tailOptions = CanonTailControl`ReadOptions[task];
If[FailureQ[tailOptions], CanonMethodCard`WriteResult[task, outputDir, "ERROR",
  "INVALID_OPTIONS", <||>, <|"reason" -> ToString[tailOptions, InputForm]|>]; Quit[1]];
backendEvidence = <||>; backendArtifacts = <||>;
fullDE = CanonMethodCard`LoadArtifact[task, inputPath, "full_sector_de"];
core = CanonMethodCard`LoadArtifact[task, inputPath, "core_transform"];
fail[code_, reason_] := (CanonMethodCard`WriteResult[task, outputDir, "ERROR",
  code, <||>, <|"reason" -> reason|>]; Quit[1]);
If[!AssociationQ[fullDE] || !AssociationQ[core] ||
  Lookup[fullDE, "schema", None] =!= "canon-neu/full-prefix-candidates/v1" ||
  !StringQ[Lookup[core, "candidate_id", None]] || !ListQ[Lookup[fullDE, "candidates", None]] ||
  !AllTrue[fullDE["candidates"], AssociationQ],
  fail["INVALID_TAIL_INPUT", "Supply a full-prefix candidate artifact and its selected core."]];
If[Lookup[core, "schema", None] =!= "canon-neu/core-transform/v1" ||
  !TrueQ[Lookup[Lookup[core, "checks", <||>], "pass", False]] ||
  !AllTrue[{"family_id", "variables", "regulator"},
    KeyExistsQ[core, #] && core[#] === fullDE[#] &] ||
  core["basis_id"] =!= fullDE["current_basis_id"] || !CanonMethodCard`SameSectorQ[task["sector"], fullDE["sector"], core["sector"]],
  fail["INVALID_TAIL_INPUT", "The passing core and full prefix must bind the same scientific inputs."]];
{lowerDimension, currentDimension} = Lookup[Lookup[fullDE, "block_boundaries", <||>],
  {"lower_dimension", "current_dimension"}, None];
dimension = lowerDimension + currentDimension;
If[!TrueQ[IntegerQ[lowerDimension] && lowerDimension >= 0 &&
    IntegerQ[currentDimension] && currentDimension > 0 &&
    ListQ[fullDE["source_basis"]] && Length[fullDE["source_basis"]] === dimension &&
    core["basis"] === Take[fullDE["source_basis"], -currentDimension] &&
    CanonMethodCard`ValidMatrixSystemQ[fullDE["source_matrices"], fullDE["variables"], fullDE["regulator"], dimension] &&
    ListQ[fullDE["alphabet"]] && AllTrue[fullDE["alphabet"], CanonMethodCard`ExactAlgebraicExpressionQ]],
  fail["INVALID_TAIL_INPUT", "Invalid full-prefix dimensions, ordered current basis or exact matrices."]];
selected = Select[fullDE["candidates"], Lookup[#, "candidate_id", None] === core["candidate_id"] &];
If[Length[selected] =!= 1,
  fail["INVALID_TAIL_INPUT", "The selected core must identify exactly one full-prefix candidate."]];
selected = First[selected];
{variables, regulator} = fullDE /@ {"variables", "regulator"};
If[!TrueQ[MatrixQ[selected["full_transformation"]] &&
    Dimensions[selected["full_transformation"]] === {dimension, dimension} &&
    AllTrue[Flatten[selected["full_transformation"]], CanonMethodCard`ExactAlgebraicExpressionQ] &&
    Together[Det[selected["full_transformation"]]] =!= 0 &&
    CanonMethodCard`ValidMatrixSystemQ[selected["transformed_matrices"], fullDE["variables"], fullDE["regulator"], dimension]],
  fail["INVALID_TAIL_INPUT", "The selected full transformation must be exact, invertible and correctly shaped."]];
tailStarted = AbsoluteTime[];
solution = CheckAbort[CanonTailCompletion`CompleteAlgebraicTail[fullDE, selected, tailOptions["max_wall_seconds"]],
  fail["EXECUTION_INTERRUPTED", "Tail completion was interrupted."]];
solution = Join[solution, <|"builtin_completion" ->
  Join[<|"attempted" -> True|>, KeyTake[solution, {"method", "solved", "dlog_epsilon_normalization"}]]|>];

If[!TrueQ[solution["solved"]],
  If[!And @@ (CanonMethodCard`ExactRationalExpressionQ /@ Flatten[solution["matrices"]]),
    publishUnsolved[task, outputDir, fullDE, core["candidate_id"], solution,
      "remaining_algebraic_tail_outside_rational_CANONICA_domain"]; Quit[0]
  ];
  transformation = solution["transformation"]; matrices = solution["matrices"];
  If[!DirectoryQ[outputDir], CreateDirectory[outputDir, CreateIntermediateDirectories -> True]];
  messageStream = OpenWrite[FileNameJoin[{outputDir, "canonica-tail-messages.log"}]];
  initialKernels = Kernels[];
  backend = Block[{$Messages = Append[$Messages, messageStream]},
    CanonTailControl`RunBackend[task, inputPath, fullDE, core,
      transformation, matrices, tailOptions]];
  createdKernels = Complement[Kernels[], initialKernels];
  If[createdKernels =!= {}, CloseKernels[createdKernels]];
  Close[messageStream];
  backendArtifacts = <|"method_messages" -> <|"type" -> "text",
    "path" -> "canonica-tail-messages.log"|>|>;
  backendEvidence = KeyDrop[backend, {"backend_transformation", "checkpoint", "failure_artifact"}];
  If[!TrueQ[backend["success"]],
    If[TrueQ[backend["input_error"]],
      CanonMethodCard`WriteResult[task, outputDir, "ERROR", Lookup[backend, "error_code", "INVALID_INPUT"], backendArtifacts,
        <|"reason" -> backend["reason"], "backend" -> backendEvidence,
          "builtin_completion" -> solution["builtin_completion"]|>]; Quit[1]];
    checkpointArtifacts = <||>;
    If[KeyExistsQ[backend, "checkpoint"],
      checkpointPath = CanonMethodCard`WriteWLArtifact[backend["checkpoint"], outputDir,
        "tail-checkpoint.wl"];
      checkpointArtifacts = <|"tail_checkpoint" -> <|"type" -> "mathematica-expression",
        "path" -> FileNameTake[checkpointPath],
        "sha256" -> FileHash[checkpointPath, "SHA256", "HexString"]|>|>];
    failureDetails = <||>;
    If[KeyExistsQ[backend, "failure_artifact"],
      failurePath = CanonMethodCard`WriteWLArtifact[backend["failure_artifact"], outputDir,
        "backend-failure.wl"];
      checkpointArtifacts = Join[checkpointArtifacts, <|"backend_failure" -> <|
        "type" -> "mathematica-expression", "path" -> FileNameTake[failurePath]|>|>];
      failureDetails = <|"backend_stage" -> backend["backend_stage"]|>];
    interrupted = AnyTrue[Lookup[backend, "diagnostics", {}], TrueQ[Lookup[#, "aborted", False]] &];
    CanonMethodCard`WriteResult[task, outputDir, If[interrupted, "ERROR", "INCONCLUSIVE"],
      If[interrupted, "EXECUTION_INTERRUPTED", "TAIL_UNSOLVED"],
      Join[backendArtifacts, checkpointArtifacts], Join[<|"candidate_id" -> core["candidate_id"],
      "method" -> "canonica-off-diagonal", "reason" -> backend["reason"],
      "backend" -> backendEvidence, "diagnostics" -> CanonTailCompletion`TailDiagnostics[fullDE, solution],
      "builtin_completion" -> solution["builtin_completion"]|>,
      failureDetails]]; Quit[If[interrupted, 1, 0]]
  ];
  backendTransformation = backend["backend_transformation"];
  transformation = Map[Together, transformation.backendTransformation, {2}];
  matrices = CanonMethodCard`GaugeTransform[fullDE["source_matrices"], variables, transformation];
  alphabet = DeleteDuplicates @ Join[fullDE["alphabet"],
    CanonMethodCard`DLogAlphabet[matrices, variables, regulator]];
  If[!CanonMethodCard`DLogConnectionQ[matrices, variables, regulator, alphabet],
    publishUnsolved[task, outputDir, fullDE, core["candidate_id"], solution,
      "backend_final_epsilon_or_dlog_check_failed"]; Quit[0]];
  solution = Join[solution, <|"transformation" -> transformation, "matrices" -> matrices,
    "alphabet" -> alphabet, "method" -> "canonica-off-diagonal", "solved" -> True|>];
];

solution = CanonTailCompletion`SimplifyCanonicalTail[solution, variables, regulator,
  Max[0, Min[1, tailOptions["max_wall_seconds"]/50,
    tailOptions["max_wall_seconds"] - (AbsoluteTime[] - tailStarted)]]];

value = <|"schema" -> "canon-neu/sector-transform/v1",
  "sector" -> fullDE["sector"], "family_id" -> fullDE["family_id"],
  "current_basis_id" -> fullDE["current_basis_id"],
  "accepted_prefix_id" -> fullDE["accepted_prefix_id"],
  "coefficient_domain" -> "exact-algebraic-functions",
  "source_basis" -> fullDE["source_basis"], "variables" -> fullDE["variables"],
  "regulator" -> fullDE["regulator"], "alphabet" -> solution["alphabet"],
  "convention" -> fullDE["convention"], "candidate_id" -> core["candidate_id"],
  "member_candidate_ids" -> selected["member_candidate_ids"],
  "transformation" -> solution["transformation"],
  "transformed_matrices" -> solution["matrices"], "method" -> solution["method"],
  "backend" -> backendEvidence|>;
path = CanonMethodCard`WriteWLArtifact[value, outputDir, "sector-transform.wl"];
CanonMethodCard`WriteResult[task, outputDir, "PASS", "TAIL_READY",
  Join[backendArtifacts, <|"sector_transform" -> <|"type" -> "mathematica-expression",
    "path" -> FileNameTake[path]|>|>],
  Join[<|"candidate_id" -> core["candidate_id"], "method" -> solution["method"], "backend" -> backendEvidence,
    "builtin_completion" -> solution["builtin_completion"]|>,
    KeyTake[solution, {"representation_simplification"}]]];
