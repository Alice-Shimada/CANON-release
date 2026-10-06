#!/usr/bin/env wolframscript

repoRoot = DirectoryName[DirectoryName[$InputFileName]];
arguments = Rest[$ScriptCommandLine];
If[!MemberQ[{2, 3}, Length[arguments]],
  Print["Usage: wolframscript -file tests/RunPentaboxIBPLiveTest.wls KIRA_EXECUTABLE FRESH_OUTPUT [THREADS]"];
  Exit[2]
];

fixture = FileNameJoin[{
  repoRoot, "tests", "fixtures", "kira-massless-two-loop-five-point-pentabox"
}];
output = ExpandFileName[arguments[[2]]];
threads = If[Length[arguments] === 3, ToExpression[arguments[[3]]], 1];
requestPath = output <> ".request.json";
resultDir = output <> ".result";
resultPath = FileNameJoin[{resultDir, "ibp-reduction.wl"}];
request = <|
  "executable" -> First[arguments],
  "project" -> fixture,
  "jobs" -> {"jobs.yaml", "export-math.yaml"},
  "topology" -> "pentabox5",
  "targets" -> "targets",
  "output" -> output,
  "options" -> {"--parallel=" <> ToString[threads]}
|>;
Export[requestPath, <|"schema" -> "canon-neu/script-input/v1",
  "task_id" -> "pentabox-ibp-live-test", "step" -> "REDUCE_IBP", "sector" -> Null,
  "payload" -> <|"reduction" -> request|>|>, "RawJSON"];
process = RunProcess[{"python3", FileNameJoin[{repoRoot, "run_step.py"}],
  requestPath, resultDir
}, All, ProcessDirectory -> repoRoot];
If[process["ExitCode"] =!= 0 || FileType[resultPath] =!= File,
  Print[InputForm[process]];
  Exit[1]
];
result = Block[{$Context = "CANON`DEData`", $ContextPath = {"System`"}}, Get[resultPath]];
sourceLines[name_] := Select[
  StringTrim @ StringReplace[
    StringSplit[Import[FileNameJoin[{fixture, name}], "Text"], {"\r\n", "\n", "\r"}],
    RegularExpression["#.*$"] -> ""
  ],
  # =!= "" &
];
{expectedMasters, expectedTargets} = Block[
  {$Context = "CANON`DEData`", $ContextPath = {"System`"}},
  ToExpression["{" <> StringRiffle[sourceLines[#], ","] <> "}"] & /@
    {"preferred-masters", "targets"}
];
head = Head[First[expectedMasters]];
rhsIntegrals = DeleteDuplicates @ Cases[
  Last /@ result["rules"], item_ /; Head[Unevaluated[item]] === head :> item,
  {0, Infinity}
];
passed = Keys[result] === {"masters", "rules"} &&
  result["masters"] === expectedMasters &&
  (First /@ result["rules"]) === expectedTargets &&
  SubsetQ[expectedMasters, rhsIntegrals] && FreeQ[result, _Real];
Print[InputForm[<|
  "passed" -> passed, "masters" -> Length[result["masters"]],
  "rules" -> Length[result["rules"]], "rhs_integrals" -> Length[rhsIntegrals]
|>]];
Exit[If[passed, 0, 1]];
