(* Cumulative basis composition without recursively expanding earlier bases. *)
BeginPackage["CanonPrefixComposition`"];
ComposePrefix::usage = "ComposePrefix[rawLower,lowerBasis,lowerT,currentBasis,T] returns the complete cumulative map and compact basis.";
Begin["`Private`"];
zeroQ[value_] := AllTrue[Flatten[{value}], TrueQ[Together[#] === 0] &];

lowerInverse[raw_, basis_, transformation_] := Module[
  {n = Length[raw], placeholders, expression, arrays, coefficients, inverse},
  placeholders = Table[Unique["raw$"], {n}];
  expression = basis /. Thread[raw -> placeholders];
  arrays = Quiet[Check[CoefficientArrays[expression, placeholders], $Failed]];
  If[ListQ[arrays] && Length[arrays] === 2 && zeroQ[Normal[First[arrays]]],
    coefficients = Normal[arrays[[2]]];
    If[Dimensions[coefficients] === {n, n} &&
        AllTrue[Flatten[coefficients], CanonMethodCard`ExactAlgebraicExpressionQ] &&
        AllTrue[Join[raw, placeholders], FreeQ[coefficients, #] &] &&
        zeroQ[expression - coefficients.placeholders] &&
        zeroQ[transformation.coefficients - IdentityMatrix[n]],
      Return[coefficients]]
  ];
  inverse = Map[Together, Inverse[transformation], {2}];
  If[!zeroQ[basis - inverse.raw],
    Return[Failure["PREVIOUS_BASIS_MISMATCH", <||>]]];
  inverse
];

ComposePrefix[raw_List, basis_List, lowerT_, current_List, transformation_] := Module[
  {n = Length[raw], m = Length[current], inverse, base, inverseBase},
  If[Length[basis] =!= n || !DuplicateFreeQ[Join[raw, current]] ||
      (n > 0 && (!MatrixQ[lowerT] || Dimensions[lowerT] =!= {n, n})),
    Return[Failure["INVALID_PREVIOUS_PREFIX", <||>]]];
  If[n === 0, base = inverseBase = IdentityMatrix[m],
    inverse = lowerInverse[raw, basis, lowerT];
    If[FailureQ[inverse], Return[inverse]];
    base = ArrayFlatten[{{lowerT, ConstantArray[0, {n, m}]},
      {ConstantArray[0, {m, n}], IdentityMatrix[m]}}];
    inverseBase = ArrayFlatten[{{inverse, ConstantArray[0, {n, m}]},
      {ConstantArray[0, {m, n}], IdentityMatrix[m]}}]
  ];
  (* Inverse[base.T] = Inverse[T].Inverse[base]; canonicalize coefficients
     before multiplying the original masters, rather than old basis trees. *)
  <|"transformation" -> Map[Together, base.transformation, {2}],
    "basis" -> Map[Together, Inverse[transformation].inverseBase, {2}].Join[raw, current]|>
];
End[];
EndPackage[];
