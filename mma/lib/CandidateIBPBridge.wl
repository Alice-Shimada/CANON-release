(* The standalone compiler shares Core's exact data-symbol decoder. *)
Needs["CanonMethodCard`", FileNameJoin[{DirectoryName[$InputFileName], "MethodCardCore.wl"}]];

BeginPackage["CANON`CandidateIBPBridge`"];
CompileCandidateIBPTargets::usage = "CompileCandidateIBPTargets[candidates, preparedFamily, masterBasis, preparedDerivatives, selection:\"enhanced-first\"] builds exact scalar targets for candidate derivatives.";
AttachCandidateIBPReduction::usage = "AttachCandidateIBPReduction[compiled, reduction] attaches fully reduced rules while preserving candidate IDs.";
ValidateCandidateIBPReduction::usage = "ValidateCandidateIBPReduction[compiled, reduction] checks supplied solved rules for ordered-basis identity and linear closure of the compiled non-master targets, without proving the IBP identities.";
BuildCoreCandidates::usage = "BuildCoreCandidates[bridge, preparedFamily, sectorBasis, cut] selects a reduced row basis and independent single-row exchanges.";
MasterDerivativeTargets::usage = "MasterDerivativeTargets[masters, preparedDerivatives] returns affine derivative targets for a DE-only IBP reduction.";

Begin["`Private`"];

familyIntegrals[expression_, head_] := DeleteDuplicates[
  Cases[expression, item_ /; Head[Unevaluated[item]] === head :> item, {0, Infinity}], SameQ];

canonicalExpression[definition_, head_, topology_] := ReleaseHold[definition] /. (
  HoldPattern[wrapper_[family_, indices__Integer]] /;
    SymbolName[Unevaluated[wrapper]] === "j" &&
      MemberQ[{topology, SymbolName[Unevaluated[head]]}, SymbolName[Unevaluated[family]]] :>
      Apply[head, {indices}]);

bindingFailure[message_] := Failure["SOURCE_BASIS_MISMATCH", <|"MessageTemplate" -> message|>];

nonSystemSymbolQ[symbol_Symbol] := Context[symbol] =!= "System`";
nonSystemSymbolQ[_] := False;
coordinateName[symbol_Symbol] := SymbolName[symbol];
coordinateName[value_] := With[{head = Head[value]}, {SymbolName[head], List @@ value}];

coefficientFrameBinding[frame_, prepared_, aliases_] := Module[
  {roles, targets, repeatedLabels, pairs, dimension, dimensionTarget, identities, constants},
  If[!AssociationQ[frame] || !ListQ[Lookup[frame, "variables", None]] ||
      Length[frame["variables"]] =!= Length[prepared["variables"]] ||
      !MatchQ[Lookup[frame, "regulator", None], _Symbol] || !KeyExistsQ[prepared, "regulator"],
    Return[bindingFailure["coefficient_frame requires ordered variables and a regulator matching the prepared-family roles."]]];
  roles = Join[frame["variables"], {frame["regulator"]}];
  targets = Join[prepared["variables"], {prepared["regulator"]}];
  If[!AllTrue[roles, MatchQ[#, _Symbol | _Symbol[__Integer]] &] || !DuplicateFreeQ[roles],
    Return[bindingFailure["coefficient_frame roles must be distinct coordinate identities."]]];
  repeatedLabels = Cases[Tally[coordinateName /@ roles], {label_, count_} /; count > 1 :> label];
  pairs = Transpose[{roles, targets}];
  If[AnyTrue[pairs, MatchQ[#, {source_, target_} /;
      source =!= target && (coordinateName[source] =!= coordinateName[target] ||
        MemberQ[repeatedLabels, coordinateName[source]]) && !MemberQ[aliases, source -> target]] &],
    Return[bindingFailure["coefficient_frame coordinate names/order differ or repeat ambiguously; an exact declared alias is required."]]];
  dimensionTarget = First[prepared["parameters"]];
  If[KeyExistsQ[frame, "dimension"],
    dimension = frame["dimension"];
    If[MatchQ[dimension, _Symbol] && MatchQ[dimensionTarget, _Symbol],
      If[MemberQ[roles, dimension] || (coordinateName[dimension] =!= coordinateName[dimensionTarget] &&
          !MemberQ[aliases, dimension -> dimensionTarget]),
        Return[bindingFailure["coefficient_frame dimension is ambiguous or differs from the declared dimension role."]]];
      AppendTo[pairs, {dimension, dimensionTarget}],
      If[!NumberQ[dimension] || dimension =!= dimensionTarget,
        Return[bindingFailure["coefficient_frame symbolic/numeric dimensions differ; numeric constants cannot be rebound."]]]
    ]
  ];
  identities = Select[{"family_ref", "chart_id"}, KeyExistsQ[frame, #] || KeyExistsQ[prepared, #] &];
  If[(AnyTrue[pairs, MatchQ[#, {source_, target_} /; source =!= target] &] && !KeyExistsQ[frame, "family_ref"]) ||
      AnyTrue[identities, Lookup[frame, #, None] =!= Lookup[prepared, #, None] &],
    Return[bindingFailure["coefficient_frame must identify the same prepared family and declared chart."]]];
  constants = Lookup[frame, "constants", {}];
  If[!ListQ[constants] || !AllTrue[constants, MatchQ[#, _Symbol | _Symbol[__Integer]] &] ||
      !DuplicateFreeQ[constants] || AnyTrue[constants, MemberQ[roles, #] || MemberQ[Append[targets, dimensionTarget], #] &],
    Return[bindingFailure["coefficient_frame constants must remain independent of coordinate/regulator/dimension roles."]]];
  <|"constants" -> constants, "rules" -> (Rule @@@ pairs)|>
];

coefficientBinding[candidates_, prepared_] := Module[{declared, mapping, rules, frame},
  declared = Join[prepared["parameters"], prepared["variables"],
    If[KeyExistsQ[prepared, "regulator"], {prepared["regulator"]}, {}],
    Cases[Lookup[prepared, "dimension_rule", {}], _Symbol, Infinity]];
  mapping = Lookup[prepared, "operator_source_symbol_map", <||>];
  If[!AssociationQ[mapping], Return[bindingFailure["operator_source_symbol_map must be an Association of exact symbol names."]]];
  rules = CanonMethodCard`ParseSymbolRules[mapping];
  If[rules === $Failed || !AllTrue[rules,
      MatchQ[#, _Symbol -> _Symbol] && nonSystemSymbolQ[First[#]] && nonSystemSymbolQ[Last[#]] &],
    Return[bindingFailure["Coefficient aliases must name non-System symbols explicitly."]]];
  If[!AllTrue[Last /@ rules, MemberQ[declared, #] &],
    Return[bindingFailure["Coefficient aliases must target declared prepared-family symbols."]]];
  frame = If[KeyExistsQ[candidates, "coefficient_frame"],
    coefficientFrameBinding[candidates["coefficient_frame"], prepared, rules],
    <|"constants" -> {}, "rules" -> {}|>];
  If[FailureQ[frame], Return[frame]];
  declared = DeleteDuplicates[Join[declared, frame["constants"]], SameQ];
  rules = DeleteDuplicates[Join[rules, frame["rules"]], SameQ];
  If[AnyTrue[rules, MatchQ[#, (source_ -> target_) /; MemberQ[declared, source] && source =!= target] &],
    Return[bindingFailure["Coefficient bindings cannot change an already declared symbol identity."]]];
  If[!DuplicateFreeQ[First /@ rules],
    Return[bindingFailure["Coefficient bindings are ambiguous for an exact source symbol."]]];
  <|"declared" -> declared, "rules" -> rules, "dispatch" -> Dispatch[rules]|>
];

bindExpression[expression_, head_, binding_] := Module[{sources, coefficients, unknown},
  sources = familyIntegrals[expression, head];
  coefficients = First[CanonMethodCard`IntegralCoefficientRows[{expression}, sources, head]];
  If[coefficients === $Failed,
    Return[bindingFailure["Candidate composition must be linear in the declared integral head."]]];
  coefficients = coefficients /. binding["dispatch"];
  unknown = Select[DeleteDuplicates[Cases[coefficients,
      value_ /; If[Head[value] === Symbol, nonSystemSymbolQ[value], nonSystemSymbolQ[Head[value]]], Infinity], SameQ],
    !MemberQ[binding["declared"], #] &];
  If[unknown =!= {}, Return[bindingFailure["Undeclared candidate coefficient symbols: " <>
    StringRiffle[(Block[{$Context = "CANON`DEData`", $ContextPath = {"System`"}}, ToString[#, InputForm]] &) /@ unknown, ", "] <>
    ". Supply coefficient_frame or exact operator_source_symbol_map aliases."]]];
  coefficients . sources
];

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
    "affine-fallback" | "prepared-affine", affineDerivative[head, List @@ integral, choice["operator"]],
    "enhanced-baikov", baikovDerivative[
      head, List @@ integral, choice, strategy, dimension, variable]];

targetData[integral_, protected_] := With[{indices = List @@ integral}, <|
  "integral" -> integral, "indices" -> indices,
  "sector_mask" -> Total[(Boole[indices[[#]] > 0] 2^(# - 1)) & /@ protected],
  "numerator_indices" -> indices[[Complement[Range[Length[indices]], protected]]]|>];

candidateData[candidate_, expression_, head_, variables_, choices_, strategy_, dimension_] :=
 Module[{sources, coefficients, derivatives, support, derivative},
  sources = familyIntegrals[expression, head];
  coefficients = If[sources === {}, {}, expression /. Thread[sources -> IdentityMatrix[Length[sources]]]];
  derivative[variable_] := D[expression, variable] + coefficients .
    (integralDerivative[head, #, choices[variable], strategy, dimension, variable] & /@ sources);
  derivatives = AssociationMap[derivative, variables];
  support = DeleteDuplicates[Join[sources,
    Flatten[(familyIntegrals[#, head] &) /@ Values[derivatives], 1]], SameQ];
  <|"candidate_id" -> candidate["candidate_id"],
    "exact_definition" -> candidate["exact_definition"],
    "normalization" -> candidate["normalization"], "expression" -> expression,
    "derivatives" -> derivatives,
    "targets" -> (targetData[#, strategy["propagator_slots"]] & /@ support)|>];

MasterDerivativeTargets[masters_, preparedDerivatives_] := DeleteDuplicates @ Select[
  Flatten[Table[familyIntegrals[affineDerivative[Head[master], List @@ master,
      preparedDerivatives["operators", variable]], Head[master]],
    {master, masters}, {variable, preparedDerivatives["variables"]}], 2],
  !MemberQ[masters, #] &];

CompileCandidateIBPTargets[candidates_, preparedFamily_, masterBasis_, preparedDerivatives_,
    selection_ : "enhanced-first"] :=
 Module[{topology, masters, head, variables, binding, expressions, strategy, protected, choices, invalid, records, masterTargets, targets},
  topology = Lookup[preparedFamily, "integral_head", preparedFamily["topology"]];
  masters = masterBasis["masters"];
  head = Head[First[masters]];
  variables = preparedFamily["variables"];
  binding = coefficientBinding[candidates, preparedFamily];
  If[FailureQ[binding], Return[binding]];
  expressions = bindExpression[#1["normalization", "factor"] *
      canonicalExpression[#1["exact_definition"], head, preparedFamily["topology"]], head, binding] & /@
    candidates["candidates"];
  invalid = SelectFirst[expressions, FailureQ, None];
  If[FailureQ[invalid], Return[invalid]];
  strategy = Lookup[preparedDerivatives, "exact_strategy", <||>];
  If[selection === "prepared-affine",
    protected = If[AssociationQ[strategy], Lookup[strategy, "propagator_slots", $Failed], $Failed];
    If[!ListQ[protected] || !AllTrue[protected, IntegerQ] ||
      Complement[protected, Range[Length[First[masters]]]] =!= {},
      Return[Failure["DERIVATIVE_OPERATOR_INVALID", <|"MessageTemplate" ->
        "Prepared-affine compilation requires valid exact_strategy.propagator_slots."|>]]]
  ];
  choices = AssociationMap[
    CANON`BaikovDerivative`ChooseDerivativeOperator[preparedDerivatives, #, selection] &, variables];
  invalid = SelectFirst[Values[choices], FailureQ, None];
  If[FailureQ[invalid], Return[invalid]];
  records = MapThread[candidateData[#1, #2, head, variables, choices,
    strategy, First[preparedFamily["parameters"]]] &, {candidates["candidates"], expressions}];
  masterTargets = MasterDerivativeTargets[masters, preparedDerivatives];
  targets = DeleteDuplicates[Join[
    Flatten[Function[record, #1["integral"] & /@ record["targets"]] /@ records, 1], masterTargets], SameQ];
  <|"family_ref" -> preparedFamily["family_ref"], "basis_ref" -> masterBasis["basis_ref"],
    "topology" -> topology, "slot_order" -> masterBasis["index_order"],
    "sector_convention" -> preparedFamily["sector_convention"], "variables" -> variables,
    "coefficient_symbol_bindings" -> binding["rules"],
    "proposal_id" -> candidates["proposal_id"],
    "candidate_pool" -> candidates["candidate_pool"],
    "method_evidence" -> candidates["method_evidence"],
    "tool_provenance" -> candidates["tool_provenance"],
    "operators" -> choices, "masters" -> masters, "candidates" -> records,
    "reducer_targets" -> (targetData[
      #, strategy["propagator_slots"]] & /@
        Select[targets, !MemberQ[masters, #] &])|>];

ValidateCandidateIBPReduction[compiled_, reduction_Association] := Module[
  {masters = compiled["masters"], rules, identities, head, integralQ, dispatch,
   changedMasters, targets, images, rows, unresolved},
  If[Lookup[reduction, "masters", None] =!= masters,
    Return[Failure["MASTER_BASIS_MISMATCH", <|"reason" ->
      "Supplied reduction masters must match the declared source basis in order."|>]]];
  identities = Select[{"family_ref", "basis_ref"},
    KeyExistsQ[reduction, #] && reduction[#] =!= compiled[#] &];
  If[identities =!= {}, Return[Failure["SOURCE_BASIS_MISMATCH", <|
    "reason" -> "Supplied reduction identity differs from the current inputs.",
    "mismatched_fields" -> identities|>]]];
  rules = Lookup[reduction, "rules", None];
  head = Head[First[masters]];
  integralQ[integral_] := Head[integral] === head &&
    Length[integral] === Length[First[masters]] && AllTrue[List @@ integral, IntegerQ];
  If[!ListQ[rules] || !AllTrue[rules, MatchQ[#, _Rule | _RuleDelayed] &] ||
    !AllTrue[First /@ rules, integralQ] || !DuplicateFreeQ[First /@ rules],
    Return[Failure["INVALID_REDUCTION", <|"reason" ->
      "Supplied reduction requires distinct explicit integral rules."|>]]];
  dispatch = Dispatch[rules];
  changedMasters = Select[masters, !TrueQ[Together[(# /. dispatch) - #] === 0] &];
  If[changedMasters =!= {}, Return[Failure["MASTER_BASIS_MISMATCH", <|
    "reason" -> "Supplied rules change declared source masters.",
    "changed_masters" -> (ToString[#, InputForm] & /@ changedMasters)|>]]];
  targets = #1["integral"] & /@ compiled["reducer_targets"];
  images = targets /. dispatch;
  rows = CanonMethodCard`IntegralCoefficientRows[images, masters, head];
  unresolved = Flatten[Position[rows, $Failed, {1}]];
  If[unresolved =!= {}, Return[Failure["INCOMPLETE_REDUCTION", <|
    "reason" -> "Compiled targets do not reduce completely and linearly to the declared masters in one substitution.",
    "unresolved_targets" -> (ToString[#, InputForm] & /@ targets[[unresolved]]),
    "target_images" -> (ToString[#, InputForm] & /@ images[[unresolved]])|>]]];
  reduction
];

AttachCandidateIBPReduction[compiled_, reduction_] := Module[{rules, dispatch, reduce},
  rules = reduction["rules"];
  dispatch = Dispatch[rules];
  reduce[expression_] := expression /. dispatch;
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
  If[basis =!= cut["basis"] || !AllTrue[basis, MemberQ[sourceBasis, #] &] ||
    Lookup[bridge, "variables", cut["variables"]] =!= cut["variables"] ||
    Lookup[preparedFamily, "variables", cut["variables"]] =!= cut["variables"] ||
    Lookup[preparedFamily, "regulator", cut["regulator"]] =!= cut["regulator"],
    Return[Failure["SOURCE_BASIS_MISMATCH", <|"Message" ->
      "Candidate bridge, prepared family and sector inputs must use the same basis symbols, variables and regulator."|>]]];
  positions = (First @ FirstPosition[sourceBasis, #]) & /@ basis;
  fullRows = CanonMethodCard`IntegralCoefficientRows[
    (#1["reduced_expression"] & /@ bridge["candidates"]) /. preparedFamily["dimension_rule"],
    sourceBasis, Head[First[sourceBasis]]];
  If[MemberQ[fullRows, $Failed], Return[Failure["SOURCE_BASIS_MISMATCH", <|"Message" ->
    "Reduced candidates must be linear combinations of the declared source masters."|>]]];
  fullRows = Map[Together, fullRows, {2}];
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
