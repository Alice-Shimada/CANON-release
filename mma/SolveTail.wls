#!/usr/bin/env wolframscript

$HistoryLength = 0;
repoRoot = DirectoryName[DirectoryName[ExpandFileName[$InputFileName]]];
Get[FileNameJoin[{repoRoot, "mma", "lib", "MethodCardCore.wl"}]];
Get[FileNameJoin[{repoRoot, "mma", "lib", "TailCompletion.wl"}]];

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
      "reason" -> reason, "diagnostics" -> CanonTailCompletion`TailDiagnostics[fullDE, solution]|>,
      details]]
];

{inputPath, outputDir} = ExpandFileName /@ CanonMethodCard`ScriptArguments[];
task = CanonMethodCard`ReadTask[inputPath, "SOLVE_TAIL"];
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
If[!TrueQ[MatrixQ[selected["full_transformation"]] &&
    Dimensions[selected["full_transformation"]] === {dimension, dimension} &&
    AllTrue[Flatten[selected["full_transformation"]], CanonMethodCard`ExactAlgebraicExpressionQ] &&
    Together[Det[selected["full_transformation"]]] =!= 0 &&
    CanonMethodCard`ValidMatrixSystemQ[selected["transformed_matrices"], fullDE["variables"], fullDE["regulator"], dimension]],
  fail["INVALID_TAIL_INPUT", "The selected full transformation must be exact, invertible and correctly shaped."]];
solution = CheckAbort[CanonTailCompletion`CompleteAlgebraicTail[fullDE, selected],
  fail["EXECUTION_INTERRUPTED", "Tail completion was interrupted."]];

If[!TrueQ[solution["solved"]],
  If[!And @@ (CanonMethodCard`ExactRationalExpressionQ /@ Flatten[solution["matrices"]]),
    publishUnsolved[task, outputDir, fullDE, core["candidate_id"], solution,
      "remaining_algebraic_tail_outside_rational_CANONICA_domain"]; Quit[0]
  ];
  package = CanonMethodCard`ResolveMethodPackage[task, inputPath, "CANONICA`"];
  If[FailureQ[package], fail["TOOL_UNAVAILABLE", "Cannot resolve the requested CANONICA package."]];
  solution = CheckAbort[CanonTailCompletion`CompleteRationalTail[
    fullDE, core["candidate_id"], solution, package["entry"]],
    fail["EXECUTION_INTERRUPTED", "The tail backend was interrupted."]];
  If[FailureQ[solution], fail[solution[[1]], solution[[2, "Message"]]]];
  If[!TrueQ[solution["solved"]],
    publishUnsolved[task, outputDir, fullDE, core["candidate_id"], solution,
      "backend_no_transformation"]; Quit[0]
  ]
];

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
  "transformed_matrices" -> solution["matrices"], "method" -> solution["method"]|>;
path = CanonMethodCard`WriteWLArtifact[value, outputDir, "sector-transform.wl"];
CanonMethodCard`WriteResult[task, outputDir, "PASS", "TAIL_READY",
  <|"sector_transform" -> <|"type" -> "mathematica-expression",
    "path" -> FileNameTake[path]|>|>,
  <|"candidate_id" -> core["candidate_id"], "method" -> solution["method"]|>];
