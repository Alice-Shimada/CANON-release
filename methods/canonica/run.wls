$HistoryLength = 0;

repoRoot = DirectoryName[DirectoryName[DirectoryName[ExpandFileName[$InputFileName]]]];
Get[FileNameJoin[{repoRoot, "mma", "lib", "MethodCardCore.wl"}]];

args = CanonMethodCard`ScriptArguments[];
If[Length[args] =!= 2, Print["Usage: run.wls <input.json> <output_dir>"]; Quit[2]];
{inputPath, outputDir} = ExpandFileName /@ args;
task = CanonMethodCard`ReadTask[inputPath, "SEARCH_CORE"];
If[FailureQ[task], Print[InputForm[task]]; Quit[2]];

writeFailure[status_String, code_String, reason_String] := (
  CanonMethodCard`WriteProviderResult[
    task, outputDir, status, code, <||>,
    <|"method_id" -> "canonica-recursive", "reason" -> reason|>
  ];
  Quit[If[status === "ERROR", 1, 0]]
);

package = CanonMethodCard`ResolveMethodPackage[task, inputPath, "CANONICA`"];
If[FailureQ[package],
  If[
    MatchQ[package, Failure["INVALID_METHOD_OPTIONS", _Association]],
    writeFailure["ERROR", "INVALID_OPTIONS", "method_options.package_entry must be a nonempty path string"],
    writeFailure["ERROR", "TOOL_UNAVAILABLE", "Cannot resolve CANONICA from method_options.package_entry or Wolfram $Path"]
  ]
];
entry = package["entry"];
entryHash = Quiet @ Check[FileHash[entry, "SHA256", "HexString"], $Failed];
If[!StringQ[entryHash] || !StringMatchQ[entryHash, RegularExpression["[0-9a-fA-F]{64}"]],
  writeFailure["ERROR", "TOOL_ERROR", "Cannot compute the CANONICA entry SHA-256"]
];
requiredSymbols = {
  "CANONICA`RecursivelyTransformSectors",
  "CANONICA`ExtractIrreducibles",
  "CANONICA`CheckEpsForm",
  "CANONICA`SectorBoundariesFromDE"
};
loadSucceeded = TrueQ[Quiet[Check[(Get[entry]; True), False]]];
symbolsAvailable = And @@ (NameQ /@ requiredSymbols);
If[!loadSucceeded,
  writeFailure["ERROR", "TOOL_ERROR", "CANONICA failed to load"]
];
If[!symbolsAvailable,
  writeFailure["ERROR", "TOOL_ERROR", "CANONICA lacks public symbols required by this card"]
];

sectorBasis = CanonMethodCard`LoadArtifact[task, inputPath, "sector_basis"];
cut = CanonMethodCard`LoadArtifact[task, inputPath, "sector_cut_de"];
If[
  FailureQ[sectorBasis] || FailureQ[cut] ||
    !CanonMethodCard`ValidSectorBasisQ[sectorBasis] ||
    !CanonMethodCard`ValidCutDEQ[cut],
  writeFailure[
    "ERROR", "INVALID_DIFFERENTIAL_SYSTEM",
    "Invalid sector_basis or sector_cut_de artifact"
  ]
];
If[
  sectorBasis["sector"] =!= task["sector"] ||
    cut["sector"] =!= task["sector"] ||
    sectorBasis["family_id"] =!= cut["family_id"] ||
    sectorBasis["basis_id"] =!= cut["basis_id"] ||
    sectorBasis["basis"] =!= cut["basis"],
  writeFailure[
    "ERROR", "INVALID_DIFFERENTIAL_SYSTEM",
    "Sector, family, basis, or order differs between the task, sector_basis, and sector_cut_de"
  ]
];
If[!CanonMethodCard`FlatConnectionQ[cut["matrices"], cut["variables"]],
  writeFailure["ERROR", "INVALID_DIFFERENTIAL_SYSTEM", "The input differential connection is not flat"]
];

variables = cut["variables"];
regulator = cut["regulator"];
matrices = cut["matrices"];
toolRegulator = CANONICA`eps;
aFull = Map[Together, matrices /. regulator -> toolRegulator, {3}];

boundaries = Lookup[cut, "sector_boundaries", Automatic];
If[boundaries === Automatic,
  boundaries = Quiet[CANONICA`SectorBoundariesFromDE[aFull]]
];
If[boundaries === $Failed || !ListQ[boundaries] || boundaries === {},
  writeFailure["INCONCLUSIVE", "METHOD_EXHAUSTED", "CANONICA could not determine sector boundaries"]
];

result = Quiet @ CheckAbort[
  CANONICA`RecursivelyTransformSectors[
    aFull,
    variables,
    boundaries,
    {1, Length[boundaries]},
    CANONICA`VerbosityLevel -> 1
  ],
  $Aborted
];
If[result === $Aborted || !ListQ[result] || Length[result] < 2,
  writeFailure["INCONCLUSIVE", "METHOD_EXHAUSTED", "CANONICA produced no transformation"]
];

transformation = result[[1]];
transformedRaw = result[[2]];
transformation = transformation /. toolRegulator -> regulator;
transformedMatrices = transformedRaw /. toolRegulator -> regulator;
alphabet = Quiet @ Check[CANONICA`ExtractIrreducibles[aFull], {}];
providerEFormQ = TrueQ @ Quiet @ Check[
  CANONICA`CheckEpsForm[transformedRaw, variables, alphabet],
  False
];
alphabet = alphabet /. toolRegulator -> regulator;
If[!providerEFormQ,
  writeFailure["INCONCLUSIVE", "METHOD_EXHAUSTED", "The CANONICA transformation failed the provider epsilon-form check"]
];

candidateArtifact = <|
  "schema" -> "canon-neu/core-candidates/v1",
  "sector" -> cut["sector"],
  "family_id" -> cut["family_id"],
  "basis_id" -> cut["basis_id"],
  "coefficient_domain" -> "exact-rational-functions",
  "basis" -> cut["basis"],
  "source_basis" -> cut["basis"],
  "variables" -> variables,
  "regulator" -> regulator,
  "convention" -> "old_basis = transformation . new_basis",
  "method" -> <|
    "id" -> "canonica-recursive",
    "tool" -> "CANONICA",
    "tool_identity" -> "CANONICA-compatible",
    "package_source" -> package["source"],
    "entry" -> entry,
    "entry_sha256" -> entryHash,
    "wolfram_version" -> $Version,
    "system_id" -> $SystemID
  |>,
  "candidate_group_pool" -> <|
    "declared" -> 1, "eligible" -> 1, "remaining" -> 0,
    "unconsumed_candidates" -> 0, "pool_exhausted" -> True|>,
  "candidates" -> {
    <|
      "candidate_id" -> "canonica-recursive:1",
      "member_candidate_ids" -> Table["canonica-recursive:row:" <> ToString[i],
        {i, Length[cut["basis"]]}],
      "full_new_basis_rows" -> Map[Together, Inverse[transformation], {2}],
      "construction_rejection" -> None,
      "transformation" -> transformation,
      "transformed_matrices" -> transformedMatrices,
      "provider_evidence" -> <|
        "sector_boundaries" -> boundaries,
        "alphabet" -> alphabet,
        "check_eps_form" -> providerEFormQ
      |>
    |>
  }
|>;

artifactPath = CanonMethodCard`WriteWLArtifact[candidateArtifact, outputDir, "core-candidates.wl"];
If[artifactPath === $Failed,
  writeFailure["ERROR", "OUTPUT_ERROR", "Cannot write the core-candidate artifact"]
];
resultPath = CanonMethodCard`WriteProviderResult[
  task,
  outputDir,
  "PROVISIONAL",
  "CANDIDATE_TRANSFORMATION",
  <|"core_candidates" -> <|"type" -> "mathematica-expression", "path" -> FileNameTake[artifactPath]|>|>,
  <|
    "method_id" -> "canonica-recursive",
    "tool" -> "CANONICA",
    "provider_check_eps_form" -> providerEFormQ,
    "candidate_count" -> 1
  |>
];
If[resultPath === $Failed, Print["Failed to write result.json"]; Quit[1]];
Quit[0];
