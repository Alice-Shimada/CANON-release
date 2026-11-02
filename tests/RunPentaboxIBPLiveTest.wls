#!/usr/bin/env wolframscript

$HistoryLength = 0;
repoRoot = DirectoryName[DirectoryName[ExpandFileName[$InputFileName]]];
Get[FileNameJoin[{repoRoot, "mma", "lib", "MethodCardCore.wl"}]];
arguments = CanonMethodCard`ScriptArguments[];
If[!MemberQ[{2, 3}, Length[arguments]],
  Print["Usage: wolframscript -file tests/RunPentaboxIBPLiveTest.wls KIRA_EXECUTABLE FRESH_OUTPUT [THREADS]"];
  Exit[2]
];

fixture = FileNameJoin[{
  repoRoot, "tests", "fixtures", "kira-massless-two-loop-five-point-pentabox"
}];
output = ExpandFileName[arguments[[2]]];
If[Length[arguments] === 3 &&
    (!StringMatchQ[arguments[[3]], DigitCharacter ..] || FromDigits[arguments[[3]]] < 1),
  Print["THREADS must be a positive integer."]; Exit[2]];
threads = If[Length[arguments] === 3, FromDigits[arguments[[3]]], 1];
requestPath = output <> ".request.json";
resultDir = output <> ".result";
resultJSONPath = FileNameJoin[{resultDir, "result.json"}];
If[AnyTrue[{output, requestPath, resultDir, output <> ".check"}, FileExistsQ],
  Print["Require fresh reduction, request, result and check output paths."]; Exit[2]];
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
python = Environment["CANON_PYTHON"];
If[!StringQ[python], python = "python3"];
process = RunProcess[{python, FileNameJoin[{repoRoot, "run_step.py"}],
  requestPath, resultDir
}, All, ProcessDirectory -> repoRoot];
reducerResult = Quiet @ Check[Import[resultJSONPath, "RawJSON"], $Failed];
If[process["ExitCode"] =!= 0 || !AssociationQ[reducerResult] ||
    Lookup[reducerResult, {"schema", "task_id", "step", "status"}] =!=
      {"canon-neu/script-result/v1", "pentabox-ibp-live-test", "REDUCE_IBP", "PASS"},
  Print[InputForm[<|"process" -> process, "result" -> reducerResult|>]];
  Exit[1]
];
reductionDescriptor = Lookup[Lookup[reducerResult, "artifacts", <||>], "ibp_reduction", None];
If[!AssociationQ[reductionDescriptor] || !StringQ[Lookup[reductionDescriptor, "path", None]],
  Print[InputForm[reducerResult]]; Exit[1]];
resultPath = CanonMethodCard`ResolveInputPath[resultJSONPath, reductionDescriptor["path"]];
If[FileType[resultPath] =!= File ||
    (KeyExistsQ[reductionDescriptor, "sha256"] &&
      Quiet @ Check[FileHash[resultPath, "SHA256", "HexString"], $Failed] =!= reductionDescriptor["sha256"]),
  Print["Declared reduction artifact is missing or its hash does not match."]; Exit[1]];
wolfram = Environment["CANON_WOLFRAMSCRIPT"];
If[!StringQ[wolfram], wolfram = "wolframscript"];
check = RunProcess[{wolfram, "-file", FileNameJoin[{repoRoot, "tests", "CheckPentaboxIBP.wls"}],
  resultPath, output <> ".check"}, All, ProcessDirectory -> repoRoot];
Print[check["StandardOutput"]];
If[check["StandardError"] =!= "", Print[check["StandardError"]]];
Exit[If[check["ExitCode"] === 0, 0, 1]];
