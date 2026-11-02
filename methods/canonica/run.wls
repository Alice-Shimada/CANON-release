$HistoryLength = 0;

repoRoot = DirectoryName[DirectoryName[DirectoryName[ExpandFileName[$InputFileName]]]];
Get[FileNameJoin[{repoRoot, "mma", "lib", "MethodCardCore.wl"}]];
Get[FileNameJoin[{repoRoot, "methods", "canonica", "Control.wl"}]];

args = CanonMethodCard`ScriptArguments[];
If[Length[args] =!= 2, Print["Usage: run.wls <input.json> <output_dir>"]; Quit[2]];
{inputPath, outputDir} = ExpandFileName /@ args;
task = CanonMethodCard`ReadTask[inputPath, "SEARCH_CORE"];
If[FailureQ[task], Print[InputForm[task]]; Quit[2]];
If[AnyTrue[{"result.json", "canonica-messages.log"},
    FileExistsQ[FileNameJoin[{outputDir, #}]] &],
  Print["OUTPUT_ERROR: output directory already contains a result or CANONICA message log."];
  Quit[1]];
ansatzOptions = <||>; controlOptions = <||>; attempts = {}; diagnosticSummary = <||>;
validationDetails = <||>; toolMetadata = <||>; methodId = "canonica-recursive";
messageStream = None; diagnosticArtifacts = <||>;
writeDiagnostics[] := Module[{path},
  If[attempts === {}, Return[Null]];
  path = CanonMethodCard`WriteWLArtifact[<|"schema" -> "canon-neu/canonica-diagnostics/v1",
    "task_id" -> task["task_id"], "method_id" -> methodId, "attempts" -> attempts|>,
    outputDir, "diagnostics.wl"];
  If[StringQ[path], diagnosticArtifacts["method_diagnostics"] =
    <|"type" -> "mathematica-expression", "path" -> FileNameTake[path]|>];
];
closeMessages[] := If[Head[messageStream] === OutputStream, Close[messageStream]; messageStream = None];
recordAttempt[captured_Association] := (
  AppendTo[attempts, captured["diagnostics"]]; diagnosticSummary = captured["diagnostics"];
  If[TrueQ[Lookup[diagnosticSummary, "aborted", False]],
    cleanupKernels[];
    writeFailure["ERROR", "EXECUTION_INTERRUPTED", "CANONICA execution was interrupted."]];
  captured["result"]
);
markMalformedAttempt[block_] := If[Lookup[diagnosticSummary, "failed_stage", Null] === Null,
  diagnosticSummary["failed_stage"] = diagnosticSummary["requested_stage"];
  diagnosticSummary["failed_block"] = block;
  diagnosticSummary["diagnostic_classes"] = Append[diagnosticSummary["diagnostic_classes"], "invalid_provider_result"];
  attempts[[-1]] = diagnosticSummary
];

writeFailure[status_String, code_String, reason_String] := (
  closeMessages[]; writeDiagnostics[];
  CanonMethodCard`WriteProviderResult[
    task, outputDir, status, code, diagnosticArtifacts,
    Join[<|"method_id" -> methodId, "reason" -> reason,
      "ansatz_options" -> ansatzOptions, "control_options" -> controlOptions,
      "attempts" -> attempts|>, diagnosticSummary, validationDetails, toolMetadata]
  ];
  Quit[If[status === "ERROR", 1, 0]]
);

methodOptions = Lookup[task["payload"], "method_options", <||>];
degreeKeys = {"t_delta_numerator_degree", "t_delta_denominator_degree",
  "d_delta_numerator_degree"};
If[!AssociationQ[methodOptions],
  writeFailure["ERROR", "INVALID_OPTIONS", "method_options must be an object"]];
If[Complement[Keys[methodOptions], Join[degreeKeys, {"package_entry", "max_wall_seconds", "max_ansatz_terms"}]] =!= {},
  writeFailure["ERROR", "INVALID_OPTIONS", "method_options contains unknown options"]];
ansatzOptions = AssociationThread[degreeKeys, Lookup[methodOptions, degreeKeys, 0]];
If[!AllTrue[Values[ansatzOptions], IntegerQ[#] && # >= 0 &],
  writeFailure["ERROR", "INVALID_OPTIONS", "ansatz degree increments must be nonnegative integers"]];
controlOptions = <|"max_wall_seconds" -> Lookup[methodOptions, "max_wall_seconds", 60],
  "max_ansatz_terms" -> Lookup[methodOptions, "max_ansatz_terms", 256]|>;
If[!TrueQ[NumericQ[controlOptions["max_wall_seconds"]] && controlOptions["max_wall_seconds"] > 0] ||
    !IntegerQ[controlOptions["max_ansatz_terms"]] || controlOptions["max_ansatz_terms"] <= 0,
  writeFailure["ERROR", "INVALID_OPTIONS", "max_wall_seconds must be positive and max_ansatz_terms a positive integer"]];
customAnsatzQ = KeyExistsQ[task["payload"], "t_ansatz"];
If[customAnsatzQ, methodId = "canonica-directed-t"];

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
toolMetadata = <|"tool" -> "CANONICA", "package_source" -> package["source"],
  "entry" -> entry, "entry_sha256" -> entryHash, "wolfram_version" -> $Version,
  "system_id" -> $SystemID|>;
requiredSymbols = {
  "CANONICA`RecursivelyTransformSectors",
  "CANONICA`ExtractIrreducibles",
  "CANONICA`CheckEpsForm",
  "CANONICA`SectorBoundariesFromDE"
};
If[customAnsatzQ, requiredSymbols = Join[requiredSymbols,
  {"CANONICA`TransformNextDiagonalBlock", "CANONICA`TransformOffDiagonalBlock", "CANONICA`TransformDlogToEpsForm"}]];
loadSucceeded = TrueQ[Check[(Get[entry]; True), False]];
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

variables = cut["variables"];
regulator = cut["regulator"];
matrices = cut["matrices"];
toolRegulator = CANONICA`eps;
aFull = Map[Together, matrices /. regulator -> toolRegulator, {3}];

boundaries = Lookup[cut, "sector_boundaries", Automatic];
inferredBoundaries = boundaries === Automatic;
If[inferredBoundaries,
  boundaries = Quiet[CANONICA`SectorBoundariesFromDE[aFull]]
];
validBoundariesQ[value_] := ListQ[value] && value =!= {} &&
  AllTrue[value, MatchQ[#, {_Integer, _Integer}] && 1 <= #[[1]] <= #[[2]] <= Length[cut["basis"]] &] &&
  Flatten[Range @@@ value] === Range[Length[cut["basis"]]];
If[!TrueQ[validBoundariesQ[boundaries]],
  If[inferredBoundaries,
    writeFailure["INCONCLUSIVE", "METHOD_EXHAUSTED", "CANONICA could not determine valid sector boundaries"],
    writeFailure["ERROR", "INVALID_DIFFERENTIAL_SYSTEM", "sector_boundaries must partition the ordered cut basis into contiguous row ranges"]]
];
If[!AllTrue[Most[boundaries], Function[bounds, And @@
    (CanonMethodCard`ZeroMatrixQ /@
      matrices[[All, bounds[[1]] ;; bounds[[2]], bounds[[2]] + 1 ;; Length[cut["basis"]]]])]],
  If[inferredBoundaries,
    writeFailure["INCONCLUSIVE", "METHOD_EXHAUSTED", "CANONICA could not determine block-triangular sector boundaries"],
    writeFailure["ERROR", "INVALID_DIFFERENTIAL_SYSTEM", "sector_boundaries do not respect the cut's block-triangular ordering"]]
];

finiteAnsatz = <||>; ansatzProvenance = <||>; targetBlock = Null;
If[customAnsatzQ,
  (* Read scope only to select a declared block; the shared validator binds the
     complete identity, variables, scope and byte hash before any solver call. *)
  descriptor = task["payload", "t_ansatz"];
  If[!AssociationQ[descriptor] || Lookup[descriptor, "type", None] =!= "mathematica-expression" ||
      !StringQ[Lookup[descriptor, "path", None]] || !StringQ[Lookup[descriptor, "sha256", None]],
    validationDetails = <|"field" -> "t_ansatz"|>;
    writeFailure["ERROR", "INVALID_ANSATZ", "T ansatz requires a path, type and SHA-256 descriptor"]];
  directedPath = CanonMethodCard`ResolveInputPath[inputPath, descriptor["path"]];
  directedHash = Quiet @ Check[FileHash[directedPath, "SHA256", "HexString"], $Failed];
  If[!StringQ[directedHash] || ToLowerCase[descriptor["sha256"]] =!= ToLowerCase[directedHash],
    validationDetails = <|"field" -> "t_ansatz.sha256"|>;
    writeFailure["ERROR", "INVALID_ANSATZ", "T ansatz byte hash differs from its descriptor"]];
  ansatzArtifact = CanonMethodCard`LoadArtifact[task, inputPath, "t_ansatz"];
  If[FailureQ[ansatzArtifact], writeFailure["ERROR", "INVALID_ANSATZ", "Cannot read the finite T ansatz artifact"]];
  targetBlock = Lookup[Lookup[ansatzArtifact, "scope", <||>], "block_index", None];
  If[!IntegerQ[targetBlock] || !Between[targetBlock, {1, Length[boundaries]}],
    validationDetails = <|"field" -> "scope.block_index"|>;
    writeFailure["ERROR", "INVALID_ANSATZ", "T ansatz block_index is outside the ordered cut"]];
  finiteAnsatz = CanonCANONICAControl`LoadFiniteAnsatz[task, inputPath, "t_ansatz",
    <|"kind" -> "T", "identity" -> <|"sector" -> cut["sector"],
      "family_id" -> cut["family_id"], "basis_id" -> cut["basis_id"],
      "source_basis" -> cut["basis"], "regulator" -> regulator,
      "source_de_sha256" -> FileHash[CanonMethodCard`ResolveInputPath[inputPath,
        task["payload", "sector_cut_de", "path"]], "SHA256", "HexString"]|>,
      "scope" -> <|"block_index" -> targetBlock, "block_bounds" -> boundaries[[targetBlock]]|>,
      "variables" -> variables|>, controlOptions["max_ansatz_terms"]];
  If[FailureQ[finiteAnsatz], validationDetails = finiteAnsatz[[2]];
    writeFailure["ERROR", "INVALID_ANSATZ", finiteAnsatz[[2]]["reason"]]];
  ansatzProvenance = KeyTake[finiteAnsatz["provenance"], {"path", "sha256", "kind", "scope", "term_count", "max_terms"}];
  ansatzProvenance["source_de_sha256"] = finiteAnsatz["provenance", "identity", "source_de_sha256"];
];

If[!DirectoryQ[outputDir], CreateDirectory[outputDir, CreateIntermediateDirectories -> True]];
messageStream = OpenWrite[FileNameJoin[{outputDir, "canonica-messages.log"}]];
diagnosticArtifacts["method_messages"] = <|"type" -> "text", "path" -> "canonica-messages.log"|>;
(* The wrapper budget is shared by every stage of this one finite attempt. *)
startedAt = AbsoluteTime[];
remainingSeconds[] := Max[0, controlOptions["max_wall_seconds"] - (AbsoluteTime[] - startedAt)];
initialKernels = Kernels[];
cleanupKernels[] := Module[{created = Complement[Kernels[], initialKernels]},
  If[created =!= {}, CloseKernels[created]]];
validProviderPairQ[pair_, n_Integer] := ListQ[pair] && Length[pair] >= 2 &&
  MatrixQ[pair[[1]]] && Dimensions[pair[[1]]] === {n, n} &&
  Dimensions[pair[[2]]] === {Length[variables], n, n};

If[customAnsatzQ,
  result = {{}, {{}}};
  Do[
    attempted = Join[<|"mode" -> If[block === targetBlock, "explicit-finite-T", "package-default"],
      "options" -> ansatzOptions|>, If[block === targetBlock, ansatzProvenance, <||>]];
    result = recordAttempt @ Block[{$Messages = Append[$Messages, messageStream]},
      CanonCANONICAControl`CaptureStage[
        CANONICA`TransformNextDiagonalBlock[aFull, variables, boundaries, result[[1]], result[[2]],
          If[block === targetBlock, finiteAnsatz["terms"], {}],
          CANONICA`VerbosityLevel -> 1,
          CANONICA`TDeltaNumeratorDegree -> ansatzOptions["t_delta_numerator_degree"],
          CANONICA`TDeltaDenominatorDegree -> ansatzOptions["t_delta_denominator_degree"]],
        "diagonal_block", block, remainingSeconds[], attempted]];
    If[!validProviderPairQ[result, boundaries[[block, 2]]],
      markMalformedAttempt[block];
      cleanupKernels[];
      writeFailure["INCONCLUSIVE", "METHOD_EXHAUSTED", "CANONICA produced no complete transformation for the directed block attempt"]];
    result = recordAttempt @ Block[{$Messages = Append[$Messages, messageStream]},
      CanonCANONICAControl`CaptureStage[
        CANONICA`TransformOffDiagonalBlock[variables, boundaries, result[[1]], result[[2]],
          CANONICA`VerbosityLevel -> 1,
          CANONICA`DDeltaNumeratorDegree -> ansatzOptions["d_delta_numerator_degree"]],
        "off_diagonal_block", block, remainingSeconds[], <|"mode" -> "package-default-D", "options" -> ansatzOptions|>]];
    If[!validProviderPairQ[result, boundaries[[block, 2]]], markMalformedAttempt[block]; cleanupKernels[];
      writeFailure["INCONCLUSIVE", "METHOD_EXHAUSTED", "CANONICA exhausted the cut's internal off-diagonal stage"]];
    result = recordAttempt @ Block[{$Messages = Append[$Messages, messageStream]},
      CanonCANONICAControl`CaptureStage[
        CANONICA`TransformDlogToEpsForm[variables, boundaries, result[[1]], result[[2]], CANONICA`VerbosityLevel -> 1],
        "epsilon_normalization", block, remainingSeconds[], <|"mode" -> "package-epsilon-normalization"|>]];
    If[!validProviderPairQ[result, boundaries[[block, 2]]], markMalformedAttempt[block]; cleanupKernels[];
      writeFailure["INCONCLUSIVE", "METHOD_EXHAUSTED", "CANONICA exhausted the cut's internal epsilon-normalization stage"]],
    {block, Length[boundaries]}],
  result = recordAttempt @ Block[{$Messages = Append[$Messages, messageStream]},
    CanonCANONICAControl`CaptureStage[
      CANONICA`RecursivelyTransformSectors[aFull, variables, boundaries, {1, Length[boundaries]},
        CANONICA`VerbosityLevel -> 1,
        CANONICA`TDeltaNumeratorDegree -> ansatzOptions["t_delta_numerator_degree"],
        CANONICA`TDeltaDenominatorDegree -> ansatzOptions["t_delta_denominator_degree"],
        CANONICA`DDeltaNumeratorDegree -> ansatzOptions["d_delta_numerator_degree"]],
      "recursively_transform_sectors", Null, remainingSeconds[],
      <|"mode" -> "package-default", "options" -> ansatzOptions|>]];
  If[!validProviderPairQ[result, Length[cut["basis"]]],
    markMalformedAttempt[Null];
    (* Stock failures return the previously completed gauge, allowing exact
       localization without rerunning an unchanged scientific method. *)
    If[MatchQ[result, {False, {_List, _List}, ___}],
      completedDimension = Length[result[[2, 1]]];
      failedBlock = SelectFirst[Range[Length[boundaries]], boundaries[[#, 2]] > completedDimension &, Null];
      diagnosticSummary["failed_block"] = failedBlock;
      attempts[[-1]] = diagnosticSummary];
    cleanupKernels[];
    writeFailure["INCONCLUSIVE", "METHOD_EXHAUSTED", "CANONICA produced no complete transformation"]]
];
cleanupKernels[];
transformation = result[[1]];
transformedRaw = result[[2]];
sourceGaugeQ = recordAttempt @ CanonCANONICAControl`CaptureStage[
  And @@ (CanonMethodCard`DeclaredCoefficientDomainQ[#, Join[variables, {toolRegulator}]] & /@
    Flatten[{transformation, transformedRaw}]) && Together[Det[transformation]] =!= 0 &&
    And @@ Table[CanonMethodCard`ZeroMatrixQ[aFull[[direction]].transformation -
      D[transformation, variables[[direction]]] - transformation.transformedRaw[[direction]]],
      {direction, Length[variables]}],
  "source_gauge_check", Null, remainingSeconds[], <|"mode" -> "exact_source_gauge"|>];
If[!TrueQ[sourceGaugeQ],
  writeFailure["INCONCLUSIVE", "METHOD_EXHAUSTED", "The provider transformation failed the complete exact source-gauge check"]];
alphabet = recordAttempt @ Block[{$Messages = Append[$Messages, messageStream]},
  CanonCANONICAControl`CaptureStage[CANONICA`ExtractIrreducibles[aFull],
    "extract_alphabet", Null, remainingSeconds[], <|"mode" -> "package-alphabet"|>]];
If[!ListQ[alphabet], writeFailure["INCONCLUSIVE", "METHOD_EXHAUSTED", "CANONICA could not extract the provider alphabet within the attempt budget"]];
providerEFormQ = recordAttempt @ Block[{$Messages = Append[$Messages, messageStream]},
  CanonCANONICAControl`CaptureStage[CANONICA`CheckEpsForm[transformedRaw, variables, alphabet],
    "provider_epsilon_check", Null, remainingSeconds[], <|"mode" -> "provider_epsilon_check"|>]];
If[!TrueQ[providerEFormQ],
  writeFailure["INCONCLUSIVE", "METHOD_EXHAUSTED", "The CANONICA transformation failed the provider epsilon-form check"]];
fullBasisRows = recordAttempt @ CanonCANONICAControl`CaptureStage[
  Map[Together, Inverse[transformation], {2}],
  "full_basis_rows", Null, remainingSeconds[], <|"mode" -> "exact_inverse"|>];
If[!MatrixQ[fullBasisRows] || Dimensions[fullBasisRows] =!= {Length[cut["basis"]], Length[cut["basis"]]},
  writeFailure["INCONCLUSIVE", "METHOD_EXHAUSTED", "Cannot reconstruct complete basis rows within the attempt budget"]];
transformation = transformation /. toolRegulator -> regulator;
fullBasisRows = fullBasisRows /. toolRegulator -> regulator;
transformedMatrices = transformedRaw /. toolRegulator -> regulator;
alphabet = alphabet /. toolRegulator -> regulator;
closeMessages[]; writeDiagnostics[];

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
    "id" -> methodId,
    "tool" -> "CANONICA",
    "tool_identity" -> "CANONICA-compatible",
    "package_source" -> package["source"],
    "entry" -> entry,
    "entry_sha256" -> entryHash,
    "ansatz_options" -> ansatzOptions,
    "control_options" -> controlOptions,
    "finite_ansatz" -> ansatzProvenance,
    "finite_ansatz_identity" -> If[customAnsatzQ, finiteAnsatz["provenance", "identity"], <||>],
    "attempts" -> attempts,
    "wolfram_version" -> $Version,
    "system_id" -> $SystemID
  |>,
  "candidate_group_pool" -> <|
    "declared" -> 1, "eligible" -> 1, "remaining" -> 0,
    "unconsumed_candidates" -> 0, "pool_exhausted" -> True|>,
  "candidates" -> {
    <|
      "candidate_id" -> methodId <> ":1",
      "member_candidate_ids" -> Table[methodId <> ":row:" <> ToString[i],
        {i, Length[cut["basis"]]}],
      "full_new_basis_rows" -> fullBasisRows,
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
  Join[diagnosticArtifacts, <|"core_candidates" -> <|"type" -> "mathematica-expression", "path" -> FileNameTake[artifactPath]|>|>],
  <|
    "method_id" -> methodId,
    "tool" -> "CANONICA",
    "provider_check_eps_form" -> providerEFormQ,
    "ansatz_options" -> ansatzOptions,
    "control_options" -> controlOptions,
    "finite_ansatz" -> ansatzProvenance,
    "attempts" -> attempts,
    "candidate_count" -> 1
  |>
];
If[resultPath === $Failed, Print["Failed to write result.json"]; Quit[1]];
Quit[0];
