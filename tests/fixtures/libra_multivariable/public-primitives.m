(* Boundary/fault injection fixture, not a scientific solver. *)
BeginPackage["Libra`"];
NewDSystem; Transform; Fuchsify; FactorDependence; GaussSolve;
FuchsianQ; EFormQ; TClosure; $LibraVersion; $LibraUseFermat;
Begin["`Private`"];
$LibraVersion = "fixture-multivariable";
NewDSystem[ds_, rules_List, ___] := (Do[ds[First[r]] = Last[r], {r, rules}]; ds["variables"] = First /@ rules; Null);
Transform[ds_, t_, ___] := (Do[
  ds[v] = Map[Together, Inverse[t].(ds[v].t - D[t, v]), {2}], {v, ds["variables"]}]; Null);
Fuchsify[ds_, v_] := IdentityMatrix[Length[ds[v]]];
FuchsianQ[_, _] := True;
EFormQ[m_, eps_] := CanonMethodCard`EpsilonFactorizedQ[{m}, eps];
FactorDependence[matrices_, eps_, mu_, ___] := Module[{vars},
  vars = Table[Unique["factor"], {Length[First[matrices]]}];
  {{}, DiagonalMatrix[vars], vars}];
GaussSolve[eqs_, vars_, ___] := {};
TClosure[mask_] := Table[Boole[i == j || mask[[i, j]] > 0],
  {i, Length[mask]}, {j, Length[mask]}];
End[];
EndPackage[];
