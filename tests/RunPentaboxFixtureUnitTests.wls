#!/usr/bin/env wolframscript

repoRoot = DirectoryName[DirectoryName[$InputFileName]];
fixture = FileNameJoin[{
  repoRoot, "tests", "fixtures", "kira-massless-two-loop-five-point-pentabox"
}];
prepared = Get[FileNameJoin[{fixture, "prepared-derivatives-v2.wl"}]];
strategy = prepared["exact_strategy"];
noncommentLines[path_String] := Select[
  StringTrim /@ StringSplit[Import[path, "Text"], {"\r\n", "\n", "\r"}],
  # =!= "" && !StringStartsQ[#, "#"] &
];
masters = noncommentLines[FileNameJoin[{fixture, "preferred-masters"}]];
targets = noncommentLines[FileNameJoin[{fixture, "targets"}]];
jobs = Import[FileNameJoin[{fixture, "jobs.yaml"}], "Text"];
exportJob = Import[FileNameJoin[{fixture, "export-math.yaml"}], "Text"];
kinematics = Import[FileNameJoin[{fixture, "config", "kinematics.yaml"}], "Text"];
variables = Symbol["CANON`DEData`" <> #] & /@ {"s12", "s23", "s34", "s45", "s51"};
s51 = Last[variables];
temporaryDirectory = CreateDirectory[];
generatedPath = FileNameJoin[{temporaryDirectory, "prepared-derivatives-v2.wl"}];
generatorProcess = RunProcess[
  {
    "wolframscript", "-file", FileNameJoin[{fixture, "BuildPreparedPentabox.wls"}],
    generatedPath
  },
  All,
  ProcessDirectory -> repoRoot
];

report = TestReport[{
  VerificationTest[
    Keys[prepared] === {
      "schema", "topology", "variables", "denominator_count", "operators", "exact_strategy"
    } && prepared["topology"] === "pentabox5" &&
      prepared["variables"] === variables && prepared["denominator_count"] === 11 &&
      Keys[prepared["operators"]] === variables &&
      AllTrue[
        Values[prepared["operators"]],
        Length[#] === 11 && AllTrue[
          #,
          Keys[#] === {"constant", "linear"} &&
            Lookup[#["linear"], "denominator"] === Range[11] &&
            Length[Lookup[#["linear"], "coefficient"]] === 11 &
        ] &
      ] && FreeQ[prepared, _Real],
    True,
    TestID -> "frozen-two-loop-five-point-family-has-five-exact-affine-operators"
  ],
  VerificationTest[
    strategy["kind"] === "enhanced-baikov-membership" &&
      Length[strategy["baikov_variables"]] === 11 &&
      strategy["propagator_slots"] === Range[8] &&
      strategy["fixed_scale_substitutions"] === {} &&
      strategy["search_max_total_degree"] === 1 &&
      strategy["fallback"] === "operators" &&
      !FreeQ[strategy["external_gram_determinant"], s51] &&
      !FreeQ[strategy["baikov_polynomial"], s51] &&
      !FreeQ[Values[prepared["operators"]], s51],
    True,
    TestID -> "unscaled-five-variable-exact-strategy-has-no-fixed-s51-leakage"
  ],
  VerificationTest[
    Length[masters] === 61 && Length[targets] === 2 &&
      StringContainsQ[jobs, "run_firefly: true"] &&
      StringContainsQ[jobs, "preferred_masters: \"preferred-masters\""] &&
      StringContainsQ[exportJob, "reconstruct_mass: true"] &&
      StringContainsQ[kinematics, "symbol_to_replace_by_one: s51"],
    True,
    TestID -> "kira-keeps-fixed-scale-internally-and-reconstructs-it-on-export"
  ],
  VerificationTest[
    generatorProcess["ExitCode"] === 0 &&
      StringContainsQ[generatorProcess["StandardOutput"], "DERIVATION_PASSED"] &&
      FileType[generatedPath] === File && Get[generatedPath] === prepared,
    True,
    TestID -> "full-unscaled-gram-generator-exactly-reproduces-frozen-fixture"
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
