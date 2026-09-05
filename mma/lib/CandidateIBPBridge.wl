BeginPackage["CANON`CandidateIBPBridge`"];
CompileCandidateIBPTargets::usage = "CompileCandidateIBPTargets[candidates, preparedFamily, masterBasis, preparedDerivatives] builds exact scalar targets for candidate derivatives.";
AttachCandidateIBPReduction::usage = "AttachCandidateIBPReduction[compiled, reduction] attaches fully reduced Kira rules while preserving candidate IDs.";
BuildCoreCandidates::usage = "BuildCoreCandidates[bridge, preparedFamily, sectorBasis, cut] selects a reduced row basis and independent single-row exchanges.";
MasterDerivativeTargets::usage = "MasterDerivativeTargets[masters, preparedDerivatives] returns affine derivative targets for a DE-only IBP reduction.";

Begin["`Private`"];

familyIntegrals[expression_, head_] := DeleteDuplicates[
  Cases[expression, item_ /; Head[Unevaluated[item]] === head :> item, {0, Infinity}], SameQ];

canonicalExpression[definition_, head_, topology_] := ReleaseHold[definition] /. (
  HoldPattern[wrapper_[family_, indices__Integer]] /;
    SymbolName[Unevaluated[wrapper]] === "j" && SymbolName[Unevaluated[family]] === topology :>
      Apply[head, {indices}]);

affineDerivative[head_, indices_, records_] := Together @ Total @ MapIndexed[
  Function[{record, position}, With[
    {j = First[position], unit = UnitVector[Length[indices], First[position]]},
    -indices[[j]] (record["constant"] Apply[head, indices + unit] +
      Total[(#1["coefficient"] Apply[head, indices + unit -
        UnitVector[Length[indices], #1["denominator"]]]) & /@ record["linear"]])]],
  records];

baikovDerivative[head_, indices_, choice_, strategy_, dimension_, variable_] := Module[
  {z, protected, gram, vectors, lambda, kappa, weight, monomials},
  z = strategy["baikov_variables"];
  protected = strategy["propagator_slots"];
  gram = strategy["external_gram_determinant"] /. strategy["fixed_scale_substitutions"];
  vectors = MapIndexed[
    If[MemberQ[protected, First[#2]], z[[First[#2]]] #1, #1] &, choice["cofactors"]];
  lambda = (dimension - strategy["loop_count"] -
      strategy["independent_external_count"] - 1)/2;
  kappa = (strategy["independent_external_count"] - dimension + 1)/2;
  weight = Together[kappa D[gram, variable]/gram + lambda choice["f_cofactor"] +
    Sum[indices[[i]] vectors[[i]]/z[[i]] - D[vectors[[i]], z[[i]]], {i, Length[z]}]];
  monomials = CoefficientRules[Together[weight Times @@ z], z];
  Together @ Total[(Last[#] Apply[head,
    indices - First[#] + ConstantArray[1, Length[indices]]]) & /@ monomials]];

integralDerivative[head_, integral_, choice_, strategy_, dimension_, variable_] :=
  Switch[choice["kind"],
    "affine-fallback", affineDerivative[head, List @@ integral, choice["operator"]],
    "enhanced-baikov", baikovDerivative[
      head, List @@ integral, choice, strategy, dimension, variable]];

targetData[integral_, protected_] := With[{indices = List @@ integral}, <|
  "integral" -> integral, "indices" -> indices,
  "sector_mask" -> Total[(Boole[indices[[#]] > 0] 2^(# - 1)) & /@ protected],
  "numerator_indices" -> indices[[Complement[Range[Length[indices]], protected]]]|>];

candidateData[candidate_, head_, topology_, variables_, choices_, strategy_, dimension_] :=
 Module[{expression, sources, derivatives, support, derivative},
  expression = candidate["normalization", "factor"] * canonicalExpression[candidate["exact_definition"], head, topology];
  sources = familyIntegrals[expression, head];
  derivative[variable_] := D[expression, variable] + Total[
    Coefficient[expression, #] integralDerivative[
      head, #, choices[variable], strategy, dimension, variable] & /@ sources];
  derivatives = AssociationMap[derivative, variables];
  support = DeleteDuplicates[Join[sources,
    Flatten[(familyIntegrals[#, head] &) /@ Values[derivatives], 1]], SameQ];
  <|"candidate_id" -> candidate["candidate_id"],
    "exact_definition" -> candidate["exact_definition"], "expression" -> expression,
    "derivatives" -> derivatives,
    "targets" -> (targetData[#, strategy["propagator_slots"]] & /@ support)|>];

MasterDerivativeTargets[masters_, preparedDerivatives_] := DeleteDuplicates @ Select[
  Flatten[Table[familyIntegrals[affineDerivative[Head[master], List @@ master,
      preparedDerivatives["operators", variable]], Head[master]],
    {master, masters}, {variable, preparedDerivatives["variables"]}], 2],
  !MemberQ[masters, #] &];

CompileCandidateIBPTargets[candidates_, preparedFamily_, masterBasis_, preparedDerivatives_] :=
 Module[{topology, masters, head, variables, choices, records, masterTargets, targets},
  topology = preparedFamily["topology"];
  masters = masterBasis["masters"];
  head = Head[First[masters]];
  variables = preparedFamily["variables"];
  choices = AssociationMap[
    CANON`BaikovDerivative`ChooseDerivativeOperator[preparedDerivatives, #] &, variables];
  records = candidateData[#, head, topology, variables, choices,
    preparedDerivatives["exact_strategy"], First[preparedFamily["parameters"]]] & /@
      candidates["candidates"];
  masterTargets = MasterDerivativeTargets[masters, preparedDerivatives];
  targets = DeleteDuplicates[Join[
    Lookup[Flatten[Lookup[records, "targets"], 1], "integral"], masterTargets], SameQ];
  <|"family_ref" -> preparedFamily["family_ref"], "basis_ref" -> masterBasis["basis_ref"],
    "topology" -> topology, "slot_order" -> masterBasis["index_order"],
    "sector_convention" -> preparedFamily["sector_convention"], "variables" -> variables,
    "proposal_id" -> candidates["proposal_id"],
    "candidate_pool" -> candidates["candidate_pool"],
    "method_evidence" -> candidates["method_evidence"],
    "tool_provenance" -> candidates["tool_provenance"],
    "operators" -> choices, "masters" -> masters, "candidates" -> records,
    "reducer_targets" -> (targetData[
      #, preparedDerivatives["exact_strategy", "propagator_slots"]] & /@
        Select[targets, !MemberQ[masters, #] &])|>];

AttachCandidateIBPReduction[compiled_, reduction_] := Module[{rules, reduce},
  rules = reduction["rules"];
  reduce[expression_] := expression /. Dispatch[rules];
  Join[<|"schema" -> "canon-neu/candidate-ibp-bridge/v1"|>,
    KeyDrop[compiled, {"masters", "candidates"}],
    <|"masters" -> compiled["masters"], "rules" -> rules,
      "candidates" -> (Join[#, <|"reduced_expression" -> reduce[#1["expression"]],
        "reduced_derivatives" -> Map[reduce, #1["derivatives"]]|>] & /@
          compiled["candidates"])|>]];

BuildCoreCandidates[bridge_, preparedFamily_, sectorBasis_, cut_] := Module[
  {sourceBasis, basis, positions, fullRows, rows, base, groups, makeCandidate, pool},
  sourceBasis = bridge["masters"];
  basis = sectorBasis["basis"];
  positions = (First @ FirstPosition[sourceBasis, #]) & /@ basis;
  fullRows = Function[candidate, With[
    {expression = candidate["reduced_expression"] /. preparedFamily["dimension_rule"]},
    Together[Coefficient[expression, #]] & /@ sourceBasis]] /@ bridge["candidates"];
  rows = fullRows[[All, positions]];
  base = Fold[If[MatrixRank[rows[[Append[#1, #2]]]] > Length[#1],
      Append[#1, #2], #1] &, {}, Range[Length[rows]]];
  groups = If[Length[base] === Length[basis], Join[{base},
    Select[Flatten[Table[ReplacePart[base, i -> j],
      {i, Length[base]}, {j, Complement[Range[Length[rows]], base]}], 1],
      Together[Det[rows[[#]]]] =!= 0 &]], {}];
  makeCandidate[indices_] := With[
    {transformation = Map[Together, Inverse[rows[[indices]]], {2}]},
    <|"candidate_id" -> "reduced:group:" <>
        StringRiffle[ToString /@ indices, "-"],
      "member_candidate_ids" -> Lookup[bridge["candidates"][[indices]], "candidate_id"],
      "new_basis_rows" -> rows[[indices]],
      "full_new_basis_rows" -> fullRows[[indices]],
      "construction_rejection" -> None, "transformation" -> transformation,
      "transformed_matrices" -> CanonMethodCard`GaugeTransform[
        cut["matrices"], cut["variables"], transformation]|>];
  pool = <|"selection" -> "rank-basis-and-single-row-exchanges",
    "declared" -> Length[groups], "eligible" -> Length[groups], "remaining" -> 0,
    "unconsumed_candidates" -> bridge["candidate_pool", "remaining"],
    "pool_exhausted" -> bridge["candidate_pool", "pool_exhausted"]|>;
  <|"schema" -> "canon-neu/core-candidates/v1", "sector" -> cut["sector"],
    "family_id" -> cut["family_id"], "basis_id" -> cut["basis_id"],
    "coefficient_domain" -> "exact-algebraic-functions",
    "source_basis" -> sourceBasis, "basis" -> basis,
    "variables" -> cut["variables"], "regulator" -> cut["regulator"],
    "convention" -> "old_basis = transformation . new_basis",
    "method" -> <|"id" -> "dlogbasis-refine-reduced-groups",
      "tool_provenance" -> bridge["tool_provenance"]|>,
    "candidate_group_pool" -> pool,
    "reduced_rank" -> Length[base], "required_rank" -> Length[basis],
    "candidates" -> (makeCandidate /@ groups)|>
];

End[];
EndPackage[];
