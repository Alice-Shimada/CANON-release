#!/usr/bin/env wolframscript
$HistoryLength = 0;
{casePath, receiptPath} = Rest[$ScriptCommandLine];
cases = Import[casePath, "RawJSON"];
result[name_] := Import[cases[name, "result"], "RawJSON"];
load[name_, role_] := Module[{r = result[name], path},
  path = FileNameJoin[{DirectoryName[cases[name, "result"]], r["artifacts", role, "path"]}];
  Get[path]];
checks = <||>;
check[name_, condition_] := (checks[name] = TrueQ[condition]);
zero[expression_] := AllTrue[Flatten[{expression}], Together[#] === 0 &];

scalarTargets = load["scalar-targets", "reduction_targets"];
scalarOrdered = load["scalar-build", "ordered_master_de"];
scalarCut = load["scalar-build", "sector_cut_de"];
scalarSlice = load["scalar-slice", "sector_cut_de"];
check["target_schema_and_result_code", scalarTargets["schema"] === "canon-neu/reduction-targets/v1" &&
  result["scalar-targets"]["code"] === "REDUCTION_TARGETS_READY"];
check["actual_analytic_symbolic_targets_in_helper_order", scalarTargets["targets"] === {Q[0,2], Q[1,2]}];
check["explicit_and_embedded_derivative_bindings_are_equivalent", scalarTargets === load["scalar-embedded-targets", "reduction_targets"]];
check["source_master_and_empty_symbolic_point", scalarTargets["masters"] === {Q[1,1]} && scalarTargets["point"] === {}];
check["target_source_identities", scalarTargets["family_ref"] === "scalar-bubble" && scalarTargets["basis_ref"] === "scalar-bubble-master"];
check["scalar_de_source_and_variable_order", scalarOrdered["basis"] === scalarTargets["masters"] &&
  scalarOrdered["variables"] === {u} && scalarOrdered["regulator"] === eps];
check["scalar_exact_ordered_de", zero[scalarOrdered["matrices"] - {{{-eps/u}}}]];
check["scalar_exact_cut_de", zero[scalarCut["matrices"] - {{{-eps/u}}}]];
check["scalar_slice_is_identical", scalarCut === scalarSlice];
check["scalar_basis_artifacts_identical", load["scalar-build", "sector_basis"] === load["scalar-slice", "sector_basis"]];
check["scalar_validity_scope_preserved", scalarOrdered["validity", "scope"] === "exact-point-samples"];
check["scalar_original_symbol_context", With[{head = Head[First[scalarTargets["masters"]]]}, Context[head] === "Global`"]];
check["scalar_dimension_rule_applied_after_construction", FreeQ[scalarOrdered["matrices"], d | _Real]];

mappedTargets = load["mapped-targets", "reduction_targets"];
mappedOrdered = load["mapped-build", "ordered_master_de"];
mappedCut = load["mapped-build", "sector_cut_de"];
expectedX = {{0,0,0}, {-2d,-2,-2d}, {0,-1,0}} /. d -> 4-2eps;
check["mapped_keys_control_target_variables", mappedTargets["targets"] === {f[3]}];
check["resident_master_order_is_unsorted_source_order", mappedTargets["masters"] === {f[0],f[2],f[1]} &&
  mappedOrdered["basis"] === mappedTargets["masters"] && mappedCut["basis"] === {f[2],f[1]}];
check["prepared_variable_order_is_authoritative", mappedOrdered["variables"] === {y,x}];
check["multivariable_exact_full_connection", zero[mappedOrdered["matrices"] - {2expectedX,expectedX}]];
check["multivariable_exact_quotient", zero[mappedCut["matrices"] - {2expectedX[[{2,3},{2,3}]],expectedX[[{2,3},{2,3}]]}]];
check["mapped_slice_is_identical", mappedCut === load["mapped-slice", "sector_cut_de"]];
check["resident_positions_and_proper_subsector", result["mapped-build"]["summary", "resident_positions"] === {2,3} &&
  mappedCut["proper_subsectors"] === {<|"id"->0,"propagator_count"->0|>}];
check["complete_lower_sector_tail_is_retained", mappedOrdered["matrices"][[2,2,1]] === -2(4-2eps)];
check["exact_curvature_and_recorded_flatness", zero[D[expectedX,y] - D[2expectedX,x] + expectedX . (2expectedX) - (2expectedX) . expectedX] &&
  TrueQ[result["mapped-build"]["summary", "de_flat"]]];
check["mapped_source_context_does_not_leak", FreeQ[mappedOrdered["matrices"], Source`sx | Source`sy | ignored]];

legacyTargets = load["legacy-targets", "reduction_targets"];
legacyCut = load["legacy-build", "sector_cut_de"];
check["legacy_zero_derivatives_need_no_new_targets", legacyTargets["targets"] === {}];
check["legacy_normalized_input_receipts", result["legacy-targets"]["summary", "prepared_derivative_input"] === "legacy-single-variable-records" &&
  result["legacy-build"]["summary", "prepared_derivative_denominator_count"] === 12];
check["legacy_12_index_basis_and_exact_zero_de", legacyCut["basis"] === {h[1,0,0,0,0,0,0,0,0,0,0,0]} &&
  legacyCut["variables"] === {u} && legacyCut["matrices"] === {{{0}}}];
negativeNames = Keys[Select[cases, TrueQ[#["error"]] &]];
check["all_negative_receipts_fail_without_artifacts", AllTrue[negativeNames,
  result[#]["status"] === "ERROR" && result[#]["artifacts"] === <||> &]];
receipt = <|"checks"->checks, "all_pass"->And @@ Values[checks],
  "exact_readback"-><|"targets"->ToString[scalarTargets["targets"], InputForm],
    "scalar_ordered_residual"->ToString[Map[Together, scalarOrdered["matrices"]-{{{-eps/u}}}, {3}], InputForm],
    "mapped_ordered_residual"->ToString[Map[Together, mappedOrdered["matrices"]-{2expectedX,expectedX}, {3}], InputForm]|>,
  "runtime"-><|"version"->$Version, "system_id"->$SystemID, "kernel_pid"->$ProcessID,
    "subkernel_count"->Length[Kernels[]]|>|>;
Export[receiptPath, receipt, "RawJSON"];
Print[InputForm[checks]];
Exit[If[TrueQ[receipt["all_pass"]],0,1]];
