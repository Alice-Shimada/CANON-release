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
selected = SelectFirst[fullDE["candidates"], #1["candidate_id"] === core["candidate_id"] &];
solution = CanonTailCompletion`CompleteAlgebraicTail[fullDE, selected];

If[!solution["solved"],
  If[!And @@ (CanonMethodCard`ExactRationalExpressionQ /@ Flatten[solution["matrices"]]),
    publishUnsolved[task, outputDir, fullDE, core["candidate_id"], solution,
      "remaining_algebraic_tail_outside_rational_CANONICA_domain"]; Quit[0]
  ];
  package = CanonMethodCard`ResolveMethodPackage[task, inputPath, "CANONICA`"];
  solution = CanonTailCompletion`CompleteRationalTail[
    fullDE, core["candidate_id"], solution, package["entry"]];
  If[!solution["solved"],
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
