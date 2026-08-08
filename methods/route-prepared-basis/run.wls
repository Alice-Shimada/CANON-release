$HistoryLength = 0;

repoRoot = DirectoryName[DirectoryName[DirectoryName[ExpandFileName[$InputFileName]]]];
Get[FileNameJoin[{repoRoot, "mma", "lib", "MethodCardCore.wl"}]];

args = CanonMethodCard`ScriptArguments[];
If[Length[args] =!= 2, Print["用法：run.wls <input.json> <output_dir>"]; Quit[2]];
{inputPath, outputDir} = ExpandFileName /@ args;
task = CanonMethodCard`ReadTask[inputPath, "ROUTE_PREPARED_BASIS"];
If[FailureQ[task], Print[InputForm[task]]; Quit[2]];

writeFailure[reason_String, field_] := (
  CanonMethodCard`WriteResult[
    task,
    outputDir,
    "ERROR",
    "INVALID_PREPARED_BASIS",
    <||>,
    <|"reason" -> reason, "field" -> field|>
  ];
  Quit[1]
);

prepared = CanonMethodCard`LoadArtifact[task, inputPath, "prepared_basis"];
If[FailureQ[prepared],
  writeFailure["prepared_basis artifact could not be loaded", "prepared_basis"]
];
validated = CanonMethodCard`ValidatePreparedBasis[prepared];
If[FailureQ[validated],
  writeFailure[
    Lookup[validated[[2]], "Message", "prepared_basis validation failed"],
    Lookup[validated[[2]], "Field", "prepared_basis"]
  ]
];

decision = CanonMethodCard`PreparedBasisRoute[validated];
If[FailureQ[decision],
  writeFailure["prepared_basis route construction failed", "prepared_basis"]
];
artifactPath = CanonMethodCard`WriteWLArtifact[
  decision,
  outputDir,
  "route-decision.wl"
];
If[artifactPath === $Failed,
  CanonMethodCard`WriteResult[
    task, outputDir, "ERROR", "OUTPUT_ERROR", <||>,
    <|"reason" -> "could not write route-decision artifact"|>
  ];
  Quit[1]
];

resultPath = CanonMethodCard`WriteResult[
  task,
  outputDir,
  "PROVISIONAL",
  "ROUTE_DECISION",
  <|
    "route_decision" -> <|
      "type" -> "mathematica-expression",
      "path" -> FileNameTake[artifactPath]
    |>
  |>,
  <|
    "decision" -> decision["decision"],
    "reason" -> decision["reason"],
    "selected_candidate_id" -> decision["selected_candidate_id"],
    "initial_evidence_controls_route" -> False
  |>
];
If[resultPath === $Failed, Print["写入 result.json 失败"]; Quit[1]];
Quit[0];
