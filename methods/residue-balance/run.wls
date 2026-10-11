#!/usr/bin/env wolframscript
$HistoryLength = 0;
repoRoot = DirectoryName[DirectoryName[DirectoryName[ExpandFileName[$InputFileName]]]];
Get[FileNameJoin[{repoRoot, "mma", "lib", "MethodCardCore.wl"}]];
Get[FileNameJoin[{repoRoot, "mma", "lib", "ResidueBalance.wl"}]];
args = CanonMethodCard`ScriptArguments[];
If[Length[args] =!= 2, Print["Usage: run.wls INPUT.json OUTPUT_DIR"]; Quit[2]];
{inputPath, outputDir} = ExpandFileName /@ args;
envelope = Quiet @ Check[Import[inputPath, "RawJSON"], $Failed];
step = If[AssociationQ[envelope], Lookup[envelope, "step", None], None];
If[!MemberQ[{"DIAGNOSE_CORE", "SEARCH_CORE"}, step], Print["Invalid step"]; Quit[2]];
task = If[step === "DIAGNOSE_CORE", CanonMethodCard`ReadTask[inputPath, "DIAGNOSE_CORE"],
  CanonMethodCard`ReadTask[inputPath, "SEARCH_CORE"]];
If[FailureQ[task], Print[InputForm[task]]; Quit[2]];

descriptor[path_] := <|"type" -> "mathematica-expression", "path" -> FileNameTake[path]|>;
finish[status_, code_, artifacts_, summary_] := Module[{path},
  path = CanonMethodCard`WriteProviderResult[task, outputDir, status, code, artifacts,
    Join[<|"method_id" -> "residue-balance", "nonexistence_proved" -> False|>, summary]];
  If[path === $Failed, Print["Could not write result.json"]; Quit[1]];
  Quit[If[status === "ERROR", 1, 0]]
];
publishFailure[failure_] := Module[{tag = failure[[1]], details = failure[[2]], path},
  path = CanonMethodCard`WriteWLArtifact[Join[
    <|"schema" -> "canon-neu/core-method-limit/v1", "code" -> tag|>, details],
    outputDir, "method-limit.wl"];
  If[path === $Failed, Print["Could not write method-limit.wl"]; Quit[1]];
  finish[If[MemberQ[{"METHOD_EXHAUSTED", "OUT_OF_SCOPE"}, tag], "INCONCLUSIVE", "ERROR"],
    tag, <|"method_limit" -> descriptor[path]|>,
    <|"reason" -> details["reason"], "stage" -> Lookup[details, "stage", "input-or-applicability"]|>]
];

cut = CanonMethodCard`LoadArtifact[task, inputPath, "sector_cut_de"];
sectorBasis = CanonMethodCard`LoadArtifact[task, inputPath, "sector_basis"];
If[FailureQ[cut] || !CanonMethodCard`ValidSectorBasisQ[sectorBasis],
  publishFailure[Failure["INVALID_INPUT", <|"reason" -> "Invalid sector_basis or sector_cut_de",
    "nonexistence_proved" -> False|>]]];
If[!CanonMethodCard`SameSectorQ[cut["sector"], sectorBasis["sector"], Lookup[task, "sector", None]] ||
    !AllTrue[{"family_id", "basis_id", "basis"}, cut[#] === sectorBasis[#] &],
  publishFailure[Failure["INVALID_INPUT", <|"reason" -> "Sector, family, basis or order mismatch",
    "nonexistence_proved" -> False|>]]];
options = Lookup[task["payload"], "method_options", <||>];
(* JSON carries exact reference values as numerator/denominator pairs. *)
If[AssociationQ[options] && KeyExistsQ[options, "reference_regulators"],
  refs = options["reference_regulators"];
  If[!MatchQ[refs, {{_Integer, _Integer} ..}] || MemberQ[refs[[All, 2]], 0],
    publishFailure[Failure["INVALID_OPTIONS", <|"reason" -> "reference_regulators requires exact [numerator, denominator] pairs",
      "nonexistence_proved" -> False|>]]];
  options["reference_regulators"] = (#[[1]]/#[[2]] &) /@ refs
];
proposal = If[step === "DIAGNOSE_CORE", CANON`ResidueBalance`AnalyzeCore[cut, options],
  CANON`ResidueBalance`ProposeCore[cut, options]];
If[FailureQ[proposal], publishFailure[proposal]];
If[!AssociationQ[proposal],
  publishFailure[Failure["CONSTRUCTION_ERROR", <|"reason" -> "Method did not return a result",
    "nonexistence_proved" -> False|>]]];
If[step === "DIAGNOSE_CORE",
  path = CanonMethodCard`WriteWLArtifact[proposal, outputDir, "core-diagnosis.wl"];
  If[path === $Failed, Quit[1]];
  finish["PROVISIONAL", "CORE_DIAGNOSIS", <|"core_diagnosis" -> descriptor[path]|>,
    <|"active_variable" -> ToString[proposal["active_variable"], InputForm],
      "already_epsilon_form" -> proposal["already_epsilon_form"],
      "recommended_method" -> "residue-balance",
      "regulator_zero_invertibility_required" -> False|>]
];
n = Length[cut["basis"]];
value = Join[KeyTake[cut, {"sector", "family_id", "basis_id", "basis", "variables", "regulator"}], <|
  "schema" -> "canon-neu/core-candidates/v1", "source_basis" -> cut["basis"],
  "coefficient_domain" -> "exact-rational-functions",
  "convention" -> "old_basis = transformation . new_basis",
  "method" -> Join[<|"id" -> "residue-balance"|>,
    KeyTake[proposal, {"active_variable", "scale_rows", "shears", "balances",
      "regulator_factorization", "regulator_zero_invertibility_required", "options"}]],
  "candidate_group_pool" -> <|"declared" -> 1, "eligible" -> 1, "remaining" -> 0,
    "unconsumed_candidates" -> 0, "pool_exhausted" -> True|>,
  "candidates" -> {<|"candidate_id" -> "residue-balance:1",
    "member_candidate_ids" -> ("residue-balance:row:" <> ToString[#] & /@ Range[n]),
    "new_basis_rows" -> proposal["rows"], "full_new_basis_rows" -> proposal["rows"],
    "construction_rejection" -> None, "transformation" -> proposal["transformation"],
    "transformed_matrices" -> proposal["transformed_matrices"]|>}|>];
path = CanonMethodCard`WriteWLArtifact[value, outputDir, "core-candidates.wl"];
If[path === $Failed, Quit[1]];
finish["PROVISIONAL", "CANDIDATE_TRANSFORMATION", <|"core_candidates" -> descriptor[path]|>,
  <|"candidate_count" -> 1, "balance_count" -> Length[proposal["balances"]],
    "shear_count" -> Length[proposal["shears"]], "next_step" -> "CHECK_CORE"|>];
