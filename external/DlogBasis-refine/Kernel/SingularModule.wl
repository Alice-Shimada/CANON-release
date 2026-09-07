(* Constant-target module lift over the supplied rational function parameters. *)

Options[SingularModuleLift] = {"SingularExecutable" -> "Singular"};

polynomialLCMList[expressions_List] := Fold[
  PolynomialLCM,
  1,
  Denominator[Together[#]]& /@ expressions
];

singularPolynomialString[expression_, rules_List] := StringReplace[
  ToString[InputForm[Expand[expression /. rules]]],
  "DlogBasis`Private`" -> ""
];

singularModuleString[rows_List, rules_List] := StringRiffle[
  ("[" <> StringRiffle[singularPolynomialString[#, rules]& /@ #, ","] <> "]")& /@ rows,
  ","
];

singularEmitProcedure = StringRiffle[{
  "proc dlogemit(matrix M, string tag)",
  "{",
  "  int i,j;",
  "  print(tag+\"_BEGIN\");",
  "  print(string(nrows(M))+\",\"+string(ncols(M)));",
  "  for(i=1;i<=nrows(M);i++){for(j=1;j<=ncols(M);j++){print(string(M[i,j]));}}",
  "  print(tag+\"_END\");",
  "}"
}, "\n"];

parseSingularPolynomial[string_String] := Block[
  {$Context = "DlogBasis`Private`", $ContextPath = {"System`"}},
  ToExpression[string, InputForm]
];

parseSingularMatrix[text_String, tag_String] := Module[
  {block, lines, dimensions, entries},
  block = First@StringCases[
    text,
    (tag <> "_BEGIN\n") ~~ body : Shortest[__] ~~ ("\n" <> tag <> "_END") :> body
  ];
  lines = StringSplit[StringTrim[block], "\n"];
  dimensions = ToExpression /@ StringSplit[First[lines], ","];
  entries = parseSingularPolynomial /@ Rest[lines];
  ArrayReshape[entries, dimensions]
];

singularRingData[ringSymbols_List] := Module[{safeSymbols},
  safeSymbols = Table[
    Symbol["DlogBasis`Private`r" <> ToString[i]],
    {i, Length[ringSymbols]}
  ];
  <|
    "Declaration" -> If[
      ringSymbols === {},
      "0,(dlogVariable),dp",
      "(0," <> StringRiffle[("r" <> ToString[#])& /@
        Range[Length[ringSymbols]], ","] <> "),(dlogVariable),dp"
    ],
    "ForwardRules" -> Thread[ringSymbols -> safeSymbols],
    "BackwardRules" -> Thread[safeSymbols -> ringSymbols]
  |>
];

runSingularScript[script_String, executable_String] := Module[{file, process},
  file = CreateTemporary[];
  Export[file, script <> "\nexit;\n", "Text"];
  process = RunProcess[{executable, "-q", file}];
  DeleteFile[file];
  process
];

(* First pass: normal forms decide which constant target combinations are in
   the source module. Syzygies are retained only as cut-kernel diagnostics. *)
singularNormalFormsAndSyzygies[
  sourceRows_List,
  targetRows_List,
  ringSymbols_List,
  executable_String
] := Module[{ring, script, process},
  ring = singularRingData[ringSymbols];
  script = StringRiffle[{
    singularEmitProcedure,
    "ring dlogring=" <> ring["Declaration"] <> ";",
    "option(redSB);",
    "module S=" <> singularModuleString[sourceRows, ring["ForwardRules"]] <> ";",
    "module T=" <> singularModuleString[targetRows, ring["ForwardRules"]] <> ";",
    "module B=std(S);",
    "module N=reduce(T,B); matrix NM=N;",
    "module Z=syz(S); matrix ZM=Z;",
    "dlogemit(NM,\"NORMAL_FORMS\");",
    "dlogemit(ZM,\"SYZYGIES\");"
  }, "\n"];
  process = runSingularScript[script, executable];
  <|
    "NormalFormMatrix" ->
      (parseSingularMatrix[process["StandardOutput"], "NORMAL_FORMS"] /.
        ring["BackwardRules"]),
    "SyzygyMatrix" ->
      (parseSingularMatrix[process["StandardOutput"], "SYZYGIES"] /.
        ring["BackwardRules"]),
    "StandardError" -> process["StandardError"]
  |>
];

(* A rational constant combination q of the target generators is reachable
   exactly when q annihilates every kinematic monomial of their normal forms. *)
constantTargetBasis[normalForms_List, ringSymbols_List] := Module[
  {targetCount, coefficientRows},
  targetCount = Last@Dimensions[normalForms];
  coefficientRows = DeleteCases[
    Flatten[
      Function[component,
        Module[{multiplier, polynomials, rules, monomials},
          multiplier = polynomialLCMList[component];
          polynomials = Expand[Together[# multiplier]]& /@ component;
          rules = CoefficientRules[#, ringSymbols]& /@ polynomials;
          monomials = DeleteDuplicates@Flatten[(First /@ #)& /@ rules, 1];
          Table[coefficientRuleValue[#, monomial]& /@ rules, {monomial, monomials}]
        ]
      ] /@ normalForms,
      1
    ],
    row_ /; AllTrue[row, dlogZeroQ]
  ];
  If[coefficientRows === {}, IdentityMatrix[targetCount], NullSpace[coefficientRows]]
];

singularLift[
  sourceRows_List,
  targetRows_List,
  ringSymbols_List,
  executable_String
] := Module[{ring, script, process},
  ring = singularRingData[ringSymbols];
  script = StringRiffle[{
    singularEmitProcedure,
    "ring dlogring=" <> ring["Declaration"] <> ";",
    "module S=" <> singularModuleString[sourceRows, ring["ForwardRules"]] <> ";",
    "module C=" <> singularModuleString[targetRows, ring["ForwardRules"]] <> ";",
    "matrix L=lift(S,C);",
    "dlogemit(L,\"LIFT\");"
  }, "\n"];
  process = runSingularScript[script, executable];
  parseSingularMatrix[process["StandardOutput"], "LIFT"] /.
    ring["BackwardRules"]
];

SingularModuleLift[
  higherRows_List,
  residueRows_List,
  kinematics_List,
  OptionsPattern[]
] := Module[
  {signature, candidateCount, higherCount, residueCount, source, targets,
   multipliers, clearedSource, clearedTargets, ringSymbols, firstPass,
   constants, constantTargets, liftMatrix, liftedDirections,
   directions, constantDirections, sourceOriginal, targetOriginal, residuals},
  signature = Join[higherRows, residueRows];
  candidateCount = If[signature === {}, 0, Length[First[signature]]];
  higherCount = Length[higherRows];
  residueCount = Length[residueRows];
  If[candidateCount === 0,
    Return[<|"Status" -> "EmptySignature", "CoefficientDirections" -> {},
      "ModuleLiftVerifiedQ" -> True|>]
  ];
  source = Transpose[signature];
  targets = Table[
    Join[ConstantArray[0, higherCount], UnitVector[residueCount, i]],
    {i, residueCount}
  ];
  multipliers = Table[
    polynomialLCMList[Join[source[[All, column]], targets[[All, column]]]],
    {column, higherCount + residueCount}
  ];
  clearedSource = Table[
    Expand[Together[source[[i, j]] multipliers[[j]]]],
    {i, candidateCount}, {j, higherCount + residueCount}
  ];
  clearedTargets = Table[
    Expand[targets[[i, j]] multipliers[[j]]],
    {i, residueCount}, {j, higherCount + residueCount}
  ];
  ringSymbols = kinematics;
  firstPass = singularNormalFormsAndSyzygies[
    clearedSource,
    If[residueCount === 0,
      {ConstantArray[0, higherCount]},
      clearedTargets
    ],
    ringSymbols,
    OptionValue["SingularExecutable"]
  ];
  constants = If[
    residueCount === 0,
    {},
    constantTargetBasis[firstPass["NormalFormMatrix"], ringSymbols]
  ];
  constantTargets = If[constants === {}, {}, constants.clearedTargets];
  liftMatrix = If[
    constantTargets === {},
    ConstantArray[0, {candidateCount, 0}],
    singularLift[
      clearedSource, constantTargets, ringSymbols,
      OptionValue["SingularExecutable"]
    ]
  ];
  liftedDirections = If[constantTargets === {}, {}, Transpose[liftMatrix]];
  directions = liftedDirections;
  constantDirections = constants;
  sourceOriginal = source;
  targetOriginal = targets;
  residuals = MapThread[
    Together /@ (#1.sourceOriginal - If[
      residueCount === 0,
      ConstantArray[0, higherCount],
      #2.targetOriginal
    ])&,
    {directions, constantDirections}
  ];
  <|
    "Status" -> If[directions === {}, "NoRationalDirections", "RationalDirectionsFound"],
    "CoefficientRing" -> <|
      "BaseField" -> "Q", "RationalFunctionParameters" -> kinematics|>,
    "ColumnMultipliers" -> multipliers,
    "ClearedSourceRows" -> clearedSource,
    "ClearedTargetRows" -> clearedTargets,
    "NormalFormMatrix" -> firstPass["NormalFormMatrix"],
    "ConstantTargetBasis" -> constants,
    "LiftMatrix" -> liftMatrix,
    "SyzygyMatrix" -> firstPass["SyzygyMatrix"],
    "CoefficientDirections" -> directions,
    "ConstantResidueDirections" -> constantDirections,
    "LiftResiduals" -> residuals,
    "ModuleLiftVerifiedQ" -> AllTrue[Flatten[residuals], dlogZeroQ]
  |>
];

multiquadraticFieldData[squareClasses_List] := Module[{roots, masks},
  roots = Table[Unique["DlogBasis`Private`algebraicRoot$"],
    {Length[squareClasses]}];
  masks = Tuples[{0, 1}, Length[squareClasses]];
  <|
    "SquareClasses" -> squareClasses,
    "Roots" -> roots,
    "Masks" -> masks,
    "Basis" -> (Times@@(roots^#)& /@ masks)
  |>
];

multiquadraticRootData[class_, field_Association] := Module[
  {coordinates, product, quotient},
  coordinates = squareClassCoordinates[class, field["SquareClasses"]];
  product = Times@@(field["SquareClasses"]^coordinates);
  quotient = squareFreeRootData[Factor[class/product]];
  <|
    "Coefficient" -> quotient["SquarePart"],
    "RootMonomial" -> Times@@Pick[field["Roots"], coordinates, 1]
  |>
];

formalizeMultiquadraticProduct[factors_List, field_Association] := Module[
  {radicals, rationalFactors, data, classData, rootData},
  radicals = Select[factors, halfPowerFactorQ];
  rationalFactors = Select[factors, !halfPowerFactorQ[#]&];
  If[radicals === {},
    Return[Times@@(
      formalizeMultiquadraticExpression[#, field]& /@ rationalFactors
    )]
  ];
  data = halfPowerFactorData /@ radicals;
  classData = squareFreeRootData[Times@@Lookup[data, "SquareClass"]];
  rootData = multiquadraticRootData[classData["SquareFreePart"], field];
  (Times@@Lookup[data, "Coefficient"])*classData["SquarePart"]*
    rootData["Coefficient"]*rootData["RootMonomial"]*
    Times@@(formalizeMultiquadraticExpression[#, field]& /@ rationalFactors)
];

formalizeMultiquadraticExpression[expression_Plus, field_Association] :=
  Total[formalizeMultiquadraticExpression[#, field]& /@ List@@expression];
formalizeMultiquadraticExpression[expression_Times, field_Association] :=
  formalizeMultiquadraticProduct[List@@expression, field];
formalizeMultiquadraticExpression[
  expression_?halfPowerFactorQ, field_Association
] := formalizeMultiquadraticProduct[{expression}, field];
formalizeMultiquadraticExpression[expression_Complex, field_Association] :=
  With[{root = multiquadraticRootData[-1, field]},
    Re[expression] + Im[expression] root["Coefficient"] root["RootMonomial"]
  ];
formalizeMultiquadraticExpression[
  Power[base_, exponent_], field_Association
] := formalizeMultiquadraticExpression[base, field]^exponent;
formalizeMultiquadraticExpression[expression_, _Association] := expression;

multiquadraticReducePolynomial[polynomial_, field_Association] := Fold[
  PolynomialRemainder[#1, #2[[1]]^2 - #2[[2]], #2[[1]]]&,
  Expand[polynomial],
  Transpose[{field["Roots"], field["SquareClasses"]}]
];

multiquadraticReducedRational[expression_, field_Association] := Module[
  {rational = Together[formalizeMultiquadraticExpression[expression, field]],
   reduce},
  reduce[polynomial_] := If[
    AllTrue[field["Roots"], Exponent[polynomial, #] <= 1&],
    polynomial,
    multiquadraticReducePolynomial[polynomial, field]
  ];
  Together[
    reduce[Numerator[rational]]/reduce[Denominator[rational]]
  ]
];

multiquadraticInverse[denominator_, field_Association] := Module[
  {numerator = 1, norm = denominator, conjugate},
  Do[
    conjugate = multiquadraticReducePolynomial[
      norm /. root -> -root, field
    ];
    numerator = multiquadraticReducePolynomial[numerator conjugate, field];
    norm = multiquadraticReducePolynomial[norm conjugate, field],
    {root, field["Roots"]}
  ];
  Together[numerator/norm]
];

multiquadraticCanonical[expression_, field_Association] := Module[
  {rational, numerator, denominator, inverse},
  rational = Together[formalizeMultiquadraticExpression[expression, field]];
  numerator = multiquadraticReducePolynomial[Numerator[rational], field];
  denominator = multiquadraticReducePolynomial[Denominator[rational], field];
  inverse = multiquadraticInverse[denominator, field];
  Factor[Together[
    multiquadraticReducePolynomial[numerator Numerator[inverse], field]/
      Denominator[inverse]
  ]]
];

multiquadraticComponents[expression_, field_Association] := Module[
  {canonical, rational, rules},
  canonical = multiquadraticCanonical[expression, field];
  rational = Together[canonical];
  rules = Association[CoefficientRules[Numerator[rational], field["Roots"]]];
  Together[#/Denominator[rational]]& /@
    Lookup[rules, field["Masks"], 0]
];

multiquadraticRowBlock[row_List, field_Association] := Transpose@Flatten[
  Table[
    multiquadraticComponents[row[[candidate]] field["Basis"][[basis]], field],
    {candidate, Length[row]}, {basis, Length[field["Basis"]]}
  ],
  1
];

multiquadraticSignatureComponents[{}, field_Association] :=
  ConstantArray[{}, Length[field["Basis"]]];
multiquadraticSignatureComponents[rows_List, field_Association] := Module[
  {components},
  components = (multiquadraticComponents[#, field]& /@ #)& /@ rows;
  Table[components[[All, All, basis]], {basis, Length[field["Basis"]]}]
];

multiquadraticDirection[direction_List, field_Association] := Module[
  {blocks, roots},
  blocks = Partition[direction, Length[field["Basis"]]];
  roots = Thread[field["Roots"] -> Sqrt[field["SquareClasses"]]];
  Factor[Together[#.field["Basis"] /. roots]]& /@ blocks
];

algebraicDirectionRebasis[
  virtualDirections_List, targets_List, field_Association, kinematics_List
] := Module[
  {directions, components, directionCount, candidateCount, degree,
   coefficients = {}, labels = {}, constraints, nullspace, trialRank,
   rebasedVirtual, rebasedDirections, rebasedTargets},
  If[virtualDirections === {},
    Return[<|"VirtualDirections" -> {}, "Directions" -> {}, "Targets" -> {},
      "Parities" -> {}|>]
  ];
  directions = multiquadraticDirection[#, field]& /@ virtualDirections;
  directionCount = Length[directions];
  candidateCount = Length[First[directions]];
  degree = Length[field["Basis"]];
  components = Table[
    multiquadraticComponents[directions[[direction, candidate]], field],
    {direction, directionCount}, {candidate, candidateCount}
  ];
  Do[
    constraints = Flatten[
      Table[
        Table[
          components[[direction, candidate, component]],
          {direction, directionCount}
        ],
        {candidate, candidateCount},
        {component, DeleteCases[Range[degree], basis]}
      ],
      1
    ];
    constraints = Flatten[
      rationalIdentityRows[#, kinematics]& /@ constraints, 1
    ];
    nullspace = If[constraints === {}, IdentityMatrix[directionCount],
      NullSpace[constraints]];
    Do[
      trialRank = MatrixRank[Append[coefficients, vector]];
      If[trialRank > Length[coefficients],
        coefficients = Append[coefficients, vector];
        labels = Append[labels, Which[
          basis === 1, "Even",
          degree === 2, "Odd",
          True, "Algebraic"
        ]]
      ],
      {vector, nullspace}
    ],
    {basis, degree}
  ];
  Do[
    trialRank = MatrixRank[Append[coefficients, vector]];
    If[trialRank > Length[coefficients],
      coefficients = Append[coefficients, vector];
      labels = Append[labels, "Algebraic"]
    ],
    {vector, IdentityMatrix[directionCount]}
  ];
  rebasedVirtual = coefficients.virtualDirections;
  rebasedDirections = multiquadraticDirection[#, field]& /@ rebasedVirtual;
  rebasedTargets = coefficients.targets;
  <|
    "VirtualDirections" -> rebasedVirtual,
    "Directions" -> rebasedDirections,
    "Targets" -> rebasedTargets,
    "Parities" -> labels
  |>
];

AlgebraicConstantLSLift[
  signature_Association,
  kinematics_List,
  executable_String
] := Module[
  {squareClasses, higher, residues, field, higherBlocks, residueBlocks,
   higherComponents, residueComponents, expandedHigher, expandedResidues,
   lift, rebased, directions},
  higher = Lookup[
    signature, "ModuleConstraintRows", signature["HigherPoleRows"]
  ];
  residues = signature["TerminalResidueRows"];
  higher = constantPhaseNormalizeRows[higher, kinematics];
  residues = constantPhaseNormalizeRows[residues, kinematics];
  squareClasses = independentSquareClasses[algebraicSquareClasses[
    Flatten[Join[higher, residues]]
  ]];
  If[squareClasses === {},
    lift = SingularModuleLift[
      higher, residues, kinematics, "SingularExecutable" -> executable
    ];
    Return[<|
      "Status" -> lift["Status"],
      "FieldBasis" -> {1},
      "ExpandedLift" -> lift,
      "CoefficientDirections" -> lift["CoefficientDirections"],
      "DirectionParities" -> ConstantArray[
        "Even", Length[lift["CoefficientDirections"]]
      ],
      "ConstantResidueDirections" -> lift["ConstantResidueDirections"],
      "ModuleLiftVerifiedQ" -> lift["ModuleLiftVerifiedQ"]
    |>]
  ];
  field = multiquadraticFieldData[squareClasses];
  higherComponents = multiquadraticSignatureComponents[higher, field];
  residueComponents = multiquadraticSignatureComponents[residues, field];
  higherBlocks = multiquadraticRowBlock[#, field]& /@ higher;
  residueBlocks = multiquadraticRowBlock[#, field]& /@ residues;
  expandedHigher = Join[
    Flatten[higherBlocks, 1],
    Flatten[Rest /@ residueBlocks, 1]
  ];
  expandedResidues = First /@ residueBlocks;
  lift = SingularModuleLift[
    expandedHigher, expandedResidues, kinematics,
    "SingularExecutable" -> executable
  ];
  rebased = algebraicDirectionRebasis[
    lift["CoefficientDirections"], lift["ConstantResidueDirections"], field,
    kinematics
  ];
  directions = rebased["Directions"];
  <|
    "Status" -> If[
      directions === {}, "NoAlgebraicConstantLSDirections",
      "AlgebraicConstantLSDirectionsFound"
    ],
    "FieldBasis" -> (field["Basis"] /.
      Thread[field["Roots"] -> Sqrt[field["SquareClasses"]]]),
    "ExpandedHigherPoleRows" -> expandedHigher,
    "ExpandedResidueRows" -> expandedResidues,
    "HigherPoleComponentRows" -> higherComponents,
    "ResidueComponentRows" -> residueComponents,
    "RationalHigherPoleRows" -> First[higherComponents],
    "AlgebraicHigherPoleRows" -> higherComponents[[2]],
    "RationalResidueRows" -> First[residueComponents],
    "AlgebraicResidueRows" -> residueComponents[[2]],
    "ExpandedLift" -> lift,
    "CoefficientDirections" -> directions,
    "DirectionParities" -> rebased["Parities"],
    "ConstantResidueDirections" -> rebased["Targets"],
    "ModuleLiftVerifiedQ" -> lift["ModuleLiftVerifiedQ"]
  |>
];
