$HistoryLength = 0;

repoRoot = DirectoryName[DirectoryName[DirectoryName[ExpandFileName[$InputFileName]]]];
Get[FileNameJoin[{repoRoot, "mma", "lib", "MethodCardCore.wl"}]];
Get[FileNameJoin[{repoRoot, "mma", "lib", "InitialInterface.wl"}]];

args = CanonMethodCard`ScriptArguments[];
If[Length[args] =!= 2, Print["usage: CheckUTEvidence.wls <input.json> <new-output-dir>"]; Quit[2]];
{inputPath, outputDir} = ExpandFileName /@ args;
task = CanonMethodCard`ReadTask[inputPath, "CHECK_UT_EVIDENCE"];
If[FailureQ[task], Print[InputForm[task]]; Quit[2]];

(* Reference validation must not write into its read-only installation, even
   when rejecting a request before loading any scientific artifact. *)
insideQ[path_String, root_String] := path === root || StringStartsQ[path,
  If[StringEndsQ[root, $PathnameSeparator], root, root <> $PathnameSeparator]];
realPath[path_String] := Lookup[
  Quiet @ Check[Association[FileInformation[path]], <||>], "AbsoluteFileName", $Failed];
resolvedLocation[path_String] := Module[{ancestor = path, suffix = {}, parent, resolved},
  While[!FileExistsQ[ancestor], parent = DirectoryName[ancestor];
    If[parent === ancestor, Return[$Failed]];
    PrependTo[suffix, FileNameTake[ancestor]]; ancestor = parent];
  resolved = realPath[ancestor];
  If[StringQ[resolved], FileNameJoin[Prepend[suffix, resolved]], $Failed]];
checkerOptions = Lookup[task["payload"], "checker_options", <||>];
checkerComponentPaths = If[AssociationQ[checkerOptions],
  CanonMethodCard`ResolveInputPath[inputPath, #] & /@
    Select[Lookup[checkerOptions, {"package_entry", "finite_flow_package_file", "finite_flow_library"}, None],
      StringQ[#] && # =!= "" &], {}];
protectedRoots = Join[
  Select[resolvedLocation /@ (DirectoryName /@ checkerComponentPaths), StringQ],
  DirectoryName /@ Select[realPath /@ Select[checkerComponentPaths, FileType[#] === File &], StringQ],
  If[AssociationQ[checkerOptions] && StringQ[Lookup[checkerOptions, "reference_directory", None]] &&
      checkerOptions["reference_directory"] =!= "",
    Select[{resolvedLocation[CanonMethodCard`ResolveInputPath[inputPath,
      checkerOptions["reference_directory"]]]}, StringQ], {}]];
outputParent = realPath[DirectoryName[outputDir]];
If[FileExistsQ[outputDir] || FileType[DirectoryName[outputDir]] =!= Directory || !StringQ[outputParent],
  Print["INITIAL evidence checker requires a new output directory with an existing parent"]; Quit[2]];
If[AnyTrue[protectedRoots, insideQ[FileNameJoin[{outputParent, FileNameTake[outputDir]}], #] &],
  Print["INITIAL evidence checker output cannot be inside a component or reference directory"]; Quit[2]];

expectedInitialIdentity = "INITIAL 2.1; 63d8f813ac415f82f7ef945ee7e3f78a242fae49";
expectedFiniteFlowIdentity = "FiniteFlow; 278344c169010b74e791af8c5604c8cb9cd8df11";
expectedCandidate = <|
  "family_id" -> "initial-official-massless-3l4p",
  "candidate_id" -> "official-planar-ladder-26x26",
  "basis_id" -> "initial-2.1-massless-3l4p-ladder-basis-26",
  "basis_order" -> "initial_basis_ladder.m:official-order",
  "normalization" -> "D=4-2 eps;x=t/s",
  "reference_id" -> "INITIAL-2.1:massless_3L4P/TMatrix_ladder_to_UT.m",
  "dimension" -> 26,
  "variable" -> "x",
  "regulator" -> "eps",
  "alphabet" -> {"x", "1+x"},
  "ut_seed" -> "G[2,{1,1,1,1,1,1,1,1,1,1,-1,0,0,0,0}]",
  "take_row" -> 1
|>;

officialLadderDLogQ[matrix_?MatrixQ] := And @@ (
  Function[entry,
    Module[{scaled, cleared},
      scaled = Together[entry/eps];
      cleared = Cancel[Together[scaled*x*(1 + x)]];
      FreeQ[scaled, eps] && DeleteCases[Cases[cleared, _Symbol, Infinity], x] === {} &&
        PolynomialQ[cleared, x] &&
        TrueQ[Exponent[cleared, x] <= 1]
    ]
  ] /@ Flatten[matrix]
);

writeOutcome[status_String, code_String, reason_String, details_: <||>] := (
  CanonMethodCard`WriteResult[
    task, outputDir, status, code, <||>, Join[<|"reason" -> reason,
      "interface" -> CanonInitialInterface`OfficialContract[]|>, details]
  ];
  Quit[If[status === "ERROR", 1, 0]]
);
reject[reason_String, details_: <||>] :=
  writeOutcome["FAIL", "EVIDENCE_REJECTED", reason, details];

candidate = Lookup[task["payload"], "candidate", Missing["candidate"]];
providerTaskId = Lookup[task["payload"], "provider_task_id", Missing["provider_task_id"]];
If[!AssociationQ[candidate] || !StringQ[providerTaskId],
  writeOutcome["ERROR", "INVALID_INPUT", "candidate or provider_task_id is missing"]
];
scopeKeys = Keys[expectedCandidate];
If[
  !And @@ (KeyExistsQ[candidate, #] & /@ scopeKeys) ||
  !And @@ (SameQ[Lookup[candidate, #], expectedCandidate[#]] & /@ scopeKeys),
  reject["checker task does not identify the fixed official ladder scope"]
];

evidence = CanonMethodCard`LoadArtifact[task, inputPath, "ut_evidence"];
If[FailureQ[evidence] || !AssociationQ[evidence],
  writeOutcome["ERROR", "INVALID_INPUT", "ut_evidence artifact is missing or invalid"]
];
If[Lookup[evidence, "schema", None] =!= "canon-neu/ut-evidence/v1",
  reject["unexpected UT evidence schema"]
];
identityChecks = <|
  "source_task_id" -> SameQ[Lookup[evidence, "source_task_id", None], providerTaskId],
  "family_id" -> SameQ[Lookup[evidence, "family_id", None], expectedCandidate["family_id"]],
  "candidate_id" -> SameQ[Lookup[evidence, "candidate_id", None], expectedCandidate["candidate_id"]],
  "basis_id" -> SameQ[Lookup[evidence, "basis_id", None], expectedCandidate["basis_id"]],
  "basis_order" -> SameQ[Lookup[evidence, "basis_order", None], expectedCandidate["basis_order"]],
  "normalization" -> SameQ[Lookup[evidence, "normalization", None], expectedCandidate["normalization"]],
  "reference_id" -> SameQ[Lookup[evidence, "reference_id", None], expectedCandidate["reference_id"]],
  "dimension" -> SameQ[Lookup[evidence, "dimension", None], 26],
  "take_row" -> SameQ[Lookup[evidence, "take_row", None], 1],
  "convention" -> SameQ[Lookup[evidence, "convention", None], "old_basis = transformation . new_basis"],
  "coefficient_domain" -> SameQ[Lookup[evidence, "coefficient_domain", None], "exact-rational-functions"],
  "verification_status" -> SameQ[Lookup[evidence, "verification_status", None], "AWAITING_INDEPENDENT_VERIFICATION"]
|>;
If[!And @@ Values[identityChecks],
  reject["task, family, candidate, basis, order, normalization, reference, or convention mismatch", <|"identity_checks" -> identityChecks|>]
];

basis = Lookup[evidence, "basis", None];
variable = Lookup[evidence, "variable", None];
regulator = Lookup[evidence, "regulator", None];
alphabet = Lookup[evidence, "alphabet", None];
utSeed = Lookup[evidence, "ut_seed", None];
sourceMatrix = Lookup[evidence, "source_matrix", None];
transformation = Lookup[evidence, "transformation", None];
declaredTransformed = Lookup[evidence, "transformed_matrix", None];
method = Lookup[evidence, "method", None];
expectedUTSeed = G[2, {1, 1, 1, 1, 1, 1, 1, 1, 1, 1, -1, 0, 0, 0, 0}];
shapeChecks = <|
  "basis_length" -> TrueQ[ListQ[basis] && Length[basis] === 26],
  "basis_seed" -> TrueQ[ListQ[basis] && Length[basis] > 0 && First[basis] === expectedUTSeed && utSeed === expectedUTSeed],
  "variable" -> SameQ[variable, x],
  "regulator" -> SameQ[regulator, eps],
  "alphabet" -> SameQ[alphabet, {x, 1 + x}],
  "source_shape" -> SameQ[Dimensions[sourceMatrix], {26, 26}],
  "transformation_shape" -> SameQ[Dimensions[transformation], {26, 26}],
  "transformed_shape" -> SameQ[Dimensions[declaredTransformed], {26, 26}],
  "method_shape" -> AssociationQ[method]
|>;
If[!And @@ Values[shapeChecks],
  reject["basis/order/seed/variable/alphabet or matrix shape mismatch", <|"shape_checks" -> shapeChecks|>]
];
If[
  !And @@ (CanonMethodCard`ExactRationalExpressionQ /@ Flatten[{sourceMatrix, transformation, declaredTransformed}]),
  reject["evidence is outside the exact rational-function domain"]
];
If[!TrueQ[Together[Det[transformation]] =!= 0],
  reject["evidence transformation is singular", <|"invertible" -> False|>]
];
If[
  Lookup[method, "initial_identity", None] =!= expectedInitialIdentity ||
  Lookup[method, "finiteflow_identity", None] =!= expectedFiniteFlowIdentity,
  reject["provider tool identity mismatch"]
];

checkerOptions = Lookup[task["payload"], "checker_options", <||>];
If[!AssociationQ[checkerOptions],
  writeOutcome["ERROR", "TOOL_CONFIGURATION", "checker_options must be an object"]
];
componentPaths = Lookup[checkerOptions, {
  "package_entry", "finite_flow_package_file", "reference_directory"
}, Missing["path"]];
If[!AllTrue[componentPaths, StringQ[#] && # =!= "" &],
  writeOutcome["ERROR", "TOOL_CONFIGURATION", "declare INITIAL/FiniteFlow entries and the reference directory"]
];
{initialEntry, finiteFlowEntry, exampleRoot} =
  CanonMethodCard`ResolveInputPath[inputPath, #] & /@ componentPaths;
amatrixPath = FileNameJoin[{exampleRoot, "AMatrix_ladder.m"}];
basisPath = FileNameJoin[{exampleRoot, "initial_basis_ladder.m"}];
referencePath = FileNameJoin[{exampleRoot, "TMatrix_ladder_to_UT.m"}];
requiredComponents = {
  initialEntry, finiteFlowEntry,
  amatrixPath, basisPath, referencePath
};
If[Or @@ (FileType[#] =!= File & /@ requiredComponents),
  writeOutcome["ERROR", "TOOL_COMPONENT_MISSING", "a registered tool or official reference component is missing"]
];

pathChecks = <|
  "initial_entry" -> SameQ[Lookup[method, "initial_entry", None], initialEntry],
  "finiteflow_entry" -> SameQ[Lookup[method, "finiteflow_entry", None], finiteFlowEntry],
  "initial_entry_sha256" -> SameQ[Lookup[method, "initial_entry_sha256", None], FileHash[initialEntry, "SHA256", "HexString"]],
  "finiteflow_entry_sha256" -> SameQ[Lookup[method, "finiteflow_entry_sha256", None], FileHash[finiteFlowEntry, "SHA256", "HexString"]],
  "amatrix_sha256" -> SameQ[Lookup[method, "amatrix_sha256", None], FileHash[amatrixPath, "SHA256", "HexString"]],
  "basis_sha256" -> SameQ[Lookup[method, "basis_sha256", None], FileHash[basisPath, "SHA256", "HexString"]],
  "reference_sha256" -> SameQ[Lookup[method, "reference_sha256", None], FileHash[referencePath, "SHA256", "HexString"]]
|>;
If[!And @@ Values[pathChecks],
  reject["registered entry or official input/reference hash mismatch", <|"path_checks" -> pathChecks|>]
];

officialA = Together[Get[amatrixPath]];
officialBasis = Get[basisPath];
officialReference = Get[referencePath];
scientificChecks = <|
  "official_a_match" -> SameQ[sourceMatrix, officialA],
  "official_basis_order_match" -> SameQ[basis, officialBasis],
  "official_reference_match" -> SameQ[transformation, officialReference],
  "invertible" -> TrueQ[Together[Det[transformation]] =!= 0],
  "exact_gauge" -> TrueQ[
    CanonMethodCard`ZeroMatrixQ[
      Map[Together, officialA.transformation - D[transformation, x] - transformation.declaredTransformed, {2}]
    ]
  ],
  "epsilon_independent_after_division" -> TrueQ[
    CanonMethodCard`EpsilonFactorizedQ[{declaredTransformed}, eps]
  ],
  "declared_dlog_alphabet" -> TrueQ[
    officialLadderDLogQ[declaredTransformed]
  ]
|>;
If[!And @@ Values[scientificChecks],
  reject["independent exact scientific checks rejected provider evidence", <|"scientific_checks" -> scientificChecks|>]
];

verified = <|
  "schema" -> "canon-neu/verified-ut-evidence/v1",
  "interface" -> CanonInitialInterface`OfficialContract[],
  "source_task_id" -> providerTaskId,
  "checker_task_id" -> task["task_id"],
  "family_id" -> expectedCandidate["family_id"],
  "candidate_id" -> expectedCandidate["candidate_id"],
  "basis_id" -> expectedCandidate["basis_id"],
  "basis_order" -> expectedCandidate["basis_order"],
  "normalization" -> expectedCandidate["normalization"],
  "reference_id" -> expectedCandidate["reference_id"],
  "alphabet" -> {x, 1 + x},
  "transformation" -> transformation,
  "transformed_matrix" -> declaredTransformed,
  "checks" -> Join[identityChecks, shapeChecks, pathChecks, scientificChecks],
  "verification_status" -> "VERIFIED_EVIDENCE"
|>;
artifactPath = CanonMethodCard`WriteWLArtifact[verified, outputDir, "verified-ut-evidence.wl"];
If[artifactPath === $Failed,
  writeOutcome["ERROR", "OUTPUT_ERROR", "could not write verified UT evidence"]
];
resultPath = CanonMethodCard`WriteResult[
  task, outputDir, "PASS", "VERIFIED_EVIDENCE",
  <|"verified_ut_evidence" -> <|"type" -> "mathematica-expression", "path" -> FileNameTake[artifactPath]|>|>,
  <|
    "family_id" -> expectedCandidate["family_id"],
    "interface" -> CanonInitialInterface`OfficialContract[],
    "candidate_id" -> expectedCandidate["candidate_id"],
    "basis_id" -> expectedCandidate["basis_id"],
    "official_reference_match" -> scientificChecks["official_reference_match"],
    "invertible" -> scientificChecks["invertible"],
    "exact_gauge" -> scientificChecks["exact_gauge"],
    "epsilon_independent_after_division" -> scientificChecks["epsilon_independent_after_division"],
    "declared_dlog_alphabet" -> scientificChecks["declared_dlog_alphabet"]
  |>
];
If[resultPath === $Failed, Print["failed to write result.json"]; Quit[1]];
Quit[0];
