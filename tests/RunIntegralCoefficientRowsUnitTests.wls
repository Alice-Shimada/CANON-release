#!/usr/bin/env wolframscript
(* Neutral integral algebra and bounded factored-coefficient cost regression. *)
$HistoryLength = 0;
repoRoot = DirectoryName[DirectoryName[$InputFileName]];
Get[FileNameJoin[{repoRoot, "mma", "lib", "MethodCardCore.wl"}]];
Get[FileNameJoin[{repoRoot, "mma", "lib", "CandidateIBPBridge.wl"}]];
outputPath = Last[$ScriptCommandLine];
row[expression_, basis_ : {G[1], G[2]}] :=
  First[CanonMethodCard`IntegralCoefficientRows[{expression}, basis, G]];
facts = <||>;
check[name_, value_] := (facts[name] = TrueQ[value]);
zero = (G[1] + G[2])^2 - G[1]^2 - 2 G[1] G[2] - G[2]^2;
scalarZero = (x + y)^2 - x^2 - y^2 - 2 x y;
positive = {
  {"zero", 0, {0, 0}}, {"master", G[1], {1, 0}},
  {"factored", (1 + x + y)^8 (G[1] + 2 G[2])/(1 + x y),
    {(1 + x + y)^8/(1 + x y), 2 (1 + x + y)^8/(1 + x y)}},
  {"algebraic", Sqrt[x] (G[1] + G[2]), {Sqrt[x], Sqrt[x]}},
  {"contexts", (Left`x + Right`x) G[1], {Left`x + Right`x, 0}},
  {"polynomial-cancellation", zero + x G[1], {x, 0}},
  {"scalar-cancellation", scalarZero + G[2], {0, 1}},
  {"nonlinear-coefficient-cancellation", scalarZero G[1]^2 + G[2], {0, 1}},
  {"affine-cancellation", (G[1] + 1) x - x, {x, 0}},
  {"zero-polynomial", zero, {0, 0}}
};
Do[check["positive/" <> item[[1]], row[item[[2]]] === item[[3]]], {item, positive}];
negative = <|
  "square" -> G[1]^2, "cross-product" -> G[1] G[2],
  "disguised-square" -> G[1]^2 - G[1],
  "function" -> Sin[G[1]], "reciprocal" -> 1/G[1],
  "master-denominator" -> G[1]/(1 + G[2]), "fractional-power" -> Sqrt[G[1]],
  "constant-offset" -> G[1] + x, "constant-only" -> 1,
  "unreduced" -> G[3], "residual-coefficient" -> G[1] Sin[G[2]],
  "two-dependent-factors" -> (G[1] + 1) (G[2] + 1)|>;
KeyValueMap[check["negative/" <> #1, row[#2] === $Failed] &, negative];
check["empty-basis/zero", row[0, {}] === {}];
check["empty-basis/nonzero", row[1, {}] === $Failed];
check["order/reversed", row[3 G[1] + 7 G[2], {G[2], G[1]}] === {7, 3}];
check["symbol-basis/coordinates-remain-coefficients",
  CanonMethodCard`IntegralCoefficientRows[{j+x k, 0, j^2, j k, j+1}, {j,k}, Symbol] ===
    {{1,x},{0,0},$Failed,$Failed,$Failed}];

compiled = <|"masters" -> {G[1], G[2]}, "family_ref" -> "neutral", "basis_ref" -> "ordered",
  "reducer_targets" -> {<|"integral" -> G[3]|>}|>;
validate[rules_, overrides_ : <||>] := CANON`CandidateIBPBridge`ValidateCandidateIBPReduction[
  compiled, Join[<|"masters" -> compiled["masters"], "rules" -> rules|>, overrides]];
failure[value_, code_] := FailureQ[value] && value[[1]] === code;
check["closure/one-substitution", failure[validate[{G[3] -> G[4], G[4] -> G[1]}], "INCOMPLETE_REDUCTION"]];
check["closure/malformed-left", failure[validate[{G[a_] :> G[1]}], "INVALID_REDUCTION"]];
check["closure/duplicate-left", failure[validate[{G[3] -> G[1], G[3] -> G[2]}], "INVALID_REDUCTION"]];
check["closure/source-immutable", failure[validate[{G[1] -> 2 G[1], G[3] -> G[2]}], "MASTER_BASIS_MISMATCH"]];
check["closure/source-order", failure[validate[{G[3] -> G[1]}, <|"masters" -> {G[2], G[1]}|>], "MASTER_BASIS_MISMATCH"]];
check["closure/family-identity", failure[validate[{G[3] -> G[1]}, <|"family_ref" -> "wrong"|>], "SOURCE_BASIS_MISMATCH"]];
check["closure/zero", AssociationQ[validate[{G[3] -> 0}]]];
check["closure/identity-rule", AssociationQ[validate[{G[1] -> G[1], G[3] -> (1 + x) (G[1] + G[2])}]]];
KeyValueMap[check["closure/" <> #1, failure[validate[{G[3] -> #2}], "INCOMPLETE_REDUCTION"]] &,
  KeyDrop[negative, {"unreduced"}]];

(* Verbatim algorithm of the original supplied-reduction closure, retaining its
   row for exact comparison. No production family, rules or DE are loaded. *)
originalRow[expression_, masters_] := Module[{value = Expand[expression], coefficients},
  coefficients = Coefficient[value, #] & /@ masters;
  If[FreeQ[coefficients, integral_ /; Head[integral] === G] &&
      TrueQ[Expand[value - coefficients . masters] === 0], coefficients, $Failed]
];
masters = Array[G, 51];
coefficients = Table[(1 + x + y + z + u + v)^10/(i + x y + z u + v^2), {i, Length[masters]}];
expression = coefficients . masters;
{originalSeconds, original} = AbsoluteTiming[originalRow[expression, masters]];
{repairedSeconds, repaired} = AbsoluteTiming[row[expression, masters]];
{equivalenceSeconds, equality} = AbsoluteTiming[
  AllTrue[Together[original - repaired], # === 0 &]];
check["performance/original-valid", ListQ[original] && Length[original] === Length[masters]];
check["performance/exact-equivalence", equality];
check["performance/expected-factored-row", repaired === coefficients];
check["performance/factored-size", LeafCount[repaired] < LeafCount[original]];
expandedInput = original . masters;
{expandedOriginalSeconds, expandedOriginal} = AbsoluteTiming[originalRow[expandedInput, masters]];
{expandedRepairedSeconds, expandedRepaired} = AbsoluteTiming[row[expandedInput, masters]];
check["performance/expanded-exact-row", expandedRepaired === original && expandedOriginal === original];
{predicateSeconds, predicateFree} = AbsoluteTiming[FreeQ[original, _?(Head[#] === G &)]];
{nativePatternSeconds, nativeFree} = AbsoluteTiming[FreeQ[original, _G]];
check["performance/native-pattern-equivalence", predicateFree && nativeFree];
receipt = <|"all_pass" -> AllTrue[Values[facts], TrueQ], "facts" -> facts,
  "performance" -> <|"master_count" -> Length[masters], "kinematic_variables" -> 5, "numerator_power" -> 10,
    "original_seconds" -> originalSeconds, "repaired_seconds" -> repairedSeconds,
    "exact_equivalence_seconds" -> equivalenceSeconds,
    "speed_ratio" -> originalSeconds/repairedSeconds,
    "input_leaf_count" -> LeafCount[expression], "original_row_leaf_count" -> LeafCount[original],
    "repaired_row_leaf_count" -> LeafCount[repaired],
    "original_coefficient_calls" -> Length[masters], "repaired_coefficient_calls" -> 0,
    "original_expand" -> "all variables", "repaired_expand" -> "integral-head pattern only",
    "scope" -> "one neutral symbolic expression; exact coefficient identity, not a forecast for N34"|>,
  "expanded_performance" -> <|"input_leaf_count" -> LeafCount[expandedInput],
    "original_seconds" -> expandedOriginalSeconds, "repaired_seconds" -> expandedRepairedSeconds,
    "speed_ratio" -> expandedOriginalSeconds/expandedRepairedSeconds,
    "predicate_freeq_seconds" -> predicateSeconds, "native_pattern_freeq_seconds" -> nativePatternSeconds,
    "exact_row_sameq" -> facts["performance/expanded-exact-row"]|>|>;
Export[outputPath, receipt, "RawJSON"];
Print[InputForm[<|"total" -> Length[facts], "failed" -> Keys[Select[facts, !TrueQ[#] &]],
  "performance" -> receipt["performance"]|>]];
Exit[If[receipt["all_pass"], 0, 1]];
