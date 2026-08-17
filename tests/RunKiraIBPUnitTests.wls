#!/usr/bin/env wolframscript

repoRoot = DirectoryName[DirectoryName[$InputFileName]];
adapter = FileNameJoin[{repoRoot, "mma", "ReduceIBP.wls"}];
wolframScript = "wolframscript";
temporaryDirectory = CreateDirectory[];
backend = FileNameJoin[{temporaryDirectory, "FakeKira.wls"}];

Export[backend, StringRiffle[{
  "mode = StringTrim[Import[\"mode\", \"Text\"]];",
  "If[mode === \"fail\", Exit[7]];",
  "directory = FileNameJoin[{Directory[], \"results\", \"box\"}];",
  "If[FileType[directory] =!= Directory, CreateDirectory[directory, CreateIntermediateDirectories -> True]];",
  "Export[FileNameJoin[{directory, \"masters.final\"}], \"box[1,1,1,1] # 15\\nbox[1,0,0,0] # 1\\n\", \"Text\"];",
  "marker = StringTrim[Import[\"marker-path\", \"Text\"]];",
  "rules = Switch[mode,",
  "  \"success\", \"{box[2,1,1,1] -> 2 box[1,1,1,1] + s box[1,0,0,0]}\",",
  "  \"missing\", \"{}\",",
  "  \"malicious\", \"{box[2,1,1,1] -> Put[1, \" <> ToString[marker, InputForm] <> \"]}\"",
  "];",
  "Export[FileNameJoin[{directory, \"kira_targets.m\"}], rules, \"Text\"];",
  "Exit[0];"
}, "\n"], "Text"];

runCase[mode_String] := Module[
  {project, output, requestPath, resultPath, marker, request, process},
  project = CreateDirectory[FileNameJoin[{temporaryDirectory, "project-" <> mode}]];
  output = FileNameJoin[{temporaryDirectory, "output-" <> mode}];
  requestPath = FileNameJoin[{temporaryDirectory, mode <> ".json"}];
  resultPath = FileNameJoin[{temporaryDirectory, mode <> ".wl"}];
  marker = FileNameJoin[{temporaryDirectory, mode <> "-marker"}];
  Export[FileNameJoin[{project, "reduce.yaml"}], "jobs: []\n", "Text"];
  Export[FileNameJoin[{project, "export.yaml"}], "jobs: []\n", "Text"];
  Export[
    FileNameJoin[{project, "targets"}],
    "box[2,1,1,1]\nbox[1,0,0,0]\n",
    "Text"
  ];
  Export[FileNameJoin[{project, "mode"}], mode, "Text"];
  Export[FileNameJoin[{project, "marker-path"}], marker, "Text"];
  request = <|
    "executable" -> wolframScript,
    "project" -> project,
    "jobs" -> {"reduce.yaml", "export.yaml"},
    "topology" -> "box",
    "targets" -> "targets",
    "output" -> output,
    "options" -> {"-file", backend}
  |>;
  Export[requestPath, request, "RawJSON"];
  process = RunProcess[
    {wolframScript, "-file", adapter, requestPath, resultPath},
    All,
    ProcessDirectory -> repoRoot
  ];
  <|
    "process" -> process,
    "result" -> If[FileType[resultPath] === File, Get[resultPath], Missing["NotWritten"]],
    "marker" -> marker
  |>
];

success = runCase["success"];
missing = runCase["missing"];
malicious = runCase["malicious"];
failedProcess = runCase["fail"];
head = Symbol["CANON`DEData`box"];
s = Symbol["CANON`DEData`s"];

report = TestReport[{
  VerificationTest[
    success["process", "ExitCode"] === 0 &&
      Keys[success["result"]] === {"masters", "rules"} &&
      success["result", "masters"] === {head[1, 1, 1, 1], head[1, 0, 0, 0]} &&
      success["result", "rules"] === {
        head[2, 1, 1, 1] -> 2 head[1, 1, 1, 1] + s head[1, 0, 0, 0]
      },
    True,
    TestID -> "minimal-result-preserves-kira-master-order-and-rules"
  ],
  VerificationTest[
    missing["process", "ExitCode"] === 1 &&
      MissingQ[missing["result"]],
    True,
    TestID -> "missing-target-rule-is-rejected"
  ],
  VerificationTest[
    malicious["process", "ExitCode"] === 1 &&
      MissingQ[malicious["result"]] &&
      !FileExistsQ[malicious["marker"]],
    True,
    TestID -> "held-parser-does-not-execute-exported-code"
  ],
  VerificationTest[
    failedProcess["process", "ExitCode"] === 1 && MissingQ[failedProcess["result"]],
    True,
    TestID -> "nonzero-reducer-exit-is-rejected"
  ]
}];

Print[InputForm[<|
  "total" -> report["TestsSucceededCount"] + report["TestsFailedCount"],
  "succeeded" -> report["TestsSucceededCount"],
  "failed" -> report["TestsFailedCount"]
|>]];
If[report["TestsFailedCount"] =!= 0, Print[InputForm[report["TestsFailed"]]]];
DeleteDirectory[temporaryDirectory, DeleteContents -> True];
Exit[If[report["TestsFailedCount"] === 0, 0, 1]];
