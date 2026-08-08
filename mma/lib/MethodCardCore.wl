BeginPackage["CanonMethodCard`"];

ReadTask::usage = "ReadTask[path, step] reads and validates a script input envelope.";
ScriptArguments::usage = "ScriptArguments[] returns arguments following the active WL script.";
LoadArtifact::usage = "LoadArtifact[task, inputPath, name] reads one WL Association artifact.";
ResolveMethodPackage::usage = "ResolveMethodPackage[task, inputPath, context] resolves a workflow-declared package entry or the standard Wolfram package path.";
WriteWLArtifact::usage = "WriteWLArtifact[expr, outputDir, fileName] writes a new WL artifact.";
WriteResult::usage = "WriteResult[task, outputDir, status, code, artifacts, summary] writes result.json.";
WriteProviderResult::usage = "WriteProviderResult[task, outputDir, status, code, artifacts, summary] writes a provider result that cannot claim PASS or FAIL.";
ValidCutDEQ::usage = "ValidCutDEQ[expr] checks the sector-cut-DE artifact shape.";
ValidSectorBasisQ::usage = "ValidSectorBasisQ[expr] checks the sector-basis artifact shape.";
ValidCandidatesQ::usage = "ValidCandidatesQ[expr] checks the core-candidates artifact shape.";
ValidatePreparedBasis::usage = "ValidatePreparedBasis[expr] validates canon-neu/prepared-basis/v1 and returns the input or a deterministic Failure.";
PreparedBasisRoute::usage = "PreparedBasisRoute[prepared] returns a deterministic canon-neu/route-decision/v1 artifact for a valid prepared basis.";
CheckCoreCandidate::usage = "CheckCoreCandidate[candidate, matrices, variables, regulator, index] independently checks one exact core candidate.";
GaugeTransform::usage = "GaugeTransform[matrices, variables, T] applies old=T.new exactly.";
ZeroMatrixQ::usage = "ZeroMatrixQ[matrix] tests exact entrywise vanishing.";
FlatConnectionQ::usage = "FlatConnectionQ[matrices, variables] tests exact integrability.";
EpsilonFactorizedQ::usage = "EpsilonFactorizedQ[matrices, eps] tests exact epsilon factorization.";
DLogConnectionQ::usage = "DLogConnectionQ[matrices, variables, eps, alphabet] tests the bounded exact one-variable dlog form.";
ExactRationalExpressionQ::usage = "ExactRationalExpressionQ[expr] accepts only finite exact rational functions.";

Begin["`Private`"];

failure[tag_String, message_String] := Failure[tag, <|"Message" -> message|>];

ScriptArguments[] := Module[{scriptArguments, position},
  scriptArguments = Quiet @ Check[$ScriptCommandLine, {}];
  If[ListQ[scriptArguments] && Length[scriptArguments] > 1,
    Return[Rest[scriptArguments]]
  ];
  position = FirstPosition[$CommandLine, "-script", Missing["not-found"]];
  If[MissingQ[position],
    position = FirstPosition[$CommandLine, "-file", Missing["not-found"]]
  ];
  If[MissingQ[position], {}, Drop[$CommandLine, First[position] + 1]]
];

ReadTask[path_String, expectedStep_String] := Module[{task},
  task = Quiet @ Check[Import[path, "RawJSON"], $Failed];
  If[!AssociationQ[task], Return[failure["INVALID_INPUT", "input is not a JSON object"]]];
  If[Lookup[task, "schema", None] =!= "canon-neu/script-input/v1",
    Return[failure["INVALID_INPUT", "unexpected input schema"]]
  ];
  If[Lookup[task, "step", None] =!= expectedStep,
    Return[failure["INVALID_INPUT", "unexpected workflow step"]]
  ];
  If[!StringQ[Lookup[task, "task_id", None]] || !AssociationQ[Lookup[task, "payload", None]],
    Return[failure["INVALID_INPUT", "task_id or payload is missing"]]
  ];
  task
];

artifactPath[inputPath_String, descriptor_Association] := Module[{raw},
  raw = Lookup[descriptor, "path", Missing["path"]];
  If[!StringQ[raw], Return[$Failed]];
  If[StringStartsQ[raw, $PathnameSeparator],
    ExpandFileName[raw],
    ExpandFileName[FileNameJoin[{DirectoryName[ExpandFileName[inputPath]], raw}]]
  ]
];

absolutePathQ[path_String] := If[
  $OperatingSystem === "Windows",
  StringMatchQ[path, LetterCharacter ~~ ":" ~~ ("/" | "\\") ~~ ___] ||
    StringStartsQ[path, "\\\\"] || StringStartsQ[path, "//"],
  StringStartsQ[path, $PathnameSeparator]
];

ResolveMethodPackage[task_Association, inputPath_String, context_String] := Module[
  {options, requested, path, source},
  options = Lookup[Lookup[task, "payload", <||>], "method_options", <||>];
  If[!AssociationQ[options],
    Return[failure["INVALID_METHOD_OPTIONS", "method_options must be an Association"]]
  ];
  requested = Lookup[options, "package_entry", Automatic];
  Which[
    requested === Automatic,
      path = Quiet @ Check[FindFile[context], $Failed];
      source = "wolfram-package-path",
    StringQ[requested] && requested =!= "",
      path = If[
        absolutePathQ[requested],
        ExpandFileName[requested],
        ExpandFileName[FileNameJoin[{DirectoryName[ExpandFileName[inputPath]], requested}]]
      ];
      source = "method_options.package_entry",
    True,
      Return[failure["INVALID_METHOD_OPTIONS", "package_entry must be a non-empty path string"]]
  ];
  If[!StringQ[path] || FileType[path] =!= File,
    Return[failure["METHOD_PACKAGE_UNAVAILABLE", "declared method package could not be resolved"]]
  ];
  <|"entry" -> ExpandFileName[path], "source" -> source|>
];

LoadArtifact[task_Association, inputPath_String, name_String] := Module[
  {descriptor, path, value},
  descriptor = Lookup[Lookup[task, "payload", <||>], name, Missing[name]];
  If[!AssociationQ[descriptor], Return[failure["MISSING_ARTIFACT", name]]];
  path = artifactPath[inputPath, descriptor];
  If[path === $Failed || FileType[path] =!= File,
    Return[failure["MISSING_ARTIFACT", name <> " path is not a file"]]
  ];
  value = Quiet @ Check[Get[path], $Failed];
  If[!AssociationQ[value], Return[failure["INVALID_ARTIFACT", name <> " is not an Association"]]];
  value
];

prepareOutput[outputDir_String] := Module[{dir = ExpandFileName[outputDir]},
  If[FileExistsQ[dir] && FileType[dir] =!= Directory, Return[$Failed]];
  If[!FileExistsQ[dir], Quiet @ Check[CreateDirectory[dir, CreateIntermediateDirectories -> True], Return[$Failed]]];
  If[FileExistsQ[FileNameJoin[{dir, "result.json"}]], Return[$Failed]];
  dir
];

WriteWLArtifact[expr_, outputDir_String, fileName_String] := Module[{dir, path},
  dir = prepareOutput[outputDir];
  If[dir === $Failed, Return[$Failed]];
  path = FileNameJoin[{dir, fileName}];
  If[FileExistsQ[path], Return[$Failed]];
  If[Quiet @ Check[Put[expr, path]; FileType[path] === File, False], path, $Failed]
];

WriteResult[
  task_Association,
  outputDir_String,
  status_String,
  code_String,
  artifacts_Association,
  summary_Association : <||>
] := Module[{dir, result, path},
  If[
    !MemberQ[{"ERROR", "INCONCLUSIVE", "PROVISIONAL", "FAIL", "PASS"}, status] ||
      !StringQ[code] || code === "" || !AssociationQ[artifacts] || !AssociationQ[summary],
    Return[$Failed]
  ];
  dir = prepareOutput[outputDir];
  If[dir === $Failed, Return[$Failed]];
  result = <|
    "schema" -> "canon-neu/script-result/v1",
    "task_id" -> task["task_id"],
    "step" -> task["step"],
    "status" -> status,
    "code" -> code,
    "artifacts" -> artifacts,
    "summary" -> summary
  |>;
  path = FileNameJoin[{dir, "result.json"}];
  If[Quiet @ Check[Export[path, result, "RawJSON"]; FileType[path] === File, False], path, $Failed]
];

WriteProviderResult[
  task_Association,
  outputDir_String,
  status_String,
  code_String,
  artifacts_Association,
  summary_Association : <||>
] := Module[{valid},
  valid = Switch[status,
    "ERROR", True,
    "INCONCLUSIVE", MemberQ[{"OUT_OF_SCOPE", "METHOD_EXHAUSTED"}, code],
    "PROVISIONAL", MemberQ[{"CANDIDATE_TRANSFORMATION", "EVIDENCE_AWAITING_VERIFICATION"}, code],
    _, False
  ];
  If[!TrueQ[valid], Return[$Failed]];
  WriteResult[task, outputDir, status, code, artifacts, summary]
];

squareMatrixQ[m_, n_Integer] := MatrixQ[m] && Dimensions[m] === {n, n};

rationalPolynomialSyntaxQ[expr_] := Which[
  IntegerQ[expr] || Head[Unevaluated[expr]] === Rational, True,
  MatchQ[Unevaluated[expr], _Symbol], Context[Unevaluated[expr]] =!= "System`",
  Head[Unevaluated[expr]] === Complex,
    rationalPolynomialSyntaxQ[Re[expr]] && rationalPolynomialSyntaxQ[Im[expr]],
  Head[Unevaluated[expr]] === Plus || Head[Unevaluated[expr]] === Times,
    And @@ (rationalPolynomialSyntaxQ /@ List @@ expr),
  Head[Unevaluated[expr]] === Power,
    IntegerQ[Last[List @@ expr]] && TrueQ[Last[List @@ expr] >= 0] &&
      rationalPolynomialSyntaxQ[First[List @@ expr]],
  True, False
];

ExactRationalExpressionQ[expr_] := Module[{value, variables, numerator, denominator},
  If[!FreeQ[Unevaluated[expr], _Real | Indeterminate | ComplexInfinity | DirectedInfinity[___] | Undefined],
    Return[False]
  ];
  value = Quiet @ Check[Together[expr], $Failed];
  If[value === $Failed, Return[False]];
  variables = DeleteDuplicates[Cases[value, _Symbol, Infinity]];
  numerator = Numerator[value];
  denominator = Denominator[value];
  rationalPolynomialSyntaxQ[numerator] && rationalPolynomialSyntaxQ[denominator] &&
    PolynomialQ[numerator, variables] && PolynomialQ[denominator, variables] && denominator =!= 0
];

exactRationalMatrixQ[m_, n_Integer] := squareMatrixQ[m, n] &&
  And @@ (ExactRationalExpressionQ /@ Flatten[m]);

ValidCutDEQ[value_] := Module[{basis, variables, regulator, matrices, n},
  If[!AssociationQ[value] || Lookup[value, "schema", None] =!= "canon-neu/sector-cut-de/v1", Return[False]];
  If[
    !AssociationQ[Lookup[value, "sector", None]] ||
    !StringQ[Lookup[value, "family_id", None]] ||
    !StringQ[Lookup[value, "basis_id", None]] ||
    Lookup[value, "coefficient_domain", None] =!= "exact-rational-functions",
    Return[False]
  ];
  basis = Lookup[value, "basis", None];
  variables = Lookup[value, "variables", None];
  regulator = Lookup[value, "regulator", None];
  matrices = Lookup[value, "matrices", None];
  If[!ListQ[basis] || !ListQ[variables] || variables === {} || !ListQ[matrices], Return[False]];
  If[Length[variables] =!= Length[matrices] || !MatchQ[regulator, _Symbol], Return[False]];
  n = Length[basis];
  n > 0 && And @@ (exactRationalMatrixQ[#, n] & /@ matrices)
];

ValidSectorBasisQ[value_] := AssociationQ[value] &&
  Lookup[value, "schema", None] === "canon-neu/sector-basis/v1" &&
  AssociationQ[Lookup[value, "sector", None]] &&
  StringQ[Lookup[value, "family_id", None]] &&
  StringQ[Lookup[value, "basis_id", None]] &&
  ListQ[Lookup[value, "basis", None]];

ValidCandidatesQ[value_] := AssociationQ[value] &&
  Lookup[value, "schema", None] === "canon-neu/core-candidates/v1" &&
  Lookup[value, "convention", None] === "old_basis = transformation . new_basis" &&
  AssociationQ[Lookup[value, "sector", None]] &&
  StringQ[Lookup[value, "family_id", None]] &&
  StringQ[Lookup[value, "basis_id", None]] &&
  Lookup[value, "coefficient_domain", None] === "exact-rational-functions" &&
  ListQ[Lookup[value, "basis", None]] &&
  ListQ[Lookup[value, "variables", None]] &&
  MatchQ[Lookup[value, "regulator", None], _Symbol] &&
  ListQ[Lookup[value, "candidates", None]];

preparedFailure[field_String, message_String] :=
  Failure["INVALID_PREPARED_BASIS", <|"Field" -> field, "Message" -> message|>];

nonEmptyStringQ[value_] := StringQ[value] && StringLength[value] > 0;
booleanQ[value_] := TrueQ[value === True || value === False];

ValidatePreparedBasis[value_] := Module[
  {
    identity, current, prefix, candidates, candidateIDs, ranks, selected,
    quality, defect, evidence, history, attempted, unattempted, remaining, classification,
    canonicalQ
  },
  If[!AssociationQ[value], Return[preparedFailure["$", "artifact must be an Association"]]];
  If[Lookup[value, "schema", None] =!= "canon-neu/prepared-basis/v1",
    Return[preparedFailure["schema", "unexpected prepared-basis schema"]]
  ];

  identity = Lookup[value, "identity", None];
  If[
    !AssociationQ[identity] ||
      !And @@ (nonEmptyStringQ[Lookup[identity, #, None]] & /@
        {"preparation_id", "family_id", "basis_id"}) ||
      !ListQ[Lookup[identity, "variables", None]] || Lookup[identity, "variables", {}] === {} ||
      !MatchQ[Lookup[identity, "regulator", None], _Symbol],
    Return[preparedFailure["identity", "identity must declare preparation, family, basis, variables, and regulator"]]
  ];

  current = Lookup[value, "current_basis", None];
  If[
    !AssociationQ[current] ||
      !nonEmptyStringQ[Lookup[current, "basis_id", None]] ||
      Lookup[current, "basis_id", None] =!= identity["basis_id"] ||
      !ListQ[Lookup[current, "basis", None]] || Lookup[current, "basis", {}] === {},
    Return[preparedFailure["current_basis", "current basis must be nonempty and match identity.basis_id"]]
  ];

  prefix = Lookup[value, "frozen_lower_prefix", None];
  If[
    !AssociationQ[prefix] || !booleanQ[Lookup[prefix, "present", None]] ||
      !booleanQ[Lookup[prefix, "accepted", None]] || !ListQ[Lookup[prefix, "basis", None]],
    Return[preparedFailure["frozen_lower_prefix", "frozen prefix shape is invalid"]]
  ];
  If[TrueQ[prefix["present"]],
    If[
      !TrueQ[prefix["accepted"]] || !nonEmptyStringQ[Lookup[prefix, "prefix_id", None]] ||
        prefix["basis"] === {},
      Return[preparedFailure["frozen_lower_prefix", "a present lower prefix must be accepted, identified, and nonempty"]]
    ],
    If[
      prefix["accepted"] =!= False || Lookup[prefix, "prefix_id", None] =!= Null || prefix["basis"] =!= {},
      Return[preparedFailure["frozen_lower_prefix", "an absent lower prefix must have accepted=False, prefix_id=Null, and an empty basis"]]
    ]
  ];

  candidates = Lookup[value, "candidates", None];
  If[!ListQ[candidates] || candidates === {},
    Return[preparedFailure["candidates", "candidate definitions must be a nonempty list"]]
  ];
  If[!And @@ (AssociationQ /@ candidates),
    Return[preparedFailure["candidates", "every candidate must be an Association"]]
  ];
  If[
    !And @@ Table[
      nonEmptyStringQ[Lookup[candidate, "candidate_id", None]] &&
        AssociationQ[Lookup[candidate, "definition", None]] && Lookup[candidate, "definition", <||>] =!= <||> &&
        nonEmptyStringQ[Lookup[candidate, "normalization", None]] &&
        IntegerQ[Lookup[candidate, "rank", None]] && Lookup[candidate, "rank", 0] > 0 &&
        booleanQ[Lookup[candidate, "selected", None]] && booleanQ[Lookup[candidate, "suspicious", None]],
      {candidate, candidates}
    ],
    Return[preparedFailure["candidates", "each candidate needs a definition, normalization, positive rank, selected flag, and suspicious flag"]]
  ];
  candidateIDs = Lookup[candidates, "candidate_id"];
  ranks = Lookup[candidates, "rank"];
  If[DuplicateFreeQ[candidateIDs] =!= True,
    Return[preparedFailure["candidates.candidate_id", "candidate IDs must be unique"]]
  ];
  If[Sort[ranks] =!= Range[Length[candidates]],
    Return[preparedFailure["candidates.rank", "candidate ranks must be a unique contiguous ordering starting at one"]]
  ];
  selected = Select[candidates, TrueQ[Lookup[#, "selected", False]] &];
  If[Length[selected] =!= 1,
    Return[preparedFailure["candidates.selected", "exactly one current candidate must be selected"]]
  ];

  quality = Lookup[value, "quality", None];
  defect = If[AssociationQ[quality], Lookup[quality, "localized_defect", None], None];
  If[
    !AssociationQ[quality] ||
      !MemberQ[{"CANONICAL", "DEFECT", "UNKNOWN"}, Lookup[quality, "diagonal", None]] ||
      !MemberQ[{"CANONICAL", "DEFECT", "UNKNOWN"}, Lookup[quality, "off_diagonal", None]] ||
      !AssociationQ[defect] || !booleanQ[Lookup[defect, "present", None]] ||
      !AssociationQ[Lookup[defect, "signature", None]],
    Return[preparedFailure["quality", "quality must declare diagonal, off-diagonal, and localized-defect data"]]
  ];
  If[TrueQ[defect["present"]],
    If[!nonEmptyStringQ[Lookup[defect, "block", None]] || defect["signature"] === <||>,
      Return[preparedFailure["quality.localized_defect", "a present localized defect needs a block and nonempty signature"]]
    ],
    If[Lookup[defect, "block", None] =!= Null || defect["signature"] =!= <||>,
      Return[preparedFailure["quality.localized_defect", "an absent localized defect must have block=Null and an empty signature"]]
    ]
  ];

  evidence = Lookup[value, "ut_evidence_references", None];
  If[
    !ListQ[evidence] ||
      !And @@ Table[
        AssociationQ[reference] && nonEmptyStringQ[Lookup[reference, "reference_id", None]] &&
          nonEmptyStringQ[Lookup[reference, "provider", None]] &&
          MemberQ[candidateIDs, Lookup[reference, "candidate_id", None]] &&
          nonEmptyStringQ[Lookup[reference, "verification_status", None]],
        {reference, evidence}
      ],
    Return[preparedFailure["ut_evidence_references", "UT evidence references must identify a provider, candidate, and verification status"]]
  ];
  If[DuplicateFreeQ[Lookup[evidence, "reference_id", {}]] =!= True,
    Return[preparedFailure["ut_evidence_references.reference_id", "UT evidence reference IDs must be unique"]]
  ];

  history = Lookup[value, "search_history", None];
  If[
    !AssociationQ[history] || !booleanQ[Lookup[history, "plateau", None]] ||
      !booleanQ[Lookup[history, "pool_exhausted", None]] ||
      !IntegerQ[Lookup[history, "alternatives_remaining", None]] || history["alternatives_remaining"] < 0 ||
      !ListQ[Lookup[history, "attempted_candidate_ids", None]],
    Return[preparedFailure["search_history", "search history must declare plateau, pool exhaustion, alternatives, and attempted IDs"]]
  ];
  attempted = history["attempted_candidate_ids"];
  If[
    !And @@ (nonEmptyStringQ /@ attempted) || DuplicateFreeQ[attempted] =!= True ||
      !SubsetQ[candidateIDs, attempted],
    Return[preparedFailure["search_history.attempted_candidate_ids", "attempted IDs must be unique declared candidates"]]
  ];
  unattempted = Complement[candidateIDs, attempted];
  If[history["alternatives_remaining"] =!= Length[unattempted],
    Return[preparedFailure["search_history.alternatives_remaining", "alternatives_remaining must equal the number of declared unattempted candidates"]]
  ];
  If[TrueQ[history["pool_exhausted"]] && history["alternatives_remaining"] =!= 0,
    Return[preparedFailure["search_history", "pool_exhausted=True contradicts alternatives_remaining"]]
  ];
  If[TrueQ[history["pool_exhausted"]] && unattempted =!= {},
    Return[preparedFailure["search_history.pool_exhausted", "pool exhaustion requires every declared candidate to be attempted"]]
  ];

  remaining = Lookup[value, "remaining_problem", None];
  classification = If[AssociationQ[remaining], Lookup[remaining, "classification", None], None];
  If[
    !AssociationQ[remaining] ||
      !MemberQ[
        {"NONE", "SUSPICIOUS_CANDIDATE", "LOCALIZED_RATIONAL_DEFECT", "GLOBAL_RATIONAL_DEFECT", "UNKNOWN_OR_NONRATIONAL"},
        classification
      ] ||
      !booleanQ[Lookup[remaining, "candidate_selection_complete", None]] ||
      !booleanQ[Lookup[remaining, "rational_transformation_expected", None]],
    Return[preparedFailure["remaining_problem", "remaining problem classification is invalid"]]
  ];
  If[TrueQ[remaining["candidate_selection_complete"]] && history["alternatives_remaining"] =!= 0,
    Return[preparedFailure["remaining_problem.candidate_selection_complete", "completed candidate selection contradicts remaining alternatives"]]
  ];
  If[TrueQ[remaining["candidate_selection_complete"]] && unattempted =!= {},
    Return[preparedFailure["remaining_problem.candidate_selection_complete", "completed candidate selection requires every declared candidate to be attempted"]]
  ];

  If[
    TrueQ[First[selected]["suspicious"]] &&
      !MemberQ[{"SUSPICIOUS_CANDIDATE", "LOCALIZED_RATIONAL_DEFECT"}, classification],
    Return[preparedFailure["candidates.selected", "selected candidate suspicion contradicts the remaining-problem classification"]]
  ];
  If[classification === "SUSPICIOUS_CANDIDATE" && !TrueQ[First[selected]["suspicious"]],
    Return[preparedFailure["remaining_problem.classification", "suspicious-candidate classification requires the selected candidate to be marked suspicious"]]
  ];

  canonicalQ = quality["diagonal"] === "CANONICAL" && quality["off_diagonal"] === "CANONICAL";
  If[canonicalQ &&
      (TrueQ[First[selected]["suspicious"]] || TrueQ[defect["present"]] ||
        classification =!= "NONE" || TrueQ[remaining["rational_transformation_expected"]]),
    Return[preparedFailure["quality", "canonical quality contradicts selected-candidate suspicion, a remaining defect, or an expected transformation"]]
  ];
  If[classification === "NONE" && !canonicalQ,
    Return[preparedFailure["remaining_problem.classification", "classification NONE requires canonical diagonal and off-diagonal quality"]]
  ];
  If[classification === "LOCALIZED_RATIONAL_DEFECT" && !TrueQ[defect["present"]],
    Return[preparedFailure["quality.localized_defect", "localized classification requires localized defect data"]]
  ];
  If[TrueQ[defect["present"]] &&
      !MemberQ[{quality["diagonal"], quality["off_diagonal"]}, "DEFECT"],
    Return[preparedFailure["quality.localized_defect", "localized defect data requires a DEFECT quality dimension"]]
  ];
  If[classification === "LOCALIZED_RATIONAL_DEFECT" &&
      !TrueQ[remaining["rational_transformation_expected"]],
    Return[preparedFailure["remaining_problem.rational_transformation_expected", "localized rational defect requires an expected rational transformation"]]
  ];
  If[TrueQ[defect["present"]] && MemberQ[{"NONE", "GLOBAL_RATIONAL_DEFECT"}, classification],
    Return[preparedFailure["remaining_problem.classification", "localized defect data contradicts the remaining-problem classification"]]
  ];
  If[classification === "GLOBAL_RATIONAL_DEFECT" &&
      (TrueQ[defect["present"]] || !TrueQ[remaining["rational_transformation_expected"]]),
    Return[preparedFailure["remaining_problem", "global rational defect requires no localized defect and an expected rational transformation"]]
  ];

  value
];

PreparedBasisRoute[prepared_Association] := Module[
  {
    validated, identity, candidates, selected, quality, defect, history, remaining,
    canonicalQ, suspiciousQ, alternativesQ, localizedQ, decision, reason
  },
  validated = ValidatePreparedBasis[prepared];
  If[FailureQ[validated], Return[validated]];
  identity = prepared["identity"];
  candidates = prepared["candidates"];
  selected = First @ Select[candidates, TrueQ[Lookup[#, "selected", False]] &];
  quality = prepared["quality"];
  defect = quality["localized_defect"];
  history = prepared["search_history"];
  remaining = prepared["remaining_problem"];
  canonicalQ = quality["diagonal"] === "CANONICAL" && quality["off_diagonal"] === "CANONICAL";
  suspiciousQ = TrueQ[selected["suspicious"]] || remaining["classification"] === "SUSPICIOUS_CANDIDATE";
  alternativesQ = history["alternatives_remaining"] > 0 && !TrueQ[history["pool_exhausted"]];
  localizedQ = TrueQ[defect["present"]] || remaining["classification"] === "LOCALIZED_RATIONAL_DEFECT";
  {decision, reason} = Which[
    canonicalQ,
      {"VERIFY_CANONICAL_DE", "ALREADY_CANONICAL"},
    (suspiciousQ || localizedQ) && alternativesQ && !TrueQ[history["plateau"]],
      {"REFINE_SECTOR_UT_CANDIDATES", "ALTERNATIVES_REMAIN"},
    localizedQ && (TrueQ[history["plateau"]] || TrueQ[history["pool_exhausted"]]),
      {"REPAIR_WITH_LIBRA", "LOCALIZED_SEARCH_EXHAUSTED"},
    remaining["classification"] === "GLOBAL_RATIONAL_DEFECT" &&
      TrueQ[remaining["candidate_selection_complete"]] &&
      TrueQ[remaining["rational_transformation_expected"]],
      {"FIND_RATIONAL_CANONICAL_WITH_CANONICA", "GLOBAL_RATIONAL_DEFECT"},
    True,
      {"DIAGNOSE_OR_CHANGE_VARIABLES", "NO_BOUNDED_PROVIDER_ROUTE"}
  ];
  <|
    "schema" -> "canon-neu/route-decision/v1",
    "preparation_id" -> identity["preparation_id"],
    "family_id" -> identity["family_id"],
    "basis_id" -> identity["basis_id"],
    "selected_candidate_id" -> selected["candidate_id"],
    "decision" -> decision,
    "reason" -> reason,
    "ut_evidence_controls_route" -> False,
    "ut_evidence_reference_count" -> Length[prepared["ut_evidence_references"]]
  |>
];

ZeroMatrixQ[expr_] := MatrixQ[expr] &&
  And @@ (TrueQ[Together[#] === 0] & /@ Flatten[expr]);

GaugeTransform[matrices_List, variables_List, transformation_?MatrixQ] :=
  MapThread[
    Map[Together, Inverse[transformation].(#1.transformation - D[transformation, #2]), {2}] &,
    {matrices, variables}
  ];

FlatConnectionQ[matrices_List, variables_List] := Module[{pairs, residual},
  If[Length[matrices] =!= Length[variables], Return[False]];
  pairs = Subsets[Range[Length[variables]], {2}];
  And @@ Map[
    Function[pair,
      With[{i = pair[[1]], j = pair[[2]]},
        residual = D[matrices[[j]], variables[[i]]] - D[matrices[[i]], variables[[j]]] +
          matrices[[j]].matrices[[i]] - matrices[[i]].matrices[[j]];
        ZeroMatrixQ[Map[Together, residual, {2}]]
      ]
    ],
    pairs
  ]
];

EpsilonFactorizedQ[matrices_List, regulator_Symbol] :=
  And @@ (FreeQ[Together[#/regulator], regulator] & /@ Flatten[matrices]);

CheckCoreCandidate[
  candidate_Association,
  matrices_List,
  variables_List,
  regulator_Symbol,
  index_Integer
] := Module[
  {basisDimension, transformation, declared, computed, residuals, invertible, exactGauge, flat, epsilonForm},
  basisDimension = Length[First[matrices]];
  transformation = Lookup[candidate, "transformation", None];
  declared = Lookup[candidate, "transformed_matrices", None];
  If[
    !MatrixQ[transformation] || Dimensions[transformation] =!= {basisDimension, basisDimension} ||
    !ListQ[declared] || Length[declared] =!= Length[variables] ||
    !And @@ (MatrixQ[#] && Dimensions[#] === {basisDimension, basisDimension} & /@ declared),
    Return[<|"index" -> index, "pass" -> False, "reason" -> "candidate shape mismatch"|>]
  ];
  If[
    !And @@ (ExactRationalExpressionQ /@ Flatten[transformation]) ||
    !And @@ (ExactRationalExpressionQ /@ Flatten[declared]),
    Return[<|"index" -> index, "pass" -> False, "reason" -> "candidate is outside the exact rational-function domain"|>]
  ];
  invertible = TrueQ[Together[Det[transformation]] =!= 0];
  If[!invertible, Return[<|"index" -> index, "pass" -> False, "reason" -> "singular transformation"|>]];
  computed = Quiet @ Check[GaugeTransform[matrices, variables, transformation], $Failed];
  If[computed === $Failed,
    Return[<|"index" -> index, "pass" -> False, "reason" -> "gauge transformation failed"|>]
  ];
  residuals = MapThread[Map[Together, #1 - #2, {2}] &, {computed, declared}];
  exactGauge = And @@ (ZeroMatrixQ /@ residuals);
  flat = FlatConnectionQ[computed, variables];
  epsilonForm = EpsilonFactorizedQ[computed, regulator];
  <|
    "index" -> index,
    "pass" -> TrueQ[invertible && exactGauge && flat && epsilonForm],
    "invertible" -> invertible,
    "exact_gauge" -> exactGauge,
    "flat_connection" -> flat,
    "epsilon_factorized" -> epsilonForm,
    "transformation" -> transformation,
    "transformed_matrices" -> computed
  |>
];

dLogExpressionQ[expr_, variable_Symbol, derivatives_List] := Module[
  {coefficients, residual, numerator, equations, instance},
  coefficients = Table[Unique["dlogCoefficient$"], {Length[derivatives]}];
  residual = Together[expr - coefficients.derivatives];
  numerator = Expand[Numerator[residual]];
  If[!PolynomialQ[numerator, variable], Return[False]];
  equations = Thread[CoefficientList[numerator, variable] == 0];
  instance = Quiet @ Check[FindInstance[equations, coefficients, Rationals, 1], {}];
  If[instance === {}, Return[False]];
  TrueQ[Together[residual /. First[instance]] === 0]
];

DLogConnectionQ[
  matrices_List,
  variables_List,
  regulator_Symbol,
  alphabet_List
] := Module[{variable, derivatives},
  (* The first executable gate is deliberately bounded to one exact rational variable. *)
  If[Length[variables] =!= 1 || alphabet === {} || !EpsilonFactorizedQ[matrices, regulator], Return[False]];
  variable = First[variables];
  If[
    !MatchQ[variable, _Symbol] ||
    !And @@ (ExactRationalExpressionQ /@ alphabet) ||
    !FreeQ[alphabet, regulator],
    Return[False]
  ];
  derivatives = Quiet @ Check[Together[D[#, variable]/#] & /@ alphabet, $Failed];
  If[derivatives === $Failed || !And @@ (ExactRationalExpressionQ /@ derivatives), Return[False]];
  And @@ (dLogExpressionQ[Together[#/regulator], variable, derivatives] & /@ Flatten[matrices])
];

End[];
EndPackage[];
