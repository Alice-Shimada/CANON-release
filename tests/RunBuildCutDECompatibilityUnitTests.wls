#!/usr/bin/env wolframscript

$HistoryLength = 0;

repoRoot = DirectoryName[DirectoryName[ExpandFileName[$InputFileName]]];
Get[FileNameJoin[{repoRoot, "mma", "lib", "MethodCardCore.wl"}]];
temporary = CreateDirectory[];
ClearAll[h, d, eps, u, v];

master = Apply[h, Join[{1}, ConstantArray[0, 11]]];
zeroRecords = ConstantArray[<|"constant" -> 0, "linear" -> {}|>, 12];
legacy = <|"denominators" -> Range[12], "records" -> zeroRecords|>;

runCase[name_String, variables_List, derivatives_Association,
    reductionDescriptorFields_Association : <||>] := Module[
  {directory, derivativesPath, preparedPath, mastersPath, sectorsPath,
   reductionPath, inputPath, outputPath, process, resultPath},
  directory = FileNameJoin[{temporary, name}];
  CreateDirectory[directory];
  derivativesPath = FileNameJoin[{directory, "prepared-derivatives.wl"}];
  preparedPath = FileNameJoin[{directory, "prepared-family.wl"}];
  mastersPath = FileNameJoin[{directory, "master-basis.wl"}];
  sectorsPath = FileNameJoin[{directory, "sector-manifest.wl"}];
  reductionPath = FileNameJoin[{directory, "ibp-reduction.wl"}];
  inputPath = FileNameJoin[{directory, "input.json"}];
  outputPath = FileNameJoin[{directory, "output"}];
  Put[derivatives, derivativesPath];
  Put[<|
    "schema" -> "canon-neu/prepared-family/v1",
    "family_ref" -> "fixture-build-cut-de-compatibility",
    "basis_ref" -> "fixture-build-cut-de-compatibility/order",
    "topology" -> "fixture",
    "parameters" -> Join[{d}, variables],
    "variables" -> variables,
    "regulator" -> eps,
    "dimension_rule" -> d -> 4 - 2 eps,
    "index_order" -> ("D" <> ToString[#] & /@ Range[12]),
    "sector_convention" -> "positive first propagator index",
    "prepared_derivatives" -> <|"path" -> derivativesPath|>
  |>, preparedPath];
  Put[<|
    "schema" -> "canon-neu/master-basis/v1",
    "family_ref" -> "fixture-build-cut-de-compatibility",
    "basis_ref" -> "fixture-build-cut-de-compatibility/order",
    "topology" -> "fixture",
    "index_order" -> ("D" <> ToString[#] & /@ Range[12]),
    "ordering" -> "frozen fixture order",
    "masters" -> {master}
  |>, mastersPath];
  Put[<|
    "schema" -> "canon-neu/sector-manifest/v1",
    "family_ref" -> "fixture-build-cut-de-compatibility",
    "sector_convention" -> "positive first propagator index",
    "propagator_slots" -> {1},
    "bit_order" -> "D1 is least-significant",
    "ordering" -> "ascending (propagator_count, id)",
    "sectors" -> {
      <|"id" -> 0, "propagator_count" -> 0,
        "sector_bits" -> ConstantArray[0, 12]|>,
      <|"id" -> 1, "propagator_count" -> 1,
        "sector_bits" -> Join[{1}, ConstantArray[0, 11]]|>
    }
  |>, sectorsPath];
  Put[<|
    "schema" -> "canon-neu/candidate-ibp-bridge/v1",
    "family_ref" -> "fixture-build-cut-de-compatibility",
    "basis_ref" -> "fixture-build-cut-de-compatibility/order",
    "topology" -> "fixture",
    "masters" -> {master},
    "rules" -> {}
  |>, reductionPath];
  Export[inputPath, <|
    "schema" -> "canon-neu/script-input/v1",
    "task_id" -> "BUILD-CUT-DE-COMPATIBILITY-TEST-" <> name,
    "step" -> "BUILD_CUT_DE",
    "sector" -> <|"id" -> 1, "propagator_count" -> 1|>,
    "payload" -> <|
      "prepared_family" -> <|"type" -> "mathematica-expression", "path" -> preparedPath|>,
      "master_basis" -> <|"type" -> "mathematica-expression", "path" -> mastersPath|>,
      "sector_manifest" -> <|"type" -> "mathematica-expression", "path" -> sectorsPath|>,
      "ibp_reduction" -> Join[<|"type" -> "mathematica-expression", "path" -> reductionPath|>,
        reductionDescriptorFields]
    |>
  |>, "RawJSON"];
  process = RunProcess[{
    "wolframscript", "-file", FileNameJoin[{repoRoot, "mma", "BuildSectorCutDE.wls"}],
    inputPath, outputPath
  }];
  resultPath = FileNameJoin[{outputPath, "result.json"}];
  <|
    "exit_code" -> process["ExitCode"],
    "stdout" -> process["StandardOutput"],
    "stderr" -> process["StandardError"],
    "output" -> outputPath,
    "result" -> If[FileType[resultPath] === File, Import[resultPath, "RawJSON"], Missing["result"]]
  |>
];

accepted = runCase["accepted-legacy", {u}, legacy];
acceptedCut = If[
  accepted["result", "status"] === "PASS",
  Get[FileNameJoin[{accepted["output"], "sector-cut-de.wl"}]],
  Missing["cut"]
];

missingRecordField = ReplacePart[legacy, {"records", 1} -> <|"linear" -> {}|>];
recordCountMismatch = ReplacePart[legacy, "records" -> Most[zeroRecords]];
badDenominatorIndex = ReplacePart[
  legacy,
  {"records", 1, "linear"} -> {<|"coefficient" -> 1, "denominator" -> 13|>}
];
missingLinearField = ReplacePart[
  legacy,
  {"records", 1, "linear"} -> {<|"denominator" -> 1|>}
];

invalidRuns = {
  runCase["missing-record-field", {u}, missingRecordField],
  runCase["record-count-mismatch", {u}, recordCountMismatch],
  runCase["bad-denominator-index", {u}, badDenominatorIndex],
  runCase["missing-linear-field", {u}, missingLinearField],
  runCase["multivariable-legacy", {u, v}, legacy]
};
unreducedBuiltDE = runCase[
  "unreduced-built-de",
  {u},
  ReplacePart[legacy, {"records", 1, "constant"} -> 1]
];
wrongHashRun = runCase["wrong-reduction-hash", {u}, legacy,
  <|"sha256" -> StringRepeat["0", 64]|>];

If[accepted["exit_code"] =!= 0,
  Print[InputForm[KeyTake[accepted, {"exit_code", "stdout", "stderr", "result"}]]]
];

tests = {
  VerificationTest[
    wrongHashRun["exit_code"] =!= 0 &&
      wrongHashRun["result", "status"] === "ERROR" &&
      wrongHashRun["result", "code"] === "IBP_EXECUTION_FAILED" &&
      wrongHashRun["result", "summary", "reason_code"] === "INVALID_IBP_AUDIT_INPUT" &&
      wrongHashRun["result", "artifacts"] === <||> &&
      !FileExistsQ[FileNameJoin[{wrongHashRun["output"], "ordered-master-de.wl"}]],
    True, TestID -> "declared-reduction-hash-mismatch-stops-before-DE-publication"],
  VerificationTest[
    accepted["exit_code"] === 0 &&
      accepted["result", "status"] === "PASS" &&
      accepted["result", "code"] === "OK" &&
      accepted["result", "summary", "prepared_derivative_input"] === "legacy-single-variable-records" &&
      accepted["result", "summary", "prepared_derivative_denominator_count"] === 12 &&
      acceptedCut["variables"] === {u} &&
      acceptedCut["basis"] === {master} &&
      acceptedCut["matrices"] === {{{0}}} &&
      CanonMethodCard`ValidCutDEQ[acceptedCut] &&
      FreeQ[acceptedCut["matrices"], _Missing | h[___]],
    True,
    TestID -> "accepted-12-record-single-variable-legacy-form-normalizes-to-v2"
  ],
  VerificationTest[
    And @@ Map[
      #1["exit_code"] =!= 0 &&
        #1["result", "status"] === "ERROR" &&
        #1["result", "code"] === "INVALID_PREPARED_DERIVATIVES" &&
        #1["result", "artifacts"] === <||> &,
      invalidRuns
    ],
    True,
    TestID -> "malformed-or-ambiguous-legacy-derivatives-fail-closed"
  ],
  VerificationTest[
    unreducedBuiltDE["exit_code"] =!= 0 &&
      unreducedBuiltDE["result", "status"] === "FAIL" &&
      unreducedBuiltDE["result", "code"] === "IBP_CHECK_FAILED" &&
      unreducedBuiltDE["result", "summary", "reason_code"] === "IBP_MISSING_TARGETS" &&
      unreducedBuiltDE["result", "artifacts"] === <||>,
    True,
    TestID -> "unreduced-built-de-cannot-publish-pass"
  ]
};

report = TestReport[tests];
Print[InputForm[<|
  "total" -> report["TestsSucceededCount"] + report["TestsFailedCount"],
  "succeeded" -> report["TestsSucceededCount"],
  "failed" -> report["TestsFailedCount"]
|>]];
If[report["TestsFailedCount"] =!= 0, Print[InputForm[report["TestsFailed"]]]];
DeleteDirectory[temporary, DeleteContents -> True];
Exit[If[report["TestsFailedCount"] === 0, 0, 1]];
