#!/usr/bin/env wolframscript

$HistoryLength = 0;

repoRoot = DirectoryName[DirectoryName[ExpandFileName[$InputFileName]]];
Get[FileNameJoin[{repoRoot, "mma", "lib", "MethodCardCore.wl"}]];

{inputPath, outputDir} = ExpandFileName /@ CanonMethodCard`ScriptArguments[];
task = CanonMethodCard`ReadTask[inputPath, "PREPARE"];
spec = CanonMethodCard`LoadArtifact[task, inputPath, "family_spec"];
specPath = CanonMethodCard`ResolveInputPath[inputPath, task["payload", "family_spec", "path"]];
preparedPath = FileNameJoin[{outputDir, "prepared-family.wl"}];
source[path_String] := With[{resolved = CanonMethodCard`ResolveInputPath[specPath, path]}, <|
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
CanonMethodCard`WriteResult[
  task, outputDir, "PASS", "OK",
  <|"prepared_family" -> <|
    "type" -> "mathematica-expression",
    "path" -> FileNameTake[artifactPath]
  |>|>,
  <|"family_ref" -> prepared["family_ref"], "basis_ref" -> prepared["basis_ref"]|>
];
