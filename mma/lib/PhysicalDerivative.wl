BeginPackage["CANON`PhysicalDerivative`"];

PreparePhysicalDerivatives::usage =
  "PreparePhysicalDerivatives[family] derives fixed-loop physical kinematic derivatives from routing and the external Gram matrix, returning canon.prepared-derivatives/v2 or Failure.";

Begin["`Private`"];

need[q_, code_, details_: <||>] := If[!TrueQ[q], Throw[Failure[code, details]]];
rat[e_] := Cancel[Together[e]];
zeroQ[e_] := And @@ (TrueQ[rat[#] === 0] & /@ Flatten[{e}]);
rationalSyntaxQ[e_] := Which[
  IntegerQ[e] || Head[e] === Rational, True,
  Head[e] === Symbol, Context[e] =!= "System`",
  MemberQ[{Plus, Times}, Head[e]], AllTrue[List @@ e, rationalSyntaxQ],
  Head[e] === Power, IntegerQ[Last[List @@ e]] && rationalSyntaxQ[First[List @@ e]],
  True, False
];

(* A deterministic particular solution: free columns are zero. Both uses are
   exact linear systems over the declared symbolic chart. *)
linearSolution[matrix_, rhs_] := Module[{rows, columns, result, pivot},
  columns = Last[Dimensions[matrix]];
  rows = Quiet @ Check[RowReduce[Join[matrix, rhs, 2]], $Failed];
  If[rows === $Failed, Return[$Failed]];
  If[AnyTrue[rows, zeroQ[Take[#, columns]] && !zeroQ[Drop[#, columns]] &], Return[$Failed]];
  result = ConstantArray[0, {columns, Last[Dimensions[rhs]]}];
  Do[
    pivot = SelectFirst[Range[columns], !zeroQ[row[[#]]] &, None];
    If[pivot =!= None, result[[pivot]] = rat[Drop[row, columns]/row[[pivot]]]], {row, rows}];
  result
];

PreparePhysicalDerivatives[family_Association] := Catch @ Module[
  {loops, external, basis, variables, coordinates, forward, backward, routing,
   masses, scalarProducts, gram, value, count, allMomenta, coefficients,
   scalarPairs, scalarVariables, fullGram, denominators, rows, affineMatrix,
   unknowns, flowMatrix, gramPairs, flowRHS, flowSolution, flows, derivativeRows,
   velocity, derivatives, targetRows, solution, records, operators, rationalQ, slots, metadata},
  loops = Lookup[family, "loop_momenta", {}];
  external = Lookup[family, "external_momenta", {}];
  variables = Lookup[family, "variables", None];
  routing = Lookup[family, "propagator_momenta", None];
  masses = Lookup[family, "propagator_masses_squared", None];
  scalarProducts = Lookup[family, "scalar_products", {}];
  need[VectorQ[loops, MatchQ[#, _Symbol] &] && loops =!= {} &&
    VectorQ[external, MatchQ[#, _Symbol] &] && DuplicateFreeQ[Join[loops, external]] &&
    ListQ[variables] && DuplicateFreeQ[variables] &&
    AllTrue[variables, MatchQ[#, _Symbol | _Symbol[__Integer]] &] &&
    Intersection[variables, Join[loops, external]] === {} &&
    ListQ[routing] && routing =!= {} && ListQ[masses] && Length[routing] === Length[masses],
    "INVALID_DERIVATIVE_FAMILY"];
  need[FreeQ[{routing, masses, scalarProducts}, _Real | Indeterminate | _DirectedInfinity | Undefined],
    "INEXACT_DERIVATIVE_GEOMETRY"];
  need[FreeQ[variables, Lookup[family, "dimension", None] | Lookup[family, "regulator", None]],
    "KINEMATIC_DERIVATIVES_ONLY"];
  count = Length[routing];
  metadata = <||>;
  If[KeyExistsQ[family, "propagator_slots"],
    slots = family["propagator_slots"];
    need[ListQ[slots] && AllTrue[slots, IntegerQ] && DuplicateFreeQ[slots] &&
      Complement[slots, Range[count]] === {}, "INVALID_DERIVATIVE_FAMILY"];
    metadata = <|"exact_strategy" -> <|"propagator_slots" -> slots|>|>
  ];
  If[variables === {}, Return[Join[<|"schema" -> "canon.prepared-derivatives/v2",
    "variables" -> {}, "denominator_count" -> count, "operators" -> <||>|>, metadata]]];
  coordinates = Table[Unique["coordinate$"], {Length[variables]}];
  forward = Thread[variables -> coordinates]; backward = Thread[coordinates -> variables];
  basis = If[KeyExistsQ[family, "external_basis"], external[[family["external_basis"]]], external];
  routing = Expand[routing /. Lookup[family, "momentum_rules", {}]] /. forward;
  masses = masses /. forward; scalarProducts = scalarProducts /. forward;
  allMomenta = Join[loops, basis];
  coefficients = Table[Coefficient[momentum, label], {momentum, routing}, {label, allMomenta}];
  need[zeroQ[routing - coefficients . allMomenta] &&
    FreeQ[{coefficients, masses, Last /@ scalarProducts}, Alternatives @@ allMomenta],
    "NONLINEAR_OR_UNDECLARED_DERIVATIVE_MOMENTUM"];
  gram = Table[
    value = SelectFirst[scalarProducts, MatchQ[#, Rule[{_Symbol, _Symbol}, _]] &&
      Sort[First[#]] === Sort[{basis[[i]], basis[[j]]}] &, None];
    need[value =!= None, "INCOMPLETE_EXTERNAL_GRAM", <|"momenta" -> {basis[[i]], basis[[j]]}|>];
    Last[value], {i, Length[basis]}, {j, Length[basis]}];
  If[basis === {}, flows = ConstantArray[{}, Length[coordinates]],
    unknowns = Table[Unique["flow$"], {Length[basis]^2}];
    flowMatrix = Partition[unknowns, Length[basis]];
    gramPairs = Flatten[Table[{i, j}, {i, Length[basis]}, {j, i, Length[basis]}], 1];
    rows = Extract[flowMatrix . gram + gram . Transpose[flowMatrix], gramPairs];
    flowRHS = Transpose[Table[Extract[D[gram, x], gramPairs], {x, coordinates}]];
    flowSolution = linearSolution[Table[Coefficient[row, unknown], {row, rows}, {unknown, unknowns}], flowRHS];
    need[flowSolution =!= $Failed, "EXTERNAL_GRAM_DERIVATIVE_UNSUPPORTED"];
    flows = Table[Partition[flowSolution[[All, i]], Length[basis]], {i, Length[coordinates]}];
    need[And @@ MapThread[zeroQ[#1 . gram + gram . Transpose[#1] - D[gram, #2]] &,
      {flows, coordinates}], "EXTERNAL_GRAM_DERIVATIVE_UNSUPPORTED"]
  ];
  scalarPairs = Flatten[Table[{i, j}, {i, Length[loops]},
    {j, i, Length[allMomenta]}], 1];
  scalarVariables = Table[Unique["scalar$"], {Length[scalarPairs]}];
  fullGram = ConstantArray[0, {Length[allMomenta], Length[allMomenta]}];
  Do[With[{pair = scalarPairs[[i]]},
    fullGram[[pair[[1]], pair[[2]]]] = scalarVariables[[i]];
    fullGram[[pair[[2]], pair[[1]]]] = scalarVariables[[i]]], {i, Length[scalarPairs]}];
  If[basis =!= {}, fullGram[[Length[loops] + 1 ;;, Length[loops] + 1 ;;]] = gram];
  denominators = MapThread[Expand[#1 . fullGram . #1 - #2] &, {coefficients, masses}];
  rows = Table[Append[Coefficient[denominator, #] & /@ scalarVariables,
    denominator /. Thread[scalarVariables -> 0]], {denominator, denominators}];
  affineMatrix = Transpose[Append[rows, Append[ConstantArray[0, Length[scalarVariables]], 1]]];
  derivativeRows = Table[
    Table[
      velocity = D[coefficients[[i]], coordinates[[v]]];
      If[basis =!= {}, velocity += Join[ConstantArray[0, Length[loops]],
        coefficients[[i, Length[loops] + 1 ;;]] . flows[[v]]]];
      Expand[2 velocity . fullGram . coefficients[[i]] - D[masses[[i]], coordinates[[v]]]],
      {i, count}], {v, Length[coordinates]}];
  derivatives = Flatten[derivativeRows];
  targetRows = Transpose[Table[Append[Coefficient[derivative, #] & /@ scalarVariables,
    derivative /. Thread[scalarVariables -> 0]], {derivative, derivatives}]];
  solution = linearSolution[affineMatrix, targetRows];
  need[solution =!= $Failed, "DERIVATIVE_OUTSIDE_PROPAGATOR_SPAN",
    <|"reason" -> "The declared denominators/ISPs do not span the physical derivative. Supply the missing family slots."|>];
  need[zeroQ[affineMatrix . solution - targetRows], "DERIVATIVE_OUTSIDE_PROPAGATOR_SPAN"];
  rationalQ[e_] := With[{value = rat[e]}, With[{symbols = DeleteDuplicates @ Cases[value,
      s_Symbol /; Context[s] =!= "System`", {0, Infinity}]},
    rationalSyntaxQ[Numerator[value]] && rationalSyntaxQ[Denominator[value]] &&
      PolynomialQ[Numerator[value], symbols] && PolynomialQ[Denominator[value], symbols]]];
  need[AllTrue[Flatten[solution], rationalQ], "NONRATIONAL_PHYSICAL_DERIVATIVE"];
  records = Table[With[{column = rat[solution[[All, k]]]},
    <|"constant" -> Last[column], "linear" -> DeleteCases[Table[
      If[zeroQ[column[[i]]], Nothing,
        <|"denominator" -> i, "coefficient" -> column[[i]]|>], {i, count}], Nothing]|>],
    {k, Length[derivatives]}];
  operators = AssociationThread[variables, Partition[records /. backward, count]];
  Join[<|"schema" -> "canon.prepared-derivatives/v2", "variables" -> variables,
    "denominator_count" -> count, "operators" -> operators,
    "construction" -> <|"method" -> "external-momentum-chain-rule", "external_momenta" -> basis,
      "external_flows" -> AssociationThread[variables, flows /. backward],
      "external_gram_identity" -> True, "denominator_identity" -> True|>|>, metadata]
];

PreparePhysicalDerivatives[___] := Failure["INVALID_DERIVATIVE_FAMILY", <||>];

End[];
EndPackage[];
