BeginPackage["CanonMethodCard`"];

SectorBits::usage = "SectorBits[integral, propagatorSlots] returns the full index-order sector mask, with ISP slots set to zero.";

ReadTask::usage = "ReadTask[path, step] reads and validates a script input envelope.";
ScriptArguments::usage = "ScriptArguments[] returns arguments following the active WL script.";
LoadArtifact::usage = "LoadArtifact[task, inputPath, name] reads one WL Association artifact.";
ResolveInputPath::usage = "ResolveInputPath[inputFile, path] resolves a path relative to the file that declares it.";
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
FermatGaugeIdentityQ::usage = "FermatGaugeIdentityQ[matrices, variables, T, target] proves A.T-D[T]-T.target=0 in the binomial algebraic extension using a loaded Fermatica backend.";
ZeroMatrixQ::usage = "ZeroMatrixQ[matrix] tests exact entrywise vanishing.";
FlatConnectionQ::usage = "FlatConnectionQ[matrices, variables] tests the exact symbolic curvature in every pair of variables.";
EpsilonFactorizedQ::usage = "EpsilonFactorizedQ[matrices, eps] tests exact epsilon factorization.";
DLogResidues::usage = "DLogResidues[matrices, variables, eps, alphabet] solves shared constant residues using exact Wolfram algebraic expressions.";
DLogAlphabet::usage = "DLogAlphabet[matrices, variables, eps] extracts regulator-free pole factors as candidate letters.";
QuadraticRootLetters::usage = "QuadraticRootLetters[matrices, variables] proposes norm-ratio letters for quadratic roots with rational square leading coefficients.";
AlgebraicPrimitive::usage = "AlgebraicPrimitive[components, variables] solves a polynomial-over-poles primitive in the algebraic components of an exact one-form.";
DLogConnectionQ::usage = "DLogConnectionQ[matrices, variables, eps, alphabet] tests the exact shared-residue dlog form across all directions.";
ExactRationalExpressionQ::usage = "ExactRationalExpressionQ[expr] accepts only finite exact rational functions.";
ExactAlgebraicExpressionQ::usage = "ExactAlgebraicExpressionQ[expr] accepts finite exact rational functions, algebraic numbers, radicals and polynomial Root functions.";
ValidateStructuredRepairInput::usage = "ValidateStructuredRepairInput[prepared, route, request] validates the frozen-prefix Libra repair contract.";
DeclaredCoefficientDomainQ::usage = "DeclaredCoefficientDomainQ[expr, symbols] checks exact rational syntax and rejects undeclared coefficient symbols.";
StructuredRepairPublicationGate::usage = "StructuredRepairPublicationGate[request, candidate] applies only the provider's minimal structural publication gate.";

Begin["`Private`"];

SectorBits[integral_, propagatorSlots_List] := ReplacePart[
  ConstantArray[0, Length[integral]],
  Thread[({#} & /@ propagatorSlots) -> (Boole[# > 0] & /@ (List @@ integral)[[propagatorSlots]])]];

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
  ResolveInputPath[inputPath, raw]
];

absolutePathQ[path_String] := If[
  $OperatingSystem === "Windows",
  StringMatchQ[path, LetterCharacter ~~ ":" ~~ ("/" | "\\") ~~ ___] ||
    StringStartsQ[path, "\\\\"] || StringStartsQ[path, "//"],
  StringStartsQ[path, $PathnameSeparator]
];

ResolveInputPath[inputPath_String, path_String] := ExpandFileName[
  If[absolutePathQ[path], path, FileNameJoin[{DirectoryName[ExpandFileName[inputPath]], path}]]
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
      path = ResolveInputPath[inputPath, requested];
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
    "ERROR", code =!= "ERROR",
    "INCONCLUSIVE", MemberQ[{"OUT_OF_SCOPE", "METHOD_EXHAUSTED"}, code],
    "PROVISIONAL", MemberQ[
      {
        {"PROPOSE_INTEGRAL_CANDIDATES", "INTEGRAL_CANDIDATES"},
        {"SEARCH_CORE", "CANDIDATE_TRANSFORMATION"},
        {"REPAIR_WITH_LIBRA", "CANDIDATE_TRANSFORMATION"},
        {"PROVIDE_UT_EVIDENCE", "EVIDENCE_AWAITING_VERIFICATION"}
      },
      {Lookup[task, "step", None], code}
    ],
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

(* Check the expression tree, rather than treating every exact expression as
   algebraic. In particular, a symbolic exponent or Exp/Log is outside this
   field. Parameters remain symbolic and no branch-changing rewrite is used. *)
ExactAlgebraicExpressionQ[expr_] := Which[
  IntegerQ[expr] || Head[expr] === Rational, True,
  MatchQ[expr, _Symbol], Context[expr] =!= "System`",
  Head[expr] === Complex,
    ExactAlgebraicExpressionQ[Re[expr]] && ExactAlgebraicExpressionQ[Im[expr]],
  Head[expr] === Plus || Head[expr] === Times,
    And @@ (ExactAlgebraicExpressionQ /@ List @@ expr),
  Head[expr] === Power,
    (IntegerQ[Last[expr]] || Head[Last[expr]] === Rational) &&
      ExactAlgebraicExpressionQ[First[expr]],
  Head[expr] === AlgebraicNumber, TrueQ[Element[expr, Algebraics]],
  Head[expr] === Root, algebraicRootQ[expr],
  True, False
];

algebraicRootQ[expr_] := Module[{variable = Unique["root$"], polynomial, degree},
  If[!MemberQ[{2, 3}, Length[expr]] || Head[First[expr]] =!= Function ||
      !IntegerQ[expr[[2]]] || expr[[2]] < 1, Return[False]];
  polynomial = Quiet @ Check[First[expr][variable], $Failed];
  If[polynomial === $Failed || !PolynomialQ[polynomial, variable], Return[False]];
  degree = Exponent[polynomial, variable];
  IntegerQ[degree] && 1 <= expr[[2]] <= degree &&
    And @@ (ExactAlgebraicExpressionQ /@ CoefficientList[polynomial, variable])
];

DeclaredCoefficientDomainQ[expr_, allowedSymbols_List] :=
  ExactRationalExpressionQ[expr] && SubsetQ[
    DeleteDuplicates[allowedSymbols],
    DeleteDuplicates[Cases[Unevaluated[expr], _Symbol, Infinity]]
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
    suspiciousQ && alternativesQ,
      {"REFINE_SECTOR_UT_CANDIDATES", "ALTERNATIVES_REMAIN"},
    localizedQ && quality["diagonal"] === "CANONICAL" &&
      defect["block"] === "lower-to-current",
      {"SOLVE_TAIL", "NONZERO_SUBSECTOR_COUPLING"},
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
  And @@ (TrueQ[FullSimplify[Together[#]] === 0] & /@ Flatten[expr]);

FermatGaugeIdentityQ[matrices_List, variables_List, transformation_?MatrixQ, target_List] := Module[
  {powers, bases, orders, roots, formal, relations, t, residual},
  powers = DeleteDuplicates @ Cases[{matrices, transformation, target},
    Power[b_, p_Rational] :> {Factor[b], Denominator[p]}, Infinity];
  bases = DeleteDuplicates[First /@ powers];
  orders = (LCM @@ Cases[powers, {#, n_} :> n]) & /@ bases;
  roots = Table[Unique["root$"], {Length[bases]}];
  formal[expr_] := expr /. Power[b_, p_Rational] /;
      MemberQ[bases, Factor[b]] :> With[
        {i = First @ FirstPosition[bases, Factor[b]]}, roots[[i]]^(p orders[[i]])];
  relations = MapThread[#1 -> #1^#2 - formal[#3] &, {roots, orders, bases}];
  t = formal[transformation];
  And @@ Table[
    residual = Fermatica`FPlus[
      Fermatica`FDot[formal[matrices[[i]]], t],
      -formal[D[transformation, variables[[i]]]],
      -Fermatica`FDot[t, formal[target[[i]]]]];
    residual = Fermatica`FQuolyMod[residual, relations];
    And @@ (TrueQ[# === 0] & /@ Flatten[residual]),
    {i, Length[variables]}]
];

GaugeTransform[matrices_List, variables_List, transformation_?MatrixQ] :=
 With[{inverse = Inverse[transformation]},
  MapThread[
    Map[Together, inverse.(#1.transformation - D[transformation, #2]), {2}] &,
    {matrices, variables}
  ]];

FlatConnectionQ[matrices_List, variables_List] := With[
  {sparse = SparseArray /@ matrices},
  And @@ (Function[pair, With[{i = pair[[1]], j = pair[[2]]},
    ZeroMatrixQ[D[matrices[[j]], variables[[i]]] -
      D[matrices[[i]], variables[[j]]] +
      Normal[sparse[[j]].sparse[[i]] - sparse[[i]].sparse[[j]]]]
  ]] /@ Subsets[Range[Length[variables]], {2}])
];

EpsilonFactorizedQ[matrices_List, regulator_Symbol] :=
  And @@ (FreeQ[Together[#/regulator], regulator] & /@ Flatten[matrices]);

CheckCoreCandidate[
  candidate_Association,
  matrices_List,
  variables_List,
  regulator_Symbol,
  index_Integer,
  inverseProposal_:Automatic
] := Module[
  {candidateID, construction, transformation, declared, computed, residuals,
    invertible, exactGauge, flat, epsilonForm, reasons, certifiedInverse,
    inverseVerification = "symbolic_inverse"},
  candidateID = candidate["candidate_id"];
  construction = candidate["construction_rejection"];
  If[StringQ[construction], Return[<|
    "candidate_id" -> candidateID, "index" -> index, "pass" -> False,
    "invertible" -> False, "rejection_signature" -> {construction}|>]];
  transformation = candidate["transformation"];
  declared = candidate["transformed_matrices"];
  (* A supplied row matrix is only a proposal. Both exact inverse identities
     must hold before it replaces symbolic determinant/inverse construction. *)
  certifiedInverse = MatrixQ[inverseProposal] &&
    Dimensions[inverseProposal] === Dimensions[transformation] &&
    ZeroMatrixQ[transformation.inverseProposal - IdentityMatrix[Length[transformation]]] &&
    ZeroMatrixQ[inverseProposal.transformation - IdentityMatrix[Length[transformation]]];
  invertible = TrueQ[certifiedInverse] || TrueQ[Together[Det[transformation]] =!= 0];
  If[!invertible, Return[<|
    "candidate_id" -> candidateID, "index" -> index, "pass" -> False,
    "invertible" -> False, "rejection_signature" -> {"singular_transformation"}|>]];
  If[TrueQ[certifiedInverse],
    inverseVerification = "two_sided_exact_identity";
    residuals = MapThread[#1.transformation - D[transformation, #2] -
      transformation.#3 &, {matrices, variables, declared}];
    exactGauge = And @@ (ZeroMatrixQ /@ residuals);
    (* The independently verified invertibility and exact source equation
       uniquely determine B. No provider flag or numerical test is trusted. *)
    computed = If[exactGauge, declared, MapThread[
      Map[Together, inverseProposal.(#1.transformation - D[transformation, #2]), {2}] &,
      {matrices, variables}]],
    computed = GaugeTransform[matrices, variables, transformation];
    residuals = MapThread[Map[Together, #1 - #2, {2}] &, {computed, declared}];
    exactGauge = And @@ (ZeroMatrixQ /@ residuals)
  ];
  flat = FlatConnectionQ[computed, variables];
  epsilonForm = EpsilonFactorizedQ[computed, regulator];
  reasons = Pick[
    {"gauge_residual", "nonflat_connection", "not_epsilon_factorized"},
    Not /@ {exactGauge, flat, epsilonForm}];
  <|
    "candidate_id" -> candidateID, "index" -> index, "pass" -> (reasons === {}),
    "invertible" -> invertible,
    "inverse_verification" -> inverseVerification,
    "exact_gauge" -> exactGauge,
    "flat_connection" -> flat,
    "epsilon_factorized" -> epsilonForm,
    "rejection_signature" -> reasons,
    "transformation" -> transformation,
    "transformed_matrices" -> computed
  |>
];

DLogAlphabet[matrices_List, variables_List, regulator_Symbol] := DeleteDuplicates @ Select[
  Flatten[(First /@ Rest[FactorList[Denominator[Together[#/regulator]]]]) & /@
    Flatten[matrices]],
  FreeQ[#, regulator] && !FreeQ[#, Alternatives @@ variables] &];

QuadraticRootLetters[matrices_List, variables_List] := Module[
  {bases, squareRoot, candidates = {}, a, c, numerators},
  squareRoot[value_] := Module[{factors = FactorList[Together[value]]},
    If[And @@ (EvenQ[Last[#]] & /@ Rest[factors]),
      Sqrt[factors[[1, 1]]] Times @@ (First[#]^(Last[#]/2) & /@ Rest[factors]),
      $Failed]];
  bases = DeleteDuplicates @ Cases[matrices,
    Power[b_, p_Rational] /; Denominator[p] === 2 :> Factor[b], Infinity];
  Do[
    If[PolynomialQ[base, variables] && Exponent[base, x] === 2,
      a = squareRoot[Coefficient[base, x, 2]];
      If[a =!= $Failed,
        c = squareRoot[Coefficient[base, x, 0]];
        numerators = If[c === $Failed, {D[base, x]/(2 a)},
          Expand /@ {a x - c, a x + c}];
        candidates = Join[candidates,
          ((# + Sqrt[base])/(# - Sqrt[base]) &) /@ numerators]
      ]
    ], {base, bases}, {x, variables}];
  DeleteDuplicates[candidates]
];

DLogResidues[matrices_List, variables_List, regulator_Symbol, alphabet_List] := Catch[Module[
  {powers, bases, orders, roots, relations, formal, numerator, fieldPowers,
   fieldBasis, fieldVector, points, logarithmicDerivatives, sampled, coefficientMatrix,
   pivotPositions, rows, columns, inverse, entry, entryResidues},
  If[!FreeQ[alphabet, regulator] || !EpsilonFactorizedQ[matrices, regulator],
    Return[$Failed]];
  If[alphabet === {}, Return[If[And @@ (ZeroMatrixQ /@ matrices), {}, $Failed]]];
  powers = DeleteDuplicates @ Cases[{matrices, alphabet},
    Power[b_, p_Rational] /; !FreeQ[b, Alternatives @@ variables] :>
      {Factor[b], Denominator[p]}, Infinity];
  bases = DeleteDuplicates[First /@ powers];
  orders = (LCM @@ Cases[powers, {#, n_} :> n]) & /@ bases;
  roots = Table[Unique["root$"], {Length[bases]}];
  formal[expr_] := expr /. Power[b_, p_Rational] /;
      MemberQ[bases, Factor[b]] :> With[
        {i = First @ FirstPosition[bases, Factor[b]]}, roots[[i]]^(p orders[[i]])];
  relations = MapThread[#1^#2 - formal[#3] &, {roots, orders, bases}];
  numerator[expr_] := With[{n = Numerator[Together[expr]]},
    If[roots === {}, n, Numerator[Together[Last @ PolynomialReduce[n, relations, roots]]]]];
  fieldPowers = Tuples[Range[0, # - 1] & /@ orders];
  fieldBasis = Times @@ MapThread[Power, {roots, #}] & /@ fieldPowers;
  fieldVector[expr_, point_] := Module[{q, rel, vector, n, d},
    q = Together[expr /. point];
    If[roots === {}, Return[{q}]];
    rel = relations /. point;
    vector[poly_] := With[{rules = CoefficientRules[
        Last @ PolynomialReduce[poly, rel, roots], roots]},
      Replace[fieldPowers, Join[rules, {_List -> 0}], {1}]];
    n = vector[Numerator[q]]; d = Denominator[q];
    LinearSolve[Transpose[vector[d #] & /@ fieldBasis], n]
  ];
  logarithmicDerivatives = Table[formal[Together[D[letter, direction]/letter]],
    {direction, variables}, {letter, alphabet}];
  points = Table[Thread[variables -> Prime[Range[Length[variables]] + k Length[variables]]],
    {k, 0, Ceiling[Length[alphabet]/Max[1, Length[variables] - 1]] + 1}];
  sampled = Table[Transpose[fieldVector[#, point] & /@ logarithmicDerivatives[[i]]],
    {point, points}, {i, Length[variables]}];
  coefficientMatrix = Flatten[sampled, 2];
  pivotPositions[a_] := (First @ FirstPosition[#, x_ /; x =!= 0, Missing[], {1}, Heads -> False] &) /@
    DeleteCases[RowReduce[a], {0..}];
  rows = pivotPositions[Transpose[coefficientMatrix]];
  columns = pivotPositions[coefficientMatrix];
  If[columns =!= {}, inverse = Inverse[coefficientMatrix[[rows, columns]]]];
  (* Samples fix candidate constants; every original direction is proved below. *)
  entry[entries_] := entry[entries] = Module[{values, sampledValues, solution},
    values = formal[Together[entries/regulator]];
    sampledValues = Flatten[Table[fieldVector[values[[i]], point],
      {point, points}, {i, Length[variables]}]];
    solution = ConstantArray[0, Length[alphabet]];
    If[columns =!= {}, solution[[columns]] = inverse.sampledValues[[rows]]];
    If[Cases[solution, _Symbol, Infinity] =!= {} ||
        !And @@ MapThread[TrueQ[numerator[Together[#1 - solution.#2]] === 0] &,
        {values, logarithmicDerivatives}], Throw[$Failed, DLogResidues]];
    solution
  ];
  entryResidues = Table[entry[matrices[[All, row, column]]],
    {row, Length[First[matrices]]}, {column, Length[First[matrices]]}];
  Table[entryResidues[[All, All, i]], {i, Length[alphabet]}]
], DLogResidues];

AlgebraicPrimitive[components_List, variables_List] := Catch[Module[
  {parts, classes, radicalPart, terms, prefactor, rational, den, factors, fd,
   degree, monomials, coefficients, ansatz, equations, solutions, solution,
   t, totalDegree, result = 0},
  radicalPart[term_] := Times @@ Cases[term,
    Power[b_, p_Rational] :> Factor[b]^Mod[p, 1], {0, Infinity}];
  terms[expr_] := With[{x = Expand[expr]}, If[Head[x] === Plus, List @@ x, {x}]];
  parts = (GroupBy[terms[#], radicalPart, Total] & /@ components);
  classes = Union @@ (Keys /@ parts);
  totalDegree[poly_] := Exponent[poly /. Thread[variables -> t variables], t];
  Do[
    rational = Together[Lookup[#, root, 0]/root] & /@ parts;
    If[!FreeQ[rational, Power[_, _Rational]], Throw[$Failed, AlgebraicPrimitive]];
    den = PolynomialLCM @@ (Denominator /@ rational);
    factors = Rest[FactorList[den]];
    prefactor = root/Times @@ (#[[1]]^Max[0, #[[2]] - 1] & /@ factors);
    fd = Together[D[prefactor, #]/prefactor] & /@ variables;
    rational = Together[root rational/prefactor];
    degree = Max[0, Max[(totalDegree[Numerator[#]] -
      totalDegree[Denominator[#]] + 1) & /@ DeleteCases[rational, 0]]];
    monomials = DeleteDuplicates[Times @@@ Tuples[Prepend[variables, 1], degree]];
    coefficients = Array[Unique["primitive$"] &, Length[monomials]];
    ansatz = coefficients.monomials;
    equations = Union @@ Table[Last /@ CoefficientRules[Numerator[Together[
      D[ansatz, variables[[i]]] + fd[[i]] ansatz - rational[[i]]]], variables],
      {i, Length[variables]}];
    solutions = Solve[Thread[equations == 0], coefficients];
    If[solutions === {}, Throw[$Failed, AlgebraicPrimitive]];
    solution = ansatz /. First[solutions] /. Thread[coefficients -> 0];
    result += prefactor solution,
    {root, classes}];
  Together[result]
], AlgebraicPrimitive];

DLogConnectionQ[matrices_List, variables_List, regulator_Symbol, alphabet_List] :=
  DLogResidues[matrices, variables, regulator, alphabet] =!= $Failed;

repairFailure[field_String, message_String] :=
  Failure["INVALID_STRUCTURED_REPAIR_INPUT", <|"Field" -> field, "Message" -> message|>];

exactMatrixListQ[matrices_, count_Integer, dimension_Integer] :=
  ListQ[matrices] && Length[matrices] === count &&
    And @@ (
      MatrixQ[#] && Dimensions[#] === {dimension, dimension} &&
        And @@ (ExactRationalExpressionQ /@ Flatten[#]) & /@ matrices
    );

sameMatrixListsQ[left_List, right_List] := Length[left] === Length[right] &&
  And @@ MapThread[ZeroMatrixQ[Map[Together, #1 - #2, {2}]] &, {left, right}];

matrixBlocks[matrices_List, rows_, columns_] := (#[[rows, columns]] & /@ matrices);

zeroMatrixListQ[matrices_List] := And @@ (ZeroMatrixQ /@ matrices);

ValidateStructuredRepairInput[
  prepared_Association,
  route_Association,
  request_Association
] := Module[
  {
    validated, identity, selected, prefix, frozen, target, search, variables,
    regulator, parameters, allowedSymbols, basis, matrices, alphabet, dimension,
    prefixDimension, prefixRows, tailRows, acceptedMatrices, acceptedBlocks,
    signature, expectedFullEntry, prefixDLog
  },
  validated = ValidatePreparedBasis[prepared];
  If[FailureQ[validated],
    Return[repairFailure["prepared_basis", "prepared basis did not pass canon-neu/prepared-basis/v1 validation"]]
  ];
  identity = prepared["identity"];
  selected = First @ Select[prepared["candidates"], TrueQ[Lookup[#, "selected", False]] &];
  prefix = prepared["frozen_lower_prefix"];
  If[
    Lookup[route, "schema", None] =!= "canon-neu/route-decision/v1" ||
      Lookup[route, "decision", None] =!= "REPAIR_WITH_LIBRA",
    Return[repairFailure["route_decision.decision", "route decision must be exactly REPAIR_WITH_LIBRA"]]
  ];
  If[
    Lookup[route, "preparation_id", None] =!= identity["preparation_id"] ||
      Lookup[route, "family_id", None] =!= identity["family_id"] ||
      Lookup[route, "basis_id", None] =!= identity["basis_id"] ||
      Lookup[route, "selected_candidate_id", None] =!= selected["candidate_id"],
    Return[repairFailure["route_decision.identity", "route identity or selected candidate does not match the prepared basis"]]
  ];
  If[Lookup[request, "schema", None] =!= "canon-neu/libra-structured-repair-input/v1",
    Return[repairFailure["schema", "unexpected repair request schema"]]
  ];
  If[
    Lookup[request, "preparation_id", None] =!= identity["preparation_id"] ||
      Lookup[request, "family_id", None] =!= identity["family_id"] ||
      Lookup[request, "basis_id", None] =!= identity["basis_id"] ||
      Lookup[request, "selected_candidate_id", None] =!= selected["candidate_id"],
    Return[repairFailure["identity", "repair request identity or selected candidate mismatch"]]
  ];
  If[
    Lookup[request, "coefficient_domain", None] =!= "exact-rational-functions" ||
      Lookup[request, "convention", None] =!= "old_basis = transformation . new_basis",
    Return[repairFailure["convention", "repair request requires the exact rational domain and old_basis transformation convention"]]
  ];
  variables = Lookup[request, "variables", None];
  regulator = Lookup[request, "regulator", None];
  parameters = Lookup[request, "parameters", None];
  basis = Lookup[request, "basis", None];
  matrices = Lookup[request, "original_matrices", None];
  If[
    variables =!= {First[identity["variables"]]} || Length[identity["variables"]] =!= 1 ||
      !MatchQ[regulator, _Symbol] || parameters =!= {} || !ListQ[basis] || basis === {},
    Return[repairFailure["differential_system", "v1 requires one variable, one regulator, and parameters={} in an ordered basis"]]
  ];
  If[variables =!= identity["variables"] || regulator =!= identity["regulator"],
    Return[repairFailure["differential_system.identity", "variables or regulator contradict the prepared basis"]]
  ];
  dimension = Length[basis];
  allowedSymbols = Join[variables, {regulator}, parameters];
  If[
    !exactMatrixListQ[matrices, Length[variables], dimension] ||
      !And @@ (DeclaredCoefficientDomainQ[#, allowedSymbols] & /@ Flatten[matrices]),
    Return[repairFailure["original_matrices", "full differential matrices must be exact rational square matrices in basis order"]]
  ];
  If[!FlatConnectionQ[matrices, variables],
    Return[repairFailure["original_matrices.flatness", "full differential connection is not flat"]]
  ];
  alphabet = Lookup[request, "alphabet", None];
  If[
    !ListQ[alphabet] || alphabet === {} ||
      !And @@ (DeclaredCoefficientDomainQ[#, allowedSymbols] & /@ alphabet) ||
      !FreeQ[alphabet, regulator],
    Return[repairFailure["alphabet", "declared alphabet must be nonempty, exact rational, and regulator independent"]]
  ];
  frozen = Lookup[request, "frozen_prefix", None];
  If[!AssociationQ[frozen], Return[repairFailure["frozen_prefix", "frozen-prefix contract is missing"]]];
  prefixDimension = Lookup[frozen, "dimension", None];
  acceptedMatrices = Lookup[frozen, "accepted_matrices", None];
  If[
    prefixDimension =!= 1 || dimension =!= 3 || Length[prepared["current_basis"]["basis"]] =!= 2 ||
      Lookup[request, "repair_scope", None] =!= "DIRECT_SUM_1X1_PREFIX_PLUS_2X2_TAIL_INTERNAL" ||
      Lookup[frozen, "prefix_id", None] =!= prefix["prefix_id"] ||
      Lookup[frozen, "basis", None] =!= prefix["basis"] ||
      Lookup[frozen, "order", None] =!= Range[prefixDimension] ||
      prefixDimension =!= Length[prefix["basis"]] ||
      basis =!= Join[prefix["basis"], prepared["current_basis"]["basis"]] ||
      !exactMatrixListQ[acceptedMatrices, Length[variables], prefixDimension] ||
      !And @@ (DeclaredCoefficientDomainQ[#, allowedSymbols] & /@ Flatten[acceptedMatrices]),
    Return[repairFailure["frozen_prefix", "v1 requires a direct-sum 1x1 accepted prefix plus an ordered 2x2 tail"]]
  ];
  prefixRows = 1 ;; prefixDimension;
  tailRows = prefixDimension + 1 ;; dimension;
  If[
    !sameMatrixListsQ[matrixBlocks[matrices, prefixRows, prefixRows], acceptedMatrices] ||
      !zeroMatrixListQ[matrixBlocks[matrices, prefixRows, tailRows]] ||
      !zeroMatrixListQ[matrixBlocks[matrices, tailRows, prefixRows]],
    Return[repairFailure["frozen_prefix.source_blocks", "v1 source must be the declared 1x1 prefix direct-summed with a 2x2 tail"]]
  ];
  (* The contract already restricts this prefix to one variable. The dlog gate
     includes epsilon factorization, so no duplicate regulator check is needed. *)
  prefixDLog = DLogConnectionQ[acceptedMatrices, variables, regulator, alphabet];
  If[!TrueQ[prefixDLog],
    Return[repairFailure[
      "frozen_prefix.accepted_matrices",
      "accepted 1x1 prefix must be flat, epsilon-factorized without residual regulator dependence, and in the declared dlog alphabet"
    ]]
  ];
  acceptedBlocks = Lookup[frozen, "accepted_blocks", None];
  If[
    Sort[acceptedBlocks] =!= Sort[{"prefix-prefix", "prefix-from-tail", "tail-from-prefix"}],
    Return[repairFailure["frozen_prefix.accepted_blocks", "v1 fixes all direct-sum prefix and cross blocks"]]
  ];
  If[
    Sort[Lookup[frozen, "forbidden_mixing", {}]] =!= Sort[{"prefix-from-tail", "tail-from-prefix"}],
    Return[repairFailure["frozen_prefix.forbidden_mixing", "v1 forbids both cross-block transformation mixings"]]
  ];
  target = Lookup[request, "localized_target", None];
  If[
    !AssociationQ[target] || Lookup[target, "scope", None] =!= "LOCALIZED_BLOCK" ||
      Lookup[target, "prepared_block", None] =!= "current-current" ||
      prepared["quality"]["localized_defect"]["block"] =!= "current-current" ||
      Lookup[target, "prepared_signature", None] =!= prepared["quality"]["localized_defect"]["signature"] ||
      !MatchQ[Lookup[target, "full_entry", None], {_Integer, _Integer}] ||
      Lookup[target, "failure_test", None] =!= "REGULATOR_INDEPENDENT_TERM",
    Return[repairFailure["localized_target", "localized target does not match the prepared defect signature"]]
  ];
  signature = target["prepared_signature"];
  If[
    Lookup[signature, "kind", None] =!= "epsilon-factorization" ||
      !IntegerQ[Lookup[signature, "row", None]] || !IntegerQ[Lookup[signature, "column", None]] ||
      !Between[signature["row"], {1, 2}] || !Between[signature["column"], {1, 2}],
    Return[repairFailure[
      "localized_target.prepared_signature",
      "v1 target must be an epsilon-factorization defect inside the 2x2 current-current tail"
    ]]
  ];
  expectedFullEntry = prefixDimension + {signature["row"], signature["column"]};
  If[target["full_entry"] =!= expectedFullEntry,
    Return[repairFailure["localized_target.full_entry", "full_entry must equal prefix_dimension + prepared current-current coordinates"]]
  ];
  search = Lookup[request, "search_evidence", None];
  If[!AssociationQ[search] || search =!= prepared["search_history"],
    Return[repairFailure["search_evidence", "repair search evidence must exactly match the validated prepared basis"]]
  ];
  If[!TrueQ[search["pool_exhausted"]],
    Return[repairFailure["search_evidence.pool_exhausted", "repair requires complete candidate-pool exhaustion"]]
  ];
  If[search["alternatives_remaining"] =!= 0,
    Return[repairFailure["search_evidence.pool_exhausted", "pool exhaustion contradicts remaining alternatives"]]
  ];
  If[
    Complement[
      Lookup[prepared["candidates"], "candidate_id", {}],
      search["attempted_candidate_ids"]
    ] =!= {},
    Return[repairFailure[
      "search_evidence.attempted_candidate_ids",
      "repair requires every declared candidate to be attempted"
    ]]
  ];
  request
];

StructuredRepairPublicationGate[
  request_Association,
  candidate_Association
] := Module[
  {
    variables, regulator, parameters, allowedSymbols, basis, original, frozen, target, dimension,
    prefixDimension, prefixRows, tailRows, transformation, declared, shape,
    exactDomain, invertible, prefixIdentity, forbiddenMixing, identityMatch,
    providerStatus, reasons
  },
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
  identityMatch =
    Lookup[candidate, "schema", None] === "canon-neu/libra-structured-repair-candidate/v1" &&
      Lookup[candidate, "preparation_id", None] === request["preparation_id"] &&
      Lookup[candidate, "family_id", None] === request["family_id"] &&
      Lookup[candidate, "basis_id", None] === request["basis_id"] &&
      Lookup[candidate, "selected_candidate_id", None] === request["selected_candidate_id"] &&
      Lookup[candidate, "basis", None] === basis &&
      Lookup[candidate, "variables", None] === variables &&
      Lookup[candidate, "regulator", None] === regulator &&
      Lookup[candidate, "parameters", None] === parameters &&
      Lookup[candidate, "repair_scope", None] === request["repair_scope"] &&
      Lookup[candidate, "coefficient_domain", None] === request["coefficient_domain"] &&
      Lookup[candidate, "convention", None] === request["convention"] &&
      Lookup[candidate, "original_matrices", None] === original &&
      Lookup[candidate, "frozen_prefix", None] === frozen &&
      Lookup[candidate, "localized_target", None] === target;
  providerStatus = Lookup[candidate, "provider_status", None] ===
    "PROVISIONAL/CANDIDATE_TRANSFORMATION";
  transformation = Lookup[candidate, "transformation", None];
  declared = Lookup[candidate, "transformed_matrices", None];
  shape = MatrixQ[transformation] && Dimensions[transformation] === {dimension, dimension} &&
    ListQ[declared] && Length[declared] === Length[variables] &&
    And @@ (MatrixQ[#] && Dimensions[#] === {dimension, dimension} & /@ declared);
  exactDomain = TrueQ[shape] &&
    And @@ (DeclaredCoefficientDomainQ[#, allowedSymbols] & /@ Flatten[transformation]) &&
    And @@ (DeclaredCoefficientDomainQ[#, allowedSymbols] & /@ Flatten[declared]);
  invertible = TrueQ[exactDomain] && TrueQ[Together[Det[transformation]] =!= 0];
  prefixIdentity = TrueQ[invertible] && ZeroMatrixQ[
    Map[Together, transformation[[prefixRows, prefixRows]] - IdentityMatrix[prefixDimension], {2}]
  ];
  forbiddenMixing = TrueQ[invertible] &&
    (!MemberQ[frozen["forbidden_mixing"], "prefix-from-tail"] ||
      ZeroMatrixQ[transformation[[prefixRows, tailRows]]]) &&
    (!MemberQ[frozen["forbidden_mixing"], "tail-from-prefix"] ||
      ZeroMatrixQ[transformation[[tailRows, prefixRows]]]);
  reasons = Pick[
    {
      "identity_or_order_mismatch", "forged_provider_status", "candidate_shape_invalid",
      "coefficient_domain_invalid", "singular_transformation", "frozen_prefix_modified",
      "forbidden_prefix_mixing"
    },
    {
      !TrueQ[identityMatch], !TrueQ[providerStatus], !TrueQ[shape], !TrueQ[exactDomain],
      !TrueQ[invertible], !TrueQ[prefixIdentity], !TrueQ[forbiddenMixing]
    }
  ];
  <|
    "pass" -> (reasons === {}),
    "reasons" -> reasons,
    "identity_and_order" -> TrueQ[identityMatch],
    "provider_status_provisional" -> TrueQ[providerStatus],
    "invertible" -> TrueQ[invertible],
    "frozen_prefix_identity" -> TrueQ[prefixIdentity],
    "forbidden_mixing_zero" -> TrueQ[forbiddenMixing]
  |>
];

End[];
EndPackage[];
