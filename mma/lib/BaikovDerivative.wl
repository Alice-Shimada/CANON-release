BeginPackage["CANON`BaikovDerivative`"];

ChooseDerivativeOperator::usage =
  "ChooseDerivativeOperator[prepared, variable, selection:\"enhanced-first\"] uses the bounded enhanced search by default; selection \"prepared-affine\" explicitly uses the supplied affine operator without searching.";

Begin["`Private`"];

failure[message_String] :=
  Failure["DERIVATIVE_OPERATOR_INVALID", <|"MessageTemplate" -> message|>];

zeroQ[expression_] := TrueQ[Together[expression] === 0];

monomialBasis[variables_List, degree_Integer] := Module[{powers},
  powers = Select[Tuples[Range[0, degree], Length[variables]], Total[#] <= degree &];
  MonomialList[
    Total[(Times @@ MapThread[Power, {variables, #}]) & /@ powers],
    variables,
    DegreeReverseLexicographic
  ]
];

solveLinear[equations_List, unknowns_List] := Module[
  {arrays, matrix, rhs, augmented},
  If[equations === {}, Return[ConstantArray[0, Length[unknowns]]]];
  arrays = CoefficientArrays[equations, unknowns];
  If[Length[arrays] =!= 2, Return[$Failed]];
  matrix = Normal[arrays[[2]]];
  rhs = -Normal[arrays[[1]]];
  augmented = Join[matrix, List /@ rhs, 2];
  If[MatrixRank[matrix] =!= MatrixRank[augmented], Return[$Failed]];
  Quiet @ Check[LinearSolve[matrix, rhs], $Failed]
];

findZeroGrowth[strategy_Association, variable_Symbol] := Module[
  {z, protected, substitutions, polynomial, generators, cap, basis,
   unknowns, blocks, cofactors, residual, equations, solution, candidate,
   found = Missing["NotFound"]},
  z = Lookup[strategy, "baikov_variables", $Failed];
  protected = Lookup[strategy, "propagator_slots", $Failed];
  substitutions = Lookup[strategy, "fixed_scale_substitutions", $Failed];
  polynomial = Lookup[strategy, "baikov_polynomial", $Failed];
  cap = Lookup[strategy, "search_max_total_degree", $Failed];
  If[
    !VectorQ[z, MatchQ[#, _Symbol] &] ||
      !VectorQ[protected, IntegerQ] ||
      Complement[protected, Range[Length[z]]] =!= {} ||
      !ListQ[substitutions] ||
      polynomial === $Failed ||
      !IntegerQ[cap] || cap < 0,
    Return[failure["The enhanced-Baikov search data are malformed."]]
  ];
  polynomial = Expand[polynomial /. substitutions];
  generators = Append[
    MapIndexed[
      If[MemberQ[protected, First[#2]], z[[First[#2]]] D[polynomial, #1], D[polynomial, #1]] &,
      z
    ],
    polynomial
  ];
  Do[
    basis = monomialBasis[z, degree];
    unknowns = Table[Unique["coefficient$"], {Length[generators] Length[basis]}];
    blocks = Partition[unknowns, Length[basis]];
    cofactors = Together /@ (# . basis & /@ blocks);
    residual = Together[D[polynomial, variable] - cofactors . generators];
    equations = If[
      Numerator[residual] === 0,
      {},
      Last /@ CoefficientRules[Expand[Numerator[residual]], z]
    ];
    solution = solveLinear[equations, unknowns];
    If[solution =!= $Failed,
      candidate = Together /@ (cofactors /. Thread[unknowns -> solution]);
      If[zeroQ[D[polynomial, variable] - candidate . generators],
        found = <|
          "kind" -> "enhanced-baikov",
          "cofactors" -> Most[candidate],
          "f_cofactor" -> Last[candidate]
        |>;
        Break[]
      ]
    ],
    {degree, 0, cap}
  ];
  found
];

ChooseDerivativeOperator[prepared_Association, variable_Symbol, selection_ : "enhanced-first"] := Module[
  {operators, strategy, exact},
  If[!MemberQ[{"enhanced-first", "prepared-affine"}, selection],
    Return[failure["Unknown derivative operator selection."]]];
  operators = Lookup[prepared, "operators", $Failed];
  If[
    !AssociationQ[operators] || !KeyExistsQ[operators, variable],
    Return[failure["The requested variable or its prepared operator is missing."]]
  ];
  If[selection === "prepared-affine",
    Return[<|"kind" -> "prepared-affine", "operator" -> operators[variable],
      "enhanced_search_attempted" -> False|>]];
  strategy = Lookup[prepared, "exact_strategy", $Failed];
  If[!AssociationQ[strategy],
    Return[failure["The enhanced-Baikov strategy is missing."]]];
  exact = findZeroGrowth[strategy, variable];
  If[FailureQ[exact], Return[exact]];
  If[AssociationQ[exact], exact, <|"kind" -> "affine-fallback", "operator" -> operators[variable]|>]
];
ChooseDerivativeOperator[___] :=
  failure["ChooseDerivativeOperator expects a prepared Association and a symbolic variable."];

End[];
EndPackage[];
