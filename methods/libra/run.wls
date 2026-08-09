$HistoryLength = 0;

repoRoot = DirectoryName[DirectoryName[DirectoryName[ExpandFileName[$InputFileName]]]];
Get[FileNameJoin[{repoRoot, "mma", "lib", "MethodCardCore.wl"}]];

args = CanonMethodCard`ScriptArguments[];
If[Length[args] =!= 2, Print["用法：run.wls <input.json> <output_dir>"]; Quit[2]];
{inputPath, outputDir} = ExpandFileName /@ args;
task = CanonMethodCard`ReadTask[inputPath, "SEARCH_CORE"];
If[FailureQ[task], Print[InputForm[task]]; Quit[2]];

writeFailure[
  status_String,
  code_String,
  reason_String,
  evidence_Association : <||>
] := (
  CanonMethodCard`WriteProviderResult[
    task, outputDir, status, code, <||>,
    Join[<|"method_id" -> "libra-single-variable", "reason" -> reason|>, evidence]
  ];
  Quit[If[status === "ERROR", 1, 0]]
);

resolvePayloadArtifactPath[artifactName_String] := Module[{descriptor, raw},
  descriptor = Lookup[
    Lookup[task, "payload", <||>], artifactName, Missing[artifactName]
  ];
  If[
    !AssociationQ[descriptor] ||
      Lookup[descriptor, "type", None] =!= "mathematica-expression",
    Return[$Failed]
  ];
  raw = Lookup[descriptor, "path", Missing["path"]];
  If[!StringQ[raw] || raw === "", Return[$Failed]];
  If[
    StringStartsQ[raw, $PathnameSeparator],
    ExpandFileName[raw],
    ExpandFileName[FileNameJoin[{DirectoryName[inputPath], raw}]]
  ]
];

binarySquareMaskQ[mask_, n_Integer] :=
  MatrixQ[mask, Function[value, IntegerQ[value] && MemberQ[{0, 1}, value]]] &&
    Dimensions[mask] === {n, n};

hierarchyValidationReason[hierarchy_, cut_] := Module[
  {n, provenance, mask, labels, budget, sourceHash},
  If[
    !AssociationQ[hierarchy] ||
      Lookup[hierarchy, "schema", None] =!=
        "canon-neu/libra-dependent-row-hierarchy/v1",
    Return["dependent_row_hierarchy schema 无效"]
  ];
  n = Length[cut["basis"]];
  If[
    !StringQ[Lookup[hierarchy, "hierarchy_id", None]] ||
      Lookup[hierarchy, "hierarchy_id", ""] === "",
    Return["dependent_row_hierarchy hierarchy_id 无效"]
  ];
  If[
    Lookup[hierarchy, "sector", None] =!= cut["sector"] ||
      Lookup[hierarchy, "family_id", None] =!= cut["family_id"] ||
      Lookup[hierarchy, "basis_id", None] =!= cut["basis_id"] ||
      Lookup[hierarchy, "basis", None] =!= cut["basis"],
    Return["dependent_row_hierarchy 与 cut sector/family/basis/order 不匹配"]
  ];
  labels = Lookup[hierarchy, "master_sector_labels", None];
  If[!ListQ[labels] || Length[labels] =!= n,
    Return["dependent_row_hierarchy master_sector_labels 长度无效"]
  ];
  mask = Lookup[hierarchy, "sector_hierarchy", None];
  If[!binarySquareMaskQ[mask, n],
    Return["dependent_row_hierarchy sector_hierarchy 必须是 n-by-n 0/1 mask"]
  ];
  If[Diagonal[mask] =!= ConstantArray[1, n],
    Return["dependent_row_hierarchy sector_hierarchy 对角必须全为 1"]
  ];
  budget = Lookup[hierarchy, "max_mask_nonzeros", None];
  If[!IntegerQ[budget] || budget <= 0,
    Return["dependent_row_hierarchy max_mask_nonzeros 必须是正整数"]
  ];
  provenance = Lookup[hierarchy, "provenance", None];
  If[!AssociationQ[provenance],
    Return["dependent_row_hierarchy provenance 无效"]
  ];
  sourceHash = Lookup[provenance, "source_sha256", None];
  If[
    !StringQ[Lookup[provenance, "producer", None]] ||
      Lookup[provenance, "producer", ""] === "" ||
      !StringQ[Lookup[provenance, "tool", None]] ||
      Lookup[provenance, "tool", ""] === "" ||
      !StringQ[Lookup[provenance, "tool_revision", None]] ||
      Lookup[provenance, "tool_revision", ""] === "" ||
      Lookup[provenance, "mapped_sectors", None] =!= False ||
      !StringQ[Lookup[provenance, "source_artifact", None]] ||
      Lookup[provenance, "source_artifact", ""] === "" ||
      !StringQ[sourceHash] ||
      !StringMatchQ[sourceHash, RegularExpression["[0-9a-fA-F]{64}"]],
    Return[
      "dependent_row_hierarchy provenance 必须完整记录 producer/tool/revision/MappedSectors=False/source/hash"
    ]
  ];
  None
];

deriveResidueHierarchy[matrix_, variable_, regulator_, n_Integer] := Module[
  {residues, residueVectors, adjacency, closure},
  residues = Quiet @ Check[
    Libra`LeadingSeriesCoefficient[matrix/regulator, {variable, #1, 0}] & @@@
      Libra`PolesInfo[matrix, variable],
    $Failed
  ];
  If[
    !ListQ[residues] || residues === {} ||
      !And @@ (MatrixQ[#] && Dimensions[#] === {n, n} & /@ residues),
    Return[$Failed]
  ];
  residueVectors = Transpose[residues, {3, 1, 2}];
  adjacency = Map[Boole[!MatchQ[#, {0 ..}]] &, residueVectors, {2}];
  If[!binarySquareMaskQ[adjacency, n], Return[$Failed]];
  closure = Quiet @ Check[Libra`TClosure[adjacency], $Failed];
  If[!binarySquareMaskQ[closure, n], $Failed, closure]
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
If[Length[cut["variables"]] =!= 1,
  writeFailure["INCONCLUSIVE", "OUT_OF_SCOPE", "当前 Libra 卡只接受恰好一个变量"]
];

methodOptions = Lookup[Lookup[task, "payload", <||>], "method_options", <||>];
If[!AssociationQ[methodOptions],
  writeFailure["ERROR", "INVALID_OPTIONS", "method_options 必须是 Association"]
];
If[Complement[Keys[methodOptions], {"package_entry", "dependent_row_strategy"}] =!= {},
  writeFailure["ERROR", "INVALID_OPTIONS", "method_options 含未知选项"]
];
dependentRowStrategy = Lookup[methodOptions, "dependent_row_strategy", "automatic"];
If[!MemberQ[{"automatic", "sector-de-closure"}, dependentRowStrategy],
  writeFailure[
    "ERROR", "INVALID_OPTIONS",
    "method_options.dependent_row_strategy 必须是 automatic 或 sector-de-closure"
  ]
];

hierarchy = None;
hierarchyPath = None;
hierarchyHash = None;
If[dependentRowStrategy === "sector-de-closure",
  hierarchyPath = resolvePayloadArtifactPath["dependent_row_hierarchy"];
  If[hierarchyPath === $Failed || FileType[hierarchyPath] =!= File,
    writeFailure[
      "ERROR", "INVALID_DIFFERENTIAL_SYSTEM",
      "dependent_row_hierarchy artifact 缺失或 descriptor 无效"
    ]
  ];
  hierarchyHash = Quiet @ Check[FileHash[hierarchyPath, "SHA256", "HexString"], $Failed];
  If[
    !StringQ[hierarchyHash] ||
      !StringMatchQ[hierarchyHash, RegularExpression["[0-9a-fA-F]{64}"]],
    writeFailure[
      "ERROR", "INVALID_DIFFERENTIAL_SYSTEM",
      "无法计算 dependent_row_hierarchy artifact SHA-256"
    ]
  ];
  hierarchy = CanonMethodCard`LoadArtifact[
    task, inputPath, "dependent_row_hierarchy"
  ];
  hierarchyReason = hierarchyValidationReason[hierarchy, cut];
  If[hierarchyReason =!= None,
    writeFailure["ERROR", "INVALID_DIFFERENTIAL_SYSTEM", hierarchyReason]
  ];
  hierarchyHash = ToLowerCase[hierarchyHash];
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
  "OverallTransformation", "EFormQ", "TClosure",
  "LeadingSeriesCoefficient", "PolesInfo"
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

strategyEvidence = <|
  "dependent_row_strategy" -> dependentRowStrategy,
  "hierarchy_stage" -> "post-fuchsify-residue-matrices",
  "specialization_policy" -> "C[*] -> 1"
|>;
If[dependentRowStrategy === "automatic",
  factorTransformation = Quiet @ Check[
    FactorOut[cardSystem, variable, regulator, 1/2] /. _C -> 1,
    $Failed
  ],
  n = Length[cut["basis"]];
  hsector = hierarchy["sector_hierarchy"];
  hde = deriveResidueHierarchy[cardSystem[variable], variable, regulator, n];
  If[hde === $Failed,
    writeFailure[
      "ERROR", "INVALID_DIFFERENTIAL_SYSTEM",
      "无法从 post-Fuchsify residue matrices 构造 Libra hierarchy"
    ]
  ];
  combinedMask = Quiet @ Check[TClosure[hsector + hde], $Failed];
  If[
    !binarySquareMaskQ[combinedMask, n] ||
      Diagonal[combinedMask] =!= ConstantArray[1, n],
    writeFailure[
      "ERROR", "INVALID_DIFFERENTIAL_SYSTEM",
      "sector 与 residue hierarchy 的 closure 维数或 domain 无效"
    ]
  ];
  hsectorNonzeros = Count[hsector, 1, {2}];
  hdeNonzeros = Count[hde, 1, {2}];
  combinedNonzeros = Count[combinedMask, 1, {2}];
  maskBudget = hierarchy["max_mask_nonzeros"];
  strategyEvidence = Join[
    strategyEvidence,
    <|
      "hierarchy_id" -> hierarchy["hierarchy_id"],
      "hierarchy_artifact" -> FileNameTake[hierarchyPath],
      "hierarchy_artifact_sha256" -> hierarchyHash,
      "mapped_sectors" -> False,
      "hierarchy_source_artifact" -> hierarchy["provenance"]["source_artifact"],
      "hierarchy_source_sha256" -> ToLowerCase[hierarchy["provenance"]["source_sha256"]],
      "n" -> n,
      "hsector_nonzeros" -> hsectorNonzeros,
      "hde_nonzeros" -> hdeNonzeros,
      "combined_mask_nonzeros" -> combinedNonzeros,
      "max_mask_nonzeros" -> maskBudget
    |>
  ];
  If[combinedNonzeros > maskBudget,
    writeFailure[
      "INCONCLUSIVE", "METHOD_EXHAUSTED",
      "combined dependent-row mask 超出 max_mask_nonzeros；未调用 FactorOut",
      strategyEvidence
    ]
  ];
  factorTransformation = Quiet @ Check[
    FactorOut[
      cardSystem, variable, regulator, 1/2,
      DependentRowIndices -> combinedMask
    ] /. _C -> 1,
    $Failed
  ]
];
If[factorTransformation === $Failed || !MatrixQ[factorTransformation],
  writeFailure[
    "INCONCLUSIVE", "METHOD_EXHAUSTED",
    "Libra FactorOut 未生成矩阵 transformation", strategyEvidence
  ]
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
        "use_fermatica" -> False,
        "dependent_rows" -> strategyEvidence
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
    "candidate_count" -> 1,
    "dependent_rows" -> strategyEvidence
  |>
];
If[resultPath === $Failed, Print["写入 result.json 失败"]; Quit[1]];
Quit[0];
