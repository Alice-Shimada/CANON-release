$HistoryLength = 0;

repoRoot = DirectoryName[DirectoryName[DirectoryName[ExpandFileName[$InputFileName]]]];
Get[FileNameJoin[{repoRoot, "mma", "lib", "MethodCardCore.wl"}]];

args = CanonMethodCard`ScriptArguments[];
If[Length[args] =!= 2, Print["Usage: run.wls <input.json> <output_dir>"]; Quit[2]];
{inputPath, outputDir} = ExpandFileName /@ args;
task = CanonMethodCard`ReadTask[inputPath, "SEARCH_CORE"];
If[FailureQ[task], Print[InputForm[task]]; Quit[2]];
methodID = "libra-single-variable";
Get[FileNameJoin[{repoRoot, "methods", "libra", "Factorization.wl"}]];
multivariableSummary[evidence_Association] := KeyTake[evidence, {
  "strategy", "direction_sequence", "completed_directions", "stopped_stage",
  "factorization_max_equations", "max_wall_seconds", "factorization_equation_count",
  "factorization_solver_equation_count",
  "directional_fuchsian", "limit_code", "timed_out", "adapter_source", "adapter_sha256",
  "reference_regulator_exact", "free_parameter_strategy", "free_parameter_trial_count",
  "free_parameter_selected_index", "free_parameter_max_trials"}];

writeFailure[
  status_String,
  code_String,
  reason_String,
  evidence_Association : <||>
] := (
  CanonMethodCard`WriteProviderResult[
    task, outputDir, status, code, <||>,
    Join[<|"method_id" -> methodID, "reason" -> reason|>,
      If[AssociationQ[normalizationEvidence],
        <|"normalization" -> normalizationEvidence|>, <||>], evidence]
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
If[!And @@ (MatchQ[#, _Symbol] & /@ cut["variables"]) ||
    !DuplicateFreeQ[cut["variables"]] || MemberQ[cut["variables"], cut["regulator"]],
  writeFailure["ERROR", "INVALID_DIFFERENTIAL_SYSTEM",
    "Cut variables must be distinct symbols with a separate regulator"]
];
If[!CanonMethodCard`FlatConnectionQ[cut["matrices"], cut["variables"]],
  writeFailure["ERROR", "INVALID_DIFFERENTIAL_SYSTEM", "The input differential connection is not flat"]
];
methodOptions = Lookup[Lookup[task, "payload", <||>], "method_options", <||>];
If[!AssociationQ[methodOptions],
  writeFailure["ERROR", "INVALID_OPTIONS", "method_options must be an Association"]
];
factorOptions = CanonLibraFactorization`ReadOptions[methodOptions];
If[FailureQ[factorOptions],
  writeFailure["ERROR", "INVALID_OPTIONS", factorOptions[[2, "reason"]]]];
referenceRegulator = factorOptions["reference_regulator"];
multivariableRoute = KeyExistsQ[methodOptions, "direction_sequence"];
If[Length[cut["variables"]] =!= 1 && !multivariableRoute,
  writeFailure["INCONCLUSIVE", "OUT_OF_SCOPE",
    "Multivariable Libra requires an explicit direction_sequence"]
];
If[multivariableRoute,
  methodID = "libra-multivariable";
  directionSequence = methodOptions["direction_sequence"];
  If[Length[cut["variables"]] < 2 || !ListQ[directionSequence] ||
      !And @@ (IntegerQ[#] && 1 <= # <= Length[cut["variables"]] & /@ directionSequence),
    writeFailure["ERROR", "INVALID_OPTIONS",
      "direction_sequence must be a finite list of variable indexes for a multivariable cut"]];
  factorizationMaxEquations = Lookup[methodOptions, "factorization_max_equations", 4096];
  maxWallSeconds = Lookup[methodOptions, "max_wall_seconds", 60];
  If[!IntegerQ[factorizationMaxEquations] || factorizationMaxEquations <= 0 ||
      !MatchQ[maxWallSeconds, _Integer | _Rational | _Real] || !TrueQ[maxWallSeconds > 0],
    writeFailure["ERROR", "INVALID_OPTIONS", "Factorization budgets must be finite and positive"]]
];
normalizationBudgetDefaults = <|
  "normalization_max_steps" -> 8,
  "normalization_max_projectors" -> 64,
  "normalization_max_dimension" -> 8,
  "normalization_max_seconds" -> 30
|>;
If[Complement[Keys[methodOptions], Join[
    {"package_entry", "dependent_row_strategy", "normalization_strategy",
      "reference_regulator", "free_parameter_strategy", "free_parameter_max_trials"},
    If[multivariableRoute, {"direction_sequence", "factorization_max_equations", "max_wall_seconds"}, {}],
    Keys[normalizationBudgetDefaults]
  ]] =!= {},
  writeFailure["ERROR", "INVALID_OPTIONS", "method_options contains unknown options"]
];
dependentRowStrategy = Lookup[methodOptions, "dependent_row_strategy", "automatic"];
If[!MemberQ[{"automatic", "sector-de-closure"}, dependentRowStrategy],
  writeFailure[
    "ERROR", "INVALID_OPTIONS",
    "method_options.dependent_row_strategy must be automatic or sector-de-closure"
  ]
];
normalizationStrategy = Lookup[methodOptions, "normalization_strategy", "none"];
If[!MemberQ[{"none", "bounded"}, normalizationStrategy],
  writeFailure["ERROR", "INVALID_OPTIONS",
    "method_options.normalization_strategy must be none or bounded"]
];
normalizationBudgets = Join[normalizationBudgetDefaults,
  KeyTake[methodOptions, Keys[normalizationBudgetDefaults]]];
If[!And @@ (IntegerQ[#] && # > 0 & /@ Values[normalizationBudgets]),
  writeFailure["ERROR", "INVALID_OPTIONS",
    "Normalization budgets must be positive integers"]
];
If[normalizationStrategy === "none" &&
    Intersection[Keys[methodOptions], Keys[normalizationBudgetDefaults]] =!= {},
  writeFailure["ERROR", "INVALID_OPTIONS",
    "Normalization budgets require normalization_strategy=bounded"]
];
normalizationEvidence = <|"strategy" -> normalizationStrategy|>;
If[multivariableRoute && normalizationStrategy =!= "none",
  writeFailure["INCONCLUSIVE", "OUT_OF_SCOPE",
    "The multivariable Libra route currently supports normalization_strategy=none"]
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
requiredSymbols = If[multivariableRoute,
  Join[{"NewDSystem", "Transform", "FactorDependence", "GaussSolve", "EFormQ", "FuchsianQ"},
    If[directionSequence === {}, {}, {"Fuchsify"}]],
  {"NewDSystem", "Fuchsify", "Transform", "FactorOut", "OverallTransformation", "EFormQ"}];
If[normalizationStrategy === "bounded",
  requiredSymbols = Join[requiredSymbols, {"GetSubspaces", "Projector", "Balance"}]];
If[dependentRowStrategy === "sector-de-closure",
  requiredSymbols = Join[requiredSymbols, If[multivariableRoute,
    {"TClosure"}, {"TClosure", "LeadingSeriesCoefficient", "PolesInfo"}]]];
loadSucceeded = TrueQ[Quiet[Check[(Get[entry]; True), False]]];
If[!loadSucceeded,
  writeFailure["ERROR", "TOOL_ERROR", "Libra failed to load"]
];
libraSymbolAvailableQ[symbolName_String] :=
  NameQ["Libra`" <> symbolName] || (!multivariableRoute && NameQ["Global`" <> symbolName]);
symbolsAvailable = And @@ (libraSymbolAvailableQ /@ requiredSymbols);
If[normalizationStrategy === "bounded",
  symbolsAvailable = symbolsAvailable && And @@
    (NameQ["Libra`" <> #] & /@ {"GetSubspaces", "Projector", "Balance"})
];
If[!symbolsAvailable,
  writeFailure["ERROR", "TOOL_ERROR", "Libra lacks public symbols required by this card"]
];
Libra`$LibraUseFermat = False;

If[multivariableRoute,
  multivariableAdapter = FileNameJoin[{repoRoot, "methods", "libra", "Multivariable.wl"}];
  Get[multivariableAdapter];
  proposal = CanonLibraMultivariable`Propose[cut, directionSequence,
    hierarchy, factorizationMaxEquations, maxWallSeconds, factorOptions];
  multivariableEvidence = Join[proposal["evidence"], <|
    "adapter_source" -> "methods/libra/Multivariable.wl",
    "adapter_sha256" -> FileHash[multivariableAdapter, "SHA256", "HexString"]|>];
  If[dependentRowStrategy === "sector-de-closure",
    multivariableEvidence["dependent_rows"] = Join[multivariableEvidence["dependent_rows"], <|
      "hierarchy_id" -> hierarchy["hierarchy_id"],
      "hierarchy_artifact" -> hierarchyPath, "hierarchy_artifact_sha256" -> hierarchyHash,
      "mapped_sectors" -> False, "hierarchy_source_artifact" -> hierarchy["provenance"]["source_artifact"],
      "hierarchy_source_sha256" -> ToLowerCase[hierarchy["provenance"]["source_sha256"]]|>]];
  If[!TrueQ[proposal["success"]],
    diagnosticPath = CanonMethodCard`WriteWLArtifact[multivariableEvidence, outputDir, "libra-diagnostic.wl"];
    If[diagnosticPath === $Failed,
      writeFailure["ERROR", "OUTPUT_ERROR", "Cannot write the Libra diagnostic artifact"]];
    resultPath = CanonMethodCard`WriteProviderResult[task, outputDir, "INCONCLUSIVE", "METHOD_EXHAUSTED",
      <|"libra_diagnostic" -> <|"type" -> "mathematica-expression", "path" -> FileNameTake[diagnosticPath]|>|>,
      <|"method_id" -> methodID, "reason" -> proposal["reason"],
        "multivariable" -> multivariableSummary[multivariableEvidence]|>];
    If[resultPath === $Failed, Print["Failed to write result.json"]; Quit[1]];
    Quit[0]];
  transformation = proposal["transformation"];
  transformedMatrices = proposal["transformed_matrices"];
  newBasisRows = proposal["full_new_basis_rows"];
  providerEFormQ = True;
  strategyEvidence = multivariableEvidence["dependent_rows"];
  providerEvidence = KeyDrop[multivariableEvidence,
    {"transformation", "transformed_matrices", "source_basis", "variables", "regulator"}],

variable = First[cut["variables"]];
regulator = cut["regulator"];
matrix = Map[Together, First[cut["matrices"]], {2}];
If[normalizationStrategy === "bounded",
  normalizationAdapter = FileNameJoin[{repoRoot, "methods", "libra", "BoundedNormalization.wl"}];
  Get[normalizationAdapter];
  normalization = CanonLibraNormalization`Normalize[
    matrix, variable, regulator, normalizationBudgets];
  normalizationEvidence = Join[normalization["evidence"], <|
    "adapter_source" -> "methods/libra/BoundedNormalization.wl",
    "adapter_sha256" -> FileHash[normalizationAdapter, "SHA256", "HexString"]|>];
  If[!TrueQ[normalization["success"]],
    writeFailure["INCONCLUSIVE",
      If[MemberQ[{"DIMENSION_BUDGET", "STEP_BUDGET", "PROJECTOR_BUDGET",
          "SECONDS_BUDGET", "NO_PROGRESS_PROJECTOR", "SUBSPACE_RESULT"},
          normalization["limit_code"]], "METHOD_EXHAUSTED", "OUT_OF_SCOPE"],
      normalization["reason"], <|"normalization" -> normalizationEvidence|>]
  ];
];
If[!TrueQ[Quiet @ Check[NewDSystem[cardSystem, variable -> matrix]; True, False]],
  writeFailure["ERROR", "TOOL_ERROR", "Libra could not initialize the differential system"]
];
If[normalizationStrategy === "bounded",
  If[!TrueQ[Quiet @ Check[
      Transform[cardSystem, normalization["transformation"]]; True, False]] ||
      !CanonMethodCard`ZeroMatrixQ[
        cardSystem[variable] - normalization["matrix"]],
    writeFailure["INCONCLUSIVE", "METHOD_EXHAUSTED",
      "Libra could not apply the verified normalization transformation",
      <|"normalization" -> normalizationEvidence|>]
  ];
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
  "specialization_policy" -> factorOptions["free_parameter_strategy"],
  "reference_regulator_exact" -> factorOptions["reference_regulator_exact"]
|>;
referenceMatrix = Quiet[Check[Map[Together, cardSystem[variable]/regulator, {2}] /.
  regulator -> referenceRegulator, $Failed]];
If[!MatrixQ[referenceMatrix] ||
    !And @@ (CanonMethodCard`ExactRationalExpressionQ /@ Flatten[referenceMatrix]),
  writeFailure["INCONCLUSIVE", "METHOD_EXHAUSTED", "The selected regulator reference is singular",
    <|"limit_code" -> "REFERENCE_EPSILON_SINGULAR",
      "reference_regulator_exact" -> factorOptions["reference_regulator_exact"]|>]];
If[dependentRowStrategy === "automatic",
  factorTemplate = Quiet @ Check[
    FactorOut[cardSystem, variable, regulator, referenceRegulator],
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
  factorTemplate = Quiet @ Check[
    FactorOut[
      cardSystem, variable, regulator, referenceRegulator,
      DependentRowIndices -> combinedMask
    ],
    $Failed
  ]
];
If[factorTemplate === $Failed || !MatrixQ[factorTemplate],
  writeFailure[
    "INCONCLUSIVE", "METHOD_EXHAUSTED",
    "Libra FactorOut produced no matrix transformation", strategyEvidence
  ]
];
freeParameters = DeleteDuplicates[Cases[factorTemplate, _C, Infinity]];
factorSelection = CanonLibraFactorization`SelectFactor[factorTemplate, freeParameters, factorOptions,
  Function[{candidate, specification}, If[factorOptions["free_parameter_strategy"] === "ones", <||>,
    <|"epsilon_factorized" -> CanonMethodCard`EpsilonFactorizedQ[
      CanonMethodCard`GaugeTransform[{cardSystem[variable]}, {variable}, candidate], regulator]|>]]];
strategyEvidence = Join[strategyEvidence, factorSelection["evidence"]];
If[!TrueQ[factorSelection["success"]],
  writeFailure["INCONCLUSIVE", "METHOD_EXHAUSTED", "No tried free-parameter point supplied a valid factor",
    Join[strategyEvidence, <|"limit_code" -> factorSelection["limit_code"]|>]]];
factorTransformation = factorSelection["factor"];
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
transformedMatrices = {transformed};
newBasisRows = Map[Together, Inverse[transformation], {2}];
providerEvidence = <|
  "check_eps_form" -> providerEFormQ,
  "stages" -> If[normalizationStrategy === "bounded",
    {"BoundedNormalization", "Fuchsify", "FactorOut"}, {"Fuchsify", "FactorOut"}],
  "factor_out_mu" -> referenceRegulator,
  "reference_regulator_exact" -> factorOptions["reference_regulator_exact"], "use_fermatica" -> False,
  "dependent_rows" -> strategyEvidence, "normalization" -> normalizationEvidence|>
];

candidateArtifact = <|
  "schema" -> "canon-neu/core-candidates/v1",
  "sector" -> cut["sector"],
  "family_id" -> cut["family_id"],
  "basis_id" -> cut["basis_id"],
  "coefficient_domain" -> "exact-rational-functions",
  "basis" -> cut["basis"],
  "source_basis" -> cut["basis"],
  "variables" -> cut["variables"],
  "regulator" -> cut["regulator"],
  "convention" -> "old_basis = transformation . new_basis",
  "method" -> <|
    "id" -> methodID,
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
      "candidate_id" -> methodID <> ":1",
      "member_candidate_ids" -> Table[methodID <> ":row:" <> ToString[i],
        {i, Length[cut["basis"]]}],
      "full_new_basis_rows" -> newBasisRows,
      "construction_rejection" -> None,
      "transformation" -> transformation,
      "transformed_matrices" -> transformedMatrices,
      "provider_evidence" -> providerEvidence
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
  Join[<|
    "method_id" -> methodID,
    "tool" -> "Libra",
    "provider_check_eps_form" -> providerEFormQ,
    "candidate_count" -> 1,
    "dependent_rows" -> strategyEvidence,
    "normalization" -> normalizationEvidence
  |>, If[multivariableRoute,
    <|"multivariable" -> multivariableSummary[multivariableEvidence]|>, <||>]]
];
If[resultPath === $Failed, Print["Failed to write result.json"]; Quit[1]];
Quit[0];
