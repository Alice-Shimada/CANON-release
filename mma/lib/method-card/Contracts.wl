(* Exact coefficient syntax and the structural contracts shared by the public steps.
   Loaded inside CanonMethodCard`Private` by MethodCardCore.wl. *)

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
    DeleteDuplicates[Cases[Unevaluated[expr], _Symbol, {0, Infinity}]]
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

matrixListShapeQ[matrices_, count_Integer, dimension_Integer] :=
  ListQ[matrices] && Length[matrices] === count &&
    And @@ (squareMatrixQ[#, dimension] & /@ matrices);

exactMatrixListQ[matrices_, count_Integer, dimension_Integer] :=
  ListQ[matrices] && Length[matrices] === count &&
    And @@ (
      MatrixQ[#] && Dimensions[#] === {dimension, dimension} &&
        And @@ (ExactRationalExpressionQ /@ Flatten[#]) & /@ matrices
    );
