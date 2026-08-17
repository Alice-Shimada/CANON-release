#!/usr/bin/env wolframscript

repoRoot = DirectoryName[DirectoryName[$InputFileName]];
arguments = Rest[$ScriptCommandLine];
If[Length[arguments] =!= 2,
  Print["Usage: wolframscript -file tests/RunPentaboxIBPLiveTest.wls KIRA_EXECUTABLE FRESH_OUTPUT"];
  Exit[2]
];

fixture = FileNameJoin[{
  repoRoot, "tests", "fixtures", "kira-massless-two-loop-five-point-pentabox"
}];
output = ExpandFileName[Last[arguments]];
requestPath = output <> ".request.json";
resultPath = output <> ".result.wl";
request = <|
  "executable" -> First[arguments],
  "project" -> fixture,
  "jobs" -> {"jobs.yaml", "export-math.yaml"},
  "topology" -> "pentabox5",
  "targets" -> "targets",
  "output" -> output,
  "options" -> {"--parallel=20"}
|>;
Export[requestPath, request, "RawJSON"];
process = RunProcess[{
  "wolframscript", "-file", FileNameJoin[{repoRoot, "mma", "ReduceIBP.wls"}],
  requestPath, resultPath
}, All, ProcessDirectory -> repoRoot];
If[process["ExitCode"] =!= 0 || FileType[resultPath] =!= File,
  Print[InputForm[process]];
  Exit[1]
];
result = Get[resultPath];
passed = Keys[result] === {"masters", "rules"} &&
  Length[result["masters"]] === 61 && Length[result["rules"]] === 2;
Print[InputForm[<|"passed" -> passed, "masters" -> 61, "rules" -> 2|>]];
Exit[If[passed, 0, 1]];
