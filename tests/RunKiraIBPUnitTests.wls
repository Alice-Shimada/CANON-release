#!/usr/bin/env wolframscript

repoRoot = DirectoryName[DirectoryName[$InputFileName]];
runner = FileNameJoin[{repoRoot, "run_step.py"}];
temporaryDirectory = CreateDirectory[];
project = CreateDirectory[FileNameJoin[{temporaryDirectory, "project with spaces"}]];
output = FileNameJoin[{temporaryDirectory, "output with spaces"}];
backend = FileNameJoin[{temporaryDirectory, "FakeKira.wls"}];
requestPath = FileNameJoin[{temporaryDirectory, "request.json"}];
resultDir = FileNameJoin[{temporaryDirectory, "result"}];
resultPath = FileNameJoin[{resultDir, "ibp-reduction.wl"}];

Export[backend, StringRiffle[{
  "directory = FileNameJoin[{Directory[], \"results\", \"box\"}];",
  "CreateDirectory[directory, CreateIntermediateDirectories -> True];",
  "Export[FileNameJoin[{directory, \"masters.final\"}], \"box[1,1,1,1] # 15\\nbox[1,0,0,0] # 1\\n\", \"Text\"];",
  "Export[FileNameJoin[{directory, \"kira_targets.m\"}], \"{box[2,1,1,1] -> 2 box[1,1,1,1] + s box[1,0,0,0]}\", \"Text\"];"
}, "\n"], "Text"];
Export[FileNameJoin[{project, "reduce.yaml"}], "jobs: []\n", "Text"];
Export[FileNameJoin[{project, "export.yaml"}], "jobs: []\n", "Text"];
Export[FileNameJoin[{project, "targets"}], "box[2,1,1,1]\n", "Text"];
Export[requestPath, <|
  "schema" -> "canon-neu/script-input/v1", "task_id" -> "ibp-interface-test",
  "step" -> "REDUCE_IBP", "sector" -> Null, "payload" -> <|"reduction" -> <|
  "executable" -> "wolframscript", "project" -> FileNameTake[project],
  "jobs" -> {"reduce.yaml", "export.yaml"}, "topology" -> "box",
  "targets" -> "targets", "output" -> FileNameTake[output],
  "options" -> {"-file", backend}
|>|>|>, "RawJSON"];

process = RunProcess[
  {"python3", runner, requestPath, resultDir},
  All,
  ProcessDirectory -> repoRoot
];
result = Block[{$Context = "CANON`DEData`", $ContextPath = {"System`"}}, Get[resultPath]];
receipt = Import[FileNameJoin[{resultDir, "result.json"}], "RawJSON"];
head = Symbol["CANON`DEData`box"];
s = Symbol["CANON`DEData`s"];
report = TestReport[{VerificationTest[
  process["ExitCode"] === 0 && receipt["status"] === "PASS" &&
    receipt["code"] === "IBP_REDUCED" &&
    receipt["artifacts", "ibp_reduction", "path"] === FileNameTake[resultPath] &&
    Keys[result] === {"masters", "rules"} &&
    result["masters"] === {head[1, 1, 1, 1], head[1, 0, 0, 0]} &&
    result["rules"] === {
      head[2, 1, 1, 1] -> 2 head[1, 1, 1, 1] + s head[1, 0, 0, 0]
    },
  True,
  TestID -> "direct-kira-adapter-preserves-master-order-and-fully-reduced-rule"
]}];
Print[InputForm[<|
  "total" -> report["TestsSucceededCount"] + report["TestsFailedCount"],
  "succeeded" -> report["TestsSucceededCount"],
  "failed" -> report["TestsFailedCount"]
|>]];
DeleteDirectory[temporaryDirectory, DeleteContents -> True];
Exit[If[report["TestsFailedCount"] === 0, 0, 1]];
