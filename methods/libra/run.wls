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
    <|"method_id" -> "libra-single-variable", "reason" -> reason|>
  ];
  Quit[If[status === "ERROR", 1, 0]]
);

cut = CanonMethodCard`LoadArtifact[task, inputPath, "sector_cut_de"];
If[FailureQ[cut] || !CanonMethodCard`ValidCutDEQ[cut],
  writeFailure["ERROR", "INVALID_DIFFERENTIAL_SYSTEM", "sector_cut_de artifact 无效"]
];
If[!CanonMethodCard`FlatConnectionQ[cut["matrices"], cut["variables"]],
  writeFailure["ERROR", "INVALID_DIFFERENTIAL_SYSTEM", "输入 differential connection 不可积"]
];
If[Length[cut["variables"]] =!= 1,
  writeFailure["INCONCLUSIVE", "OUT_OF_SCOPE", "当前 Libra 卡只接受恰好一个变量"]
];

package = CanonMethodCard`ResolveMethodPackage[task, inputPath, "Libra`"];
If[FailureQ[package],
  If[
    MatchQ[package, Failure["INVALID_METHOD_OPTIONS", _Association]],
    writeFailure["ERROR", "INVALID_OPTIONS", "method_options.package_entry 必须是非空路径字符串"],
    writeFailure["ERROR", "TOOL_UNAVAILABLE", "无法从 method_options.package_entry 或 Wolfram $Path 解析 Libra"]
  ]
];
entry = package["entry"];
entryHash = Quiet @ Check[FileHash[entry, "SHA256", "HexString"], $Failed];
If[!StringQ[entryHash] || !StringMatchQ[entryHash, RegularExpression["[0-9a-fA-F]{64}"]],
  writeFailure["ERROR", "TOOL_ERROR", "无法计算 Libra 入口的 SHA-256"]
];
requiredSymbols = {
  "NewDSystem", "Fuchsify", "Transform", "FactorOut",
  "OverallTransformation", "EFormQ"
};
loadSucceeded = TrueQ[Quiet[Check[(Get[entry]; True), False]]];
If[!loadSucceeded,
  writeFailure["ERROR", "TOOL_ERROR", "Libra 加载失败"]
];
libraSymbolAvailableQ[symbolName_String] :=
  NameQ["Libra`" <> symbolName] || NameQ["Global`" <> symbolName];
symbolsAvailable = And @@ (libraSymbolAvailableQ /@ requiredSymbols);
If[!symbolsAvailable,
  writeFailure["ERROR", "TOOL_ERROR", "Libra 缺少本卡所需的公共符号"]
];
If[!ValueQ[Libra`$LibraVersion] || Libra`$LibraVersion =!= "1.2",
  writeFailure["ERROR", "TOOL_IDENTITY_MISMATCH", "Libra 版本不兼容；本卡要求 1.2"]
];
Libra`$LibraUseFermat = False;

variable = First[cut["variables"]];
regulator = cut["regulator"];
matrix = Map[Together, First[cut["matrices"]], {2}];
If[!TrueQ[Quiet @ Check[NewDSystem[cardSystem, variable -> matrix]; True, False]],
  writeFailure["ERROR", "TOOL_ERROR", "Libra 无法初始化微分系统"]
];
fuchsTransformation = Quiet @ Check[Fuchsify[cardSystem, variable], $Failed];
If[fuchsTransformation === $Failed || !MatrixQ[fuchsTransformation],
  writeFailure["INCONCLUSIVE", "METHOD_EXHAUSTED", "Libra Fuchsify 未生成矩阵 transformation"]
];
If[!TrueQ[Quiet @ Check[Transform[cardSystem, fuchsTransformation]; True, False]],
  writeFailure["INCONCLUSIVE", "METHOD_EXHAUSTED", "Libra 无法应用 Fuchsify transformation"]
];
factorTransformation = Quiet @ Check[
  FactorOut[cardSystem, variable, regulator, 1/2] /. _C -> 1,
  $Failed
];
If[factorTransformation === $Failed || !MatrixQ[factorTransformation],
  writeFailure["INCONCLUSIVE", "METHOD_EXHAUSTED", "Libra FactorOut 未生成矩阵 transformation"]
];
If[!TrueQ[Quiet @ Check[Transform[cardSystem, factorTransformation]; True, False]],
  writeFailure["INCONCLUSIVE", "METHOD_EXHAUSTED", "Libra 无法应用 FactorOut transformation"]
];
transformation = Quiet @ Check[OverallTransformation[cardSystem][Transform], $Failed];
transformed = Quiet @ Check[cardSystem[variable], $Failed];
If[transformation === $Failed || !MatrixQ[transformation] || transformed === $Failed,
  writeFailure["INCONCLUSIVE", "METHOD_EXHAUSTED", "Libra 无法合并 transformation history"]
];
providerEFormQ = TrueQ @ Quiet @ Check[EFormQ[transformed, regulator], False];
If[!providerEFormQ,
  writeFailure["INCONCLUSIVE", "METHOD_EXHAUSTED", "Libra stages 未生成 epsilon form candidate"]
];

candidateArtifact = <|
  "schema" -> "canon-neu/core-candidates/v1",
  "sector" -> cut["sector"],
  "family_id" -> cut["family_id"],
  "basis_id" -> cut["basis_id"],
  "coefficient_domain" -> "exact-rational-functions",
  "basis" -> cut["basis"],
  "variables" -> {variable},
  "regulator" -> regulator,
  "convention" -> "old_basis = transformation . new_basis",
  "method" -> <|
    "id" -> "libra-single-variable",
    "tool" -> "Libra",
    "tool_identity" -> Libra`$LibraVersion,
    "package_source" -> package["source"],
    "entry" -> entry,
    "entry_sha256" -> entryHash,
    "wolfram_version" -> $Version,
    "system_id" -> $SystemID
  |>,
  "candidates" -> {
    <|
      "candidate_id" -> "libra-single-variable:1",
      "transformation" -> transformation,
      "transformed_matrices" -> {transformed},
      "provider_evidence" -> <|
        "check_eps_form" -> providerEFormQ,
        "stages" -> {"Fuchsify", "FactorOut"},
        "factor_out_mu" -> 1/2,
        "use_fermatica" -> False
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
    "method_id" -> "libra-single-variable",
    "tool" -> "Libra",
    "provider_check_eps_form" -> providerEFormQ,
    "candidate_count" -> 1
  |>
];
If[resultPath === $Failed, Print["写入 result.json 失败"]; Quit[1]];
Quit[0];
