#!/usr/bin/env wolframscript
$HistoryLength = 0;
{root, comparisonSector, staged, receipt} = Rest[$ScriptCommandLine];
Get[FileNameJoin[{root, "mma", "lib", "MethodCardCore.wl"}]];
Get[FileNameJoin[{root, "mma", "lib", "DEBuilder.wl"}]];
Get[comparisonSector];
ClearAll[x, y, z, d, eps, f];
cases = Quiet[{
  0, -3, 2/7, 3 + 2 I, x, (x^2 + y)/(x - y),
  Sum[(x^i + y)/(x + i y + z), {i, 1, 8}],
  (x + 1)/(x - y) + (y + 2)/(x + z),
  ((x + 1)/(x - y)) ((y + 2)/(x + z)),
  1/(1 + Sin[x]) + Sin[x]/(1 + Sin[x]),
  1/(1 + Sqrt[x]) + 1/(1 - Sqrt[x]),
  (1 + Sqrt[x]) (1 - Sqrt[x]),
  1.0, (1.0 + x)/(1 + y), Sin[x], Exp[x], Sqrt[x], x^y, Pi,
  Infinity, ComplexInfinity, Indeterminate, Undefined,
  1/(x^2 - y^2 - (x - y) (x + y))
}];
expected = Join[ConstantArray[True, 10], ConstantArray[False, 14]];
{beforeSeconds, before} = AbsoluteTiming[CanonMethodCard`ExactRationalExpressionQ /@ cases];
prepared = <|"family_ref" -> "neutral", "parameters" -> {d,x,y},
  "variables" -> {x,y}, "regulator" -> eps, "dimension_rule" -> (d -> 4 - 2 eps)|>;
basis = <|"basis_ref" -> "neutral-basis", "masters" -> {f[1]}|>;
reduction = <|"masters" -> {f[1]}, "rules" -> {}|>;
normalized = <|"derivatives" -> <|"denominator_count" -> 1, "variables" -> {x,y},
  "operators" -> <|
    x -> {<|"constant" -> 0, "linear" -> {<|"denominator" -> 1, "coefficient" -> d/x|>}|>},
    y -> {<|"constant" -> 0, "linear" -> {<|"denominator" -> 1, "coefficient" -> d/y|>}|>}|>|>|>;
beforeBuild = CANON`SectorDE`BuildOrderedMasterDE[prepared, basis, reduction, normalized];
nonflat = ReplacePart[normalized, {Key["derivatives"], Key["operators"], Key[y], 1, Key["linear"], 1, Key["coefficient"]} -> x];
beforeNonflat = CANON`SectorDE`BuildOrderedMasterDE[prepared, basis, reduction, nonflat];
(* A neutral cost fixture with repeated polynomial numerators and distinct
   rational denominators tests the actual source versions, not a copied predicate. *)
DownValues[originalExactRationalCheck] = DownValues[CanonMethodCard`ExactRationalExpressionQ] /.
  CanonMethodCard`ExactRationalExpressionQ -> originalExactRationalCheck;
checkerCalls = 0; checkerHeads = <||>;
CanonMethodCard`ExactRationalExpressionQ[entry_] := Module[{head, start, value, record},
  head = ToString[Head[entry], InputForm]; start = AbsoluteTime[];
  value = originalExactRationalCheck[entry]; checkerCalls++;
  record = Lookup[checkerHeads, head, <|"calls" -> 0, "seconds" -> 0.|>];
  checkerHeads[head] = <|"calls" -> record["calls"] + 1,
    "seconds" -> record["seconds"] + N[AbsoluteTime[] - start]|>; value
];
costPolynomial = Sum[k x^Mod[k, 7] y^Quotient[k, 7], {k, 1, 140}];
costExpression = Sum[costPolynomial/(x + k y + z), {k, 1, 12}];
costMatrices = {ConstantArray[costExpression, {12,12}]};
{beforeCostSeconds, beforeCost} = AbsoluteTiming[
  CANON`SectorDE`Private`validMatricesQ[costMatrices, {x}, 12]];
beforeCostCalls = checkerCalls; beforeCostHeads = checkerHeads;
Get[FileNameJoin[{staged, "mma", "lib", "SectorDE.wl"}]];
checkerCalls = 0; checkerHeads = <||>;
{afterCostSeconds, afterCost} = AbsoluteTiming[
  CANON`SectorDE`Private`validMatricesQ[costMatrices, {x}, 12]];
afterCostCalls = checkerCalls; afterCostHeads = checkerHeads;
{afterSeconds, after} = AbsoluteTiming[CANON`SectorDE`Private`exactRationalEntryQ /@ cases];
afterBuild = CANON`SectorDE`BuildOrderedMasterDE[prepared, basis, reduction, normalized];
afterNonflat = CANON`SectorDE`BuildOrderedMasterDE[prepared, basis, reduction, nonflat];
checkerCalls = 0;
negativeCached = CANON`SectorDE`Private`validMatricesQ[{ConstantArray[Sin[x], {2,2}]}, {x}, 2];
negativeCalls = checkerCalls;
checkerCalls = 0;
negativeSecond = CANON`SectorDE`Private`validMatricesQ[{ConstantArray[Sin[x], {2,2}]}, {x}, 2];
negativeSecondCalls = checkerCalls;
checkerCalls = 0;
positiveSecond = CANON`SectorDE`Private`validMatricesQ[costMatrices, {x}, 12];
positiveSecondCalls = checkerCalls;
checkerCalls = 0;
contextKeys = CANON`SectorDE`Private`validMatricesQ[
  {{{1/LeftContext`x, 1/RightContext`x}, {1/LeftContext`x, 1/RightContext`x}}}, {x}, 2];
contextKeyCalls = checkerCalls;
checks = <|
  "cached_false_rejects_all_repeated_entries" -> (!negativeCached && negativeCalls === 1),
  "negative_cache_discarded_between_calls" -> (!negativeSecond && negativeSecondCalls === 1),
  "positive_cache_discarded_between_calls" -> (positiveSecond && positiveSecondCalls === afterCostCalls && positiveSecondCalls > 0),
  "exact_contexts_remain_distinct_keys" -> (contextKeys && contextKeyCalls === 2),
  "cost_fixture_acceptance_retained" -> TrueQ[beforeCost && afterCost],
  "cost_fixture_checker_calls_reduced" -> (afterCostCalls < beforeCostCalls),
  "cost_fixture_time_reduced" -> (afterCostSeconds < beforeCostSeconds),
  "original_matches_expected" -> (before === expected),
  "fast_path_same_acceptance" -> (after === before),
  "unchanged_exact_positive_de" -> (afterBuild === beforeBuild),
  "positive_flatness_retained" -> TrueQ[afterBuild["validity", "flat"]],
  "nonflat_de_and_flag_retained" -> (afterNonflat === beforeNonflat && !TrueQ[afterNonflat["validity", "flat"]]),
  "exact_point_scope_retained" -> (afterBuild["validity", "scope"] === "exact-point-samples"),
  "analytic_dimension_substitution" ->
    (And @@ (# === 0 & /@ Flatten[Together[afterBuild["matrices"] - {{{-(4 - 2 eps)/x}}, {{-(4 - 2 eps)/y}}}]])),
  "bad_matrix_shape_rejected" -> !CANON`SectorDE`Private`validMatricesQ[{{{1, 2}}}, {x}, 1],
  "inexact_matrix_rejected" -> !CANON`SectorDE`Private`validMatricesQ[{{{1.0}}}, {x}, 1],
  "nonrational_matrix_rejected" -> !CANON`SectorDE`Private`validMatricesQ[{{{Sin[x]}}}, {x}, 1]
|>;
result = <|"all_pass" -> And @@ Values[checks], "checks" -> checks,
 "cases" -> MapThread[<|"expression" -> ToString[#1, InputForm], "original" -> #2, "changed" -> #3|> &, {cases,before,after}],
 "seconds" -> <|"original" -> beforeSeconds, "changed" -> afterSeconds|>,
 "cost_fixture" -> <|"comparison_source" -> comparisonSector,
   "before_seconds" -> beforeCostSeconds, "after_seconds" -> afterCostSeconds,
   "before_checker_calls" -> beforeCostCalls, "after_checker_calls" -> afterCostCalls,
   "before_checker_heads" -> beforeCostHeads, "after_checker_heads" -> afterCostHeads|>,
 "per_call_cache" -> <|"negative_first_calls" -> negativeCalls, "negative_second_calls" -> negativeSecondCalls,
   "positive_second_calls" -> positiveSecondCalls, "context_distinct_calls" -> contextKeyCalls|>,
 "claim" -> "Exact per-call fallback memoization; exact/context-preserving keys; no cross-call cache; same neutral acceptance and DE content"|>;
Export[receipt, result, "RawJSON"];
Print[InputForm[checks]];
Exit[If[TrueQ[result["all_pass"]], 0, 1]];
