$HistoryLength = 0;

repoRoot = DirectoryName[DirectoryName[DirectoryName[ExpandFileName[$InputFileName]]]];
Get[FileNameJoin[{repoRoot, "mma", "lib", "MethodCardCore.wl"}]];

args = CanonMethodCard`ScriptArguments[];
If[Length[args] =!= 2, Print["Usage: run.wls <input.json> <output_dir>"]; Quit[2]];
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
    Return["Invalid dependent_row_hierarchy schema"]
  ];
  n = Length[cut["basis"]];
  If[
    !StringQ[Lookup[hierarchy, "hierarchy_id", None]] ||
      Lookup[hierarchy, "hierarchy_id", ""] === "",
    Return["Invalid dependent_row_hierarchy hierarchy_id"]
  ];
  If[
    !CanonMethodCard`SameSectorQ[Lookup[hierarchy, "sector", None], cut["sector"]] ||
      Lookup[hierarchy, "family_id", None] =!= cut["family_id"] ||
      Lookup[hierarchy, "basis_id", None] =!= cut["basis_id"] ||
      Lookup[hierarchy, "basis", None] =!= cut["basis"],
    Return["dependent_row_hierarchy does not match the cut sector, family, basis, or order"]
  ];
  labels = Lookup[hierarchy, "master_sector_labels", None];
  If[!ListQ[labels] || Length[labels] =!= n,
    Return["Invalid dependent_row_hierarchy master_sector_labels length"]
  ];
  mask = Lookup[hierarchy, "sector_hierarchy", None];
  If[!binarySquareMaskQ[mask, n],
    Return["dependent_row_hierarchy sector_hierarchy must be an n-by-n binary mask"]
  ];
  If[Diagonal[mask] =!= ConstantArray[1, n],
    Return["dependent_row_hierarchy sector_hierarchy must have an all-ones diagonal"]
  ];
  budget = Lookup[hierarchy, "max_mask_nonzeros", None];
  If[!IntegerQ[budget] || budget <= 0,
    Return["dependent_row_hierarchy max_mask_nonzeros must be a positive integer"]
  ];
  provenance = Lookup[hierarchy, "provenance", None];
  If[!AssociationQ[provenance],
    Return["Invalid dependent_row_hierarchy provenance"]
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
      "dependent_row_hierarchy provenance must record producer, tool, revision, MappedSectors=False, source, and hash"
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
    "Invalid sector_basis or sector_cut_de artifact"
  ]
];
If[
  !CanonMethodCard`SameSectorQ[sectorBasis["sector"], cut["sector"], task["sector"]] ||
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
If[Length[cut["variables"]] =!= 1,
  writeFailure["INCONCLUSIVE", "OUT_OF_SCOPE", "The current Libra card requires exactly one variable"]
];

methodOptions = Lookup[Lookup[task, "payload", <||>], "method_options", <||>];
If[!AssociationQ[methodOptions],
  writeFailure["ERROR", "INVALID_OPTIONS", "method_options must be an Association"]
];
If[Complement[Keys[methodOptions], {"package_entry", "dependent_row_strategy"}] =!= {},
  writeFailure["ERROR", "INVALID_OPTIONS", "method_options contains unknown options"]
];
dependentRowStrategy = Lookup[methodOptions, "dependent_row_strategy", "automatic"];
If[!MemberQ[{"automatic", "sector-de-closure"}, dependentRowStrategy],
  writeFailure[
    "ERROR", "INVALID_OPTIONS",
    "method_options.dependent_row_strategy must be automatic or sector-de-closure"
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
      "The dependent_row_hierarchy artifact is missing or its descriptor is invalid"
    ]
  ];
  hierarchyHash = Quiet @ Check[FileHash[hierarchyPath, "SHA256", "HexString"], $Failed];
  If[
    !StringQ[hierarchyHash] ||
      !StringMatchQ[hierarchyHash, RegularExpression["[0-9a-fA-F]{64}"]],
    writeFailure[
      "ERROR", "INVALID_DIFFERENTIAL_SYSTEM",
      "Cannot compute the dependent_row_hierarchy artifact SHA-256"
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
    writeFailure["ERROR", "INVALID_OPTIONS", "method_options.package_entry must be a nonempty path string"],
    writeFailure["ERROR", "TOOL_UNAVAILABLE", "Cannot resolve Libra from method_options.package_entry or Wolfram $Path"]
  ]
];
entry = package["entry"];
entryHash = Quiet @ Check[FileHash[entry, "SHA256", "HexString"], $Failed];
If[!StringQ[entryHash] || !StringMatchQ[entryHash, RegularExpression["[0-9a-fA-F]{64}"]],
  writeFailure["ERROR", "TOOL_ERROR", "Cannot compute the Libra entry SHA-256"]
];
requiredSymbols = {
  "NewDSystem", "Fuchsify", "Transform", "FactorOut",
  "OverallTransformation", "EFormQ", "TClosure",
  "LeadingSeriesCoefficient", "PolesInfo"
};
loadSucceeded = TrueQ[Quiet[Check[(Get[entry]; True), False]]];
If[!loadSucceeded,
  writeFailure["ERROR", "TOOL_ERROR", "Libra failed to load"]
];
libraSymbolAvailableQ[symbolName_String] :=
  NameQ["Libra`" <> symbolName] || NameQ["Global`" <> symbolName];
symbolsAvailable = And @@ (libraSymbolAvailableQ /@ requiredSymbols);
If[!symbolsAvailable,
  writeFailure["ERROR", "TOOL_ERROR", "Libra lacks public symbols required by this card"]
];
Libra`$LibraUseFermat = False;

variable = First[cut["variables"]];
regulator = cut["regulator"];
matrix = Map[Together, First[cut["matrices"]], {2}];
If[!TrueQ[Quiet @ Check[NewDSystem[cardSystem, variable -> matrix]; True, False]],
  writeFailure["ERROR", "TOOL_ERROR", "Libra could not initialize the differential system"]
];
fuchsTransformation = Quiet @ Check[Fuchsify[cardSystem, variable], $Failed];
If[fuchsTransformation === $Failed || !MatrixQ[fuchsTransformation],
  writeFailure["INCONCLUSIVE", "METHOD_EXHAUSTED", "Libra Fuchsify produced no matrix transformation"]
];
If[!TrueQ[Quiet @ Check[Transform[cardSystem, fuchsTransformation]; True, False]],
  writeFailure["INCONCLUSIVE", "METHOD_EXHAUSTED", "Libra could not apply the Fuchsify transformation"]
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
      "Cannot construct the Libra hierarchy from post-Fuchsify residue matrices"
    ]
  ];
  combinedMask = Quiet @ Check[TClosure[hsector + hde], $Failed];
  If[
    !binarySquareMaskQ[combinedMask, n] ||
      Diagonal[combinedMask] =!= ConstantArray[1, n],
    writeFailure[
      "ERROR", "INVALID_DIFFERENTIAL_SYSTEM",
      "The sector/residue hierarchy closure has invalid dimensions or domain"
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
      "The combined dependent-row mask exceeds max_mask_nonzeros; FactorOut was not called",
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
    "Libra FactorOut produced no matrix transformation", strategyEvidence
  ]
];
If[!TrueQ[Quiet @ Check[Transform[cardSystem, factorTransformation]; True, False]],
  writeFailure["INCONCLUSIVE", "METHOD_EXHAUSTED", "Libra could not apply the FactorOut transformation"]
];
transformation = Quiet @ Check[OverallTransformation[cardSystem][Transform], $Failed];
transformed = Quiet @ Check[cardSystem[variable], $Failed];
If[transformation === $Failed || !MatrixQ[transformation] || transformed === $Failed,
  writeFailure["INCONCLUSIVE", "METHOD_EXHAUSTED", "Libra could not combine the transformation history"]
];
providerEFormQ = TrueQ @ Quiet @ Check[EFormQ[transformed, regulator], False];
If[!providerEFormQ,
  writeFailure["INCONCLUSIVE", "METHOD_EXHAUSTED", "The Libra stages produced no epsilon-form candidate"]
];

candidateArtifact = <|
  "schema" -> "canon-neu/core-candidates/v1",
  "sector" -> cut["sector"],
  "family_id" -> cut["family_id"],
  "basis_id" -> cut["basis_id"],
  "coefficient_domain" -> "exact-rational-functions",
  "basis" -> cut["basis"],
  "source_basis" -> cut["basis"],
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
  "candidate_group_pool" -> <|
    "declared" -> 1, "eligible" -> 1, "remaining" -> 0,
    "unconsumed_candidates" -> 0, "pool_exhausted" -> True|>,
  "candidates" -> {
    <|
      "candidate_id" -> "libra-single-variable:1",
      "member_candidate_ids" -> Table["libra-single-variable:row:" <> ToString[i],
        {i, Length[cut["basis"]]}],
      "full_new_basis_rows" -> Map[Together, Inverse[transformation], {2}],
      "construction_rejection" -> None,
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
  writeFailure["ERROR", "OUTPUT_ERROR", "Cannot write the core-candidate artifact"]
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
If[resultPath === $Failed, Print["Failed to write result.json"]; Quit[1]];
Quit[0];
