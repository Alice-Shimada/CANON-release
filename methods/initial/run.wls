$HistoryLength = 0;

repoRoot = DirectoryName[DirectoryName[DirectoryName[ExpandFileName[$InputFileName]]]];
Get[FileNameJoin[{repoRoot, "mma", "lib", "MethodCardCore.wl"}]];

args = CanonMethodCard`ScriptArguments[];
If[Length[args] =!= 2, Print["Usage: run.wls <input.json> <new-output-dir>"]; Quit[2]];
{inputPath, outputDir} = ExpandFileName /@ args;
task = CanonMethodCard`ReadTask[inputPath, "PROVIDE_UT_EVIDENCE"];
If[FailureQ[task], Print[InputForm[task]]; Quit[2]];

methodId = "initial-2.1-official-massless-3l4p-ladder";
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
  CanonMethodCard`WriteProviderResult[
    task, outputDir, status, code, <||>,
    Join[<|"method_id" -> methodId, "reason" -> reason, "workflow_action" -> "none"|>, details]
  ];
  Quit[If[status === "ERROR", 1, 0]]
);

candidate = Lookup[task["payload"], "candidate", Missing["candidate"]];
If[!AssociationQ[candidate],
  writeOutcome["ERROR", "INVALID_INPUT", "payload.candidate must be an object"]
];
scopeKeys = Keys[expectedCandidate];
If[!And @@ (KeyExistsQ[candidate, #] & /@ scopeKeys),
  writeOutcome["INCONCLUSIVE", "OUT_OF_SCOPE", "The candidate scope is incomplete"]
];
If[!And @@ (SameQ[Lookup[candidate, #], expectedCandidate[#]] & /@ scopeKeys),
  writeOutcome[
    "INCONCLUSIVE", "OUT_OF_SCOPE",
    "This card covers only the official INITIAL ladder candidate with its fixed normalization",
    <|"requested_family_id" -> Lookup[candidate, "family_id", None],
      "requested_candidate_id" -> Lookup[candidate, "candidate_id", None]|>
  ]
];

options = Lookup[task["payload"], "method_options", <||>];
If[!AssociationQ[options],
  writeOutcome["ERROR", "TOOL_CONFIGURATION", "method_options must be an object"]
];
componentPaths = Lookup[options, {
  "package_entry", "finite_flow_package_file", "finite_flow_library", "reference_directory"
}, Missing["path"]];
initialIdentity = Lookup[options, "initial_identity", Missing["initial_identity"]];
finiteFlowIdentity = Lookup[options, "finiteflow_identity", Missing["finiteflow_identity"]];
If[
  !AllTrue[componentPaths, StringQ[#] && # =!= "" &],
  writeOutcome["ERROR", "TOOL_CONFIGURATION", "Specify the INITIAL and FiniteFlow entries, native library, and reference data directory"]
];
If[initialIdentity =!= expectedInitialIdentity || finiteFlowIdentity =!= expectedFiniteFlowIdentity,
  writeOutcome["ERROR", "TOOL_IDENTITY_MISMATCH", "The declared INITIAL or FiniteFlow identity differs from the registered identity"]
];
If[!MemberQ[$CommandLine, "-noinit"] || !MemberQ[$CommandLine, "-script"],
  writeOutcome["ERROR", "TOOL_CONFIGURATION", "WolframKernel must be invoked with -noinit -script"]
];

insideQ[path_String, root_String] := path === root || StringStartsQ[path, root <> $PathnameSeparator];
realPath[path_String] := Lookup[
  Quiet @ Check[Association[FileInformation[path]], <||>], "AbsoluteFileName", $Failed
];
{initialEntry, finiteFlowEntry, finiteFlowLibrary, exampleRoot} =
  CanonMethodCard`ResolveInputPath[inputPath, #] & /@ componentPaths;
finiteFlowLibraryDirectory = DirectoryName[finiteFlowLibrary];
requiredComponents = {initialEntry, finiteFlowEntry, finiteFlowLibrary};
If[Or @@ (FileType[#] =!= File & /@ requiredComponents),
  writeOutcome["ERROR", "TOOL_COMPONENT_MISSING", "A registered INITIAL or FiniteFlow component is missing"]
];
If[
  FileExistsQ[outputDir] || FileType[DirectoryName[outputDir]] =!= Directory ||
  AnyTrue[DirectoryName /@ requiredComponents, insideQ[outputDir, #] &],
  writeOutcome["ERROR", "TOOL_CONFIGURATION", "The output directory must be new, owned by the caller, and outside the tool installation directories"]
];

$LibraryPath = Prepend[DeleteCases[$LibraryPath, finiteFlowLibraryDirectory], finiteFlowLibraryDirectory];
If[Check[Get[finiteFlowEntry], $Failed] === $Failed,
  writeOutcome["ERROR", "TOOL_LOAD_FAILED", "FiniteFlow failed to load"]
];
If[realPath[FiniteFlow`Private`fflowlib] =!= realPath[finiteFlowLibrary],
  writeOutcome["ERROR", "TOOL_COMPONENT_MISMATCH", "FiniteFlow loaded an unexpected library"]
];
If[Check[Get[initialEntry], $Failed] === $Failed,
  writeOutcome["ERROR", "TOOL_LOAD_FAILED", "INITIAL failed to load"]
];

amatrixPath = FileNameJoin[{exampleRoot, "AMatrix_ladder.m"}];
basisPath = FileNameJoin[{exampleRoot, "initial_basis_ladder.m"}];
referencePath = FileNameJoin[{exampleRoot, "TMatrix_ladder_to_UT.m"}];
If[Or @@ (FileType[#] =!= File & /@ {amatrixPath, basisPath, referencePath}),
  writeOutcome["ERROR", "TOOL_COMPONENT_MISSING", "The official ladder A matrix, basis, or reference is missing"]
];

amatrix = Together[Get[amatrixPath]];
initialBasis = Get[basisPath];
referenceTransformation = Get[referencePath];
utSeed = G[2, {1, 1, 1, 1, 1, 1, 1, 1, 1, 1, -1, 0, 0, 0, 0}];
ansatzFunctions = {1/x, 1/(1 + x)};
takeRow = 1;
nThreads = Lookup[options, "threads", 1];
If[!IntegerQ[nThreads] || nThreads < 1,
  writeOutcome["ERROR", "TOOL_CONFIGURATION", "threads must be a positive integer"]
];
If[
  Dimensions[amatrix] =!= {26, 26} || Length[initialBasis] =!= 26 ||
  First[initialBasis] =!= utSeed || Dimensions[referenceTransformation] =!= {26, 26},
  writeOutcome["ERROR", "TOOL_REFERENCE_MISMATCH", "The official ladder A matrix, basis, seed, or reference has changed"]
];

If[Quiet @ Check[CreateDirectory[outputDir]; SetDirectory[outputDir]; True, False] =!= True,
  writeOutcome["ERROR", "TOOL_CONFIGURATION", "Cannot create and enter the new output directory"]
];
FiniteFlow`FFNThreads = nThreads;
{elapsedSeconds, transformation} = AbsoluteTiming[
  Quiet @ Check[
    TCalc[
      amatrix, ansatzFunctions, x, eps,
      "TakeRow" -> takeRow, "Silent" -> True, "NThreads" -> nThreads
    ],
    $Failed
  ]
];
If[transformation === $Failed || !MatrixQ[transformation],
  writeOutcome["ERROR", "TOOL_COMPUTATION_FAILED", "INITIAL TCalc failed"]
];
If[!SameQ[transformation, referenceTransformation],
  writeOutcome[
    "INCONCLUSIVE", "METHOD_EXHAUSTED",
    "The computed transformation differs from the official reference"
  ]
];
transformedMatrix = Quiet @ Check[basisChange[amatrix, transformation, x, "NThreads" -> nThreads], $Failed];
If[transformedMatrix === $Failed || Dimensions[transformedMatrix] =!= {26, 26},
  writeOutcome["ERROR", "TOOL_COMPUTATION_FAILED", "INITIAL basisChange failed"]
];

exactGauge = CanonMethodCard`ZeroMatrixQ[
  Map[Together, amatrix.transformation - D[transformation, x] - transformation.transformedMatrix, {2}]
];
epsilonIndependent = CanonMethodCard`EpsilonFactorizedQ[{transformedMatrix}, eps];
declaredDLog = officialLadderDLogQ[transformedMatrix];
If[!TrueQ[exactGauge && epsilonIndependent && declaredDLog],
  writeOutcome[
    "INCONCLUSIVE", "METHOD_EXHAUSTED",
    "The provider result did not pass all exact gauge, epsilon-factorization, and declared dlog checks"
  ]
];

evidence = <|
  "schema" -> "canon-neu/ut-evidence/v1",
  "source_task_id" -> task["task_id"],
  "family_id" -> expectedCandidate["family_id"],
  "candidate_id" -> expectedCandidate["candidate_id"],
  "basis_id" -> expectedCandidate["basis_id"],
  "basis_order" -> expectedCandidate["basis_order"],
  "normalization" -> expectedCandidate["normalization"],
  "reference_id" -> expectedCandidate["reference_id"],
  "coefficient_domain" -> "exact-rational-functions",
  "dimension" -> 26,
  "basis" -> initialBasis,
  "variable" -> x,
  "regulator" -> eps,
  "alphabet" -> {x, 1 + x},
  "ut_seed" -> utSeed,
  "take_row" -> takeRow,
  "convention" -> "old_basis = transformation . new_basis",
  "source_matrix" -> amatrix,
  "transformation" -> transformation,
  "transformed_matrix" -> transformedMatrix,
  "method" -> <|
    "id" -> methodId,
    "tool" -> "INITIAL",
    "initial_identity" -> initialIdentity,
    "finiteflow_identity" -> finiteFlowIdentity,
    "initial_entry" -> initialEntry,
    "initial_entry_sha256" -> FileHash[initialEntry, "SHA256", "HexString"],
    "finiteflow_entry" -> finiteFlowEntry,
    "finiteflow_entry_sha256" -> FileHash[finiteFlowEntry, "SHA256", "HexString"],
    "amatrix_sha256" -> FileHash[amatrixPath, "SHA256", "HexString"],
    "basis_sha256" -> FileHash[basisPath, "SHA256", "HexString"],
    "reference_sha256" -> FileHash[referencePath, "SHA256", "HexString"],
    "wolfram_version" -> $Version,
    "system_id" -> $SystemID,
    "threads" -> nThreads
  |>,
  "provider_evidence" -> <|
    "exact_reference_match" -> True,
    "invertible" -> TrueQ[Together[Det[transformation]] =!= 0],
    "exact_gauge" -> exactGauge,
    "epsilon_independent_after_division" -> epsilonIndependent,
    "declared_dlog_alphabet" -> declaredDLog,
    "elapsed_seconds" -> elapsedSeconds
  |>,
  "verification_status" -> "AWAITING_INDEPENDENT_VERIFICATION"
|>;

artifactPath = CanonMethodCard`WriteWLArtifact[evidence, outputDir, "ut-evidence.wl"];
If[artifactPath === $Failed,
  writeOutcome["ERROR", "OUTPUT_ERROR", "Cannot write the UT-evidence artifact"]
];
resultPath = CanonMethodCard`WriteProviderResult[
  task, outputDir, "PROVISIONAL", "EVIDENCE_AWAITING_VERIFICATION",
  <|"ut_evidence" -> <|"type" -> "mathematica-expression", "path" -> FileNameTake[artifactPath]|>|>,
  <|
    "method_id" -> methodId,
    "family_id" -> expectedCandidate["family_id"],
    "candidate_id" -> expectedCandidate["candidate_id"],
    "dimension" -> 26,
    "take_row" -> takeRow,
    "threads" -> nThreads,
    "elapsed_seconds" -> elapsedSeconds,
    "verification_status" -> "AWAITING_INDEPENDENT_VERIFICATION",
    "workflow_action" -> "none"
  |>
];
If[resultPath === $Failed, Print["Failed to write result.json"]; Quit[1]];
Quit[0];
