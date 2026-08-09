$HistoryLength = 0;

repoRoot = DirectoryName[DirectoryName[DirectoryName[ExpandFileName[$InputFileName]]]];
Get[FileNameJoin[{repoRoot, "mma", "lib", "MethodCardCore.wl"}]];

args = CanonMethodCard`ScriptArguments[];
If[Length[args] =!= 2, Print["用法：run.wls <input.json> <output_dir>"]; Quit[2]];
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
    writeFailure["ERROR", "INVALID_OPTIONS", "method_options.package_entry 必须是非空路径字符串"],
    writeFailure["ERROR", "TOOL_UNAVAILABLE", "无法从 method_options.package_entry 或 Wolfram $Path 解析 CANONICA"]
  ]
];
entry = package["entry"];
entryHash = Quiet @ Check[FileHash[entry, "SHA256", "HexString"], $Failed];
If[!StringQ[entryHash] || !StringMatchQ[entryHash, RegularExpression["[0-9a-fA-F]{64}"]],
  writeFailure["ERROR", "TOOL_ERROR", "无法计算 CANONICA 入口的 SHA-256"]
];
requiredSymbols = {
  "CANONICA`RecursivelyTransformSectors",
  "CANONICA`ExtractIrreducibles",
  "CANONICA`CheckEpsForm",
  "CANONICA`CheckIntegrability",
  "CANONICA`SectorBoundariesFromDE"
};
loadSucceeded = TrueQ[Quiet[Check[(Get[entry]; True), False]]];
symbolsAvailable = And @@ (NameQ /@ requiredSymbols);
If[!loadSucceeded,
  writeFailure["ERROR", "TOOL_ERROR", "CANONICA 加载失败"]
];
If[!symbolsAvailable,
  writeFailure["ERROR", "TOOL_ERROR", "CANONICA 缺少本卡所需的公共符号"]
];

sectorBasis = CanonMethodCard`LoadArtifact[task, inputPath, "sector_basis"];
cut = CanonMethodCard`LoadArtifact[task, inputPath, "sector_cut_de"];
If[
  FailureQ[sectorBasis] || FailureQ[cut] ||
    !CanonMethodCard`ValidSectorBasisQ[sectorBasis] ||
    !CanonMethodCard`ValidCutDEQ[cut],
  writeFailure[
    "ERROR", "INVALID_DIFFERENTIAL_SYSTEM",
    "sector_basis 或 sector_cut_de artifact 无效"
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
    "task、sector_basis 与 sector_cut_de 的 sector/family/basis/order 不匹配"
  ]
];
If[!CanonMethodCard`FlatConnectionQ[cut["matrices"], cut["variables"]],
  writeFailure["ERROR", "INVALID_DIFFERENTIAL_SYSTEM", "输入 differential connection 不可积"]
];

variables = cut["variables"];
regulator = cut["regulator"];
matrices = cut["matrices"];
toolRegulator = CANONICA`eps;
aFull = matrices /. regulator -> toolRegulator;

If[Length[variables] > 1 && !TrueQ[Quiet @ Check[CANONICA`CheckIntegrability[aFull, variables], False]],
  writeFailure["ERROR", "INVALID_DIFFERENTIAL_SYSTEM", "输入 connection 未通过 CANONICA 可积性检查"]
];

boundaries = Lookup[cut, "sector_boundaries", Automatic];
If[boundaries === Automatic,
  boundaries = Quiet[CANONICA`SectorBoundariesFromDE[aFull]]
];
If[boundaries === $Failed || !ListQ[boundaries] || boundaries === {},
  writeFailure["INCONCLUSIVE", "METHOD_EXHAUSTED", "CANONICA 无法确定 sector boundaries"]
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
  writeFailure["INCONCLUSIVE", "METHOD_EXHAUSTED", "CANONICA 未生成 transformation"]
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
  writeFailure["INCONCLUSIVE", "METHOD_EXHAUSTED", "CANONICA transformation 未通过 provider epsilon-form check"]
];

candidateArtifact = <|
  "schema" -> "canon-neu/core-candidates/v1",
  "sector" -> cut["sector"],
  "family_id" -> cut["family_id"],
  "basis_id" -> cut["basis_id"],
  "coefficient_domain" -> "exact-rational-functions",
  "basis" -> cut["basis"],
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
  "candidates" -> {
    <|
      "candidate_id" -> "canonica-recursive:1",
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
  writeFailure["ERROR", "OUTPUT_ERROR", "无法写入 core candidate artifact"]
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
If[resultPath === $Failed, Print["写入 result.json 失败"]; Quit[1]];
Quit[0];
