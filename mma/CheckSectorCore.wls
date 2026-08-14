$HistoryLength = 0;

repoRoot = DirectoryName[DirectoryName[ExpandFileName[$InputFileName]]];
Get[FileNameJoin[{repoRoot, "mma", "lib", "MethodCardCore.wl"}]];

args = CanonMethodCard`ScriptArguments[];
If[Length[args] =!= 2, Print["usage: CheckSectorCore.wls <input.json> <output_dir>"]; Quit[2]];
{inputPath, outputDir} = ExpandFileName /@ args;
task = CanonMethodCard`ReadTask[inputPath, "CHECK_CORE"];
If[FailureQ[task], Print[InputForm[task]]; Quit[2]];

writeFailure[status_String, code_String, reason_String, details_: <||>] := (
  CanonMethodCard`WriteResult[
    task, outputDir, status, code, <||>,
    Join[<|"reason" -> reason|>, details]
  ];
  Quit[If[status === "ERROR", 1, 0]]
);

sectorBasis = CanonMethodCard`LoadArtifact[task, inputPath, "sector_basis"];
cut = CanonMethodCard`LoadArtifact[task, inputPath, "sector_cut_de"];
candidates = CanonMethodCard`LoadArtifact[task, inputPath, "core_candidates"];
If[
  FailureQ[sectorBasis] || FailureQ[cut] || FailureQ[candidates] ||
  !CanonMethodCard`ValidSectorBasisQ[sectorBasis] ||
  !CanonMethodCard`ValidCutDEQ[cut] ||
  !CanonMethodCard`ValidCandidatesQ[candidates],
  writeFailure["ERROR", "INVALID_INPUT", "one or more core-check artifacts are invalid"]
];

If[
  sectorBasis["sector"] =!= task["sector"] ||
  cut["sector"] =!= task["sector"] ||
  candidates["sector"] =!= task["sector"] ||
  sectorBasis["family_id"] =!= cut["family_id"] ||
  candidates["family_id"] =!= cut["family_id"] ||
  sectorBasis["basis_id"] =!= cut["basis_id"] ||
  candidates["basis_id"] =!= cut["basis_id"] ||
  sectorBasis["basis"] =!= cut["basis"] ||
  candidates["basis"] =!= cut["basis"] ||
  candidates["variables"] =!= cut["variables"] ||
  candidates["regulator"] =!= cut["regulator"],
  writeFailure["FAIL", "CORE_FAIL", "sector, family, basis, variable, or regulator identity mismatch"]
];

matrices = cut["matrices"];
variables = cut["variables"];
regulator = cut["regulator"];

If[!CanonMethodCard`FlatConnectionQ[matrices, variables],
  writeFailure["ERROR", "INVALID_CUT_DE", "input cut connection is not flat"]
];

checks = MapIndexed[
  CanonMethodCard`CheckCoreCandidate[#1, matrices, variables, regulator, First[#2]] &,
  candidates["candidates"]
];
accepted = SelectFirst[checks, TrueQ[Lookup[#, "pass", False]] &, Missing["not-found"]];
If[MissingQ[accepted],
  writeFailure[
    "FAIL",
    "CORE_FAIL",
    "no candidate passed the independent exact core checks",
    <|"candidate_checks" -> (KeyDrop[#, {"transformation", "transformed_matrices"}] & /@ checks)|>
  ]
];

coreTransform = <|
  "schema" -> "canon-neu/core-transform/v1",
  "sector" -> cut["sector"],
  "family_id" -> cut["family_id"],
  "basis_id" -> cut["basis_id"],
  "coefficient_domain" -> "exact-rational-functions",
  "basis" -> cut["basis"],
  "variables" -> variables,
  "regulator" -> regulator,
  "convention" -> "old_basis = transformation . new_basis",
  "method" -> candidates["method"],
  "candidate_index" -> accepted["index"],
  "transformation" -> accepted["transformation"],
  "transformed_matrices" -> accepted["transformed_matrices"],
  "checks" -> KeyDrop[accepted, {"transformation", "transformed_matrices"}]
|>;
artifactPath = CanonMethodCard`WriteWLArtifact[coreTransform, outputDir, "core-transform.wl"];
If[artifactPath === $Failed,
  writeFailure["ERROR", "OUTPUT_ERROR", "could not write accepted core transformation"]
];
resultPath = CanonMethodCard`WriteResult[
  task,
  outputDir,
  "PASS",
  "CORE_PASS",
  <|"core_transform" -> <|"type" -> "mathematica-expression", "path" -> FileNameTake[artifactPath]|>|>,
  <|
    "candidate_index" -> accepted["index"],
    "invertible" -> accepted["invertible"],
    "exact_gauge" -> accepted["exact_gauge"],
    "flat_connection" -> accepted["flat_connection"],
    "epsilon_factorized" -> accepted["epsilon_factorized"]
  |>
];
If[resultPath === $Failed, Print["failed to write result.json"]; Quit[1]];
Quit[0];
