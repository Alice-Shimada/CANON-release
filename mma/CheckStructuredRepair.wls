$HistoryLength = 0;

repoRoot = DirectoryName[DirectoryName[ExpandFileName[$InputFileName]]];
Get[FileNameJoin[{repoRoot, "mma", "lib", "MethodCardCore.wl"}]];

args = CanonMethodCard`ScriptArguments[];
If[Length[args] =!= 2, Print["usage: CheckStructuredRepair.wls <input.json> <fresh-output-dir>"]; Quit[2]];
{inputPath, outputDir} = ExpandFileName /@ args;
task = CanonMethodCard`ReadTask[inputPath, "CHECK_STRUCTURED_REPAIR"];
If[FailureQ[task], Print[InputForm[task]]; Quit[2]];

writeResult[status_String, code_String, reason_String, details_: <||>] := (
  CanonMethodCard`WriteResult[
    task, outputDir, status, code, <||>,
    Join[<|"reason" -> reason, "provider_claims_authoritative" -> False|>, details]
  ];
  Quit[If[status === "ERROR", 1, 0]]
);

If[FileExistsQ[outputDir],
  Print["structured-repair checker output directory must be fresh: ", outputDir];
  Quit[2]
];

prepared = CanonMethodCard`LoadArtifact[task, inputPath, "prepared_basis"];
route = CanonMethodCard`LoadArtifact[task, inputPath, "route_decision"];
request = CanonMethodCard`LoadArtifact[task, inputPath, "repair_request"];
candidate = CanonMethodCard`LoadArtifact[task, inputPath, "repair_candidate"];
If[FailureQ[prepared] || FailureQ[route] || FailureQ[request] || FailureQ[candidate],
  writeResult["ERROR", "INVALID_REPAIR_INPUT", "one or more authoritative checker artifacts could not be loaded"]
];

requestCheck = CanonMethodCard`ValidateStructuredRepairInput[prepared, route, request];
If[FailureQ[requestCheck],
  writeResult[
    "ERROR", "INVALID_REPAIR_INPUT",
    Lookup[requestCheck[[2]], "Message", "structured-repair input contract is invalid"],
    <|"field" -> Lookup[requestCheck[[2]], "Field", "repair_request"]|>
  ]
];

(* Authenticate the injected read-only Libra entry by canonical path metadata
   and SHA-256 only.  Never evaluate provider package code in the checker. *)
checkerOptions = Lookup[task["payload"], "checker_options", None];
If[
  !AssociationQ[checkerOptions] ||
    !StringQ[Lookup[checkerOptions, "package_entry", None]] || checkerOptions["package_entry"] === "" ||
    !StringQ[Lookup[checkerOptions, "expected_tool_identity", None]] ||
    !StringQ[Lookup[checkerOptions, "expected_entry_sha256", None]] ||
    !StringMatchQ[checkerOptions["expected_entry_sha256"], RegularExpression["[0-9a-fA-F]{64}"]],
  writeResult["ERROR", "INVALID_OPTIONS", "checker_options must inject an authoritative Libra identity, entry, and SHA-256"]
];
authoritativeEntry = If[
  StringStartsQ[checkerOptions["package_entry"], $PathnameSeparator],
  ExpandFileName[checkerOptions["package_entry"]],
  ExpandFileName[FileNameJoin[{DirectoryName[inputPath], checkerOptions["package_entry"]}]]
];
If[FileType[authoritativeEntry] =!= File,
  writeResult["ERROR", "TOOL_UNAVAILABLE", "authoritative checker Libra entry is not a file"]
];
authoritativeEntry = Lookup[
  Association[FileInformation[authoritativeEntry]], "AbsoluteFileName", authoritativeEntry
];
observedEntryHash = Quiet @ Check[FileHash[authoritativeEntry, "SHA256", "HexString"], $Failed];
If[
  !StringQ[observedEntryHash] ||
    ToLowerCase[observedEntryHash] =!= ToLowerCase[checkerOptions["expected_entry_sha256"]],
  writeResult["ERROR", "TOOL_IDENTITY_MISMATCH", "authoritative Libra entry hash does not match checker options"]
];
(* Checker-owned exact implementation.  This deliberately does not call the
   provider publication gate or a shared structured scientific helper. *)
zeroMatrixQ[expr_] := MatrixQ[expr] &&
  And @@ (TrueQ[Together[#] === 0] & /@ Flatten[expr]);
sameMatrixListsQ[left_List, right_List] := Length[left] === Length[right] &&
  And @@ MapThread[zeroMatrixQ[Map[Together, #1 - #2, {2}]] &, {left, right}];
matrixBlocks[matrices_List, rows_, columns_] := (#[[rows, columns]] & /@ matrices);
zeroMatrixListQ[matrices_List] := And @@ (zeroMatrixQ /@ matrices);
declaredDomainQ[expr_, symbols_List] :=
  CanonMethodCard`ExactRationalExpressionQ[expr] && SubsetQ[
    DeleteDuplicates[symbols],
    DeleteDuplicates[Cases[Unevaluated[expr], _Symbol, Infinity]]
  ];
gaugeTransformLocal[matrices_List, variables_List, transformation_?MatrixQ] :=
  MapThread[
    Map[Together, Inverse[transformation].(#1.transformation - D[transformation, #2]), {2}] &,
    {matrices, variables}
  ];
epsilonFactorizedLocalQ[matrices_List, regulator_Symbol] :=
  And @@ (FreeQ[Together[#/regulator], regulator] & /@ Flatten[matrices]);
dLogExpressionLocalQ[expr_, variable_Symbol, derivatives_List] := Module[
  {coefficients, residual, numerator, equations, instance},
  coefficients = Table[Unique["structuredDLogCoefficient$"], {Length[derivatives]}];
  residual = Together[expr - coefficients.derivatives];
  numerator = Expand[Numerator[residual]];
  If[!PolynomialQ[numerator, variable], Return[False]];
  equations = Thread[CoefficientList[numerator, variable] == 0];
  instance = Quiet @ Check[FindInstance[equations, coefficients, Rationals, 1], {}];
  If[instance === {}, Return[False]];
  TrueQ[Together[residual /. First[instance]] === 0]
];
dLogConnectionLocalQ[matrices_List, variables_List, regulator_Symbol, alphabet_List] := Module[
  {variable, derivatives},
  variable = First[variables];
  derivatives = Quiet @ Check[Together[D[#, variable]/#] & /@ alphabet, $Failed];
  If[derivatives === $Failed, Return[False]];
  And @@ (dLogExpressionLocalQ[Together[#/regulator], variable, derivatives] & /@ Flatten[matrices])
];

variables = request["variables"];
regulator = request["regulator"];
parameters = request["parameters"];
allowedSymbols = Join[variables, {regulator}, parameters];
basis = request["basis"];
original = request["original_matrices"];
frozen = request["frozen_prefix"];
target = request["localized_target"];
dimension = Length[basis];
prefixDimension = frozen["dimension"];
prefixRows = 1 ;; prefixDimension;
tailRows = prefixDimension + 1 ;; dimension;
method = Lookup[candidate, "method", None];
expectedStages = {
  "NewDSystem", "Fuchsify", "Transform", "FactorOut", "Transform",
  "OverallTransformation", "EFormQ"
};
provenanceQ = AssociationQ[method] &&
  Lookup[method, "id", None] === "libra-structured-repair-single-variable" &&
  Lookup[method, "tool", None] === "Libra" &&
  Lookup[method, "tool_identity", None] === checkerOptions["expected_tool_identity"] &&
  Lookup[method, "package_source", None] === "method_options.package_entry" &&
  FileType[Lookup[method, "entry", ""]] === File &&
  Lookup[
    Association[FileInformation[Lookup[method, "entry", ""]]],
    "AbsoluteFileName", ExpandFileName[Lookup[method, "entry", ""]]
  ] === authoritativeEntry &&
  ToLowerCase[Lookup[method, "entry_sha256", ""]] === ToLowerCase[observedEntryHash] &&
  Lookup[method, "wolfram_version", None] === $Version &&
  Lookup[method, "system_id", None] === $SystemID &&
  Lookup[Lookup[method, "options", <||>], "use_fermatica", None] === False &&
  Lookup[Lookup[method, "options", <||>], "factor_out_mu", None] === 1/2 &&
  Lookup[method, "stages", None] === expectedStages;
identityMatch =
  Lookup[candidate, "schema", None] === "canon-neu/libra-structured-repair-candidate/v1" &&
    Lookup[candidate, "preparation_id", None] === request["preparation_id"] &&
    Lookup[candidate, "family_id", None] === request["family_id"] &&
    Lookup[candidate, "basis_id", None] === request["basis_id"] &&
    Lookup[candidate, "selected_candidate_id", None] === request["selected_candidate_id"] &&
    Lookup[candidate, "coefficient_domain", None] === request["coefficient_domain"] &&
    Lookup[candidate, "basis", None] === basis &&
    Lookup[candidate, "variables", None] === variables &&
    Lookup[candidate, "regulator", None] === regulator &&
    Lookup[candidate, "parameters", None] === parameters &&
    Lookup[candidate, "repair_scope", None] === request["repair_scope"] &&
    Lookup[candidate, "convention", None] === request["convention"] &&
    Lookup[candidate, "original_matrices", None] === original &&
    Lookup[candidate, "frozen_prefix", None] === frozen &&
    Lookup[candidate, "localized_target", None] === target &&
    Lookup[candidate, "alphabet", None] === request["alphabet"];
providerStatus = Lookup[candidate, "provider_status", None] ===
  "PROVISIONAL/CANDIDATE_TRANSFORMATION";
transformation = Lookup[candidate, "transformation", None];
declared = Lookup[candidate, "transformed_matrices", None];
shape = MatrixQ[transformation] && Dimensions[transformation] === {dimension, dimension} &&
  ListQ[declared] && Length[declared] === Length[variables] &&
  And @@ (MatrixQ[#] && Dimensions[#] === {dimension, dimension} & /@ declared);
exactDomain = TrueQ[shape] &&
  And @@ (declaredDomainQ[#, allowedSymbols] & /@ Flatten[transformation]) &&
  And @@ (declaredDomainQ[#, allowedSymbols] & /@ Flatten[declared]);
invertible = TrueQ[exactDomain] && TrueQ[Together[Det[transformation]] =!= 0];
prefixIdentity = TrueQ[invertible] && zeroMatrixQ[
  Map[Together, transformation[[prefixRows, prefixRows]] - IdentityMatrix[prefixDimension], {2}]
];
forbiddenMixing = TrueQ[invertible] &&
  zeroMatrixQ[transformation[[prefixRows, tailRows]]] &&
  zeroMatrixQ[transformation[[tailRows, prefixRows]]];
computed = If[
  TrueQ[invertible],
  Quiet @ Check[gaugeTransformLocal[original, variables, transformation], $Failed],
  $Failed
];
exactGauge = computed =!= $Failed && TrueQ[shape] && sameMatrixListsQ[computed, declared];
(* The validated v1 contract has one variable, so curvature is identically zero. *)
flat = computed =!= $Failed;
epsilonForm = computed =!= $Failed && epsilonFactorizedLocalQ[computed, regulator];
noResidualRegulator = epsilonForm;
dlog = epsilonForm && dLogConnectionLocalQ[
  computed, variables, regulator, request["alphabet"]
];
entry = target["full_entry"];
defectPresent = TrueQ[Together[First[original][[Sequence @@ entry]] /. regulator -> 0] =!= 0];
defectRemoved = computed =!= $Failed && TrueQ[
  Together[First[computed][[Sequence @@ entry]] /. regulator -> 0] === 0
];
prefixNonRegression = computed =!= $Failed && sameMatrixListsQ[
  matrixBlocks[computed, prefixRows, prefixRows], frozen["accepted_matrices"]
];
prefixFromTailNonRegression = computed =!= $Failed &&
  zeroMatrixListQ[matrixBlocks[computed, prefixRows, tailRows]];
tailFromPrefixNonRegression = computed =!= $Failed &&
  zeroMatrixListQ[matrixBlocks[computed, tailRows, prefixRows]];
reasons = Pick[
  {
    "identity_or_order_mismatch", "forged_provider_status", "libra_provenance_mismatch",
    "candidate_shape_invalid", "coefficient_domain_invalid", "singular_transformation",
    "frozen_prefix_modified", "forbidden_prefix_mixing", "wrong_gauge_residual",
    "nonflat_transformed_system", "not_epsilon_factorized", "residual_regulator_dependence",
    "outside_declared_dlog_alphabet", "declared_target_not_present", "unresolved_target_defect",
    "accepted_prefix_regression", "accepted_prefix_from_tail_regression",
    "accepted_tail_from_prefix_regression"
  },
  {
    !TrueQ[identityMatch], !TrueQ[providerStatus], !TrueQ[provenanceQ], !TrueQ[shape],
    !TrueQ[exactDomain], !TrueQ[invertible], !TrueQ[prefixIdentity], !TrueQ[forbiddenMixing],
    !TrueQ[exactGauge], !TrueQ[flat], !TrueQ[epsilonForm], !TrueQ[noResidualRegulator],
    !TrueQ[dlog], !TrueQ[defectPresent], !TrueQ[defectRemoved], !TrueQ[prefixNonRegression],
    !TrueQ[prefixFromTailNonRegression], !TrueQ[tailFromPrefixNonRegression]
  }
];
check = <|
  "pass" -> (reasons === {}),
  "reasons" -> reasons,
  "identity_and_order" -> TrueQ[identityMatch],
  "provider_status_provisional" -> TrueQ[providerStatus],
  "authenticated_libra_provenance" -> TrueQ[provenanceQ],
  "invertible" -> TrueQ[invertible],
  "frozen_prefix_identity" -> TrueQ[prefixIdentity],
  "forbidden_mixing_zero" -> TrueQ[forbiddenMixing],
  "exact_full_gauge" -> TrueQ[exactGauge],
  "flat_connection" -> TrueQ[flat],
  "epsilon_factorized" -> TrueQ[epsilonForm],
  "no_residual_regulator_dependence" -> TrueQ[noResidualRegulator],
  "declared_dlog_alphabet" -> TrueQ[dlog],
  "target_defect_present_before" -> TrueQ[defectPresent],
  "target_defect_eliminated" -> TrueQ[defectRemoved],
  "accepted_blocks_nonregressed" -> TrueQ[
    prefixNonRegression && prefixFromTailNonRegression && tailFromPrefixNonRegression
  ],
  "computed_matrices" -> computed
|>;

If[!TrueQ[check["pass"]],
  writeResult[
    "FAIL", "STRUCTURED_REPAIR_REJECTED",
    "candidate failed checker-owned exact structured-repair verification",
    <|"rejection_signature" -> check["reasons"],
      "checks" -> KeyDrop[check, {"computed_matrices"}]|>
  ]
];

authenticatedProvenance = <|
  "tool" -> "Libra",
  "tool_identity" -> checkerOptions["expected_tool_identity"],
  "entry" -> authoritativeEntry,
  "entry_sha256" -> observedEntryHash,
  "provider_package_source" -> method["package_source"],
  "provider_wolfram_version" -> method["wolfram_version"],
  "provider_system_id" -> method["system_id"],
  "options" -> method["options"],
  "stages" -> method["stages"],
  "checker_wolfram_version" -> $Version,
  "checker_system_id" -> $SystemID,
  "authenticated" -> True
|>;
verified = <|
  "schema" -> "canon-neu/verified-structured-repair/v1",
  "preparation_id" -> request["preparation_id"],
  "family_id" -> request["family_id"],
  "basis_id" -> request["basis_id"],
  "selected_candidate_id" -> request["selected_candidate_id"],
  "coefficient_domain" -> request["coefficient_domain"],
  "basis" -> request["basis"],
  "variables" -> variables,
  "regulator" -> regulator,
  "parameters" -> parameters,
  "repair_scope" -> request["repair_scope"],
  "convention" -> request["convention"],
  "original_matrices" -> original,
  "transformation" -> transformation,
  "transformed_matrices" -> computed,
  "frozen_prefix" -> frozen,
  "localized_target" -> target,
  "alphabet" -> request["alphabet"],
  "authenticated_provenance" -> authenticatedProvenance,
  "checks" -> KeyDrop[check, {"computed_matrices"}],
  "provider_claims_authoritative" -> False
|>;
artifactPath = CanonMethodCard`WriteWLArtifact[
  verified, outputDir, "verified-structured-repair.wl"
];
If[artifactPath === $Failed,
  writeResult["ERROR", "OUTPUT_ERROR", "could not write independently verified repair artifact"]
];
resultPath = CanonMethodCard`WriteResult[
  task, outputDir, "PASS", "VERIFIED_STRUCTURED_REPAIR",
  <|
    "verified_structured_repair" -> <|
      "type" -> "mathematica-expression",
      "path" -> FileNameTake[artifactPath]
    |>
  |>,
  Join[
    <|
      "provider_claims_authoritative" -> False,
      "preparation_id" -> request["preparation_id"],
      "selected_candidate_id" -> request["selected_candidate_id"],
      "authenticated_libra_entry_sha256" -> observedEntryHash
    |>,
    KeyDrop[check, {"pass", "reasons", "computed_matrices"}]
  ]
];
If[resultPath === $Failed, Print["failed to write result.json"]; Quit[1]];
Quit[0];
