(* Exact options and finite specialization shared by the Libra core routes. *)
BeginPackage["CanonLibraFactorization`"];
ReadOptions; SelectFactor;
Begin["`Private`"];

ReadOptions[options_Association] := Module[{raw, reference, strategy, budget},
  raw = Lookup[options, "reference_regulator", 1/2];
  reference = Which[
    MatchQ[raw, _Integer | _Rational], raw,
    AssociationQ[raw] && Sort[Keys[raw]] === {"denominator", "numerator"} &&
      IntegerQ[raw["numerator"]] && IntegerQ[raw["denominator"]] && raw["denominator"] =!= 0,
      raw["numerator"]/raw["denominator"],
    True, $Failed];
  strategy = Lookup[options, "free_parameter_strategy", "ones"];
  budget = Lookup[options, "free_parameter_max_trials", 64];
  If[reference === $Failed || !MemberQ[{"ones", "bounded-rational-search"}, strategy] ||
      !IntegerQ[budget] || budget <= 0 ||
      (strategy === "ones" && KeyExistsQ[options, "free_parameter_max_trials"]),
    Return[Failure["INVALID_OPTIONS", <|"reason" ->
      "Use an exact integer or numerator/denominator reference, ones or bounded-rational-search, and a positive trial budget only with bounded-rational-search."|>]]];
  <|"reference_regulator" -> reference, "reference_regulator_exact" -> ToString[reference, InputForm],
    "free_parameter_strategy" -> strategy, "free_parameter_max_trials" -> budget|>
];

(* Try all ones, all zeros, then unit points, stopping at the first valid factor.
   Generate only attempted points; the finite policy is not a complete search. *)
SelectFactor[template_, free_List, options_Association, validate_] := Module[
  {count = Length[free], n = Length[template], strategy = options["free_parameter_strategy"],
    budget = options["free_parameter_max_trials"], required, values, rules, factor,
    determinant, invertible, checks, trials = {}, selected = None, index, evidence, code},
  required = Which[strategy === "ones" || count === 0, 1, count === 1, 2, True, count + 2];
  Do[
    values = Which[index === 1, ConstantArray[1, count], index === 2,
      ConstantArray[0, count], True, UnitVector[count, index - 2]];
    rules = Thread[free -> values];
    factor = Quiet[Check[Map[Together, template /. rules, {2}], $Failed]];
    determinant = If[MatrixQ[factor] && Dimensions[factor] === {n, n} &&
        And @@ (CanonMethodCard`ExactRationalExpressionQ /@ Flatten[factor]),
      Quiet[Check[Together[Det[factor]], $Failed]], $Failed];
    invertible = determinant =!= $Failed &&
      CanonMethodCard`ExactRationalExpressionQ[determinant] && determinant =!= 0;
    checks = If[TrueQ[invertible], validate[factor, rules], <||>];
    AppendTo[trials, Join[<|"trial_index" -> index, "specification_values" -> values,
      "determinant_exact" -> ToString[determinant, InputForm], "invertible" -> invertible|>, checks]];
    If[TrueQ[invertible] && And @@ (TrueQ /@ Values[checks]),
      selected = <|"factor" -> factor, "rules" -> rules, "index" -> index|>; Break[]],
    {index, Min[required, budget]}];
  evidence = <|"free_parameter_strategy" -> strategy, "free_parameter_count" -> count,
    "free_parameter_names" -> (ToString[#, InputForm] & /@ free),
    "free_parameter_max_trials" -> budget, "free_parameter_trial_count" -> Length[trials],
    "free_parameter_trials" -> trials,
    "free_parameter_selected_index" -> If[AssociationQ[selected], selected["index"], Null]|>;
  If[AssociationQ[selected], Return[Join[<|"success" -> True, "evidence" -> evidence|>, selected]]];
  code = Which[Length[trials] < required, "FREE_PARAMETER_BUDGET",
    AnyTrue[trials, TrueQ[#["invertible"]] &&
      TrueQ[Lookup[#, "kinematically_constant", False]] &&
      !TrueQ[Lookup[#, "equations_satisfied", True]] &], "LINEAR_EQUATIONS_UNSATISFIED",
    True, "FACTORIZATION_TRANSFORMATION"];
  <|"success" -> False, "limit_code" -> code, "evidence" -> evidence|>
];

End[];
EndPackage[];
