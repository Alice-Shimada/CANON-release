BeginPackage["CanonParameterization`"];
ParameterizeFamily::usage = "ParameterizeFamily[spec] preserves a symbolic chart and returns reducer-neutral WL and JSON-ready family data.";
Begin["`Private`"];
need[q_, tag_, details_: <||>] := If[!TrueQ[q], Throw[Failure[tag, details]]];
rat[e_] := Cancel[Together[e]];
zeroQ[e_] := And @@ (TrueQ[rat[#] === 0] & /@ Flatten[{e}]);
exactQ[e_] := FreeQ[e, _Real | (z_Complex /; Precision[z] =!= Infinity) | Indeterminate | _DirectedInfinity | Undefined];
str[e_] := StringReplace[ToString[e, InputForm], " " -> ""];
variableQ[v_] := MatchQ[v, _Symbol | _Symbol[__Integer]];

ParameterizeFamily[spec_Association] := Catch[Module[
  {loops, ext, vars, dim, eps, point, invariants, remaining, invNames, kind, routing, masses,
   indexOrder, slots, vectors, positions, metric, basis, independent, coefficients,
   momentumRules, scalarProducts, gram, pairs, rules, frozenRouting, frozenMasses,
   frozenScalars, allowed, symbols, placeholders, probe, family, reducer, identities},
  need[Lookup[spec, "schema", None] === "canon-neu/parameterization-spec/v1", "INVALID_PARAMETERIZATION_SPEC"];
  identities = {"family_ref", "basis_ref", "chart_id", "topology", "integral_head"};
  need[And @@ (StringQ[Lookup[spec, #, None]] & /@ identities), "MISSING_FAMILY_IDENTITY"];
  loops = spec["loop_momenta"]; ext = spec["external_momenta"]; vars = spec["variables"];
  dim = spec["dimension"]; eps = spec["regulator"]; kind = spec["chart_type"];
  need[ListQ[loops] && Length[loops] > 0 && ListQ[ext] &&
    And @@ (MatchQ[#, _Symbol] & /@ Join[loops, ext]) && DuplicateFreeQ[Join[loops, ext]] &&
    ListQ[vars] && And @@ (variableQ /@ vars) && DuplicateFreeQ[vars] &&
    MatchQ[dim, _Symbol] && MatchQ[eps, _Symbol] && dim =!= eps &&
    FreeQ[vars, dim | eps | Alternatives @@ Join[loops, ext]] &&
    MatchQ[spec["dimension_rule"], _Rule] && First[spec["dimension_rule"]] === dim &&
    exactQ[Last[spec["dimension_rule"]]], "INVALID_DECLARED_SYMBOLS"];
  routing = spec["propagator_momenta"]; masses = spec["propagator_masses_squared"];
  indexOrder = spec["index_order"]; slots = spec["propagator_slots"];
  need[ListQ[routing] && Length[routing] > 0 && ListQ[masses] &&
    Length[routing] === Length[masses] === Length[indexOrder] && DuplicateFreeQ[indexOrder] &&
    VectorQ[slots, IntegerQ] && DuplicateFreeQ[slots] && SubsetQ[Range[Length[routing]], slots] &&
    VectorQ[spec["top_level_sectors"], IntegerQ] &&
    AllTrue[spec["top_level_sectors"], # >= 0 && BitAnd[#, Total[2^(slots - 1)]] === # &], "INVALID_PROPAGATOR_ORDER"];
  point = Lookup[spec, "point", {}]; invariants = Lookup[spec, "invariants", {}];
  need[ListQ[invariants] && And @@ (AssociationQ[#] && variableQ[Lookup[#, "name", None]] &&
    IntegerQ[Lookup[#, "mass_dimension", None]] & /@ invariants), "INVALID_INVARIANT_DECLARATION"];
  invNames = Lookup[invariants, "name", {}];
  need[DuplicateFreeQ[invNames] && ListQ[point] && And @@ (MatchQ[#, _Rule] & /@ point) &&
    DuplicateFreeQ[First /@ point] && SubsetQ[Union[vars, invNames], First /@ point] &&
    And @@ (NumericQ /@ (Last /@ point)) && exactQ[point] && FreeQ[First /@ point, dim | eps], "INVALID_EXACT_POINT"];
  remaining = Select[invariants, !MemberQ[First /@ point, #["name"]] &];
  family = Join[KeyTake[spec, Join[identities, {"chart_type", "loop_momenta", "external_momenta", "variables",
      "dimension", "regulator", "dimension_rule", "propagator_momenta", "propagator_masses_squared",
      "index_order", "propagator_slots", "top_level_sectors"}]],
    <|"schema" -> "canon-neu/parameterized-family/v1", "point_rules" -> point, "invariants" -> invariants,
      "parameters" -> Lookup[spec, "parameters", DeleteDuplicates[Join[{dim}, vars, invNames]]],
      "sector_convention" -> Lookup[spec, "sector_convention", "positive declared propagator slots; a1 is the least-significant bit; ISP bits are zero"]|>];

  Switch[kind,
    "vectors",
      vectors = spec["vectors"]; positions = spec["external_basis"]; metric = spec["metric"];
      need[MatrixQ[vectors] && Length[vectors] === Length[ext] && ListQ[metric] &&
        Length[metric] === Last[Dimensions[vectors]] && VectorQ[positions, IntegerQ] &&
        Length[positions] > 0 && DuplicateFreeQ[positions] && SubsetQ[Range[Length[ext]], positions], "INVALID_VECTOR_CHART"];
      basis = vectors[[positions]]; independent = ext[[positions]];
      need[MatrixRank[basis] === Length[positions], "DEPENDENT_EXTERNAL_BASIS"];
      coefficients = Quiet[Check[(rat[LinearSolve[Transpose[basis], #]] & /@ vectors), $Failed]];
      need[MatrixQ[coefficients] && Dimensions[coefficients] === {Length[ext], Length[positions]} &&
        zeroQ[vectors - coefficients . basis], "EXTERNAL_BASIS_DOES_NOT_SPAN_CHART"];
      momentumRules = Thread[ext -> (Expand[# . independent] & /@ coefficients)];
      gram = rat[basis . DiagonalMatrix[metric] . Transpose[basis]];
      pairs = Flatten[Table[{i, j}, {i, Length[independent]}, {j, i, Length[independent]}], 1];
      scalarProducts = Thread[(independent[[#]] & /@ pairs) -> (Extract[gram, #] & /@ pairs)];
      family = Join[family, <|"vectors" -> vectors, "external_basis" -> positions, "metric" -> metric,
        "momentum_rules" -> momentumRules, "scalar_products" -> scalarProducts|>],
    "scalar-products",
      independent = ext; momentumRules = Lookup[spec, "momentum_rules", {}];
      rules = spec["scalar_products"];
      pairs = Flatten[Table[{i, j}, {i, Length[independent]}, {j, i, Length[independent]}], 1];
      need[ListQ[momentumRules] && And @@ (MatchQ[#, _Rule] & /@ momentumRules) &&
        ListQ[rules] && Length[rules] === Length[pairs] &&
        And @@ (MatchQ[#, Rule[{_Symbol, _Symbol}, _]] & /@ rules) &&
        Sort[Sort /@ (First /@ rules)] === Sort[Sort /@ (independent[[#]] & /@ pairs)], "INVALID_SCALAR_PRODUCT_CHART"];
      scalarProducts = Table[independent[[pair]] -> Last[SelectFirst[rules,
        Sort[First[#]] === Sort[independent[[pair]]] &]], {pair, pairs}];
      family = Join[family, <|"momentum_rules" -> momentumRules, "scalar_products" -> scalarProducts|>],
    _, Throw[Failure["UNSUPPORTED_CHART_TYPE", <|"chart_type" -> kind|>]]
  ];
  need[FreeQ[{masses, Last /@ scalarProducts}, Alternatives @@ Join[loops, ext]], "MOMENTUM_IN_SCALAR_DATA"];
  (* Keep family symbolic; only the neutral reduction view is specialized. *)
  frozenRouting = rat[Expand[routing /. momentumRules] /. point];
  frozenMasses = rat[masses /. point]; frozenScalars = rat[(Last /@ scalarProducts) /. point];
  need[exactQ[{frozenRouting, frozenMasses, frozenScalars}], "INEXACT_OR_SINGULAR_CHART"];
  allowed = Join[loops, independent];
  need[AllTrue[frozenRouting, Function[q, zeroQ[q - Total[(Coefficient[Expand[q], #] # & /@ allowed)]]]],
    "NONLINEAR_OR_UNDECLARED_MOMENTUM"];
  placeholders = Table[Unique["invariant$"], {Length[remaining]}];
  probe = {frozenRouting, frozenMasses, frozenScalars} /. Thread[Lookup[remaining, "name", {}] -> placeholders];
  symbols = DeleteDuplicates[Cases[probe, s_Symbol /; Context[Unevaluated[s]] =!= "System`", {0, Infinity}, Heads -> True]];
  need[Complement[symbols, Join[allowed, placeholders]] === {}, "UNDECLARED_REMAINING_INVARIANTS",
    <|"symbols" -> Complement[symbols, Join[allowed, placeholders]]|>];
  reducer = Join[KeyTake[family, {"family_ref", "basis_ref", "chart_id", "topology", "integral_head",
      "propagator_slots", "top_level_sectors"}], <|
    "schema" -> "canon-neu/reducer-family/v1", "index_order" -> (If[StringQ[#], #, str[#]] & /@ indexOrder),
    "loop_momenta" -> (str /@ loops),
    "external_momenta" -> (str /@ independent), "propagators" -> MapThread[
      <|"momentum" -> str[#1], "mass_squared" -> str[#2]|> &, {frozenRouting, frozenMasses}],
    "scalar_products" -> MapThread[<|"momenta" -> (str /@ independent[[#1]]), "value" -> str[#2]|> &, {pairs, frozenScalars}],
    "invariants" -> (<|"name" -> str[#["name"]], "mass_dimension" -> #["mass_dimension"]|> & /@ remaining),
    "point" -> (<|"variable" -> str[First[#]], "value" -> str[Last[#]]|> & /@ point),
    "dimension" -> str[dim], "variables" -> (str /@ vars), "regulator" -> str[eps], "dimension_rule" -> str[spec["dimension_rule"]]|>];
  <|"family" -> family, "reducer" -> reducer|>
]];
End[];
EndPackage[];
