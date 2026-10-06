#!/usr/bin/env wolframscript
$HistoryLength = 0;
{canon, package, pointPackage, tree, receipt} = Rest[$ScriptCommandLine];
Get[FileNameJoin[{canon, "mma", "lib", "MethodCardCore.wl"}]];
Get[FileNameJoin[{package, "Parameterization.wl"}]];
Get[FileNameJoin[{pointPackage, "PointDE.wl"}]];
checks = <||>;
check[name_, value_] := (checks[name] = TrueQ[value]; Print[name, ": ", checks[name]]);
zero[e_] := And @@ (TrueQ[Cancel[Together[#]] === 0] & /@ Flatten[{e}]);
vectorSpec = Get[FileNameJoin[{package, "examples", "vector-spec.wl"}]];
scalarSpec = Get[FileNameJoin[{package, "examples", "scalar-spec.wl"}]];
vector = Get[FileNameJoin[{tree, "vector", "family-data.wl"}]];
scalar = Get[FileNameJoin[{tree, "scalar", "family-data.wl"}]];
vectorView = Import[FileNameJoin[{tree, "vector", "reducer-family.json"}], "RawJSON"];
scalarView = Import[FileNameJoin[{tree, "scalar", "reducer-family.json"}], "RawJSON"];
check["symbolic_geometry_retained_before_point", vector["vectors"] === vectorSpec["vectors"] &&
  zero[(D[vector["vectors"], x[1]] /. vector["point_rules"]) - vectorSpec["vectors"]/x[1]]];
check["exact_indexed_point_and_scalar_products", vectorView["point"] === {<|"variable" -> "x[1]", "value" -> "2"|>} &&
  vectorView["scalar_products"][[2]]["value"] === "8"];
check["full_order_and_dimension_metadata", vector["index_order"] === vectorSpec["index_order"] &&
  vector["variables"] === {x[1]} && vectorView["dimension_rule"] === "d->4-2*eps"];
symbolFamily = Get[FileNameJoin[{tree, "symbol", "family-data.wl"}]];
symbolPrepared = Get[FileNameJoin[{tree, "symbol", "prepared-family.wl"}]];
check["symbolic_index_order_retained_in_wl", symbolFamily["index_order"] === {D1,D2} &&
  symbolPrepared["index_order"] === {D1,D2}];
check["scalar_chart_no_forced_external_dimension", !KeyExistsQ[scalar, "vectors"] &&
  scalar["external_momenta"] === {q} && scalar["scalar_products"] === {{q, q} -> u}];
check["declared_scalar_momentum_relation_applied", scalar["momentum_rules"] === {r -> -q} &&
  scalarView["propagators"][[2]]["momentum"] === "k-q"];
check["symbolic_invariant_dimensions_preserved", scalarView["invariants"] === {<|"name" -> "u", "mass_dimension" -> 2|>} && scalarView["point"] === {}];

alternate = Join[vectorSpec /. x[1] -> (a + b), <|"chart_id" -> "sum-chart", "variables" -> {a,b}, "point" -> {a -> 1, b -> 2}|>];
alternateData = CanonParameterization`ParameterizeFamily[alternate];
check["second_arbitrary_vector_coordinate_chart", !FailureQ[alternateData] && alternateData["family", "variables"] === {a,b} &&
  alternateData["reducer", "scalar_products"][[2]]["value"] === "18"];
symbolicVector = CanonParameterization`ParameterizeFamily[Join[vectorSpec,
  <|"point" -> {}, "invariants" -> {<|"name" -> x[1], "mass_dimension" -> 1|>}|>]];
check["symbolic_indexed_vector_view", !FailureQ[symbolicVector] &&
  symbolicVector["reducer", "invariants"] === {<|"name" -> "x[1]", "mass_dimension" -> 1|>}];
twoComponents = Join[vectorSpec, <|"variables" -> {w}, "external_momenta" -> {p1,p2}, "vectors" -> {{w,0},{0,1}},
  "metric" -> {1,1}, "external_basis" -> {1,2}, "propagator_momenta" -> {l,l-p1,l-p2},
  "propagator_masses_squared" -> {0,0,0}, "index_order" -> {"D1","D2","D3"}, "point" -> {w -> 2}|>];
twoData = CanonParameterization`ParameterizeFamily[twoComponents];
check["vector_component_dimension_is_input", !FailureQ[twoData] && twoData["reducer", "scalar_products"][[1]]["value"] === "4"];
dependent = Join[vectorSpec, <|"external_momenta" -> {p1,p2,p3,p4,p5},
  "vectors" -> Append[vectorSpec["vectors"], Total[vectorSpec["vectors"][[{1,2}]]]],
  "propagator_momenta" -> {l,l-p5,l-p1,l-p3,l-p4}|>];
dependentData = CanonParameterization`ParameterizeFamily[dependent];
check["dependent_vector_momentum_eliminated", !FailureQ[dependentData] &&
  dependentData["reducer", "external_momenta"] === {"p1","p2","p3","p4"} &&
  dependentData["reducer", "propagators"][[2]]["momentum"] === "l-p1-p2"];
dependentBasis = CanonParameterization`ParameterizeFamily[Join[dependent, <|"external_basis" -> {1,2,3,4,5}|>]];
check["dependent_declared_basis_rejected", FailureQ[dependentBasis] && dependentBasis[[1]] === "DEPENDENT_EXTERNAL_BASIS"];
nonScalarMass = CanonParameterization`ParameterizeFamily[Join[scalarSpec, <|"propagator_masses_squared" -> {k,0}|>]];
check["momentum_dependent_mass_rejected", FailureQ[nonScalarMass] && nonScalarMass[[1]] === "MOMENTUM_IN_SCALAR_DATA"];
massiveSpec = Join[scalarSpec, <|"propagator_masses_squared" -> {m2,0}, "point" -> {u -> 9},
  "invariants" -> {<|"name" -> u, "mass_dimension" -> 2|>, <|"name" -> m2, "mass_dimension" -> 2|>}|>];
massive = CanonParameterization`ParameterizeFamily[massiveSpec];
check["internal_masses_and_partial_point_preserved", !FailureQ[massive] && massive["family", "scalar_products"] === {{q,q} -> u} &&
  massive["reducer", "scalar_products"][[1]]["value"] === "9" &&
  massive["reducer", "propagators"][[1]]["mass_squared"] === "m2" &&
  massive["reducer", "invariants"] === {<|"name" -> "m2", "mass_dimension" -> 2|>}];
bad = CanonParameterization`ParameterizeFamily[Join[scalarSpec, <|"invariants" -> {}|>]];
check["remaining_invariant_dimensions_not_guessed", FailureQ[bad] && bad[[1]] === "UNDECLARED_REMAINING_INVARIANTS"];
badPoint = CanonParameterization`ParameterizeFamily[Join[vectorSpec, <|"point" -> {x[1] -> 2.0}|>]];
check["inexact_point_rejected", FailureQ[badPoint] && badPoint[[1]] === "INVALID_EXACT_POINT"];

prepared = Get[FileNameJoin[{tree, "scalar", "prepared-family.wl"}]];
check["prepared_family_keeps_distinct_label_and_integral_head", prepared["topology"] === "scalar_bubble" && prepared["integral_head"] === "Q"];
referencePaths = (CanonMethodCard`ResolveInputPath[FileNameJoin[{tree, "scalar", "prepared-family.wl"}], prepared[#, "path"]] &) /@
  {"family_data", "reducer_family", "prepared_derivatives", "ordered_masters"};
check["relative_nested_references_survive_move", And @@ (FileExistsQ /@ referencePaths) &&
  And @@ (!StringStartsQ[prepared[#, "path"], "/"] & /@ {"family_data", "reducer_family", "prepared_derivatives", "ordered_masters"})];
vectorPrepared = Get[FileNameJoin[{tree, "vector", "prepared-family.wl"}]];
check["physical_derivatives_generated_without_masters", vectorPrepared["available_inputs"] === <|"prepared_derivatives" -> True, "ordered_masters" -> False|> &&
  KeyExistsQ[vectorPrepared, "prepared_derivatives"] && !KeyExistsQ[vectorPrepared, "ordered_masters"]];
de = Get[FileNameJoin[{tree, "scalar-de", "ordered-master-de.wl"}]];
check["generated_scalar_derivatives_use_default_builder", de["variables"] === {u} && zero[de["matrices"] - {{{-eps/u}}}]];
discovered = Get[FileNameJoin[{tree, "discovery", "master-basis.wl"}]];
check["supplied_master_reference_uses_default_discovery", Length[discovered["masters"]] === 1 &&
  SymbolName[Head[First[discovered["masters"]]]] === "Q" && (List @@ First[discovered["masters"]]) === {1,1}];

point = Get[FileNameJoin[{tree, "point", "prepared-point.wl"}]];
targets = Get[FileNameJoin[{tree, "point", "targets.wl"}]];
check["neutral_family_consumed_by_point_preparation", point["variables"] === {x[1]} &&
  point["expressions"] === {2 B[1,1,0,0,0]} && point["frame_derivatives"] === {{{-1/4}}}];
check["point_targets_bind_family_and_source_basis", targets["schema"] === "canon-neu/reduction-targets/v1" &&
  targets["family_ref"] === "synthetic-bubble" && targets["basis_ref"] === "bubble-master" && targets["masters"] === {B[1,1,0,0,0]}];
sample = Get[FileNameJoin[{tree, "point-de-result", "de-sample.wl"}]];
check["neutral_family_binds_point_reduction", sample["matrices"] === {{{-eps}}} && sample["reduction_scope", "kind"] === "declared-point-reduction"];
master = Get[FileNameJoin[{tree, "vector-masters.wl"}]];
candidates = Get[FileNameJoin[{tree, "vector-candidates.wl"}]];
pointSpec = Get[FileNameJoin[{tree, "vector-point.wl"}]];
legacyFamily = Join[KeyDrop[vector, {"chart_id", "chart_type", "propagator_momenta", "propagator_masses_squared"}],
  <|"schema" -> "canon-neu/twistor-family/v1", "propagators" -> (#^2 & /@ vector["propagator_momenta"])|>];
legacy = CanonPointDE`PreparePoint[legacyFamily, master, candidates, pointSpec];
check["legacy_saved_family_reader_preserved", !FailureQ[legacy] && legacy["expressions"] === point["expressions"] &&
  legacy["candidate_derivatives"] === point["candidate_derivatives"]];
scalarLimit = CanonPointDE`PreparePoint[scalar, master, candidates, pointSpec];
massLimit = CanonPointDE`PreparePoint[Join[vector, <|"propagator_masses_squared" -> {7,0,0,0,0}|>], master, candidates, pointSpec];
check["unsupported_point_geometry_is_explicit", FailureQ[scalarLimit] && scalarLimit[[1]] === "UNSUPPORTED_POINT_DE_CHART" &&
  FailureQ[massLimit] && massLimit[[1]] === "UNSUPPORTED_POINT_DE_MASSES"];
chartLimit = CanonPointDE`PreparePoint[vector, master, candidates, Join[pointSpec, <|"chart_id" -> "other-chart"|>]];
check["point_chart_identity_enforced", FailureQ[chartLimit] && chartLimit[[1]] === "CHART_MISMATCH"];
Export[receipt, checks, "RawJSON"];
Exit[If[And @@ Values[checks], 0, 1]];
