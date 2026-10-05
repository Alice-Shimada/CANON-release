(* A deterministic provider double for adapter bounds and adversarial output.
   Real Libra regressions use the separately declared immutable package entry. *)
BeginPackage["Libra`"];
$LibraVersion = "bounded-normalization-test-double";
$LibraUseFermat = False;
NewDSystem; Fuchsify; Transform; FactorOut; OverallTransformation; EFormQ;
GetSubspaces; Projector; Balance;
Begin["`Private`"];
SetAttributes[NewDSystem, HoldFirst];
NewDSystem[ds_Symbol, rule_Rule] := (
  ds[First[rule]] = Last[rule]; ds["variable"] = First[rule];
  ds["overall"] = IdentityMatrix[Length[Last[rule]]]; Null
);
Fuchsify[ds_Symbol, variable_] := IdentityMatrix[Length[ds[variable]]];
Transform[m_?MatrixQ, t_, variable_, ___] := Together[Inverse[t].(m.t - D[t, variable])];
Transform[ds_Symbol, t_] := (
  ds[ds["variable"]] = Transform[ds[ds["variable"]], t, ds["variable"]];
  ds["overall"] = Together[ds["overall"].t]; Null
);
FactorOut[ds_Symbol, variable_, regulator_, 1/2, ___] :=
  If[EFormQ[ds[variable], regulator], IdentityMatrix[Length[ds[variable]]], $Failed];
OverallTransformation[ds_Symbol][_] := ds["overall"];
EFormQ[m_, regulator_] := FreeQ[Together[m/regulator], regulator];
GetSubspaces[m_?MatrixQ, {variable_, point_}, regulator_, side_, ___] := Module[
  {r, data, selected},
  r = If[point === Infinity, -SeriesCoefficient[m, {variable, Infinity, 1}],
    SeriesCoefficient[m, {variable, point, -1}]];
  If[side === Right, r = -Transpose[r]];
  data = Transpose[Eigensystem[r]];
  selected = Select[data, TrueQ[(First[#] /. regulator -> 0) < -1/2] &];
  List /@ (Last /@ selected)
];
Projector[u_, v_, ___] := Together[Transpose[u].Inverse[v.Transpose[u]].v];
Balance[p_, {variable_, from_, to_}] := IdentityMatrix[Length[p]] - p +
  p Which[from === Infinity, variable - to, to === Infinity, 1/(variable - from),
    True, (variable - to)/(variable - from)];
End[];
EndPackage[];
