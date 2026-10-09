#!/usr/bin/env wolframscript

$HistoryLength = 0;

repoRoot = DirectoryName[DirectoryName[ExpandFileName[$InputFileName]]];
Get[FileNameJoin[{repoRoot, "mma", "lib", "MethodCardCore.wl"}]];

{inputPath, outputDir} = ExpandFileName /@ CanonMethodCard`ScriptArguments[];
task = CanonMethodCard`ReadTask[inputPath, "PREPARE"];
fail[result_Failure] := (
  CanonMethodCard`WriteResult[task, outputDir, "ERROR", result[[1]], <||>,
    <|"reason" -> result[[2, "Message"]]|>]; Exit[1]
);
spec = CanonMethodCard`LoadArtifact[task, inputPath, "family_spec"];
If[FailureQ[spec], fail[spec]];
specPath = CanonMethodCard`ResolveInputPath[inputPath, task["payload", "family_spec", "path"]];
preparedPath = FileNameJoin[{outputDir, "prepared-family.wl"}];
source[path_] := Module[{resolved = CanonMethodCard`ResolveArtifactPath[specPath, <|"path" -> path|>]},
  If[FailureQ[resolved], fail[resolved]];
  <|
  "path" -> CanonMethodCard`RelativeArtifactPath[preparedPath, resolved],
  "sha256" -> FileHash[resolved, "SHA256", "HexString"]
|>];

prepared = <|
  "schema" -> "canon-neu/prepared-family/v1",
  "family_ref" -> spec["family_ref"],
  "basis_ref" -> spec["basis_ref"],
  "topology" -> spec["topology"],
  "parameters" -> spec["parameters"],
  "variables" -> spec["variables"],
  "regulator" -> spec["regulator"],
  "dimension_rule" -> spec["dimension_rule"],
  "index_order" -> spec["index_order"],
  "propagator_slots" -> spec["propagator_slots"],
  "sector_convention" -> spec["sector_convention"],
  "family_data" -> source[spec["family_data"]],
  "prepared_derivatives" -> source[spec["prepared_derivatives"]],
  "ordered_masters" -> source[spec["ordered_masters"]]
|>;
If[KeyExistsQ[spec, "integral_head"], prepared["integral_head"] = spec["integral_head"]];
If[KeyExistsQ[spec, "operator_source_symbol_map"],
  prepared["operator_source_symbol_map"] = spec["operator_source_symbol_map"]];
(* Legacy Kira provenance is optional; scientific preparation does not require it. *)
If[KeyExistsQ[spec, "kira"],
  project = CanonMethodCard`ResolveInputPath[specPath, spec["kira", "project"]];
  kiraSource[path_String] := source[FileNameJoin[{project, path}]];
  prepared["kira"] = <|
    "project" -> CanonMethodCard`RelativeArtifactPath[preparedPath, project],
    "jobs" -> spec["kira", "jobs"],
    "targets" -> spec["kira", "targets"],
    "sources" -> <|
      "integral_families" -> kiraSource[spec["kira", "integral_families"]],
      "kinematics" -> kiraSource[spec["kira", "kinematics"]],
      "jobs" -> (kiraSource /@ spec["kira", "jobs"]),
      "targets" -> kiraSource[spec["kira", "targets"]]
    |>
  |>
];

artifactPath = CanonMethodCard`WriteWLArtifact[
  prepared, outputDir, "prepared-family.wl"
];
If[!StringQ[artifactPath],
  fail[Failure["ARTIFACT_WRITE_FAILED", <|"Message" -> "could not write prepared family"|>]]];
CanonMethodCard`WriteResult[
  task, outputDir, "PASS", "OK",
  <|"prepared_family" -> <|
    "type" -> "mathematica-expression",
    "path" -> FileNameTake[artifactPath]
  |>|>,
  <|"family_ref" -> prepared["family_ref"], "basis_ref" -> prepared["basis_ref"]|>
];
