$HistoryLength = 0;

repoRoot = DirectoryName[DirectoryName[DirectoryName[ExpandFileName[$InputFileName]]]];
Get[FileNameJoin[{repoRoot, "mma", "lib", "MethodCardCore.wl"}]];

args = CanonMethodCard`ScriptArguments[];
If[Length[args] =!= 2, Print["用法：run.wls <input.json> <output_dir>"]; Quit[2]];
{inputPath, outputDir} = ExpandFileName /@ args;
task = CanonMethodCard`ReadTask[inputPath, "SCREEN_TAIL"];
If[FailureQ[task], Print[InputForm[task]]; Quit[2]];

writeFailure[status_String, code_String, reason_String, details_: <||>] := (
  CanonMethodCard`WriteResult[
    task,
    outputDir,
    status,
    code,
    <||>,
    Join[
      <|"method_id" -> "full-prefix-tail-screen", "reason" -> reason, "repair_invoked" -> False|>,
      details
    ]
  ];
  Quit[If[status === "ERROR", 1, 0]]
);

exactMatrixListQ[matrices_, count_Integer, dimension_Integer] :=
  ListQ[matrices] && Length[matrices] === count &&
  And @@ (
    MatrixQ[#] && Dimensions[#] === {dimension, dimension} &&
    And @@ (CanonMethodCard`ExactRationalExpressionQ /@ Flatten[#]) & /@ matrices
  );

zeroBlockQ[block_] := MatrixQ[block] &&
  And @@ (TrueQ[Together[#] === 0] & /@ Flatten[block]);

sameMatricesQ[left_List, right_List] := Length[left] === Length[right] &&
  And @@ MapThread[
    CanonMethodCard`ZeroMatrixQ[Map[Together, #1 - #2, {2}]] &,
    {left, right}
  ];

blockList[matrices_List, rows_, columns_] := (#[[rows, columns]] & /@ matrices);

sectorBasis = CanonMethodCard`LoadArtifact[task, inputPath, "sector_basis"];
cut = CanonMethodCard`LoadArtifact[task, inputPath, "sector_cut_de"];
coreCandidates = CanonMethodCard`LoadArtifact[task, inputPath, "core_candidates"];
acceptedPrefix = CanonMethodCard`LoadArtifact[task, inputPath, "accepted_prefix"];
fullPool = CanonMethodCard`LoadArtifact[task, inputPath, "full_prefix_candidates"];

If[
  FailureQ[sectorBasis] || FailureQ[cut] || FailureQ[coreCandidates] ||
  FailureQ[acceptedPrefix] || FailureQ[fullPool] ||
  !CanonMethodCard`ValidSectorBasisQ[sectorBasis] ||
  !CanonMethodCard`ValidCutDEQ[cut] ||
  !CanonMethodCard`ValidCandidatesQ[coreCandidates],
  writeFailure["ERROR", "INVALID_INPUT", "一个或多个 tail-screen artifact 无效"]
];

variables = cut["variables"];
regulator = cut["regulator"];
currentDimension = Length[cut["basis"]];

If[
  Lookup[acceptedPrefix, "schema", None] =!= "canon-neu/accepted-prefix/v1" ||
  Lookup[acceptedPrefix, "coefficient_domain", None] =!= "exact-rational-functions" ||
  !StringQ[Lookup[acceptedPrefix, "prefix_id", None]] ||
  !StringQ[Lookup[acceptedPrefix, "family_id", None]] ||
  !ListQ[Lookup[acceptedPrefix, "basis", None]] ||
  !ListQ[Lookup[acceptedPrefix, "alphabet", None]] ||
  Lookup[acceptedPrefix, "variables", None] =!= variables ||
  Lookup[acceptedPrefix, "regulator", None] =!= regulator,
  writeFailure["ERROR", "INVALID_ACCEPTED_PREFIX", "accepted lower prefix 的协议无效"]
];

lowerDimension = Length[acceptedPrefix["basis"]];
prefixMatrices = Lookup[acceptedPrefix, "matrices", None];
If[
  lowerDimension < 1 || !exactMatrixListQ[prefixMatrices, Length[variables], lowerDimension] ||
  !CanonMethodCard`FlatConnectionQ[prefixMatrices, variables] ||
  !CanonMethodCard`EpsilonFactorizedQ[prefixMatrices, regulator] ||
  !CanonMethodCard`DLogConnectionQ[prefixMatrices, variables, regulator, acceptedPrefix["alphabet"]],
  writeFailure["ERROR", "INVALID_ACCEPTED_PREFIX", "accepted lower prefix 不是精确 canonical dlog system"]
];

fullDimension = lowerDimension + currentDimension;
If[
  Lookup[fullPool, "schema", None] =!= "canon-neu/full-prefix-candidates/v1" ||
  Lookup[fullPool, "coefficient_domain", None] =!= "exact-rational-functions" ||
  Lookup[fullPool, "convention", None] =!= "old_prefix_basis = full_transformation . candidate_prefix_basis" ||
  Lookup[fullPool, "sector", None] =!= task["sector"] ||
  Lookup[fullPool, "sector", None] =!= cut["sector"] ||
  Lookup[fullPool, "family_id", None] =!= cut["family_id"] ||
  Lookup[fullPool, "family_id", None] =!= acceptedPrefix["family_id"] ||
  Lookup[fullPool, "current_basis_id", None] =!= cut["basis_id"] ||
  Lookup[fullPool, "accepted_prefix_id", None] =!= acceptedPrefix["prefix_id"] ||
  Lookup[fullPool, "lower_basis", None] =!= acceptedPrefix["basis"] ||
  Lookup[fullPool, "current_basis", None] =!= cut["basis"] ||
  Lookup[fullPool, "variables", None] =!= variables ||
  Lookup[fullPool, "regulator", None] =!= regulator ||
  !ListQ[Lookup[fullPool, "alphabet", None]] || Lookup[fullPool, "alphabet", {}] === {} ||
  !ListQ[Lookup[fullPool, "candidates", None]] || Lookup[fullPool, "candidates", {}] === {},
  writeFailure["ERROR", "INVALID_FULL_PREFIX_POOL", "full-prefix candidate pool 的协议或身份无效"]
];

If[
  sectorBasis["sector"] =!= task["sector"] || coreCandidates["sector"] =!= task["sector"] ||
  sectorBasis["family_id"] =!= cut["family_id"] || coreCandidates["family_id"] =!= cut["family_id"] ||
  sectorBasis["basis_id"] =!= cut["basis_id"] || coreCandidates["basis_id"] =!= cut["basis_id"] ||
  sectorBasis["basis"] =!= cut["basis"] || coreCandidates["basis"] =!= cut["basis"] ||
  coreCandidates["variables"] =!= variables || coreCandidates["regulator"] =!= regulator,
  writeFailure["ERROR", "IDENTITY_MISMATCH", "sector、family、basis、variable 或 regulator 身份不一致"]
];

coreList = coreCandidates["candidates"];
coreIds = Lookup[coreList, "candidate_id", Missing["candidate_id"]];
poolList = fullPool["candidates"];
poolIds = Lookup[poolList, "candidate_id", Missing["candidate_id"]];
If[
  !And @@ (StringQ /@ coreIds) || DuplicateFreeQ[coreIds] =!= True ||
  !And @@ (StringQ /@ poolIds) || DuplicateFreeQ[poolIds] =!= True ||
  Sort[poolIds] =!= Sort[coreIds],
  writeFailure[
    "ERROR",
    "INVALID_CANDIDATE_IDS",
    "full-prefix candidates 必须为每个 core candidate ID 恰好提供一个 completion"
  ]
];

sourceMatrices = Lookup[fullPool, "source_matrices", None];
If[
  !exactMatrixListQ[sourceMatrices, Length[variables], fullDimension] ||
  !CanonMethodCard`FlatConnectionQ[sourceMatrices, variables],
  writeFailure["ERROR", "INVALID_SOURCE_DE", "source full-prefix connection 无效或非 flat"]
];

lowerRows = 1 ;; lowerDimension;
currentRows = lowerDimension + 1 ;; fullDimension;
If[
  !sameMatricesQ[blockList[sourceMatrices, lowerRows, lowerRows], prefixMatrices] ||
  !And @@ (zeroBlockQ /@ blockList[sourceMatrices, lowerRows, currentRows]) ||
  !sameMatricesQ[blockList[sourceMatrices, currentRows, currentRows], cut["matrices"]],
  writeFailure["ERROR", "SOURCE_BLOCK_MISMATCH", "source DE 不包含声明的冻结 lower prefix 和 current cut core"]
];

screenOptions = Lookup[task["payload"], "screen_options", <||>];
If[!AssociationQ[screenOptions],
  writeFailure["ERROR", "INVALID_OPTIONS", "screen_options 必须是 object"]
];
candidateBudget = Lookup[screenOptions, "candidate_budget", Length[poolList]];
If[!IntegerQ[candidateBudget] || candidateBudget < 1,
  writeFailure["ERROR", "INVALID_OPTIONS", "candidate_budget 必须是正整数"]
];
candidateBudget = Min[candidateBudget, Length[poolList]];

checkFullCandidate[candidate_Association, poolIndex_Integer] := Module[
  {
    candidateId, corePosition, coreCandidate, coreCheck, transformation, declared,
    computed, residuals, fullShape, exactDomain, invertible, blockStructure,
    exactGauge, prefixFrozen, coreMatches, flat, epsilonForm, dlogForm, reasons
  },
  candidateId = Lookup[candidate, "candidate_id", Missing["candidate_id"]];
  corePosition = FirstPosition[coreIds, candidateId, Missing["not-found"]];
  If[MissingQ[corePosition],
    Return[<|"candidate_id" -> candidateId, "pool_index" -> poolIndex, "pass" -> False, "rejection_signature" -> {"missing_core_candidate"}|>]
  ];
  corePosition = First[corePosition];
  coreCandidate = coreList[[corePosition]];
  coreCheck = CanonMethodCard`CheckCoreCandidate[
    coreCandidate, cut["matrices"], variables, regulator, corePosition
  ];
  transformation = Lookup[candidate, "full_transformation", None];
  declared = Lookup[candidate, "transformed_matrices", None];
  fullShape = MatrixQ[transformation] && Dimensions[transformation] === {fullDimension, fullDimension} &&
    ListQ[declared] && Length[declared] === Length[variables] &&
    And @@ (MatrixQ[#] && Dimensions[#] === {fullDimension, fullDimension} & /@ declared);
  exactDomain = TrueQ[fullShape] &&
    And @@ (CanonMethodCard`ExactRationalExpressionQ /@ Flatten[transformation]) &&
    And @@ (CanonMethodCard`ExactRationalExpressionQ /@ Flatten[declared]);
  invertible = TrueQ[exactDomain] && TrueQ[Together[Det[transformation]] =!= 0];
  blockStructure = TrueQ[invertible] &&
    CanonMethodCard`ZeroMatrixQ[Map[Together, transformation[[lowerRows, lowerRows]] - IdentityMatrix[lowerDimension], {2}]] &&
    zeroBlockQ[transformation[[lowerRows, currentRows]]] &&
    CanonMethodCard`ZeroMatrixQ[
      Map[Together, transformation[[currentRows, currentRows]] - Lookup[coreCheck, "transformation", {{0}}], {2}]
    ];
  computed = If[TrueQ[invertible],
    Quiet @ Check[CanonMethodCard`GaugeTransform[sourceMatrices, variables, transformation], $Failed],
    $Failed
  ];
  residuals = If[computed === $Failed || !TrueQ[fullShape], {},
    MapThread[Map[Together, #1 - #2, {2}] &, {computed, declared}]
  ];
  exactGauge = computed =!= $Failed && residuals =!= {} && And @@ (CanonMethodCard`ZeroMatrixQ /@ residuals);
  prefixFrozen = computed =!= $Failed &&
    sameMatricesQ[blockList[computed, lowerRows, lowerRows], prefixMatrices] &&
    And @@ (zeroBlockQ /@ blockList[computed, lowerRows, currentRows]);
  coreMatches = computed =!= $Failed && TrueQ[Lookup[coreCheck, "pass", False]] &&
    sameMatricesQ[blockList[computed, currentRows, currentRows], coreCheck["transformed_matrices"]];
  flat = computed =!= $Failed && CanonMethodCard`FlatConnectionQ[computed, variables];
  epsilonForm = computed =!= $Failed && CanonMethodCard`EpsilonFactorizedQ[computed, regulator];
  dlogForm = computed =!= $Failed && CanonMethodCard`DLogConnectionQ[
    computed, variables, regulator, fullPool["alphabet"]
  ];
  reasons = Pick[
    {
      "core_gate_failed", "full_shape_invalid", "coefficient_domain_invalid",
      "singular_full_transformation", "forbidden_lower_prefix_transform",
      "full_gauge_residual", "lower_prefix_changed", "current_core_mismatch",
      "nonflat_full_connection", "not_epsilon_factorized", "not_declared_dlog"
    },
    {
      !TrueQ[Lookup[coreCheck, "pass", False]], !TrueQ[fullShape], !TrueQ[exactDomain],
      !TrueQ[invertible], !TrueQ[blockStructure], !TrueQ[exactGauge],
      !TrueQ[prefixFrozen], !TrueQ[coreMatches], !TrueQ[flat],
      !TrueQ[epsilonForm], !TrueQ[dlogForm]
    }
  ];
  <|
    "candidate_id" -> candidateId,
    "pool_index" -> poolIndex,
    "core_candidate_index" -> corePosition,
    "pass" -> (reasons === {}),
    "exact_core" -> TrueQ[Lookup[coreCheck, "pass", False]],
    "exact_full_gauge" -> TrueQ[exactGauge],
    "lower_prefix_frozen" -> TrueQ[prefixFrozen && blockStructure],
    "current_core_matches" -> TrueQ[coreMatches],
    "flat_connection" -> TrueQ[flat],
    "epsilon_factorized" -> TrueQ[epsilonForm],
    "dlog_form" -> TrueQ[dlogForm],
    "rejection_signature" -> reasons,
    "full_transformation" -> transformation,
    "transformed_matrices" -> computed
  |>
];

attempts = {};
accepted = Missing["not-found"];
Do[
  attempt = checkFullCandidate[poolList[[poolIndex]], poolIndex];
  AppendTo[attempts, attempt];
  If[TrueQ[Lookup[attempt, "pass", False]], accepted = attempt; Break[]],
  {poolIndex, candidateBudget}
];

publicAttempt[attempt_Association] := KeyDrop[attempt, {"full_transformation", "transformed_matrices"}];

If[MissingQ[accepted],
  poolExhausted = candidateBudget >= Length[poolList];
  writeFailure[
    If[poolExhausted, "FAIL", "INCONCLUSIVE"],
    If[poolExhausted, "CANDIDATE_POOL_EXHAUSTED", "CANDIDATE_BUDGET_EXHAUSTED"],
    If[poolExhausted, "所有声明的 candidate 均未通过 full-prefix tail 筛选", "candidate budget 已用尽，但候选池尚未耗尽"],
    <|
      "candidate_budget" -> candidateBudget,
      "candidate_count" -> Length[poolList],
      "pool_exhausted" -> poolExhausted,
      "repair_eligible" -> poolExhausted,
      "attempts" -> (publicAttempt /@ attempts)
    |>
  ]
];

screened = <|
  "schema" -> "canon-neu/screened-full-prefix-candidate/v1",
  "sector" -> cut["sector"],
  "family_id" -> cut["family_id"],
  "current_basis_id" -> cut["basis_id"],
  "accepted_prefix_id" -> acceptedPrefix["prefix_id"],
  "candidate_id" -> accepted["candidate_id"],
  "core_candidate_index" -> accepted["core_candidate_index"],
  "candidate_budget" -> candidateBudget,
  "variables" -> variables,
  "regulator" -> regulator,
  "alphabet" -> fullPool["alphabet"],
  "convention" -> fullPool["convention"],
  "full_transformation" -> accepted["full_transformation"],
  "transformed_matrices" -> accepted["transformed_matrices"],
  "checks" -> publicAttempt[accepted]
|>;

artifactPath = CanonMethodCard`WriteWLArtifact[screened, outputDir, "screened-candidate.wl"];
If[artifactPath === $Failed,
  writeFailure["ERROR", "OUTPUT_ERROR", "无法写入 screened candidate artifact"]
];
resultPath = CanonMethodCard`WriteResult[
  task,
  outputDir,
  "PASS",
  "TAIL_SCREEN_PASS",
  <|"screened_candidate" -> <|"type" -> "mathematica-expression", "path" -> FileNameTake[artifactPath]|>|>,
  <|
    "method_id" -> "full-prefix-tail-screen",
    "selected_candidate_id" -> accepted["candidate_id"],
    "selected_pool_index" -> accepted["pool_index"],
    "candidate_budget" -> candidateBudget,
    "candidate_count" -> Length[poolList],
    "pool_exhausted" -> False,
    "repair_eligible" -> False,
    "repair_invoked" -> False,
    "attempts" -> (publicAttempt /@ Take[attempts, accepted["pool_index"]])
  |>
];
If[resultPath === $Failed, Print["写入 result.json 失败"]; Quit[1]];
Quit[0];
