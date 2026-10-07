#!/usr/bin/env wolframscript
$HistoryLength = 0;
{canon, package, tree, receipt} = Rest[$ScriptCommandLine];
Get[FileNameJoin[{canon, "mma", "lib", "MethodCardCore.wl"}]];
Get[FileNameJoin[{package, "PointDE.wl"}]];
checks = <||>;
check[name_, value_] := (checks[name] = TrueQ[value]; Print[name, ": ", checks[name]]);
zero[e_] := And @@ (TrueQ[Cancel[Together[#]] === 0] & /@ Flatten[{e}]);
family = Get[FileNameJoin[{package, "examples", "family.wl"}]];
masterData = Get[FileNameJoin[{package, "examples", "masters.wl"}]];
candidates = Get[FileNameJoin[{package, "examples", "candidates.wl"}]];
spec = Get[FileNameJoin[{package, "examples", "point.wl"}]];
prepared = Get[FileNameJoin[{tree, "training-prepared", "prepared-point.wl"}]];
master = First[masterData["masters"]];
check["differentiate_geometry_before_point", prepared["operators"][[1, 2]] === {8, -1/2, 1/2, 0, 0, 0}];
check["differentiate_candidate_coefficient", zero[prepared["candidate_derivatives"][[1, 1]] - master - 2 prepared["master_derivatives"][[1, 1]]]];
check["nonconstant_frame_derivative", prepared["frame_derivatives"] === {{{-1/4}}}];
sample = Get[FileNameJoin[{tree, "training", "de-sample.wl"}]];
validation = Get[FileNameJoin[{tree, "validation", "de-sample.wl"}]];
training2 = Get[FileNameJoin[{tree, "training2", "de-sample.wl"}]];
check["retained_epsilon_connection", sample["matrices"] === {{{-eps}}} && validation["matrices"] === {{{-2 eps/3}}} &&
  training2["matrices"] === {{{-eps/2}}}];
check["sample_scope_and_order", sample["variables"] === {x} && sample["scope"] === spec["scope"] && sample["frame_id"] === spec["frame_id"]];

candidate[numerator_] := Join[candidates, <|"rows" -> {{<|"indices" -> {1, 1, 0, 0, 0}, "numerator" -> numerator|>}}|>];
oneFrame = Join[spec, <|"frame" -> {{1}}|>];
epsPrepared = CanonPointDE`PreparePoint[family, masterData, candidate[x Eps[p1, p2, p3, p4]], oneFrame];
epsValue = 4 I Det[family["vectors"] /. x -> 2];
check["external_epsilon_and_explicit_coefficient_derivatives", !FailureQ[epsPrepared] &&
  zero[epsPrepared["expressions"] - {2 epsValue master}] &&
  zero[epsPrepared["candidate_derivatives"][[1, 1]] - 5 epsValue master - 2 epsValue prepared["master_derivatives"][[1, 1]]]];
gramPrepared = CanonPointDE`PreparePoint[family, masterData, candidate[x^2 Gram[{p1, p2}, {p1, p2}]], oneFrame];
check["external_gram_derivative", !FailureQ[gramPrepared] && zero[gramPrepared["expressions"] - {-1024 master}] &&
  zero[gramPrepared["candidate_derivatives"][[1, 1]] + 3072 master + 1024 prepared["master_derivatives"][[1, 1]]]];
loopPrepared = CanonPointDE`PreparePoint[family, masterData, candidate[sp[l, l]], oneFrame];
check["regulated_loop_square_retained", loopPrepared["expressions"] === {B[0, 1, 0, 0, 0]}];
loopPreparedSingle = CanonPointDE`PreparePoint[family, masterData, candidate[sp[l]], oneFrame];
check["single_argument_scalar_product", loopPreparedSingle["expressions"] === loopPrepared["expressions"] &&
  loopPreparedSingle["candidate_derivatives"] === loopPrepared["candidate_derivatives"]];
transverse = CanonPointDE`PreparePoint[family, masterData, candidate[Gram[{l, p1, p2, p3, p4}, {l, p1, p2, p3, p4}]], oneFrame];
check["five_vector_loop_gram_not_collapsed", !FailureQ[transverse] && !zero[transverse["expressions"]]];
algebraicFrame = CanonPointDE`PreparePoint[family, masterData, candidates,
  Join[spec, <|"frame" -> {{1/Sqrt[-Gram[{p1, p2}, {p1, p2}]]}}|>]];
check["algebraic_frame_chain_rule", algebraicFrame["frame"] === {{1/16}} && algebraicFrame["frame_derivatives"] === {{{-1/16}}}];
loopEps = CanonPointDE`PreparePoint[family, masterData, candidate[Eps[l, p1, p2, p3]], oneFrame];
check["unsupported_loop_epsilon_rejected", FailureQ[loopEps] && loopEps[[1]] === "LOOP_EPSILON_UNSUPPORTED"];

family2 = Join[family, <|"integral_head" -> "H", "loop_momenta" -> {l1, l2}, "variables" -> {y, x},
  "vectors" -> x {{1, 1, 0, 0}, {1, -1, 0, 0}, {1, 0, 1, 0}, {y, 0, 0, y}},
  "propagators" -> {l1^2, l2^2, (l1-l2)^2, (l1-p1)^2, (l1-p2)^2, (l1-p3)^2, (l1-p4)^2,
    (l2-p1)^2, (l2-p2)^2, (l2-p3)^2, (l2-p4)^2}|>];
indices2 = ConstantArray[1, 11]; master2 = H @@ indices2;
masters2 = Join[masterData, <|"masters" -> {master2}|>];
candidate2 = Join[candidates, <|"rows" -> {{<|"indices" -> indices2, "numerator" -> sp[l1, l2]|>}}|>];
prepared2 = CanonPointDE`PreparePoint[family2, masters2, candidate2, Join[oneFrame, <|"point" -> {x -> 2, y -> 3}|>]];
check["loop_count_and_variable_order_are_inputs", !FailureQ[prepared2] && prepared2["variables"] === {y, x} &&
  Dimensions[prepared2["operators"]] === {2, 11, 12} &&
  zero[prepared2["expressions"] - {(H @@ (indices2 - UnitVector[11, 1]) + H @@ (indices2 - UnitVector[11, 2]) -
      H @@ (indices2 - UnitVector[11, 3]))/2}]];
indexed = CanonPointDE`PreparePoint[family /. x -> xx[1], masterData, candidates /. x -> xx[1], spec /. x -> xx[1]];
check["indexed_kinematic_variable", !FailureQ[indexed] && indexed["variables"] === {xx[1]} &&
  indexed["candidate_derivatives"] === prepared["candidate_derivatives"] &&
  indexed["frame_derivatives"] === prepared["frame_derivatives"]];

(* Independent matrix gauge fixture with two rows, including an off-diagonal dR. *)
repair = Join[prepared, <|"masters" -> {H[1], H[2]}, "expressions" -> {2 H[1], H[2]},
  "candidate_derivatives" -> {{(1 + eps) H[1], eps H[2]}},
  "master_derivatives" -> {{eps/2 H[1], eps H[2]}}, "frame" -> {{1, 2}, {0, 1}},
  "frame_derivatives" -> {{{0, 1}, {0, 0}}}, "targets" -> {H[1], H[2]}|>];
builtRepair = CanonPointDE`BuildPointDE[repair, {}];
tSymbolic = {{1, x}, {0, 1}} . DiagonalMatrix[{x, 1}];
aSymbolic = (D[tSymbolic, x] + tSymbolic . DiagonalMatrix[{eps/x, 2 eps/x}]) . Inverse[tSymbolic];
check["nonconstant_repair_gauge_full_matrix", !FailureQ[builtRepair] &&
  zero[builtRepair["sample", "matrices"] - {aSymbolic /. x -> 2}]];
check["noncanonical_sample_is_preserved", !TrueQ[builtRepair["check", "epsilon_factorized_at_this_point"]]];
singular = CanonPointDE`BuildPointDE[Join[repair, <|"expressions" -> {H[1], H[1]}|>], {}];
check["rank_failure_rejected", FailureQ[singular] && singular[[1]] === "RANK_FAILURE"];
missingMaster = Join[repair, <|"master_derivatives" -> {{H[3], 0}}, "targets" -> {H[1], H[2], H[3]}|>];
bad = CanonPointDE`BuildPointDE[missingMaster, {}];
check["all_master_derivative_targets_required", FailureQ[bad] && bad[[1]] === "MISSING_TARGETS"];
changedMaster = CanonPointDE`BuildPointDE[repair, {H[1] -> 2 H[1]}];
check["source_master_basis_identity_required", FailureQ[changedMaster] && changedMaster[[1]] === "MASTER_BASIS_CHANGED"];

setPath = FileNameJoin[{tree, "samples", "sample-set.wl"}]; set = Get[setPath];
refs = Join[set["training"], set["validation"]];
resolved = CanonMethodCard`ResolveInputPath[setPath, #["path"]] & /@ refs;
check["original_index_survives_move", And @@ (FileExistsQ /@ resolved) &&
  And @@ (#["schema"] === "canon-neu/de-sample/v1" & /@ (Get /@ resolved))];
check["relative_index_references", And @@ (!StringStartsQ[#["path"], "/"] & /@ refs)];
check["index_contains_no_matrices", !KeyExistsQ[set, "matrices"]];
sourcePaths = Values[sample["sources"]];
check["source_references_survive_move", And @@ (FileExistsQ[CanonMethodCard`ResolveInputPath[
  FileNameJoin[{tree, "training", "de-sample.wl"}], #["path"]]] & /@ sourcePaths)];
Export[receipt, checks, "RawJSON"];
Exit[If[And @@ Values[checks], 0, 1]];
