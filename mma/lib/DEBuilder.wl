BeginPackage["CANON`DEBuilder`"];

BuildDifferentialEquations::usage =
  "BuildDifferentialEquations[family, masters, rules] constructs exact ordered " <>
  "master-integral differential-equation matrices entirely in memory. An optional fourth argument reuses caller-checked coefficient rows in rule order and master order.";
DifferentialEquationTargets::usage = "DifferentialEquationTargets[family, masters] returns the distinct integral targets of the same affine derivatives used by BuildDifferentialEquations.";

Begin["`Private`"];

masterDerivative[master_, operator_] := Module[
  {indices = List @@ master, head = Head[master], arity = Length[master]},
  Total @ Table[
    -indices[[source]] (operator[[source, 1]] Apply[
        head, indices + UnitVector[arity, source]
      ] + Sum[operator[[source, target + 1]] Apply[
          head, indices + UnitVector[arity, source] - UnitVector[arity, target]
        ], {target, arity}]),
    {source, arity}
  ]
];

vectorizedRules[masters_, rules_, coefficientRows_ : Automatic] := Module[{basis, vectors, zero},
  zero = ConstantArray[0, Length[masters]];
  basis = Thread[masters -> IdentityMatrix[Length[masters]]];
  vectors = If[coefficientRows === Automatic,
    Replace[(Last /@ rules) /. basis, 0 -> zero, {1}], coefficientRows];
  Dispatch @ Join[basis, Thread[(First /@ rules) -> vectors]]
];

DifferentialEquationTargets[family_, masters_List] := Module[{head = Head[First[masters]]},
  DeleteDuplicates[Cases[
    Table[masterDerivative[master, operator],
      {master, masters}, {operator, Values[family["operators"]]}],
    Blank[head], {0, Infinity}], SameQ]
];

curvature[matrices_, {variableI_, variableJ_}, assignments_] := Module[
  {matrixI, matrixJ, derivativeJI, derivativeIJ, residual},
  matrixI = matrices[variableI];
  matrixJ = matrices[variableJ];
  derivativeJI = D[matrixJ, variableI];
  derivativeIJ = D[matrixI, variableJ];
  matrixI = SparseArray[matrixI /. assignments];
  matrixJ = SparseArray[matrixJ /. assignments];
  derivativeJI = SparseArray[derivativeJI /. assignments];
  derivativeIJ = SparseArray[derivativeIJ /. assignments];
  residual = SparseArray[
    derivativeJI - derivativeIJ + matrixJ . matrixI - matrixI . matrixJ
  ];
  Normal[residual]
];

curvatureRecord[matrices_, parameters_, pair_] := Module[
  {assignments, residual},
  assignments = Thread[parameters -> Table[
    Prime[i]/Prime[i + 1], {i, Length[parameters]}]];
  residual = curvature[KeyTake[matrices, pair], pair, assignments];
  <|"variables" -> pair, "assignments" -> assignments,
    "zero" -> And @@ (# === 0 & /@ Flatten[residual])|>
];

BuildDifferentialEquations[family_, masters_, rules_, coefficientRows_ : Automatic] := Module[
  {variables, replacements, zero, matrices, records},
  variables = Keys[family["operators"]];
  replacements = vectorizedRules[masters, rules, coefficientRows];
  zero = ConstantArray[0, Length[masters]];
  matrices = AssociationMap[Function[variable, Replace[
      (masterDerivative[#, family["operators", variable]] /. replacements) & /@
        masters,
      0 -> zero, {1}
    ]], variables];
  records = curvatureRecord[matrices, family["parameters"], #] & /@ Subsets[variables, {2}];
  <|"matrices" -> matrices, "validity" -> <|
    "scope" -> "exact-point-samples",
    "flat" -> AllTrue[records, TrueQ[#1["zero"]] &], "pairs" -> records
  |>|>
];

End[];
EndPackage[];
