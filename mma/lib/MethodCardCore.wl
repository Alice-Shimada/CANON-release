BeginPackage["CanonMethodCard`"];

ReadTask::usage = "ReadTask[path, step] reads and validates a script input envelope.";
ScriptArguments::usage = "ScriptArguments[] returns arguments following the active WL script.";
LoadArtifact::usage = "LoadArtifact[task, inputPath, name] reads one WL Association artifact.";
ResolveMethodPackage::usage = "ResolveMethodPackage[task, inputPath, context] resolves a workflow-declared package entry or the standard Wolfram package path.";
WriteWLArtifact::usage = "WriteWLArtifact[expr, outputDir, fileName] writes a new WL artifact.";
WriteResult::usage = "WriteResult[task, outputDir, status, code, artifacts, summary] writes result.json.";
ValidCutDEQ::usage = "ValidCutDEQ[expr] checks the sector-cut-DE artifact shape.";
ValidSectorBasisQ::usage = "ValidSectorBasisQ[expr] checks the sector-basis artifact shape.";
ValidCandidatesQ::usage = "ValidCandidatesQ[expr] checks the core-candidates artifact shape.";
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
  And @@ Table[
    residual = D[matrices[[j]], variables[[i]]] - D[matrices[[i]], variables[[j]]] +
      matrices[[j]].matrices[[i]] - matrices[[i]].matrices[[j]];
    ZeroMatrixQ[Map[Together, residual, {2}]],
    {{i, j}, pairs}
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
