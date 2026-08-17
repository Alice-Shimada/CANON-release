BeginPackage["CANON`DEBuilder`"];

BuildDifferentialEquations::usage =
  "BuildDifferentialEquations[family, masters, rules] constructs exact ordered " <>
  "master-integral differential-equation matrices entirely in memory.";

Begin["`Private`"];

$spectatorAttempts = 32;
$spectatorSeed = 20260811;

failure[tag_String, message_String, details_: <||>] :=
  Failure[tag, Join[<|"MessageTemplate" -> message|>, details]];

rationalExpressionQ[expression_, parameters_List] := Which[
  IntegerQ[expression] || Head[expression] === Rational, True,
  Head[expression] === Symbol, MemberQ[parameters, expression],
  MemberQ[{Plus, Times}, Head[expression]],
    AllTrue[List @@ expression, rationalExpressionQ[#, parameters] &],
  Head[expression] === Power && IntegerQ[expression[[2]]],
    rationalExpressionQ[expression[[1]], parameters],
  True, False
];

familyIntegralQ[expression_, head_Symbol, arity_Integer] :=
  Head[expression] === head && Length[expression] === arity &&
    VectorQ[List @@ expression, IntegerQ];

containsFamilyIntegralQ[expression_, head_Symbol] :=
  Cases[
    expression,
    item_ /; !AtomQ[Unevaluated[item]] && Head[Unevaluated[item]] === head,
    {0, Infinity},
    1
  ] =!= {};

validateMasters[masters_List] := Module[{head, arity},
  If[masters === {} || DuplicateFreeQ[masters] =!= True,
    Return[failure[
      "DE_INPUT_INVALID", "masters must be a nonempty ordered list without duplicates."
    ]]
  ];
  head = Head[First[masters]];
  arity = Length[First[masters]];
  If[
    !MatchQ[head, _Symbol] || arity == 0 ||
      !AllTrue[masters, familyIntegralQ[#, head, arity] &],
    Return[failure[
      "DE_SHAPE_INVALID",
      "All masters must have one common symbolic head and one common integer-index arity."
    ]]
  ];
  <|"head" -> head, "arity" -> arity|>
];

validateFamily[family_Association, arity_Integer] := Module[
  {parameters, operators, variables},
  If[Sort[Keys[family]] =!= {"operators", "parameters"},
    Return[failure[
      "DE_INPUT_INVALID", "family must contain exactly parameters and operators."
    ]]
  ];
  parameters = family["parameters"];
  operators = family["operators"];
  If[
    !ListQ[parameters] || DuplicateFreeQ[parameters] =!= True ||
      !AllTrue[parameters, MatchQ[#, _Symbol] &] ||
      !AssociationQ[operators] || Length[operators] == 0,
    Return[failure[
      "DE_INPUT_INVALID",
      "parameters must be unique symbols and operators must be a nonempty ordered Association."
    ]]
  ];
  variables = Keys[operators];
  If[
      !AllTrue[variables, MatchQ[#, _Symbol] &] ||
      Complement[variables, parameters] =!= {},
    Return[failure[
      "DE_INPUT_INVALID", "Every ordered operator variable must occur in parameters."
    ]]
  ];
  If[!AllTrue[Values[operators], MatrixQ[#] && Dimensions[#] === {arity, arity + 1} &],
    Return[failure[
      "DE_SHAPE_INVALID",
      "Each affine denominator operator must have dimensions m by (m+1)."
    ]]
  ];
  If[
    !AllTrue[
      Flatten[Values[operators]],
      rationalExpressionQ[#, parameters] &
    ],
    Return[failure[
      "DE_COEFFICIENT_INVALID",
      "Every operator entry must be a rational function over the declared parameters."
    ]]
  ];
  <|"parameters" -> parameters, "variables" -> variables, "operators" -> operators|>
];

vectorizeRules[
  rules_List, masters_List, head_Symbol, arity_Integer, parameters_List
] := Module[
  {leftSides, basisRules, vectors, vectorRules, length = Length[masters]},
  If[!AllTrue[rules, MatchQ[#, _Rule] &],
    Return[failure["DE_INPUT_INVALID", "rules must be immediate Mathematica rules."]]
  ];
  leftSides = First[List @@ #] & /@ rules;
  If[
    DuplicateFreeQ[leftSides] =!= True ||
      !AllTrue[leftSides, familyIntegralQ[#, head, arity] &] ||
      Intersection[leftSides, masters] =!= {},
    Return[failure[
      "DE_INPUT_INVALID",
      "Rule left-hand sides must be unique non-master integrals of the master family."
    ]]
  ];
  basisRules = Thread[masters -> IdentityMatrix[length]];
  vectors = Replace[
    (Last[List @@ #] /. basisRules) & /@ rules,
    0 -> ConstantArray[0, length],
    {1}
  ];
  If[
    !AllTrue[
      vectors,
      ListQ[#] && Length[#] === length && !containsFamilyIntegralQ[#, head] &
    ],
    Return[failure[
      "DE_RESIDUAL_INTEGRALS",
      "A reduction did not close on the complete ordered master vector."
    ]]
  ];
  If[!AllTrue[Flatten[vectors], rationalExpressionQ[#, parameters] &],
    Return[failure[
      "DE_COEFFICIENT_INVALID",
      "A reduced coefficient is not rational over the declared parameters."
    ]]
  ];
  vectorRules = MapThread[Rule, {leftSides, vectors}];
  Join[basisRules, vectorRules]
];

masterDerivative[master_, operator_] := Module[
  {indices = List @@ master, head = Head[master], arity = Length[master]},
  Total @ Table[
    -indices[[source]] (
      operator[[source, 1]] Apply[
        head, indices + UnitVector[arity, source]
      ] +
      Sum[
        operator[[source, target + 1]] Apply[
          head,
          indices + UnitVector[arity, source] - UnitVector[arity, target]
        ],
        {target, arity}
      ]
    ),
    {source, arity}
  ]
];

assembleMatrices[
  masters_List, variables_List, operators_Association, replacements_List,
  head_Symbol
] := Module[{length = Length[masters], rows, matrixRules, matrices},
  matrixRules = Map[
    Function[variable,
      rows = Replace[
        (masterDerivative[#, operators[variable]] /. replacements) & /@ masters,
        0 -> ConstantArray[0, length],
        {1}
      ];
      variable -> rows
    ],
    variables
  ];
  matrices = Association[matrixRules];
  If[
    !AllTrue[
      Flatten[Values[matrices], 1],
      ListQ[#] && Length[#] === length && !containsFamilyIntegralQ[#, head] &
    ],
    Return[failure[
      "DE_RESIDUAL_INTEGRALS",
      "A derivative did not reduce to the complete ordered master vector."
    ]]
  ];
  matrices
];

exactAssignments[spectators_List, pairIndex_Integer, attempt_Integer] :=
  BlockRandom[
    SeedRandom[$spectatorSeed + 1000003 pairIndex + 1009 attempt];
    Thread[
      spectators -> Table[
        RandomChoice[{-1, 1}] RandomInteger[{2, 101}]/RandomInteger[{2, 101}],
        {Length[spectators]}
      ]
    ]
  ];

finiteExactQ[expression_] := FreeQ[
  expression,
  _Real | Indeterminate | ComplexInfinity | _DirectedInfinity
];

curvatureMatrix[
  matrices_Association, variableI_Symbol, variableJ_Symbol
] := Module[{matrixI, matrixJ, residual},
  matrixI = SparseArray[matrices[variableI]];
  matrixJ = SparseArray[matrices[variableJ]];
  residual = SparseArray[D[matrices[variableJ], variableI]] -
    SparseArray[D[matrices[variableI], variableJ]] +
    matrixJ . matrixI - matrixI . matrixJ;
  residual = Quiet @ Check[Map[Together, Normal[residual], {2}], $Failed];
  If[residual === $Failed || !finiteExactQ[residual], $Failed, residual]
];

validateCurvature[matrices_Association, variables_List] := Module[
  {indexPairs, records, pairIndex, variableI, variableJ, spectators,
   assignments, specialized, residual, nonzero, accepted},
  indexPairs = Subsets[Range[Length[variables]], {2}];
  records = Catch[Table[
    {variableI, variableJ} = variables[[indexPairs[[pairIndex]]]];
    spectators = DeleteCases[variables, variableI | variableJ];
    If[spectators === {},
      residual = curvatureMatrix[matrices, variableI, variableJ];
      If[residual === $Failed,
        Throw[failure[
          "DE_CURVATURE_INVALID", "The exact global curvature could not be formed."
        ], "de-curvature"]
      ];
      nonzero = Position[residual, item_ /; item =!= 0, {2}, Heads -> False];
      If[nonzero =!= {},
        Throw[failure[
          "DE_CURVATURE_NONZERO", "The exact column-convention curvature is nonzero.",
          <|"variables" -> {variableI, variableJ}, "position" -> First[nonzero]|>
        ], "de-curvature"]
      ];
      <|"variables" -> {variableI, variableJ}, "assignments" -> {}|>,
      accepted = Missing["NotFound"];
      Do[
        assignments = exactAssignments[spectators, pairIndex, attempt];
        specialized = Quiet @ Check[
          KeyTake[matrices, {variableI, variableJ}] /. assignments,
          $Failed
        ];
        If[
          specialized === $Failed || !finiteExactQ[Values[specialized]] ||
            !FreeQ[Values[specialized], Alternatives @@ spectators],
          Continue[]
        ];
        specialized = Quiet @ Check[
          Map[Map[Together, #, {2}] &, specialized],
          $Failed
        ];
        If[specialized === $Failed || !finiteExactQ[Values[specialized]],
          Continue[]
        ];
        residual = curvatureMatrix[specialized, variableI, variableJ];
        If[residual === $Failed || !FreeQ[residual, Alternatives @@ spectators],
          Continue[]
        ];
        nonzero = Position[residual, item_ /; item =!= 0, {2}, Heads -> False];
        If[nonzero =!= {},
          Throw[failure[
            "DE_CURVATURE_NONZERO",
            "An exact bivariate spectator slice has nonzero curvature.",
            <|
              "variables" -> {variableI, variableJ},
              "assignments" -> assignments,
              "position" -> First[nonzero]
            |>
          ], "de-curvature"]
        ];
        accepted = <|
          "variables" -> {variableI, variableJ},
          "assignments" -> assignments
        |>;
        Break[],
        {attempt, $spectatorAttempts}
      ];
      If[MissingQ[accepted],
        Throw[failure[
          "DE_CURVATURE_INVALID",
          "No deterministic exact-rational spectator assignment avoided a pole.",
          <|"variables" -> {variableI, variableJ}|>
        ], "de-curvature"]
      ];
      accepted
    ],
    {pairIndex, Length[indexPairs]}
  ], "de-curvature"];
  If[FailureQ[records], Return[records]];
  <|
    "scope" -> If[Length[variables] > 2, "exact-bivariate-slices", "global-exact"],
    "pairs" -> records
  |>
];

BuildDifferentialEquations[
  family_Association, masters_List, rules_List
] := Module[
  {masterData, familyData, replacements, matrices, curvature},
  masterData = validateMasters[masters];
  If[FailureQ[masterData], Return[masterData]];
  familyData = validateFamily[family, masterData["arity"]];
  If[FailureQ[familyData], Return[familyData]];
  replacements = vectorizeRules[
    rules,
    masters,
    masterData["head"],
    masterData["arity"],
    familyData["parameters"]
  ];
  If[FailureQ[replacements], Return[replacements]];
  matrices = assembleMatrices[
    masters,
    familyData["variables"],
    familyData["operators"],
    replacements,
    masterData["head"]
  ];
  If[FailureQ[matrices], Return[matrices]];
  curvature = Quiet[validateCurvature[matrices, familyData["variables"]]];
  If[FailureQ[curvature], Return[curvature]];
  <|"matrices" -> matrices, "validity" -> curvature|>
];

BuildDifferentialEquations[___] := failure[
  "DE_INPUT_INVALID",
  "Expected BuildDifferentialEquations[family_Association, masters_List, rules_List]."
];

End[];
EndPackage[];
