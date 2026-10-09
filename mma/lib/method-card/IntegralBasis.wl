(* Integral rows only: leave scalar coefficients factored and reject nonlinear
   terms before unit-vector substitution can turn products into valid rows. *)
IntegralCoefficientRows[expressions_List, basis_List, head_] := Module[
  {integral, linearTermQ, vectors, zero},
  integral = If[head === Symbol, Alternatives @@ basis, Blank[head]];
  linearTermQ[term_] := MatchQ[term,
    coefficient_. (item : integral) /; FreeQ[coefficient, integral]];
  vectors = Dispatch[If[basis === {}, {}, Thread[basis -> IdentityMatrix[Length[basis]]]]];
  zero = ConstantArray[0, Length[basis]];
  Function[expression, Module[{value, terms, linear, residual, row},
    value = Expand[expression, integral];
    terms = If[Head[value] === Plus, List @@ value, {value}];
    linear = Total[Select[terms, linearTermQ]];
    residual = value - linear;
    If[!TrueQ[Together[residual] === 0], $Failed,
      row = linear /. vectors;
      If[row === 0, zero,
        If[VectorQ[row, FreeQ[#, integral] &] && Length[row] === Length[basis], row, $Failed]]]
  ]] /@ expressions
];
