(* Experimental root-free residues in finite polynomial algebras. *)

implicitQuotientReduce[expression_, generator_, relation_] := Module[
  {rational, numerator, denominator, extended, gcd, inverse},
  rational = Together[expression];
  numerator = Numerator[rational];
  denominator = Denominator[rational];
  extended = PolynomialExtendedGCD[denominator, relation, generator];
  gcd = First[extended];
  If[Exponent[gcd, generator] > 0,
    Return[Failure["NonUnitInImplicitQuotient", <|
      "Element" -> denominator, "Relation" -> relation|>]]
  ];
  inverse = First[Last[extended]]/gcd;
  Factor[Together[
    PolynomialRemainder[numerator inverse, relation, generator]
  ]]
];

implicitQuotientCoordinates[elements_List, generator_, relation_] := Module[
  {degree, reduced},
  degree = Exponent[relation, generator];
  reduced = implicitQuotientReduce[#, generator, relation]& /@ elements;
  If[MemberQ[reduced, _Failure], Return[FirstCase[reduced, _Failure]]];
  Table[
    Together[Coefficient[#, generator, power]]& /@ reduced,
    {power, 0, degree - 1}
  ]
];

implicitDivisorMultiplicity[form_, variable_, divisor_] := Module[
  {factors, degree, monic},
  degree = Exponent[divisor, variable];
  monic[polynomial_] := Factor[
    polynomial/Coefficient[polynomial, variable, degree]
  ];
  factors = Rest[FactorList[Denominator[Together[form]]]];
  Last@SelectFirst[
    factors,
    Exponent[First[#], variable] === degree &&
      dlogZeroQ[monic[First[#]] - monic[divisor]]&,
    divisor -> 0
  ]
];

(* The class of y encodes every zero of q(y).  Coefficients are obtained in
   the local coordinate t=q without constructing any root of q. *)
ImplicitDivisorPrincipalPart[
  forms_List, variable_, divisor_
] := Module[
  {degree, derivative, multiplicities, coefficientData, powers, elements,
   coordinateRows},
  degree = Exponent[divisor, variable];
  derivative = D[divisor, variable];
  multiplicities = implicitDivisorMultiplicity[#, variable, divisor]& /@ forms;
  coefficientData = MapThread[
    Function[{form, multiplicity},
      If[multiplicity === 0,
        <||>,
        With[{regular = Together[divisor^multiplicity form]},
          Association@Table[
            -multiplicity + order -> implicitQuotientReduce[
              Nest[D[#, variable]/derivative&, regular/derivative, order]/
                Factorial[order],
              variable, divisor
            ],
            {order, 0, multiplicity - 1}
          ]
        ]
      ]
    ],
    {forms, multiplicities}
  ];
  If[!FreeQ[coefficientData, _Failure],
    Return[FirstCase[coefficientData, _Failure, Infinity]]
  ];
  powers = Sort@DeleteDuplicates@Flatten[Keys /@ coefficientData];
  elements[power_] := Lookup[#, power, 0]& /@ coefficientData;
  coordinateRows[power_] := implicitQuotientCoordinates[
    elements[power], variable, divisor
  ];
  <|
    "Backend" -> "ImplicitQuotientPrincipalPartExperimental",
    "Divisor" -> divisor,
    "Degree" -> degree,
    "Basis" -> variable^Range[0, degree - 1],
    "CoefficientBlocks" -> Table[
      <|"Order" -> power, "Elements" -> elements[power],
        "CoordinateRows" -> coordinateRows[power]|>,
      {power, powers}
    ],
    "HigherPoleRows" -> Flatten[
      coordinateRows /@ Select[powers, # < -1&], 1
    ],
    "ResidueElements" -> elements[-1],
    "ResidueCoordinateRows" -> coordinateRows[-1]
  |>
];

implicitCanonicalDivisor[divisor_, variables_List] := Factor[
  divisor/First[FactorTermsList[divisor, variables]]
];

implicitFactorMultiplicity[form_, divisor_, variables_List] := Last@SelectFirst[
  Rest[FactorList[Denominator[Together[form]]]],
  dlogZeroQ[
    implicitCanonicalDivisor[First[#], variables] - divisor
  ]&,
  divisor -> 0
];

implicitCoverSquareClasses[radicand_, variables_List] := Module[
  {factors, constant},
  factors = FactorList[radicand];
  constant = Apply[Power, First[factors]] Times@@(
    Power@@@Select[
      Rest[factors], FreeQ[First[#], Alternatives@@variables]&
    ]
  );
  <|"Constant" -> Factor[constant],
    "Variable" -> Factor[radicand/constant]|>
];

(* Find l with l^2==polynomial modulo relation.  The cover sheet sign is kept
   separately, so one quotient-algebra square root is sufficient. *)
implicitSquareRootModulo[polynomial_, variable_, relation_] := Module[
  {degree, coefficients, root, remainder, solutions},
  degree = Exponent[relation, variable];
  coefficients = Table[
    Unique["DlogBasis`Private`implicitCoefficient$"], {degree}
  ];
  root = coefficients.(variable^Range[0, degree - 1]);
  remainder = Together[PolynomialRemainder[
    Expand[root^2 - polynomial], relation, variable
  ]];
  solutions = Solve[
    Thread[CoefficientList[Numerator[remainder], variable] == 0],
    coefficients
  ];
  If[solutions === {},
    Failure["ImplicitCoverSquareRootUnresolved", <|
      "Polynomial" -> polynomial, "Relation" -> relation|>],
    Factor[root /. First[solutions]]
  ]
];

implicitFinitePairRecord[
  forms_List, variables_List, pair_List, generator_, coverRelation_,
  constantClass_, variableClass_
] := Module[
  {coordinate, remaining, relation, degree, multiplicities, localSquareRoot,
   jacobian, coverElements, baseCoordinate, baseRoots, rows},
  coordinate = SelectFirst[
    variables, MemberQ[pair, #]&, Missing["NoCoordinateDivisor"]
  ];
  If[MissingQ[coordinate],
    Return[Failure["NonCoordinateFinitePairUnresolved", <|
      "Divisors" -> pair|>]]
  ];
  remaining = First@DeleteCases[variables, coordinate];
  relation = Factor[First@DeleteCases[pair, coordinate] /. coordinate -> 0];
  degree = Exponent[relation, remaining];
  If[!MemberQ[{1, 2}, degree],
    Return[Failure["HigherDegreeFinitePairUnresolved", <|
      "Divisors" -> pair, "Relation" -> relation|>]]
  ];
  multiplicities = Flatten@Table[
    implicitFactorMultiplicity[form, divisor, variables],
    {form, forms}, {divisor, pair}
  ];
  If[Max[multiplicities] > 1,
    Return[Failure["DottedFinitePairUnresolved", <|
      "Divisors" -> pair|>]]
  ];
  localSquareRoot = implicitSquareRootModulo[
    Factor[variableClass /. coordinate -> 0], remaining, relation
  ];
  If[FailureQ[localSquareRoot], Return[localSquareRoot]];
  jacobian = Det@Table[
    D[pair[[i]], variables[[j]]], {i, 2}, {j, 2}
  ];
  coverElements = Table[
    implicitQuotientReduce[
        implicitQuotientReduce[
            Cancel[Together[form Times@@pair/jacobian]],
            generator, coverRelation
          ] /. coordinate -> 0 /.
          generator -> sign Sqrt[constantClass] localSquareRoot,
        remaining, relation
      ],
    {sign, {1, -1}}, {form, forms}
  ];
  If[!FreeQ[coverElements, _Failure],
    Return[FirstCase[coverElements, _Failure, Infinity]]
  ];
  baseCoordinate = algebraicDivisorCoordinate[relation, {remaining}];
  If[!AssociationQ[baseCoordinate],
    Return[Failure["ImplicitBaseComponentUnresolved", <|
      "Relation" -> relation|>]]
  ];
  baseRoots = baseCoordinate["Roots"];
  rows = Flatten[
    Table[
      reduceCertifiedHalfPowers /@ (row /. remaining -> root),
      {row, coverElements}, {root, baseRoots}
    ],
    1
  ];
  <|
    "Divisors" -> pair,
    "BaseRelation" -> relation,
    "CoverSquareRoot" -> localSquareRoot,
    "ResidueRows" -> rows
  |>
];

ImplicitAlgebraicResidueSignature[
  forms_List, variables_List, kinematics_List
] := Module[
  {classes, variableClasses, radicand, generator, formal, relation, reduced,
   squareClasses, divisors, pairs, records, terminalRows},
  If[Length[variables] =!= 2,
    Return[Failure["TwoVariableImplicitCoverRequired", <|
      "Variables" -> variables|>]]
  ];
  classes = independentSquareClasses[algebraicSquareClasses[forms]];
  variableClasses = Select[
    classes, !FreeQ[#, Alternatives@@variables]&
  ];
  If[Length[variableClasses] =!= 1,
    Return[Failure["SingleImplicitCoverRequired", <|
      "VariableSquareClasses" -> variableClasses|>]]
  ];
  radicand = First[variableClasses];
  generator = Unique["DlogBasis`Private`implicitRoot$"];
  formal = formalizeQuadraticExpression[#, radicand, generator]& /@ forms;
  relation = generator^2 - radicand;
  reduced = implicitQuotientReduce[#, generator, relation]& /@ formal;
  If[MemberQ[reduced, _Failure], Return[FirstCase[reduced, _Failure]]];
  squareClasses = implicitCoverSquareClasses[radicand, variables];
  divisors = DeleteDuplicates[
    implicitCanonicalDivisor[#, variables]& /@
      finitePoleDivisors[reduced, variables]
  ];
  pairs = Subsets[divisors, {2}];
  records = implicitFinitePairRecord[
      reduced, variables, #, generator, relation,
      squareClasses["Constant"], squareClasses["Variable"]
    ]& /@ pairs;
  If[MemberQ[records, _Failure], Return[FirstCase[records, _Failure]]];
  terminalRows = Flatten[Lookup[records, "ResidueRows"], 1];
  <|
    "Backend" -> "ImplicitAlgebraicFinitePairsExperimental",
    "Scope" -> "OneImplicitCoverAndAllFiniteSimpleDivisorPairs",
    "RemainingVariables" -> variables,
    "MaximalCutForms" -> forms,
    "ImplicitGenerator" -> generator,
    "ImplicitRelation" -> relation,
    "FiniteDivisors" -> divisors,
    "DivisorPairs" -> pairs,
    "HigherPoleRecords" -> {},
    "HigherPoleRows" -> {},
    "TerminalResidueRecords" -> Flatten[
      Function[record,
        <|"Divisors" -> record["Divisors"], "ResidueRow" -> #|>& /@
          record["ResidueRows"]
      ] /@ records,
      1
    ],
    "TerminalResidueRows" -> terminalRows,
    "AlgebraicField" -> algebraicFieldDescriptors[Flatten[terminalRows]],
    "KinematicVariables" -> kinematics,
    "FiniteDivisorsOnlyQ" -> True,
    "AffineAtlasCompleteQ" -> True,
    "InfinityCheckedQ" -> False,
    "BranchTransitionsCheckedQ" -> False,
    "ChartTransitionsCheckedQ" -> False
  |>
];
