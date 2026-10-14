(* Optional representation improvements, after a valid canonical solution.
   No new solve, task input, coefficient domain or workflow decision. *)
residueComplexityImplementation = FileHash[$InputFileName, "SHA256", "HexString"];

coefficientBits[0] = 0;
coefficientBits[q_] := IntegerLength[Abs[Numerator[q]], 2] + IntegerLength[Denominator[q], 2];
largeCoefficientQ[expression_] := !FreeQ[expression,
  q : (_Integer | _Rational) /; coefficientBits[q] > 64];
residueCost[residues_] := Module[{values = DeleteCases[Flatten[residues], 0], bits},
  If[!AllTrue[values, IntegerQ[#] || Head[#] === Rational &], Return[$Failed]];
  bits = coefficientBits /@ values;
  {Total[bits], Max[Prepend[bits, 0]], Length[bits]}
];
betterResidueCostQ[a_, b_] := a[[1]] < b[[1]] && a[[2]] <= b[[2]] && a[[3]] <= b[[3]];
noNewResidueEntriesQ[before_, after_] := And @@ MapThread[
  (#1 =!= 0 || #2 === 0) &, {Flatten[before], Flatten[after]}];
smallTransformGrowthQ[before_, after_] := With[{size = ByteCount[before]},
  ByteCount[after] <= size + Max[1024, Min[65536, Quotient[size, 4]]]];
rationalContent[values_List] := If[values === {}, 1,
  (GCD @@ Abs[Numerator /@ values])/(LCM @@ (Denominator /@ values))];
residueMatrices[residues_, variables_, regulator_, alphabet_] :=
  Table[regulator Total[MapThread[#1 Together[D[#2, v]/#2] &,
    {residues, alphabet}]], {v, variables}];

(* The caller already has a canonical connection. Linear rational letters
   give its residues directly, without refitting or rechecking that result. *)
linearLetterResidues[matrices_, variables_, regulator_, alphabet_] := Module[
  {v, poles, normalized, residues, seen = {}},
  If[Length[variables] =!= 1 || alphabet === {}, Return[$Failed]];
  v = First[variables];
  If[!AllTrue[alphabet, PolynomialQ[#, v] && Exponent[#, v] === 1 &&
      AllTrue[CoefficientList[#, v], IntegerQ[#] || Head[#] === Rational &] &], Return[$Failed]];
  poles = (-Coefficient[#, v, 0]/Coefficient[#, v, 1]) & /@ alphabet;
  normalized = Map[Together[#/regulator] &, First[matrices], {2}];
  residues = ConstantArray[0, {Length[alphabet], Length[normalized], Length[normalized]}];
  Do[If[MemberQ[seen, poles[[i]]], Continue[]];
    residues[[i]] = Map[Cancel[(v-poles[[i]]) #] /. v -> poles[[i]] &, normalized, {2}];
    AppendTo[seen, poles[[i]]], {i, Length[poles]}];
  residues
];

(* Diagonal similarities preserve every zero and coordinate subspace. Only
   affected rows/columns enter trial scores; no dense inverse is required. *)
conditionConstantResidues[residues_List] := Module[
  {n = Length[First[residues]], c = residues, before, scales, indices, other,
   outgoing, incoming, oldCost, factors, scores, chosen, factor,
   trials = 0, accepted = 0},
  If[n > 128 || Length[residues] n n > 400000, Return[$Failed]];
  before = residueCost[c]; If[before === $Failed, Return[$Failed]];
  scales = ConstantArray[1, n];
  If[before[[2]] > 64,
    indices = Take[Reverse @ SortBy[Range[n], Total[coefficientBits /@ Flatten[
      {c[[All, #, All]], c[[All, All, #]]}]] &], UpTo[24]];
    Do[
      other = DeleteCases[Range[n], i];
      outgoing = DeleteCases[Flatten[c[[All, i, other]]], 0];
      incoming = DeleteCases[Flatten[c[[All, other, i]]], 0];
      oldCost = Total[coefficientBits /@ Join[outgoing, incoming]];
      factors = DeleteDuplicates[Abs /@ {rationalContent[outgoing],
        1/rationalContent[incoming],
        If[outgoing === {}, 1, First @ MaximalBy[outgoing, coefficientBits]],
        If[incoming === {}, 1, 1/(First @ MaximalBy[incoming, coefficientBits])]}];
      factors = Select[factors, # =!= 1 && coefficientBits[# scales[[i]]] <= 4096 &];
      scores = Table[trials++; With[{bits = coefficientBits /@ Join[outgoing/f, f incoming]},
        If[Max[Prepend[bits, 0]] <= before[[2]], Total[bits], Infinity]], {f, factors}];
      If[scores =!= {} && Min[scores] < oldCost,
        chosen = First @ Ordering[scores, 1]; factor = factors[[chosen]];
        c[[All, i, other]] = c[[All, i, other]]/factor;
        c[[All, other, i]] = factor c[[All, other, i]];
        scales[[i]] *= factor; accepted++], {i, indices}]
  ];
  <|"residues" -> c, "scales" -> scales, "before" -> before,
    "after" -> residueCost[c], "trials" -> trials, "accepted" -> accepted|>
];

(* Keep the first feasible intertwiner and its search order. A regular
   specialization S(mu) conjugates its canonical residues to R(mu)/mu;
   optional re-anchoring therefore needs no second rational-function solve. *)
compactDLogAnchor[baseline_Association, rawResidues_List, normalization_Association,
    variables_List, regulator_, seconds_] := Module[
  {original, result, before, constants, candidates = {}, target, cost, q, inverse,
   transformation, receipt, selected},
  original = <|"solution" -> baseline, "diagnostics" -> <|"applied" -> False|>|>;
  If[seconds <= 0 || rawResidues === {}, Return[original]];
  result = MemoryConstrained[TimeConstrained[Catch[Module[{},
    constants = Map[Together[#/regulator] &, normalization["normalized_residues"], {3}];
    before = residueCost[constants];
    If[before === $Failed || before[[2]] <= 64, Return[original]];
    Do[
      target = Quiet[Map[Together, (rawResidues /. regulator -> mu)/mu, {3}]];
      cost = residueCost[target];
      If[cost =!= $Failed && betterResidueCostQ[cost, before] && noNewResidueEntriesQ[constants, target],
        AppendTo[candidates, <|"reference" -> mu, "residues" -> target, "cost" -> cost|>]],
      {mu, {1, -1, 2, -2, 1/2, -1/2, 3, 4, 5}}];
    Do[
      q = Quiet[normalization["transformation"] /. regulator -> selected["reference"]];
      If[residueCost[{q}] === $Failed, Continue[]];
      inverse = Quiet[Check[Normal[Inverse[SparseArray[q]]], $Failed]];
      If[inverse === $Failed || residueCost[{inverse}] === $Failed, Continue[]];
      If[!And @@ MapThread[AllTrue[Flatten[Normal[
          SparseArray[#1].SparseArray[q] - SparseArray[q].SparseArray[#2]]], # === 0 &] &,
          {selected["residues"], constants}], Continue[]];
      transformation = Normal @ Map[Together,
        SparseArray[baseline["transformation"]].SparseArray[inverse], {2}];
      If[!smallTransformGrowthQ[baseline["transformation"], transformation], Continue[]];
      receipt = <|"applied" -> True, "reference" -> ToString[selected["reference"], InputForm],
        "before" -> before, "after" -> selected["cost"], "additional_linear_solves" -> 0|>;
      Throw[<|"solution" -> Join[baseline, <|"transformation" -> transformation,
        "matrices" -> residueMatrices[selected["residues"], variables, regulator, baseline["alphabet"]]|>],
        "diagnostics" -> receipt|>, compactAnchorResult],
      {selected, Take[SortBy[candidates, #["cost"] &], UpTo[2]]}];
    original], compactAnchorResult], Min[1/2, seconds], Join[original,
      <|"diagnostics" -> <|"applied" -> False, "reason" -> "time_bound"|>|>]],
    64 1024^2, Join[original,
      <|"diagnostics" -> <|"applied" -> False, "reason" -> "memory_bound"|>|>]];
  result
];

(* This optional postlude is transactional. Unsupported fields, no gain,
   exhausted budget and size growth all retain the valid original solution. *)
SimplifyCanonicalTail[solution_Association, variables_List, regulator_, seconds_] := Module[
  {n = Length[solution["transformation"]], result, residues, conditioning,
   scales, transformation, matrices, receipt, unchanged},
  If[seconds <= 0 || n > 128 || Length[solution["alphabet"]] n n > 400000 ||
      !largeCoefficientQ[solution["matrices"]], Return[solution]];
  unchanged[reason_] := Join[solution, <|"representation_simplification" ->
    <|"applied" -> False, "reason" -> reason, "implementation_sha256" -> residueComplexityImplementation|>|>];
  result = MemoryConstrained[TimeConstrained[Module[{},
    residues = linearLetterResidues[solution["matrices"], variables, regulator, solution["alphabet"]];
    If[residues === $Failed,
      residues = CanonMethodCard`DLogResidues[solution["matrices"], variables, regulator, solution["alphabet"]]];
    If[residues === $Failed || residues === {}, Return[unchanged["unsupported_residues"]]];
    conditioning = conditionConstantResidues[residues];
    If[conditioning === $Failed, Return[unchanged["domain_or_size_bound"]]];
    receipt = Join[KeyTake[conditioning, {"before", "after", "trials", "accepted"}],
      <|"applied" -> False, "implementation_sha256" -> residueComplexityImplementation|>];
    If[conditioning["accepted"] === 0, Return[Join[solution,
      <|"representation_simplification" -> Join[receipt, <|"reason" -> "no_improvement"|>]|>]]];
    scales = conditioning["scales"];
    transformation = Map[MapThread[Together[#1 #2] &, {#, scales}] &, solution["transformation"]];
    If[!smallTransformGrowthQ[solution["transformation"], transformation], Return[unchanged["transformation_growth_bound"]]];
    matrices = MapIndexed[Together[#1 scales[[#2[[3]]]]/scales[[#2[[2]]]]] &,
      solution["matrices"], {3}];
    Join[solution, <|"transformation" -> transformation, "matrices" -> matrices,
      "representation_simplification" -> Join[receipt, <|"applied" -> True|>]|>]],
    Min[1, seconds], unchanged["time_bound"]], 64 1024^2, unchanged["memory_bound"]];
  result
];
