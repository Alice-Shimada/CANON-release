#!/usr/bin/env wolframscript

$HistoryLength = 0;

repoRoot = DirectoryName[DirectoryName[ExpandFileName[$InputFileName]]];
Get[FileNameJoin[{repoRoot, "mma", "lib", "MethodCardCore.wl"}]];

{inputPath, outputDir} = ExpandFileName /@ CanonMethodCard`ScriptArguments[];
task = CanonMethodCard`ReadTask[inputPath, "PREPARE"];
spec = CanonMethodCard`LoadArtifact[task, inputPath, "family_spec"];
specPath = CanonMethodCard`ResolveInputPath[inputPath, task["payload", "family_spec", "path"]];
project = CanonMethodCard`ResolveInputPath[specPath, spec["kira", "project"]];
source[path_String] := With[{resolved = CanonMethodCard`ResolveInputPath[specPath, path]}, <|
  "path" -> resolved,
  "sha256" -> FileHash[resolved, "SHA256", "HexString"]
|>];
kiraSource[path_String] := source[FileNameJoin[{project, path}]];

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
  "kira" -> <|
    "project" -> project,
    "jobs" -> spec["kira", "jobs"],
    "targets" -> spec["kira", "targets"],
    "sources" -> <|
      "integral_families" -> kiraSource[spec["kira", "integral_families"]],
      "kinematics" -> kiraSource[spec["kira", "kinematics"]],
      "jobs" -> (kiraSource /@ spec["kira", "jobs"]),
      "targets" -> kiraSource[spec["kira", "targets"]]
    |>
  |>,
  "family_data" -> source[spec["family_data"]],
  "prepared_derivatives" -> source[spec["prepared_derivatives"]],
  "ordered_masters" -> source[spec["ordered_masters"]]
|>;

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
