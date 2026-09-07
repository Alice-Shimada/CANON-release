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
prepared = CanonMethodCard`LoadArtifact[task, inputPath, "prepared_family"];
payload = task["payload"];
methodOptions = payload["method_options"];
package = CanonMethodCard`ResolveMethodPackage[task, inputPath, "DlogBasis`"];
entry = package["entry"];
entryHash = FileHash[entry, "SHA256", "HexString"];
packageRevision = Lookup[methodOptions, "package_revision", Null];
Get[entry];

(* Sector bits follow the full propagator/ISP index order. *)
familyData = Get[prepared["family_data", "path"]];
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
    expression, item_ /; Head[Unevaluated[item]] === integralHead :> item, Infinity
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

allCandidateRecords = MapIndexed[
  candidateRecord, canonExpression /@ Lookup[result, "CandidateCombinations", {}]
];
budget = payload["candidate_budget"];
candidateRecords = Take[allCandidateRecords, UpTo[budget["maximum"]]];
remainingCandidates = Length[allCandidateRecords] - Length[candidateRecords];
poolExhausted = remainingCandidates === 0;

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
