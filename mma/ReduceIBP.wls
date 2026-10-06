#!/usr/bin/env wolframscript

repoRoot = DirectoryName[DirectoryName[ExpandFileName[$InputFileName]]];
Get[FileNameJoin[{repoRoot, "mma", "lib", "MethodCardCore.wl"}]];
{requestPath, outputDir} = ExpandFileName /@ CanonMethodCard`ScriptArguments[];
task = CanonMethodCard`ReadTask[requestPath, "REDUCE_IBP"];
configPath = requestPath;
If[KeyExistsQ[task["payload"], "backend"],
  descriptor = task["payload", "backend"];
  configPath = CanonMethodCard`ResolveInputPath[requestPath, descriptor["path"]];
  config = Import[configPath, "RawJSON"];
  request = If[KeyExistsQ[descriptor, "payload_key"], config["payload", descriptor["payload_key"]], config],
  request = task["payload", "reduction"]
];
request["project"] = CanonMethodCard`ResolveInputPath[configPath, request["project"]];
request["output"] = CanonMethodCard`ResolveInputPath[configPath, request["output"]];
If[StringContainsQ[request["executable"], {"/", "\\"}],
  request["executable"] = CanonMethodCard`ResolveInputPath[configPath, request["executable"]]
];
CopyDirectory[request["project"], request["output"]];
If[KeyExistsQ[task["payload"], "reduction_targets"],
  targetData = Block[{$Context = "CANON`DEData`", $ContextPath = {"System`"}},
    CanonMethodCard`LoadArtifact[task, requestPath, "reduction_targets"]];
  integralText[integral_] := SymbolName[Head[integral]] <> "[" <>
    StringRiffle[ToString[#, InputForm] & /@ (List @@ integral), ","] <> "]";
  Export[FileNameJoin[{request["output"], request["targets"]}],
    StringRiffle[integralText /@ targetData["targets"], "\n"] <> "\n", "Text"]
];

Do[
  process = RunProcess[
    Join[{request["executable"]}, request["options"], {job}],
    All,
    ProcessDirectory -> request["output"]
  ];
  If[process["ExitCode"] =!= 0,
    CanonMethodCard`WriteResult[task, outputDir, "ERROR", "REDUCTION_FAILED", <||>, process];
    Exit[process["ExitCode"]]],
  {job, request["jobs"]}
];

topology = request["topology"];
targetName = FileNameTake[request["targets"]];
masterLines = StringTrim @ StringReplace[
  StringSplit[
    Import[FileNameJoin[{request["output"], "results", topology, "masters.final"}], "Text"],
    {"\r\n", "\n", "\r"}
  ],
  RegularExpression["#.*$"] -> ""
];
masterLines = Select[masterLines, # =!= "" &];
result = Block[{$Context = "CANON`DEData`", $ContextPath = {"System`"}},
  <|
    "masters" -> ToExpression["{" <> StringRiffle[masterLines, ","] <> "}"],
    "rules" -> Get[FileNameJoin[{
      request["output"], "results", topology, "kira_" <> targetName <> ".m"
    }]]
  |>
];
If[KeyExistsQ[task["payload"], "master_basis"],
  expected = Block[{$Context = "CANON`DEData`", $ContextPath = {"System`"}},
    CanonMethodCard`LoadArtifact[task, requestPath, "master_basis"]]["masters"];
  If[Sort[expected] =!= Sort[result["masters"]],
    CanonMethodCard`WriteResult[task, outputDir, "INCONCLUSIVE", "MASTER_BASIS_MISMATCH", <||>,
      <|"reason" -> "Native masters differ from the declared source basis; supply an explicit conversion."|>]; Exit[0]];
  result["masters"] = expected
];
If[ValueQ[targetData],
  head = Head[First[result["masters"]]];
  completeQ[expression_] := Module[{value = Expand[expression /. Dispatch[result["rules"]]], coefficients},
    coefficients = Coefficient[value, #] & /@ result["masters"];
    FreeQ[coefficients, g_ /; Head[g] === head] &&
      TrueQ[Together[value - coefficients . result["masters"]] === 0]
  ];
  If[!AllTrue[Join[targetData["targets"], result["masters"]], completeQ] ||
      !AllTrue[(result["masters"] /. Dispatch[result["rules"]]) - result["masters"], Together[#] === 0 &],
    CanonMethodCard`WriteResult[task, outputDir, "INCONCLUSIVE", "INCOMPLETE_REDUCTION", <||>,
      <|"reason" -> "Targets do not reduce completely in the declared source basis."|>]; Exit[0]]
];
artifactPath = CanonMethodCard`WriteWLArtifact[result, outputDir, "ibp-reduction.wl"];
CanonMethodCard`WriteResult[task, outputDir, "PASS", "IBP_REDUCED",
  <|"ibp_reduction" -> <|"type" -> "mathematica-expression",
    "path" -> FileNameTake[artifactPath]|>|>, Length /@ result];
