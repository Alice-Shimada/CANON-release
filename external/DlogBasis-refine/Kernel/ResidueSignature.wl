(* Finite affine principal parts.  Positive-dimensional residues remain forms. *)

Options[FinitePoleSignature] = {
  "FiniteFlowPackageFile" -> Automatic,
  "InitialDivisors" -> {},
  "AllowLocalLinearCharts" -> False
};

loadFiniteFlow[Automatic] := If[
  DownValues[FiniteFlow`FFNewGraph] === {}, Needs["FiniteFlow`"]
];
loadFiniteFlow[file_String] := If[
  DownValues[FiniteFlow`FFNewGraph] === {}, Get[file]
];

(* FiniteFlow evaluates the full vector in one graph and reconstructs every
   coefficient from the leading Laurent power through t^-1. *)
finiteFlowPrincipalParts[
  forms_List,
  t_Symbol,
  parameters_List,
  packageFile_
] := Module[
  {inner, innerInput, evaluator, outer, outerInput, laurent, learn,
   reconstructed, lengths, coefficients},
  loadFiniteFlow[packageFile];
  inner = Unique["DlogBasis`Private`dlogInnerGraph$"];
  innerInput = Unique["DlogBasis`Private`dlogInnerInput$"];
  evaluator = Unique["DlogBasis`Private`dlogRationalEvaluator$"];
  outer = Unique["DlogBasis`Private`dlogLaurentGraph$"];
  outerInput = Unique["DlogBasis`Private`dlogOuterInput$"];
  laurent = Unique["DlogBasis`Private`dlogLaurentNode$"];
  FiniteFlow`FFNewGraph[inner, innerInput, Prepend[parameters, t]];
  FiniteFlow`FFAlgRatFunEval[
    inner, evaluator, {innerInput}, Prepend[parameters, t], Together /@ forms
  ];
  FiniteFlow`FFGraphOutput[inner, evaluator];
  FiniteFlow`FFNewGraph[outer, outerInput, parameters];
  FiniteFlow`FFAlgLaurent[outer, laurent, {outerInput}, inner, -1];
  FiniteFlow`FFGraphOutput[outer, laurent];
  learn = FiniteFlow`FFLaurentLearn[outer];
  reconstructed = If[
    parameters === {},
    FiniteFlow`FFReconstructNumeric[outer],
    FiniteFlow`FFReconstructFunction[outer, parameters]
  ];
  lengths = MapThread[Max[#2 - #1 + 1, 0]&, learn];
  coefficients = MapThread[
    Take[Drop[reconstructed, #1], #2]&,
    {Most[Accumulate[Prepend[lengths, 0]]], lengths}
  ];
  FiniteFlow`FFDeleteGraph[outer];
  FiniteFlow`FFDeleteGraph[inner];
  <|
    "StartingPowers" -> First[learn],
    "EndingPowers" -> Last[learn],
    "Coefficients" -> coefficients
  |>
];

finiteFlowLaurentCoefficient[data_Association, position_, power_] := Module[
  {start = data["StartingPowers"][[position]],
   end = data["EndingPowers"][[position]]},
  If[
    start === Infinity || power < start || power > end,
    0,
    data["Coefficients"][[position, power - start + 1]]
  ]
];

rationalFormQ[expression_, variables_List] := Module[{rational},
  rational = Together[expression];
  PolynomialQ[Numerator[rational], variables] &&
    PolynomialQ[Denominator[rational], variables]
];

polynomialOverRationalsQ[expression_, variables_List] :=
  PolynomialQ[expression, variables] && AllTrue[
    Last /@ CoefficientRules[Expand[expression], variables],
    MatchQ[#, _Integer | _Rational]&
  ];

rationalFormOverRationalsQ[expression_, variables_List] := Module[{rational},
  rational = Together[expression];
  polynomialOverRationalsQ[Numerator[rational], variables] &&
    polynomialOverRationalsQ[Denominator[rational], variables]
];

rationalLeadingData[expression_, variable_] := Module[
  {rational, numerator, denominator, numeratorOrder, denominatorOrder},
  rational = Together[expression];
  numerator = Numerator[rational];
  denominator = Denominator[rational];
  numeratorOrder = Exponent[numerator, variable, Min];
  denominatorOrder = Exponent[denominator, variable, Min];
  <|
    "Valuation" -> numeratorOrder - denominatorOrder,
    "LeadingCoefficient" -> Together[
      Coefficient[numerator, variable, numeratorOrder]/
        Coefficient[denominator, variable, denominatorOrder]
    ]
  |>
];

algebraicLeadingData[expression_, variable_] := Module[
  {powers, rational, rationalData, powerData, powerValuations,
   powerLeading, valuation, leading, normalizedLeading},
  powers = Cases[
    expression,
    Power[base_, exponent_Rational] /; Denominator[exponent] === 2 :>
      {base, exponent},
    {0, Infinity}
  ];
  rational = expression /. Power[_, exponent_Rational] /;
      Denominator[exponent] === 2 :> 1;
  rationalData = rationalLeadingData[rational, variable];
  powerData = rationalLeadingData[First[#], variable]& /@ powers;
  powerValuations = If[
    powerData === {}, {}, Lookup[powerData, "Valuation"]
  ];
  If[AnyTrue[powerValuations, # =!= 0&],
    Return[Failure["RamifiedCutDivisor", <|
      "Divisor" -> variable, "RootValuations" -> powerValuations|>]]
  ];
  valuation = rationalData["Valuation"] + Total[
    MapThread[#1 Last[#2]&, {powerValuations, powers}]
  ];
  If[!IntegerQ[valuation],
    Return[Failure["RamifiedCutDivisor", <|
      "Divisor" -> variable, "Valuation" -> valuation|>]]
  ];
  powerLeading = If[
    powerData === {}, {}, Lookup[powerData, "LeadingCoefficient"]
  ];
  leading = rationalData["LeadingCoefficient"] Times@@MapThread[
    #1^Last[#2]&, {powerLeading, powers}
  ];
  normalizedLeading = Cancel[Together[
      variable^-valuation expression/leading
    ]] /. variable -> 0;
  If[!dlogZeroQ[normalizedLeading - 1],
    Return[Failure["AlgebraicLeadingFactorUnresolved", <|
      "Divisor" -> variable, "NormalizedLeadingFactor" -> normalizedLeading
    |>]]
  ];
  <|
    "Valuation" -> valuation,
    "LeadingCoefficient" -> Factor[leading]
  |>
];

(* A common analytic factor acts unitriangularly on Laurent rows.  Removing it
   preserves the simultaneous higher-pole kernel; FiniteFlow expands only the
   rational candidate ratios, and the restricted leading factor is restored on
   the simple residue passed to the next variable. *)
commonFactorPrincipalPart[
  forms_List,
  variable_,
  parameters_List,
  packageFile_
] := Module[
  {pivot, pivotData, ratios, proxy, principal, starts, minimum, coefficient},
  pivot = SelectFirst[forms, !dlogZeroQ[#]&];
  ratios = Together[#/pivot]& /@ forms;
  If[!AllTrue[
      ratios,
      rationalFormOverRationalsQ[#, Prepend[parameters, variable]]&
    ],
    Return[Failure["NonCommonAlgebraicCutFactor", <|
      "Divisor" -> variable, "Ratios" -> ratios|>]]
  ];
  pivotData = algebraicLeadingData[pivot, variable];
  If[FailureQ[pivotData], Return[pivotData]];
  proxy = Together[variable^pivotData["Valuation"] #]& /@ ratios;
  principal = finiteFlowPrincipalParts[
    proxy, variable, parameters, packageFile
  ];
  starts = principal["StartingPowers"];
  minimum = Min[Append[Select[starts, IntegerQ[#] && # <= -1&], -1]];
  coefficient[power_] := Table[
    finiteFlowLaurentCoefficient[principal, position, power],
    {position, Length[forms]}
  ];
  <|
    "StartingPowers" -> starts,
    "CommonValuation" -> pivotData["Valuation"],
    "CommonLeadingFactor" -> pivotData["LeadingCoefficient"],
    "HigherPoleForms" -> Table[
      <|"Order" -> power, "CoefficientForm" -> coefficient[power]|>,
      {power, minimum, -2}
    ],
    "ResidueForm" ->
      pivotData["LeadingCoefficient"] coefficient[-1]
  |>
];

constantPhaseNormalizeRows[rows_List, variables_List] := Map[
  Function[row,
    If[
      AllTrue[row, dlogZeroQ],
      row,
      With[{pivot = Together@SelectFirst[row, !dlogZeroQ[#]&]},
        With[{
            phase = First@FactorTermsList[Numerator[pivot], variables]/
              First@FactorTermsList[Denominator[pivot], variables]
          },
          Factor[Together[#/phase]]& /@ row
        ]
      ]
    ]
  ],
  rows
];

commonRationalPhaseNormalize[forms_List, variables_List] := Module[
  {normalized},
  normalized = First@constantPhaseNormalizeRows[{forms}, variables];
  If[
    AllTrue[normalized, rationalFormOverRationalsQ[#, variables]&],
    normalized,
    Failure["NonCommonAlgebraicConstantPhase", <|
      "ReducedForms" -> forms, "NormalizedForms" -> normalized|>]
  ]
];

coefficientRuleValue[rules_List, monomial_List] :=
  Last@SelectFirst[rules, First[#] === monomial&, monomial -> 0];

finitePoleDivisors[forms_List, variables_List] := DeleteDuplicates@Flatten[
  Function[form,
    Select[
      First /@ Rest[FactorList[Denominator[Together[form]]]],
      !FreeQ[#, Alternatives@@variables]&
    ]
  ] /@ forms
];

linearDivisorCoordinate[
  divisor_, variables_List, allowLocalLinearCharts_
] := Module[{variable, rest, a, b},
  variable = SelectFirst[
    variables,
    Function[x,
      Exponent[divisor, x] === 1 &&
        (TrueQ[allowLocalLinearCharts] ||
          FreeQ[
            Coefficient[divisor, x],
            Alternatives@@DeleteCases[variables, x]
          ])
    ],
    Missing["NotLinearlyReducible"]
  ];
  If[MissingQ[variable], Return[variable]];
  rest = DeleteCases[variables, variable];
  a = Coefficient[divisor, variable];
  b = divisor /. variable -> 0;
  <|"Variable" -> variable, "RemainingVariables" -> rest,
    "LeadingCoefficient" -> a, "ConstantTerm" -> b|>
];

(* Turn a rational identity in residual coordinates into coefficient rows over
   the kinematic polynomial ring. *)
rationalIdentityRows[row_List, residualVariables_List] := Module[
  {denominators, multiplier, polynomials, rules, monomials},
  If[residualVariables === {}, Return[{Together /@ row}]];
  denominators = Denominator[Together[#]]& /@ row;
  multiplier = Fold[PolynomialLCM, 1, denominators];
  polynomials = Expand[Cancel[multiplier #]]& /@ row;
  rules = CoefficientRules[#, residualVariables]& /@ polynomials;
  monomials = DeleteDuplicates@Flatten[(First /@ #)& /@ rules, 1];
  Table[coefficientRuleValue[#, monomial]& /@ rules, {monomial, monomials}]
];

residueAlongDivisor[
  forms_List,
  variables_List,
  kinematics_List,
  divisor_,
  flag_List,
  packageFile_,
  allowLocalLinearCharts_
] := Module[
  {coordinate, x, remaining, a, b, t, position, transformed, principal,
   starts, minimum, coefficients, higherRecords, simple},
  coordinate = linearDivisorCoordinate[
    divisor, variables, allowLocalLinearCharts
  ];
  If[MissingQ[coordinate],
    Return[Failure["NonLinearDivisorUnresolved", <|
      "Divisor" -> divisor, "Flag" -> flag|>]]
  ];
  x = coordinate["Variable"];
  remaining = coordinate["RemainingVariables"];
  a = coordinate["LeadingCoefficient"];
  b = coordinate["ConstantTerm"];
  t = Unique["DlogBasis`Private`localDivisor$"];
  position = First@First@Position[variables, x];
  (* x=(t-b)/a and dx=(-1)^(position-1) dt/a fixes the flag orientation. *)
  transformed = Together[
    (-1)^(position - 1)/a*(# /. x -> (t - b)/a)
  ]& /@ forms;
  principal = finiteFlowPrincipalParts[
    transformed, t, Join[remaining, kinematics], packageFile
  ];
  starts = principal["StartingPowers"];
  minimum = Min[Append[Select[starts, # <= -1&], -1]];
  coefficients[power_] := Table[
    Together[finiteFlowLaurentCoefficient[principal, candidate, power]],
    {candidate, Length[forms]}
  ];
  higherRecords = Table[
    <|
      "Flag" -> Append[flag, divisor],
      "Divisor" -> divisor,
      "Order" -> power,
      "ResidualVariables" -> remaining,
      "CoefficientForm" -> coefficients[power],
      "IdentityRows" -> rationalIdentityRows[coefficients[power], remaining]
    |>,
    {power, minimum, -2}
  ];
  simple = coefficients[-1];
  <|
    "Flag" -> Append[flag, divisor],
    "Divisor" -> divisor,
    "EliminatedVariable" -> x,
    "RemainingVariables" -> remaining,
    "StartingPowers" -> starts,
    "HigherPoleRecords" -> higherRecords,
    "SimpleResidueForm" -> simple
  |>
];

residueTree[
  forms_List,
  variables_List,
  kinematics_List,
  flag_List,
  packageFile_,
  allowLocalLinearCharts_
] := Module[
  {divisors, higher = {}, terminals = {}, nodes = {}, unresolved = {}, branch,
   child},
  divisors = finitePoleDivisors[forms, variables];
  Do[
    branch = residueAlongDivisor[
      forms, variables, kinematics, divisor, flag, packageFile,
      allowLocalLinearCharts
    ];
    If[FailureQ[branch],
      unresolved = Append[unresolved, branch];
      Continue[]
    ];
    nodes = Append[nodes, KeyDrop[branch, {"HigherPoleRecords", "SimpleResidueForm"}]];
    higher = Join[higher, branch["HigherPoleRecords"]];
    If[!AllTrue[branch["SimpleResidueForm"], dlogZeroQ],
      If[branch["RemainingVariables"] === {},
        terminals = Append[terminals, <|
          "Flag" -> branch["Flag"],
          "ResidueRow" -> branch["SimpleResidueForm"]|>],
        child = residueTree[
          branch["SimpleResidueForm"], branch["RemainingVariables"],
          kinematics, branch["Flag"], packageFile, allowLocalLinearCharts
        ];
        higher = Join[higher, child["HigherPoleRecords"]];
        terminals = Join[terminals, child["TerminalResidueRecords"]];
        nodes = Join[nodes, child["Nodes"]];
        unresolved = Join[unresolved, child["UnresolvedDivisors"]]
      ]
    ],
    {divisor, divisors}
  ];
  <|
    "HigherPoleRecords" -> higher,
    "TerminalResidueRecords" -> terminals,
    "Nodes" -> nodes,
    "UnresolvedDivisors" -> unresolved
  |>
];

fixedInitialResidues[
  forms_List,
  variables_List,
  kinematics_List,
  divisors_List,
  packageFile_,
  allowLocalLinearCharts_
] := Module[
  {currentForms = forms, currentVariables = variables, flag = {}, higher = {},
   nodes = {}, branch, failure = Missing["NotFound"]},
  Do[
    branch = residueAlongDivisor[
      currentForms, currentVariables, kinematics, divisor, flag, packageFile,
      allowLocalLinearCharts
    ];
    If[FailureQ[branch], failure = branch; Break[]];
    higher = Join[higher, branch["HigherPoleRecords"]];
    nodes = Append[nodes, KeyDrop[branch, {"HigherPoleRecords", "SimpleResidueForm"}]];
    currentForms = branch["SimpleResidueForm"];
    currentVariables = branch["RemainingVariables"];
    flag = branch["Flag"],
    {divisor, divisors}
  ];
  If[FailureQ[failure], Return[failure]];
  <|"Forms" -> currentForms, "Variables" -> currentVariables, "Flag" -> flag,
    "HigherPoleRecords" -> higher, "Nodes" -> nodes|>
];

FinitePoleSignature[
  forms_List,
  variables_List,
  kinematics_List,
  OptionsPattern[]
] := Module[
  {allVariables, initial, fixed, tree, higherRecords, terminalRecords,
   unresolved},
  allVariables = Join[variables, kinematics];
  If[!AllTrue[forms, rationalFormOverRationalsQ[#, allVariables]&],
    Return[Failure["TwistedOrAlgebraicForm", <|"Forms" -> forms|>]]
  ];
  initial = OptionValue["InitialDivisors"];
  fixed = fixedInitialResidues[
    Together /@ forms, variables, kinematics, initial,
    OptionValue["FiniteFlowPackageFile"],
    OptionValue["AllowLocalLinearCharts"]
  ];
  If[FailureQ[fixed], Return[fixed]];
  tree = residueTree[
    fixed["Forms"], fixed["Variables"], kinematics, fixed["Flag"],
    OptionValue["FiniteFlowPackageFile"],
    OptionValue["AllowLocalLinearCharts"]
  ];
  higherRecords = Join[fixed["HigherPoleRecords"], tree["HigherPoleRecords"]];
  terminalRecords = tree["TerminalResidueRecords"];
  unresolved = tree["UnresolvedDivisors"];
  (* A zero-dimensional maximal cut itself is already a terminal flag. *)
  If[fixed["Variables"] === {} && !AllTrue[fixed["Forms"], dlogZeroQ],
    terminalRecords = {<|"Flag" -> fixed["Flag"],
      "ResidueRow" -> fixed["Forms"]|>}
  ];
  <|
    "Backend" -> "FiniteFlow",
    "Scope" -> "FiniteAffineMaximalCutFlags",
    "InitialDivisors" -> initial,
    "HigherPoleRecords" -> higherRecords,
    "HigherPoleRows" -> Flatten[Lookup[higherRecords, "IdentityRows", {}], 1],
    "TerminalResidueRecords" -> terminalRecords,
    "TerminalResidueRows" -> Lookup[terminalRecords, "ResidueRow", {}],
    "Nodes" -> Join[fixed["Nodes"], tree["Nodes"]],
    "UnresolvedDivisors" -> unresolved,
    "AffineAtlasCompleteQ" ->
      (unresolved === {} && !TrueQ[OptionValue["AllowLocalLinearCharts"]])
  |>
];

(* Algebraic maximal cuts.  Half-integer powers are reduced only after an
   exact square-factor certificate; no PowerExpand identity is used. *)

rationalSquareData[value : (_Integer | _Rational)] := Module[
  {numeratorFactors, denominatorFactors, squarePart},
  numeratorFactors = FactorInteger[Abs[Numerator[value]]];
  denominatorFactors = FactorInteger[Denominator[value]];
  squarePart =
    Times@@(#1^Quotient[#2, 2]& @@@ numeratorFactors)/
    Times@@(#1^Quotient[#2, 2]& @@@ denominatorFactors);
  <|
    "SquarePart" -> squarePart,
    "SquareFreePart" -> value/squarePart^2
  |>
];

squareFreeRootData[polynomial_] /; dlogZeroQ[polynomial] := <|
  "SquarePart" -> 0, "SquareFreePart" -> 1
|>;

squareFreeRootData[polynomial_] := Module[
  {factors, content, contentData, squarePart, squareFreePart},
  factors = FactorList[polynomial];
  content = Apply[Power, First[factors]];
  contentData = rationalSquareData[content];
  squarePart = contentData["SquarePart"]*
    Times@@(#1^Quotient[#2, 2]& @@@ Rest[factors]);
  squareFreePart = contentData["SquareFreePart"]*
    Times@@(#1^Mod[#2, 2]& @@@ Rest[factors]);
  <|
    "SquarePart" -> Factor[squarePart],
    "SquareFreePart" -> Factor[squareFreePart]
  |>
];

reduceCertifiedHalfPowers[expression_] := Factor[Together[
  expression /. Power[base_, exponent_Rational] /;
      Denominator[exponent] === 2 :>
    With[{data = squareFreeRootData[base]},
      base^(exponent - 1/2)*data["SquarePart"]*
        Sqrt[data["SquareFreePart"]]
  ]
]];

halfPowerFactorQ[Power[_, exponent_Rational]] :=
  Denominator[exponent] === 2;
halfPowerFactorQ[_] := False;

halfPowerFactorData[Power[base_, exponent_Rational]] := Module[{data},
  data = squareFreeRootData[base];
  <|
    "Coefficient" -> base^(exponent - 1/2) data["SquarePart"],
    "SquareClass" -> data["SquareFreePart"]
  |>
];

complexHalfPowerRadicands[expressions_] := DeleteDuplicates@Cases[
  expressions,
  Power[base_, exponent_Rational] /;
      Denominator[exponent] === 2 && !FreeQ[base, _Complex] :> base,
  Infinity
];

squareClassProduct[left_, right_] :=
  squareFreeRootData[left right]["SquareFreePart"];

squareClassProducts[left_List, right_List] := DeleteDuplicates@Flatten[
  Outer[squareClassProduct, left, right], 1
];

(* Radical factors in one monomial define the product square class. *)
expressionSquareClasses[expression_Plus] := DeleteDuplicates@Flatten[
  expressionSquareClasses /@ List@@expression
];
expressionSquareClasses[expression_Times] := Fold[
  squareClassProducts, {1}, expressionSquareClasses /@ List@@expression
];
expressionSquareClasses[expression_?halfPowerFactorQ] :=
  {halfPowerFactorData[expression]["SquareClass"]};
expressionSquareClasses[Power[base_, _]] := expressionSquareClasses[base];
expressionSquareClasses[_] := {1};

algebraicSquareClasses[expressions_List] := DeleteCases[
  DeleteDuplicates@Join[
    Flatten[expressionSquareClasses /@ expressions],
    If[FreeQ[expressions, _Complex], {}, {-1}]
  ],
  1
];

(* Square classes form an F2-vector space over the irreducible factors of the
   kinematic rational-function field.  Keep only an independent field basis. *)
rationalSquareClassKeys[value : (_Integer | _Rational)] := Join[
  If[value < 0, {-1}, {}],
  First /@ Select[
    FactorInteger[Abs[Numerator[value]]], First[#] =!= 1 && OddQ[Last[#]]&
  ],
  First /@ Select[
    FactorInteger[Denominator[value]], First[#] =!= 1 && OddQ[Last[#]]&
  ]
];

squareClassKeys[class_] := Module[{factors = FactorList[Factor[class]]},
  DeleteDuplicates@Join[
    rationalSquareClassKeys[First[factors][[1]]],
    First /@ Select[Rest[factors], OddQ[Last[#]]&]
  ]
];

squareClassVectorData[classes_List] := Module[{keys},
  keys = DeleteDuplicates@Flatten[squareClassKeys /@ classes];
  <|
    "Keys" -> keys,
    "Vectors" -> Table[
      Boole[MemberQ[squareClassKeys[class], key]],
      {class, classes}, {key, keys}
    ]
  |>
];

gf2Rank[{}] := 0;
gf2Rank[matrix_List] := Count[
  RowReduce[matrix, Modulus -> 2], row_ /; AnyTrue[row, # =!= 0&]
];

independentSquareClasses[classes_List] := Module[
  {normalized, data, selected = {}, rank = 0, trial},
  normalized = DeleteCases[
    DeleteDuplicates[
      squareFreeRootData[Factor[#]]["SquareFreePart"]& /@ classes
    ],
    1
  ];
  If[normalized === {}, Return[{}]];
  data = squareClassVectorData[normalized]["Vectors"];
  Do[
    trial = gf2Rank[data[[Append[selected, position]]]];
    If[trial > rank, selected = Append[selected, position]; rank = trial],
    {position, Length[normalized]}
  ];
  normalized[[selected]]
];

squareClassCoordinates[class_, basis_List] := Module[{data},
  If[basis === {}, Return[{}]];
  data = squareClassVectorData[Append[basis, class]]["Vectors"];
  LinearSolve[Transpose[Most[data]], Last[data], Modulus -> 2]
];

algebraicFieldDescriptors[expressions_List] := Module[{basis},
  basis = independentSquareClasses[Factor /@ algebraicSquareClasses[expressions]];
  <|
    "Generator" -> Sqrt[#],
    "MinimalPolynomialCoefficients" -> {-#, 0, 1},
    "SquareClass" -> #
  |>& /@ basis
];

(* Represent a certified one-class expression in Q(kinematics)[root]. *)
formalizeQuadraticProduct[factors_List, radicand_, root_] := Module[
  {radicals, rationalFactors, data, classData, rootFactor},
  radicals = Select[factors, halfPowerFactorQ];
  rationalFactors = Select[factors, !halfPowerFactorQ[#]&];
  If[radicals === {},
    Return[Times@@(
      formalizeQuadraticExpression[#, radicand, root]& /@ rationalFactors
    )]
  ];
  data = halfPowerFactorData /@ radicals;
  classData = squareFreeRootData[Times@@Lookup[data, "SquareClass"]];
  rootFactor = classData["SquarePart"] If[
    classData["SquareFreePart"] === 1, 1, root
  ];
  (Times@@Lookup[data, "Coefficient"]) rootFactor (Times@@(
    formalizeQuadraticExpression[#, radicand, root]& /@ rationalFactors
  ))
];

formalizeQuadraticExpression[expression_Plus, radicand_, root_] :=
  Total[formalizeQuadraticExpression[#, radicand, root]& /@
    List@@expression];
formalizeQuadraticExpression[expression_Times, radicand_, root_] :=
  formalizeQuadraticProduct[List@@expression, radicand, root];
formalizeQuadraticExpression[expression_?halfPowerFactorQ, radicand_, root_] :=
  formalizeQuadraticProduct[{expression}, radicand, root];
formalizeQuadraticExpression[Power[base_, exponent_], radicand_, root_] :=
  formalizeQuadraticExpression[base, radicand, root]^exponent;
formalizeQuadraticExpression[expression_, _, _] := expression;

(* A two-variable quadratic cover with Q(0,w)=+/-c(w)^2 and c(w)!=0 has two rational
   charts.  They are used only as local exact-dlog charts; no global atlas or
   infinity claim is made. *)
rationalConicCharts[forms_List, variables_List, kinematics_List] := Module[
  {normalized, classes, radicand, coordinateData, coordinate, x, position,
   pointClass, rationalRadicand, c, a, b, root, phase, charts},
  If[Length[variables] =!= 2,
    Return[Failure["RationalConicUnavailable", <||>]]
  ];
  normalized = First@constantPhaseNormalizeRows[
    {reduceCertifiedHalfPowers /@ forms}, Join[variables, kinematics]
  ];
  classes = Factor /@ algebraicSquareClasses[normalized];
  If[Length[classes] =!= 1,
    Return[Failure["RationalConicUnavailable", <|
      "SquareClasses" -> classes|>]]
  ];
  radicand = First[classes];
  coordinateData = Table[
    With[{constant = Factor[radicand /. variable -> 0]},
      <|
        "Coordinate" -> variable,
        "Degree" -> Exponent[radicand, variable],
        "PointData" -> If[
          dlogZeroQ[constant], Missing["ZeroPoint"],
          squareFreeRootData[constant]
        ]
      |>
    ],
    {variable, variables}
  ];
  coordinate = SelectFirst[
    coordinateData,
    0 < #["Degree"] <= 2 &&
      AssociationQ[#["PointData"]] &&
      MemberQ[{1, -1}, #["PointData"]["SquareFreePart"]]&,
    Missing["NoRationalPoint"]
  ];
  If[MissingQ[coordinate],
    Return[Failure["RationalConicUnavailable", <|
      "SquareClass" -> radicand|>]]
  ];
  x = coordinate["Coordinate"];
  position = First@First@Position[variables, x];
  pointClass = coordinate["PointData"]["SquareFreePart"];
  rationalRadicand = Factor[pointClass radicand];
  c = squareFreeRootData[Factor[rationalRadicand /. x -> 0]]["SquarePart"];
  a = Coefficient[rationalRadicand, x, 2];
  b = Coefficient[rationalRadicand, x, 1];
  root = Unique["DlogBasis`Private`conicRoot$"];
  phase = If[pointClass === 1, 1, I];
  charts = Table[
    Module[{t, signedC, xMap, rootMap, identity, newVariables, transformed},
      t = Unique["DlogBasis`Private`conicParameter$"];
      signedC = sign c;
      xMap = Factor[(b - 2 signedC t)/(t^2 - a)];
      rootMap = Factor[signedC + t xMap];
      identity = Factor[Together[
        rootMap^2 - (rationalRadicand /. x -> xMap)
      ]];
      If[!dlogZeroQ[identity],
        Failure["RationalConicIdentityFailed", <|
          "SquareClass" -> radicand, "Coordinate" -> x|>],
        newVariables = ReplacePart[variables, position -> t];
        transformed = Factor[Together[
            D[xMap, t] (
              formalizeQuadraticExpression[#, radicand, root] /.
                {root -> phase rootMap, x -> xMap}
            )
          ]]& /@ normalized;
        transformed = commonRationalPhaseNormalize[
          transformed, Join[newVariables, kinematics]
        ];
        If[
          FailureQ[transformed],
          transformed,
          <|
            "Coordinate" -> x,
            "Parameter" -> t,
            "Variables" -> newVariables,
            "CoordinateMap" -> xMap,
            "RootMap" -> phase rootMap,
            "Forms" -> transformed
          |>
        ]
      ]
    ],
    {sign, {1, -1}}
  ];
  If[AnyTrue[charts, FailureQ], Return[SelectFirst[charts, FailureQ]]];
  charts
];

squareRootAlgebraicFormQ[expression_, variables_List] := Module[
  {powers, rationalPart},
  powers = Cases[
    expression,
    Power[base_, exponent_Rational] /;
        Denominator[exponent] === 2 :> base,
    Infinity
  ];
  rationalPart = expression /. Power[_, exponent_Rational] /;
      Denominator[exponent] === 2 :> 1;
  AllTrue[powers, rationalFormQ[#, variables]&] &&
    rationalFormQ[rationalPart, variables]
];

orderedAlgebraicCut[
  forms_List,
  variables_List,
  cutVariables_List,
  kinematics_List,
  packageFile_
] := Module[
  {currentForms = forms, currentVariables = variables, higher = {}, data,
   position, remaining, failure = Missing["NotFound"]},
  Do[
    position = First@First@Position[currentVariables, variable];
    remaining = DeleteCases[currentVariables, variable];
    currentForms = (-1)^(position - 1) currentForms;
    data = commonFactorPrincipalPart[
      currentForms, variable, Join[remaining, kinematics], packageFile
    ];
    If[FailureQ[data], failure = data; Break[]];
    higher = Join[higher, Map[
      Join[<|"Divisor" -> variable,
        "RemainingVariables" -> remaining|>, #]&,
      data["HigherPoleForms"]
    ]];
    currentForms = data["ResidueForm"];
    currentVariables = remaining,
    {variable, cutVariables}
  ];
  If[FailureQ[failure], Return[failure]];
  <|
    "Forms" -> currentForms,
    "Variables" -> currentVariables,
    "HigherPoleRecords" -> higher
  |>
];

algebraicIdentityRows[records_List] := Flatten[
  Function[record,
    Module[{row, pivot, normalized},
      row = reduceCertifiedHalfPowers /@ record["CoefficientForm"];
      pivot = SelectFirst[row, !dlogZeroQ[#]&];
      normalized = Factor[Together[#/pivot]]& /@ row;
      rationalIdentityRows[normalized, record["RemainingVariables"]]
    ]
  ] /@ records,
  1
];

algebraicLocalPrincipalPart[
  forms_List, variable_, root_, parameters_List, packageFile_
] := Module[
  {local, unsupported, squareClasses, field, formal, principal, starts, minimum,
   backRules, coefficient},
  local = Together[# /. variable -> variable + root]& /@ forms;
  unsupported = complexHalfPowerRadicands[local];
  If[unsupported =!= {},
    Return[Failure["UnsupportedNestedComplexSquareClass", <|
      "Radicands" -> unsupported|>]]
  ];
  local = reduceCertifiedHalfPowers /@ local;
  squareClasses = independentSquareClasses[algebraicSquareClasses[local]];
  If[!FreeQ[squareClasses, variable],
    Return[Failure["VariableDependentAlgebraicRootUnresolved", <|
      "Variable" -> variable, "SquareClasses" -> squareClasses|>]]
  ];
  field = multiquadraticFieldData[squareClasses];
  formal = multiquadraticReducedRational[#, field]& /@ local;
  principal = finiteFlowPrincipalParts[
    formal, variable,
    DeleteDuplicates@Join[parameters, field["Roots"]],
    packageFile
  ];
  starts = principal["StartingPowers"];
  minimum = Min[Append[Select[starts, # < -1&], -1]];
  backRules = Thread[
    field["Roots"] -> Sqrt[field["SquareClasses"]]
  ];
  coefficient[power_] := reduceCertifiedHalfPowers /@ (
    Table[
      Factor[Together[
        finiteFlowLaurentCoefficient[principal, position, power] /. backRules
      ]],
      {position, Length[forms]}
    ]
  );
  <|
    "HigherPoleRows" -> Table[
      <|"Order" -> power, "CoefficientRow" -> coefficient[power]|>,
      {power, minimum, -2}
    ],
    "ResidueRow" -> coefficient[-1]
  |>
];

certifiedSquareRoot[polynomial_] := Module[{data},
  If[!FreeQ[polynomial, Power[_, exponent_Rational] /;
      Denominator[exponent] === 2],
    Return[Failure["NestedSquareRootDivisor", <|
      "Radicand" -> polynomial|>]]
  ];
  data = squareFreeRootData[Factor[polynomial]];
  data["SquarePart"] Sqrt[data["SquareFreePart"]]
];

algebraicDivisorCoordinate[divisor_, variables_List] := Module[
  {variable, degree, a, b, c, root},
  variable = SelectFirst[
    variables, MemberQ[{1, 2}, Exponent[divisor, #]]&,
    Missing["NotQuadraticallyReducible"]
  ];
  If[MissingQ[variable], Return[variable]];
  degree = Exponent[divisor, variable];
  If[degree === 1,
    Return[<|
      "Variable" -> variable,
      "Roots" -> {-Coefficient[divisor, variable, 0]/
        Coefficient[divisor, variable]}
    |>]
  ];
  a = Coefficient[divisor, variable, 2];
  b = Coefficient[divisor, variable, 1];
  c = Coefficient[divisor, variable, 0];
  root = Factor[b^2 - 4 a c];
  If[dlogZeroQ[root],
    Return[<|"Variable" -> variable, "Roots" -> {Factor[-b/(2 a)]}|>]
  ];
  root = certifiedSquareRoot[root];
  If[FailureQ[root], Return[root]];
  <|
    "Variable" -> variable,
    "Roots" -> {Factor[(-b + root)/(2 a)], Factor[(-b - root)/(2 a)]}
  |>
];

algebraicResidueBranches[
  forms_List, variables_List, kinematics_List, divisor_, flag_List, packageFile_
] := Module[{coordinate, variable, remaining, position, branches},
  coordinate = algebraicDivisorCoordinate[divisor, variables];
  If[MissingQ[coordinate],
    Return[Failure["NonQuadraticDivisorUnresolved", <|
      "Divisor" -> divisor, "Flag" -> flag|>]]
  ];
  If[FailureQ[coordinate], Return[coordinate]];
  variable = coordinate["Variable"];
  remaining = DeleteCases[variables, variable];
  position = First@First@Position[variables, variable];
  branches = Function[root,
    Module[{local, branchFlag, higher},
      branchFlag = Append[flag, <|"Divisor" -> divisor, "Root" -> root|>];
      local = algebraicLocalPrincipalPart[
        (-1)^(position - 1) forms, variable, root,
        Join[remaining, kinematics], packageFile
      ];
      If[FailureQ[local],
        local,
        higher = Map[
          Join[
            <|"Flag" -> branchFlag, "Divisor" -> divisor, "Root" -> root,
              "ResidualVariables" -> remaining|>,
            #,
            <|"IdentityRows" -> rationalIdentityRows[
              #["CoefficientRow"], remaining
            ]|>
          ]&,
          local["HigherPoleRows"]
        ];
        <|
          "Flag" -> branchFlag,
          "Divisor" -> divisor,
          "Root" -> root,
          "EliminatedVariable" -> variable,
          "RemainingVariables" -> remaining,
          "HigherPoleRecords" -> higher,
          "SimpleResidueForm" -> local["ResidueRow"]
        |>
      ]
    ]
  ] /@ coordinate["Roots"];
  If[MemberQ[branches, _Failure], FirstCase[branches, _Failure], branches]
];

algebraicFinitePoleDivisors[forms_List, variables_List] := Module[
  {divisors, coveredQuadraticQ},
  divisors = finitePoleDivisors[forms, variables];
  coveredQuadraticQ[divisor_] := Module[{coordinate, variable},
    coordinate = algebraicDivisorCoordinate[divisor, variables];
    If[!AssociationQ[coordinate] || Length[coordinate["Roots"]] =!= 2,
      Return[False]
    ];
    variable = coordinate["Variable"];
    AllTrue[
      coordinate["Roots"],
      Function[root,
        AnyTrue[
          DeleteCases[divisors, divisor],
          Exponent[#, variable] === 1 && dlogZeroQ[
            reduceCertifiedHalfPowers[# /. variable -> root]
          ]&
        ]
      ]
    ]
  ];
  SortBy[
    Select[divisors, !coveredQuadraticQ[#]&],
    Function[divisor,
      With[{degrees = Exponent[divisor, #]& /@ variables},
        {Min[Select[degrees, # > 0&]], Total[degrees], LeafCount[divisor]}
      ]
    ]
  ]
];

restrictedAlgebraicDivisors[
  divisors_List, variable_, root_, remaining_List
] := Module[{restricted},
  restricted = reduceCertifiedHalfPowers[Factor[# /. variable -> root]]& /@
    divisors;
  restricted = Select[
    restricted,
    !dlogZeroQ[#] && !FreeQ[#, Alternatives@@remaining]&
  ];
  If[restricted === {}, {},
    algebraicFinitePoleDivisors[1/#& /@ restricted, remaining]
  ]
];

algebraicResidueTreeOrdered[
  forms_List, variables_List, kinematics_List, flag_List, divisors_List,
  packageFile_
] := Module[
  {higher = {}, terminals = {}, nodes = {}, unresolved = {}, divisor,
   branches, child, childDivisors},
  Do[
    divisor = divisors[[position]];
    branches = algebraicResidueBranches[
      forms, variables, kinematics, divisor, flag, packageFile
    ];
    If[FailureQ[branches], unresolved = Append[unresolved, branches]; Continue[]];
    Do[
      nodes = Append[nodes,
        KeyDrop[branch, {"HigherPoleRecords", "SimpleResidueForm"}]];
      higher = Join[higher, branch["HigherPoleRecords"]];
      If[!AllTrue[branch["SimpleResidueForm"], dlogZeroQ],
        If[branch["RemainingVariables"] === {},
          terminals = Append[terminals, <|
            "Flag" -> branch["Flag"],
            "ResidueRow" -> branch["SimpleResidueForm"]|>],
          childDivisors = restrictedAlgebraicDivisors[
            Drop[divisors, position], branch["EliminatedVariable"],
            branch["Root"], branch["RemainingVariables"]
          ];
          child = algebraicResidueTreeOrdered[
            branch["SimpleResidueForm"], branch["RemainingVariables"],
            kinematics, branch["Flag"], childDivisors, packageFile
          ];
          higher = Join[higher, child["HigherPoleRecords"]];
          terminals = Join[terminals, child["TerminalResidueRecords"]];
          nodes = Join[nodes, child["Nodes"]];
          unresolved = Join[unresolved, child["UnresolvedDivisors"]]
        ]
      ],
      {branch, branches}
    ],
    {position, Length[divisors]}
  ];
  <|
    "HigherPoleRecords" -> higher,
    "TerminalResidueRecords" -> terminals,
    "Nodes" -> nodes,
    "UnresolvedDivisors" -> unresolved
  |>
];

algebraicResidueTree[
  forms_List, variables_List, kinematics_List, flag_List, packageFile_
] := algebraicResidueTreeOrdered[
  forms, variables, kinematics, flag,
  algebraicFinitePoleDivisors[reduceCertifiedHalfPowers /@ forms, variables],
  packageFile
];

univariateAlgebraicSignature[
  forms_List, variable_, kinematics_List, packageFile_
] := Module[
  {reduced, factors, records = {}, higher = {}, terminals = {}, divisor,
   degree, a, b, c, discriminant, roots, local,
   failure = Missing["NotFound"]},
  reduced = reduceCertifiedHalfPowers /@ forms;
  If[!FreeQ[
      reduced,
      Power[base_, exponent_Rational] /;
        Denominator[exponent] === 2 && !FreeQ[base, variable]
    ],
    Return[Failure["VariableDependentAlgebraicRootUnresolved", <|
      "Variable" -> variable, "Forms" -> reduced|>]]
  ];
  factors = DeleteDuplicates@Flatten[
    Function[form,
      First /@ Select[
        Rest[FactorList[Denominator[Together[form]]]],
        !FreeQ[First[#], variable]&
      ]
    ] /@ reduced
  ];
  Do[
    degree = Exponent[divisor, variable];
    roots = Switch[degree,
      1,
        {-Coefficient[divisor, variable, 0]/
          Coefficient[divisor, variable]},
      2,
        a = Coefficient[divisor, variable, 2];
        b = Coefficient[divisor, variable, 1];
        c = Coefficient[divisor, variable, 0];
        discriminant = Factor[b^2 - 4 a c];
        {(-b + Sqrt[discriminant])/(2 a),
          (-b - Sqrt[discriminant])/(2 a)},
      _,
        failure = Failure["HigherDegreeAlgebraicDivisor", <|
          "Divisor" -> divisor|>]
    ];
    If[FailureQ[failure], Break[]];
    Do[
      local = algebraicLocalPrincipalPart[
        reduced, variable, root, kinematics, packageFile
      ];
      If[FailureQ[local], failure = local; Break[]];
      higher = Join[higher, Map[
        Join[<|"Divisor" -> divisor, "Root" -> root|>, #]&,
        local["HigherPoleRows"]
      ]];
      If[!AllTrue[local["ResidueRow"], dlogZeroQ],
        terminals = Append[terminals, <|
          "Divisor" -> divisor, "Root" -> root,
          "ResidueRow" -> local["ResidueRow"]|>]
      ];
      records = Append[records, <|
        "Divisor" -> divisor, "Root" -> root,
        "HigherPoleRows" -> local["HigherPoleRows"],
        "ResidueRow" -> local["ResidueRow"]|>],
      {root, roots}
    ];
    If[FailureQ[failure], Break[]],
    {divisor, factors}
  ];
  If[FailureQ[failure], Return[failure]];
  <|
    "ReducedForms" -> reduced,
    "DivisorRecords" -> records,
    "HigherPoleRecords" -> higher,
    "HigherPoleRows" -> Lookup[higher, "CoefficientRow", {}],
    "TerminalResidueRecords" -> terminals,
    "TerminalResidueRows" -> Lookup[terminals, "ResidueRow", {}]
  |>
];

Options[AlgebraicMaximalCutSignature] = {
  "FiniteFlowPackageFile" -> Automatic
};

AlgebraicMaximalCutSignature[
  forms_List,
  variables_List,
  kinematics_List,
  cutVariables_List,
  OptionsPattern[]
] := Module[
  {cut, remaining, reduced, normalized, rationalSignature, univariate,
   conicCharts, conicSignatures, algebraicTree, higherRows, terminalRows, roots,
   allVariables, unsupported},
  allVariables = Join[variables, kinematics];
  unsupported = complexHalfPowerRadicands[forms];
  If[unsupported =!= {},
    Return[Failure["UnsupportedNestedComplexSquareClass", <|
      "Radicands" -> unsupported|>]]
  ];
  If[!AllTrue[forms, squareRootAlgebraicFormQ[#, allVariables]&],
    Return[Failure["UnsupportedAlgebraicForm", <|"Forms" -> forms|>]]
  ];
  cut = orderedAlgebraicCut[
    forms, variables, cutVariables, kinematics,
    OptionValue["FiniteFlowPackageFile"]
  ];
  If[FailureQ[cut], Return[cut]];
  remaining = cut["Variables"];
  reduced = reduceCertifiedHalfPowers /@ cut["Forms"];
  If[Length[remaining] > 1 &&
      AllTrue[
        reduced,
        rationalFormOverRationalsQ[#, Join[remaining, kinematics]]&
      ],
    (* Certified square factors leave one common constant sheet phase. *)
    normalized = commonRationalPhaseNormalize[
      reduced, Join[remaining, kinematics]
    ];
    If[FailureQ[normalized], Return[normalized]];
    rationalSignature = FinitePoleSignature[
      normalized, remaining, kinematics,
      "FiniteFlowPackageFile" -> OptionValue["FiniteFlowPackageFile"]
    ];
    If[FailureQ[rationalSignature], Return[rationalSignature]];
    If[!TrueQ[rationalSignature["AffineAtlasCompleteQ"]],
      Return[Failure["RationalizedDivisorUnresolved", <|
        "UnresolvedDivisors" -> rationalSignature["UnresolvedDivisors"]|>]]
    ];
    higherRows = Join[
      algebraicIdentityRows[cut["HigherPoleRecords"]],
      rationalSignature["HigherPoleRows"]
    ];
    Return[<|
      "Backend" -> "FiniteFlowAfterCertifiedSquareReduction",
      "Scope" -> "OrderedMaximalCutAndFiniteRationalizedDivisors",
      "OrderedCutVariables" -> cutVariables,
      "RemainingVariables" -> remaining,
      "MaximalCutForms" -> normalized,
      "DivisorRecords" -> rationalSignature["Nodes"],
      "HigherPoleRecords" -> Join[
        cut["HigherPoleRecords"], rationalSignature["HigherPoleRecords"]
      ],
      "HigherPoleRows" -> higherRows,
      "TerminalResidueRecords" ->
        rationalSignature["TerminalResidueRecords"],
      "TerminalResidueRows" -> rationalSignature["TerminalResidueRows"],
      "AlgebraicField" -> {},
      "KinematicVariables" -> kinematics,
      "SheetConvention" ->
        "CertifiedSquarePartWithCommonConstantPhaseRemoved",
      "FiniteDivisorsOnlyQ" -> True,
      "InfinityCheckedQ" -> False,
      "BranchTransitionsCheckedQ" -> False,
      "ChartTransitionsCheckedQ" -> False
    |>]
  ];
  If[Length[remaining] === 2,
    conicCharts = rationalConicCharts[
      cut["Forms"], remaining, kinematics
    ];
    If[
      FailureQ[conicCharts] &&
        First[conicCharts] =!= "RationalConicUnavailable",
      Return[conicCharts]
    ];
    If[!FailureQ[conicCharts],
      conicSignatures = Map[
        FinitePoleSignature[
          #["Forms"], #["Variables"], kinematics,
          "FiniteFlowPackageFile" -> OptionValue["FiniteFlowPackageFile"],
          "AllowLocalLinearCharts" -> True
        ]&,
        conicCharts
      ];
      If[AnyTrue[conicSignatures, FailureQ],
        Return[SelectFirst[conicSignatures, FailureQ]]
      ];
      higherRows = Join[
        algebraicIdentityRows[cut["HigherPoleRecords"]],
        Flatten[Lookup[conicSignatures, "HigherPoleRows"], 1]
      ];
      Return[<|
        "Backend" -> "FiniteFlowOnLocalRationalConicCharts",
        "Scope" -> "OrderedMaximalCutAndLocalConicDivisors",
        "OrderedCutVariables" -> cutVariables,
        "RemainingVariables" -> remaining,
        "ConicCharts" -> (KeyDrop[#, "Forms"]& /@ conicCharts),
        "MaximalCutForms" -> Lookup[conicCharts, "Forms"],
        "DivisorRecords" -> Flatten[Lookup[conicSignatures, "Nodes"], 1],
        "HigherPoleRecords" -> Join[
          cut["HigherPoleRecords"],
          Flatten[Lookup[conicSignatures, "HigherPoleRecords"], 1]
        ],
        "HigherPoleRows" -> higherRows,
        "TerminalResidueRecords" -> Flatten[
          Lookup[conicSignatures, "TerminalResidueRecords"], 1
        ],
        "TerminalResidueRows" -> Flatten[
          Lookup[conicSignatures, "TerminalResidueRows"], 1
        ],
        "AlgebraicField" -> {},
        "KinematicVariables" -> kinematics,
        "SheetConvention" ->
          "TwoLocalRationalConicChartsWithChartwiseConstantPhaseRemoved",
        "FiniteDivisorsOnlyQ" -> True,
        "AffineAtlasCompleteQ" -> False,
        "InfinityCheckedQ" -> False,
        "BranchTransitionsCheckedQ" -> False,
        "ChartTransitionsCheckedQ" -> False
      |>]
    ]
  ];
  If[Length[remaining] =!= 1,
    normalized = First@constantPhaseNormalizeRows[{reduced}, allVariables];
    roots = Select[
      Factor /@ algebraicSquareClasses[normalized],
      !FreeQ[#, Alternatives@@remaining]&
    ];
    If[roots =!= {},
      Return[Failure["MultivariateAlgebraicCoverUnresolved", <|
        "RemainingVariables" -> remaining,
        "VariableDependentSquareClasses" -> roots|>]]
    ];
    algebraicTree = algebraicResidueTree[
      normalized, remaining, kinematics, {},
      OptionValue["FiniteFlowPackageFile"]
    ];
    higherRows = Join[
      algebraicIdentityRows[cut["HigherPoleRecords"]],
      Flatten[Lookup[algebraicTree["HigherPoleRecords"], "IdentityRows", {}], 1]
    ];
    terminalRows = Lookup[
      algebraicTree["TerminalResidueRecords"], "ResidueRow", {}
    ];
    If[terminalRows === {},
      Return[Failure["MultivariateAlgebraicCoverUnresolved", <|
        "RemainingVariables" -> remaining,
        "UnresolvedDivisors" -> algebraicTree["UnresolvedDivisors"]|>]]
    ];
    roots = algebraicFieldDescriptors[Flatten[Join[higherRows, terminalRows]]];
    Return[<|
      "Backend" -> "ExactLocalQuadraticDivisorTree",
      "Scope" -> "OrderedMaximalCutAndLocalQuadraticDivisorFlags",
      "OrderedCutVariables" -> cutVariables,
      "RemainingVariables" -> remaining,
      "MaximalCutForms" -> normalized,
      "DivisorRecords" -> algebraicTree["Nodes"],
      "HigherPoleRecords" -> Join[
        cut["HigherPoleRecords"], algebraicTree["HigherPoleRecords"]
      ],
      "HigherPoleRows" -> higherRows,
      "TerminalResidueRecords" ->
        algebraicTree["TerminalResidueRecords"],
      "TerminalResidueRows" -> terminalRows,
      "UnresolvedDivisors" -> algebraicTree["UnresolvedDivisors"],
      "AlgebraicField" -> roots,
      "KinematicVariables" -> kinematics,
      "SheetConvention" ->
        "CertifiedSquareClassesWithLocalQuadraticRootSigns",
      "FiniteDivisorsOnlyQ" -> True,
      "AffineAtlasCompleteQ" -> False,
      "InfinityCheckedQ" -> False,
      "BranchTransitionsCheckedQ" -> False,
      "ChartTransitionsCheckedQ" -> False
    |>]
  ];
  univariate = univariateAlgebraicSignature[
    cut["Forms"], First[remaining], kinematics,
    OptionValue["FiniteFlowPackageFile"]
  ];
  If[FailureQ[univariate], Return[univariate]];
  higherRows = Join[
    algebraicIdentityRows[cut["HigherPoleRecords"]],
    univariate["HigherPoleRows"]
  ];
  terminalRows = univariate["TerminalResidueRows"];
  roots = algebraicFieldDescriptors[Flatten[Join[higherRows, terminalRows]]];
  <|
    "Backend" -> "ExactAlgebraicUnivariate",
    "Scope" -> "OrderedMaximalCutAndFiniteUnivariateDivisors",
    "OrderedCutVariables" -> cutVariables,
    "RemainingVariable" -> First[remaining],
    "MaximalCutForms" -> cut["Forms"],
    "DivisorRecords" -> univariate["DivisorRecords"],
    "HigherPoleRecords" -> Join[
      cut["HigherPoleRecords"], univariate["HigherPoleRecords"]
    ],
    "HigherPoleRows" -> higherRows,
    "TerminalResidueRecords" -> univariate["TerminalResidueRecords"],
    "TerminalResidueRows" -> terminalRows,
    "AlgebraicField" -> roots,
    "KinematicVariables" -> kinematics,
    "SheetConvention" -> "CertifiedSquarePartWithContourOrientationSign",
    "FiniteDivisorsOnlyQ" -> True,
    "InfinityCheckedQ" -> False,
    "BranchTransitionsCheckedQ" -> False,
    "ChartTransitionsCheckedQ" -> False
  |>
];

(* Write R = z^nu R0 U on the ordered propagator cut, with U|cut = 1.
   A dotted cocycle contributes the coefficient of Log[U]^n/n! selected by
   its pole orders.  Only its first nonzero epsilon order is retained. *)

orderedCutRestriction[expression_, variables_List] := Fold[
  Cancel[Together[#1 /. #2 -> 0]]&,
  expression,
  variables
];

orderedCutOrientationSign[variables_List, cutVariables_List] := Module[
  {current = variables, sign = 1, position},
  Do[
    position = First@First@Position[current, variable];
    sign *= (-1)^(position - 1);
    current = DeleteCases[current, variable],
    {variable, cutVariables}
  ];
  sign
];

orderedTwistData[ratio_, cutVariables_List] := Module[
  {current = Together[ratio], records = {}, data, restricted, unit},
  Do[
    data = rationalLeadingData[current, variable];
    restricted = Factor[data["LeadingCoefficient"]];
    unit = Cancel[Together[
      current/(variable^data["Valuation"] restricted)
    ]];
    records = Append[records, <|
      "Divisor" -> variable,
      "TwistValuation" -> data["Valuation"],
      "RestrictedTwistRatio" -> restricted,
      "NormalizedUnit" -> unit,
      "RestrictedUnit" -> Cancel[Together[unit /. variable -> 0]]
    |>];
    current = restricted,
    {variable, cutVariables}
  ];
  <|
    "CutRecords" -> records,
    "RestrictedRatio" -> current
  |>
];

mixedTaylorCoefficient[expression_, variables_List, orders_List] := Module[
  {derivative},
  derivative = Fold[
    If[Last[#2] === 0, #1, D[#1, {First[#2], Last[#2]}]]&,
    expression,
    Transpose[{variables, orders}]
  ];
  Factor[Together[
    orderedCutRestriction[derivative, variables]/
      (Times@@(Factorial /@ orders))
  ]]
];

regulatedLocalResidue[form_, unit_, variable_, regulatorOrder_Integer] :=
 Module[{leading, poleOrder, regular, term},
  leading = algebraicLeadingData[form, variable];
  If[FailureQ[leading], Return[leading]];
  If[leading["Valuation"] >= 0, Return[0]];
  poleOrder = -leading["Valuation"];
  regular = Cancel[Together[variable^poleOrder form]];
  term = Quiet[
    Check[
      mixedTaylorCoefficient[
        If[
          regulatorOrder === 0,
          regular,
          regular Log[unit]^regulatorOrder/Factorial[regulatorOrder]
        ],
        {variable},
        {poleOrder - 1}
      ],
      $Failed,
      {Power::infy, Power::indet, Infinity::indet}
    ],
    {Power::infy, Power::indet, Infinity::indet}
  ];
  If[term === $Failed || !FreeQ[
      term, _Log | Indeterminate | ComplexInfinity | _DirectedInfinity
    ],
    Failure["SingularGeneralizedCutCoefficient", <|
      "Divisor" -> variable,
      "RegulatorOrder" -> regulatorOrder|>],
    reduceCertifiedHalfPowers[term]
  ]
];

regulatedGeneralizedCutRecord[
  form_, twist_Association, variables_List, cutVariables_List
] := Catch[Module[
  {leading, powers, orders, series, next, step, sourceOrder, sourceForm,
   localLeading, localOrderBound, term, coefficient = 0,
   valuation = Missing["Vanishing"]},
  leading = algebraicLeadingData[form, #]& /@ cutVariables;
  powers = Map[
    If[FailureQ[#], Missing["OrderedEvaluation"], -#["Valuation"]]&,
    leading
  ];
  orders = Replace[powers, power_Integer :> power - 1, {1}];
  series = <|0 -> orderedCutOrientationSign[variables, cutVariables] form|>;
  Do[
    step = twist["CutRecords"][[position]];
    next = <||>;
    Do[
      sourceOrder = First[entry];
      sourceForm = Last[entry];
      localLeading = algebraicLeadingData[
        sourceForm, cutVariables[[position]]
      ];
      If[FailureQ[localLeading],
        Throw[localLeading, regulatedGeneralizedCutFailureTag]
      ];
      localOrderBound = -localLeading["Valuation"] - 1;
      Do[
        term = regulatedLocalResidue[
          sourceForm, step["NormalizedUnit"], cutVariables[[position]],
          regulatorOrder
        ];
        If[FailureQ[term],
          Throw[term, regulatedGeneralizedCutFailureTag]
        ];
        If[!dlogZeroQ[term],
          AssociateTo[next,
            sourceOrder + regulatorOrder -> Factor[Together[
              Lookup[next, sourceOrder + regulatorOrder, 0] + term
            ]]
          ]
        ],
        {regulatorOrder, 0, localOrderBound}
      ],
      {entry, Normal[series]}
    ];
    series = Association@Select[Normal[next], !dlogZeroQ[Last[#]]&],
    {position, Length[cutVariables]}
  ];
  If[Length[series] > 0,
    valuation = First[Sort[Keys[series]]];
    coefficient = series[valuation]
  ];
  <|
    "PoleOrders" -> powers,
    "DerivativeOrders" -> orders,
    "RegulatorValuation" -> valuation,
    "FirstNonzeroCoefficient" -> coefficient,
    "CutForm" -> If[
      dlogZeroQ[coefficient],
      0,
      DimensionalRegulator^valuation coefficient
    ],
    "Method" -> "FirstNonzeroOrderedTwistCoefficient"
  |>
], regulatedGeneralizedCutFailureTag];

pointResidualSignature[forms_List, parameters_List] := <|
  "Backend" -> "ExactAlgebraicPoint",
  "Scope" -> "ZeroDimensionalAlgebraicCocycle",
  "HigherPoleRecords" -> {},
  "HigherPoleRows" -> {},
  "TerminalResidueRecords" -> {<|"Flag" -> {}, "ResidueRow" -> forms|>},
  "TerminalResidueRows" -> {forms},
  "Nodes" -> {},
  "UnresolvedDivisors" -> {},
  "AlgebraicField" -> algebraicFieldDescriptors[forms],
  "KinematicVariables" -> parameters,
  "AffineAtlasCompleteQ" -> True
|>;

candidateResidualSignature[
  forms_List, remaining_List, parameters_List, packageFile_, backend_
] := If[
  remaining === {},
  pointResidualSignature[forms, parameters],
  Switch[backend,
    "ImplicitAlgebraicExperimental",
      ImplicitAlgebraicResidueSignature[forms, remaining, parameters],
    _,
      If[
        AllTrue[
          forms,
          rationalFormOverRationalsQ[#, Join[remaining, parameters]]&
        ],
        FinitePoleSignature[
          forms, remaining, parameters,
          "FiniteFlowPackageFile" -> packageFile
        ],
        AlgebraicMaximalCutSignature[
          forms, remaining, parameters, {},
          "FiniteFlowPackageFile" -> packageFile
        ]
      ]
  ]
];

embedResidualRow[row_List, positions_List, count_Integer] := ReplacePart[
  ConstantArray[0, count],
  Thread[positions -> row]
];

Options[DimensionallyRegulatedMaximalCutSignature] = {
  "FiniteFlowPackageFile" -> Automatic,
  "ResidualBackend" -> "Current"
};

DimensionallyRegulatedMaximalCutSignature[
  forms_List,
  regulatorRatio_,
  variables_List,
  kinematics_List,
  cutVariables_List,
  OptionsPattern[]
] := Module[
  {parameters, allVariables, twist, remaining, cutRecords, validPositions,
   nullPositions, unresolvedPositions, residualBlocks, residual, positions,
   higherRows = {}, terminalRows = {}, higherRecords = {},
   terminalRecords = {}, nullRows, excludedRows = {}, failures = {}, roots,
   variableRoots, field, unsupported, count, successful, atlasCompleteQ},
  parameters = Append[kinematics, DimensionalRegulator];
  allVariables = Join[variables, kinematics];
  unsupported = complexHalfPowerRadicands[forms];
  If[unsupported =!= {},
    Return[Failure["UnsupportedNestedComplexSquareClass", <|
      "Radicands" -> unsupported|>]]
  ];
  If[
    !AllTrue[forms, squareRootAlgebraicFormQ[#, allVariables]&] ||
      !rationalFormQ[regulatorRatio, allVariables],
    Return[Failure["UnsupportedDimensionallyRegulatedForm", <|
      "CocycleForms" -> forms, "RegulatorRatio" -> regulatorRatio|>]]
  ];
  count = Length[forms];
  twist = orderedTwistData[regulatorRatio, cutVariables];
  remaining = DeleteCases[variables, Alternatives@@cutVariables];
  cutRecords = regulatedGeneralizedCutRecord[
      #, twist, variables, cutVariables
    ]& /@ forms;
  unresolvedPositions = Select[
    Range[count],
    FailureQ[cutRecords[[#]]] || !FreeQ[
        Lookup[cutRecords[[#]], "CutForm"],
        ComplexInfinity | Indeterminate | _DirectedInfinity
      ]&
  ];
  nullPositions = Select[
    Complement[Range[count], unresolvedPositions],
    dlogZeroQ[Lookup[cutRecords[[#]], "CutForm"]]&
  ];
  validPositions = Complement[
    Range[count], unresolvedPositions, nullPositions
  ];
  nullRows = UnitVector[count, #]& /@ nullPositions;
  excludedRows = nullRows;
  Do[
    excludedRows = Append[excludedRows, UnitVector[count, position]];
    failures = Append[failures, <|
      "CandidatePosition" -> position,
      "Failure" -> Failure[
        "VanishingOrUnresolvedGeneralizedCut",
        <|"CutRecord" -> cutRecords[[position]]|>
      ]
    |>],
    {position, unresolvedPositions}
  ];
  residualBlocks = If[
    validPositions === {},
    {},
    {<|
      "CandidatePositions" -> validPositions,
      "Signature" -> candidateResidualSignature[
        Lookup[cutRecords[[validPositions]], "CutForm"],
        remaining,
        parameters,
        OptionValue["FiniteFlowPackageFile"],
        OptionValue["ResidualBackend"]
      ]
    |>}
  ];
  Do[
    positions = block["CandidatePositions"];
    residual = block["Signature"];
    If[
      FailureQ[residual] || residual["TerminalResidueRows"] === {},
      Do[
        excludedRows = Append[excludedRows, UnitVector[count, position]];
        failures = Append[failures, <|
          "CandidatePosition" -> position,
          "Failure" -> If[
            FailureQ[residual], residual,
            Failure["NoFiniteTerminalResidue", <||>]
          ]
        |>],
        {position, positions}
      ],
      higherRows = Join[
        higherRows,
        embedResidualRow[#, positions, count]& /@
          residual["HigherPoleRows"]
      ];
      terminalRows = Join[
        terminalRows,
        embedResidualRow[#, positions, count]& /@
          residual["TerminalResidueRows"]
      ];
      higherRecords = Join[higherRecords, Map[
        <|"CandidatePositions" -> positions, "LocalRecord" -> #|>&,
        residual["HigherPoleRecords"]
      ]];
      terminalRecords = Join[terminalRecords, Map[
        <|"CandidatePositions" -> positions, "LocalRecord" -> #|>&,
        residual["TerminalResidueRecords"]
      ]]
    ],
    {block, residualBlocks}
  ];
  roots = algebraicFieldDescriptors[Flatten[Join[higherRows, terminalRows]]];
  variableRoots = Select[
    roots, !FreeQ[#["SquareClass"], Alternatives@@variables]&
  ];
  If[variableRoots =!= {},
    Return[Failure["MultivariateAlgebraicCoverUnresolved", <|
      "VariableDependentSquareClasses" ->
        Lookup[variableRoots, "SquareClass"]|>]]
  ];
  field = roots;
  successful = Select[residualBlocks, !FailureQ[#["Signature"]]&];
  successful = If[successful === {}, {}, Lookup[successful, "Signature"]];
  atlasCompleteQ = AllTrue[
    successful,
    TrueQ[Lookup[#, "AffineAtlasCompleteQ", True]]&
  ];
  <|
    "Backend" -> "RegulatedGeneralizedCut",
    "Scope" ->
      "FirstNonzeroRegulatedGeneralizedCutAndFiniteDivisors",
    "DimensionConvention" -> "D=D0-2 DimensionalRegulator",
    "Regulator" -> DimensionalRegulator,
    "CoefficientFieldParameters" -> parameters,
    "CocycleForms" -> forms,
    "PhysicalForms" -> (forms regulatorRatio^DimensionalRegulator),
    "RegulatorRatio" -> regulatorRatio,
    "MaximalCutTwistRatio" -> twist["RestrictedRatio"],
    "NormalizedTwistUnits" -> Lookup[
      twist["CutRecords"], "NormalizedUnit"
    ],
    "OrderedCutVariables" -> cutVariables,
    "PhysicalCutRecords" -> twist["CutRecords"],
    "GeneralizedCutRecords" -> cutRecords,
    "CandidateResidualSignatures" -> residualBlocks,
    "CandidateResidualFailures" -> failures,
    "CutNullCandidatePositions" -> nullPositions,
    "CutNullCandidateRows" -> nullRows,
    "HigherPoleRecords" -> higherRecords,
    "HigherPoleRows" -> higherRows,
    "ExcludedCandidateRows" -> excludedRows,
    "ModuleConstraintRows" -> Join[higherRows, excludedRows],
    "TerminalResidueRecords" -> terminalRecords,
    "TerminalResidueRows" -> terminalRows,
    "AlgebraicField" -> field,
    "KinematicVariables" -> kinematics,
    "ResidualBackends" -> Lookup[successful, "Backend", {}],
    "CandidateResidualCompleteQ" -> (failures === {}),
    "FiniteDivisorsOnlyQ" -> (successful =!= {} && AllTrue[
      successful,
      TrueQ[Lookup[#, "FiniteDivisorsOnlyQ", True]]&
    ]),
    "AffineAtlasCompleteQ" -> atlasCompleteQ,
    "DimensionOnlyNormalization" -> "Omitted",
    "TwistInterpretation" -> "FirstNonzeroOrderedTwistCoefficient",
    "InfinityCheckedQ" -> False,
    "BranchTransitionsCheckedQ" -> False,
    "ChartTransitionsCheckedQ" -> False
  |>
];
