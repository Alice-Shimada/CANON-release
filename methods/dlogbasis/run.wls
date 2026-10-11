(*
  step    = "PROPOSE_INTEGRAL_CANDIDATES"
  success = "PROVISIONAL/INTEGRAL_CANDIDATES"
*)
$HistoryLength = 0;

repoRoot = DirectoryName[DirectoryName[DirectoryName[ExpandFileName[$InputFileName]]]];
Get[FileNameJoin[{repoRoot, "mma", "lib", "MethodCardCore.wl"}]];

args = CanonMethodCard`ScriptArguments[];
If[Length[args] =!= 2, Print["usage: run.wls <input.json> <output_dir>"]; Quit[2]];
{inputPath, outputDir} = ExpandFileName /@ args;
task = CanonMethodCard`ReadTask[inputPath, "PROPOSE_INTEGRAL_CANDIDATES"];
fail[result_Failure] := (
  CanonMethodCard`WriteProviderResult[task, outputDir, "ERROR", result[[1]], <||>,
    <|"reason" -> result[[2, "Message"]]|>]; Quit[0]
);
(* Operational evidence is separate from result.json. Close each append so a
   cancelled provider leaves the last entered/returned boundary on disk. *)
If[!DirectoryQ[outputDir], CreateDirectory[outputDir, CreateIntermediateDirectories -> True]];
progressPath = FileNameJoin[{outputDir, "dlogbasis-progress.jsonl"}];
invocationId = CreateUUID[];
startedAt = AbsoluteTime[];
recordPhase[phase_, event_, details_ : <||>] := Module[{stream},
  stream = OpenAppend[progressPath];
  WriteString[stream, ExportString[<|
    "schema" -> "canon-neu/dlogbasis-progress/v1",
    "invocation_id" -> invocationId, "process_id" -> $ProcessID,
    "elapsed_seconds" -> N[AbsoluteTime[] - startedAt],
    "phase" -> phase, "event" -> event, "details" -> details
  |>, "RawJSON", "Compact" -> True], "\n"];
  Close[stream];
];
recordPhase["request", "read", <|
  "input_path" -> inputPath, "input_sha256" -> FileHash[inputPath, "SHA256", "HexString"],
  "request" -> task, "runtime" -> $Version <> "; " <> $SystemID
|>];
recordPhase["prepared_family_load", "entered"];
prepared = CanonMethodCard`LoadArtifact[task, inputPath, "prepared_family"];
If[FailureQ[prepared], fail[prepared]];
recordPhase["prepared_family_load", "returned"];
preparedPath = CanonMethodCard`ResolveInputPath[inputPath, task["payload", "prepared_family", "path"]];
familyDataPath = CanonMethodCard`ResolveArtifactPath[preparedPath, Lookup[prepared, "family_data", None]];
If[FailureQ[familyDataPath], fail[familyDataPath]];
payload = task["payload"];
methodOptions = payload["method_options"];
package = CanonMethodCard`ResolveMethodPackage[task, inputPath, "DlogBasis`"];
entry = package["entry"];
entryHash = FileHash[entry, "SHA256", "HexString"];
packageRevision = Lookup[methodOptions, "package_revision", Null];
packageFiles = <|"path" -> #, "sha256" -> FileHash[#, "SHA256", "HexString"]|> & /@
  DeleteDuplicates[Prepend[Sort[FileNames["*.wl",
    FileNameJoin[{DirectoryName[entry], "Kernel"}], Infinity]], entry]];
recordPhase["package_load", "entered", <|
  "entry" -> entry, "package_revision" -> packageRevision,
  "implementation_files" -> packageFiles
|>];
Get[entry];
recordPhase["package_load", "returned"];

(* Sector bits follow the full propagator/ISP index order. *)
recordPhase["family_load", "entered", <|
  "prepared_family_path" -> preparedPath,
  "prepared_family_sha256" -> FileHash[preparedPath, "SHA256", "HexString"],
  "family_data_path" -> familyDataPath,
  "family_data_sha256" -> FileHash[familyDataPath, "SHA256", "HexString"]
|>];
familyData = CanonMethodCard`ReadWLData[familyDataPath];
recordPhase["family_load", "returned"];
family = familyData["Family"];
sector = Reverse @ IntegerDigits[
  task["sector", "id"], 2, Length[family["Propagators"]]];
loopOrder = family["LoopMomenta"][[methodOptions["loop_order"]]];
loopSpecifications = MapThread[
  <|"Momentum" -> #1, "BaseDimension" -> #2|> &,
  {loopOrder, methodOptions["loop_dimensions"]}
];
powerDefinition = payload["numerator_or_power_counting_policy", "definition"];
If[
  payload["candidate_unit"] =!= "NORMALIZED_LINEAR_COMBINATION" ||
    payload["normalization_policy", "convention"] =!=
      "first-integral-coefficient-outside-definition" ||
    payload["normalization_policy", "factors", "placement"] =!=
      "normalization.factor",
  CanonMethodCard`WriteProviderResult[
    task, outputDir, "ERROR", "UNSUPPORTED_CANDIDATE_NORMALIZATION", <||>,
    <|"reason" ->
      "DlogBasis candidate combinations use first-integral projective normalization"|>
  ];
  Quit[0]
];
If[payload["candidate_budget", "unit"] =!= "PROVIDER_CANDIDATE",
  CanonMethodCard`WriteProviderResult[
    task, outputDir, "ERROR", "UNSUPPORTED_CANDIDATE_BUDGET", <||>,
    <|"reason" -> "candidate_budget.maximum counts DlogBasis candidate directions"|>
  ];
  Quit[0]
];
If[powerDefinition["max_dots_per_propagator"] < powerDefinition["max_added_dots"],
  CanonMethodCard`WriteProviderResult[
    task, outputDir, "ERROR", "UNSUPPORTED_POWER_COUNTING", <||>,
    <|"reason" ->
      "DlogBasisSearch supports a total dot bound; max_dots_per_propagator must not be smaller"|>
  ];
  Quit[0]
];

methodId = "dlogbasis-refine-search";
singularExecutable = Lookup[methodOptions, "singular_executable", "Singular"];
If[StringContainsQ[singularExecutable, {"/", "\\"}],
  singularExecutable = CanonMethodCard`ResolveInputPath[inputPath, singularExecutable]
];
recordPhase["dlogbasis_search", "entered", <|
  "public_entry" -> "DlogBasis`DlogBasisSearch", "sector" -> sector,
  "loop_order" -> methodOptions["loop_order"],
  "loop_dimensions" -> methodOptions["loop_dimensions"],
  "numerator_degree" -> powerDefinition["numerator_degree"],
  "max_added_dots" -> powerDefinition["max_added_dots"],
  "numerator_positions" -> Lookup[methodOptions, "numerator_positions", "Automatic"],
  "expected_lattice_count" ->
    Binomial[Count[sector, 1] + powerDefinition["max_added_dots"], Count[sector, 1]]*
    Binomial[Count[sector, 0] + powerDefinition["numerator_degree"], Count[sector, 0]],
  "candidate_budget" -> payload["candidate_budget"],
  "candidate_budget_scope" -> "returned_directions_after_provider_return"
|>];
result = DlogBasis`DlogBasisSearch[
  family, sector,
  "LoopSpecifications" -> loopSpecifications,
  "NumeratorDegreeBound" -> powerDefinition["numerator_degree"],
  "DotDegreeBound" -> powerDefinition["max_added_dots"],
  "NumeratorPositions" -> Lookup[methodOptions, "numerator_positions", Automatic],
  "FiniteFlowPackageFile" -> CanonMethodCard`ResolveInputPath[
    inputPath, methodOptions["finite_flow_package_file"]],
  "ResidualBackend" -> Lookup[methodOptions, "residual_backend", "Current"],
  "SingularExecutable" -> singularExecutable
];
recordPhase["dlogbasis_search", "returned", <|"failure" -> FailureQ[result]|>];
If[FailureQ[result],
  CanonMethodCard`WriteProviderResult[
    task, outputDir, "ERROR", "DLOGBASIS_SEARCH_FAILED", <||>,
    <|"failure_tag" -> ToString[First[result]],
      "failure" -> ToString[result, InputForm], "entry" -> entry|>
  ];
  Quit[0]
];

(* DlogBasis uses an inert integral head and its own symbol contexts.  Map only
   those two coordinate systems; the mathematical coefficients are unchanged. *)
integralHead = Symbol["CANON`DEData`j"];
topology = Symbol["CANON`DEData`" <> prepared["topology"]];
kinematicRules = Thread[family["KinematicVariables"] -> prepared["variables"]];
canonExpression[expression_] := Factor[
  expression /.
    HoldPattern[DlogBasis`DlogIntegral[_, indices_List]] :>
      Apply[integralHead, Prepend[indices, topology]] /.
    kinematicRules /.
    DlogBasis`DimensionalRegulator -> prepared["regulator"]
];

candidateRecord[expression_, index_] := Module[{integral, factor},
  integral = First @ Cases[
    expression, item_ /; Head[Unevaluated[item]] === integralHead :> item, {0, Infinity}
  ];
  factor = Coefficient[expression, integral];
  <|
    "candidate_id" -> methodId <> ":" <> ToString[First[index]],
    "exact_definition" -> (HoldComplete @@ {Together[expression/factor]}),
    "candidate_unit" -> payload["candidate_unit"],
    "normalization" -> <|
      "convention" -> payload["normalization_policy", "convention"],
      "factor" -> factor
    |>
  |>
];

recordPhase["candidate_conversion", "entered"];
allCandidateRecords = MapIndexed[
  candidateRecord, canonExpression /@ Lookup[result, "CandidateCombinations", {}]
];
budget = payload["candidate_budget"];
candidateRecords = Take[allCandidateRecords, UpTo[budget["maximum"]]];
remainingCandidates = Length[allCandidateRecords] - Length[candidateRecords];
poolExhausted = remainingCandidates === 0;
recordPhase["candidate_conversion", "returned", <|
  "available_candidate_count" -> Length[allCandidateRecords],
  "returned_candidate_count" -> Length[candidateRecords]
|>];

summary = <|
  "method_id" -> methodId,
  "tool" -> "DlogBasis-refine",
  "public_entry" -> "DlogBasis`DlogBasisSearch",
  "scientific_status" -> result["ScientificStatus"],
  "sector" -> sector,
  "loop_order" -> methodOptions["loop_order"],
  "loop_dimensions" -> methodOptions["loop_dimensions"],
  "candidate_lattice_count" -> result["CandidateLattice", "CandidateCount"],
  "represented_candidate_count" -> Length[result["RepresentedCandidates"]],
  "candidate_count" -> Length[candidateRecords],
  "available_candidate_count" -> Length[allCandidateRecords],
  "candidate_chart_complete" -> result["CandidateChartCompleteQ"],
  "affine_finite_constant_residues_verified" ->
    result["AffineFiniteConstantResiduesVerifiedQ"],
  "constant_leading_singularity_certified" ->
    result["ConstantLeadingSingularityCertifiedQ"],
  "uniform_transcendentality_certified" ->
    result["UniformTranscendentalityCertifiedQ"],
  "canonical_basis_certified" -> result["CanonicalBasisCertifiedQ"],
  "package_source" -> package["source"],
  "package_revision" -> packageRevision,
  "entry" -> entry,
  "entry_sha256" -> entryHash,
  "implementation_files" -> packageFiles,
  "runtime" -> $Version <> "; " <> $SystemID
|>;

If[candidateRecords === {},
  CanonMethodCard`WriteProviderResult[
    task, outputDir, "INCONCLUSIVE", "METHOD_EXHAUSTED", <||>,
    Append[
      summary,
      "reason" -> "DlogBasisSearch produced no candidates within the requested budget"
    ]
  ];
  Quit[0]
];

artifact = <|
  "schema" -> "canon-neu/integral-candidates/v1",
  "proposal_id" -> methodId <> ":proposal",
  "family_identity" -> payload["family_identity"],
  "sector_identity" -> payload["sector_identity"],
  "dimension_policy" -> payload["dimension_policy"],
  "numerator_or_power_counting_policy" ->
    payload["numerator_or_power_counting_policy"],
  "candidate_budget" -> <|
    "maximum" -> budget["maximum"],
    "consumed" -> Length[candidateRecords],
    "unit" -> budget["unit"]
  |>,
  "candidate_pool" -> <|
    "available" -> Length[allCandidateRecords],
    "remaining" -> remainingCandidates,
    "pool_exhausted" -> poolExhausted
  |>,
  "pool_exhausted" -> poolExhausted,
  "candidate_unit" -> payload["candidate_unit"],
  "normalization_policy" -> payload["normalization_policy"],
  "coefficient_frame" -> Join[KeyTake[prepared, {"family_ref", "chart_id", "variables", "regulator"}],
    If[Lookup[prepared, "parameters", {}] === {}, <||>, <|
      "dimension" -> First[prepared["parameters"]],
      "constants" -> Select[prepared["parameters"],
        !MemberQ[Join[prepared["variables"], {prepared["regulator"], First[prepared["parameters"]]}], #] &]
    |>]],
  "candidates" -> candidateRecords,
  "method_evidence" -> <|
    "method_id" -> methodId,
    "evidence" -> {
      <|"stage" -> "DlogBasis`DlogBasisSearch", "output" -> result|>
    }
  |>,
  "tool_provenance" -> <|
    "tool" -> "DlogBasis-refine",
    "tool_revision" -> packageRevision,
    "entry" -> entry,
    "entry_sha256" -> entryHash,
    "implementation_files" -> packageFiles,
    "runtime" -> $Version <> "; " <> $SystemID
  |>
|>;
artifactPath = Block[
  {$ContextPath = {"System`"}},
  CanonMethodCard`WriteWLArtifact[
    artifact, outputDir, "integral-candidates.wl"
  ]
];
CanonMethodCard`WriteProviderResult[
  task, outputDir, "PROVISIONAL", "INTEGRAL_CANDIDATES",
  <|
    "integral_candidates" -> <|
      "type" -> "mathematica-expression",
      "path" -> FileNameTake[artifactPath]
    |>
  |>,
  summary
];
