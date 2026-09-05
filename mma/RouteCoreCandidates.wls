#!/usr/bin/env wolframscript

repoRoot = DirectoryName[DirectoryName[$InputFileName]];
Get[FileNameJoin[{repoRoot, "mma", "lib", "MethodCardCore.wl"}]];
Get[FileNameJoin[{repoRoot, "mma", "lib", "CandidateIBPBridge.wl"}]];

arguments = CanonMethodCard`ScriptArguments[];
{inputPath, outputDir} = ExpandFileName /@ arguments;
task = CanonMethodCard`ReadTask[inputPath, "ROUTE_CORE_CANDIDATES"];
preparedFamily = CanonMethodCard`LoadArtifact[task, inputPath, "prepared_family"];
sectorBasis = CanonMethodCard`LoadArtifact[task, inputPath, "sector_basis"];
cut = CanonMethodCard`LoadArtifact[task, inputPath, "sector_cut_de"];
bridge = CanonMethodCard`LoadArtifact[task, inputPath, "candidate_ibp_bridge"];

result = CANON`CandidateIBPBridge`BuildCoreCandidates[
  bridge, preparedFamily, sectorBasis, cut];
artifactPath = CanonMethodCard`WriteWLArtifact[result, outputDir, "core-candidates.wl"];
CanonMethodCard`WriteResult[
  task, outputDir, "PROVISIONAL", "CORE_CANDIDATES_ROUTED",
  <|"core_candidates" -> <|
    "type" -> "mathematica-expression", "path" -> FileNameTake[artifactPath]|>|>,
  <|"candidate_ids" -> (#["candidate_id"] & /@ result["candidates"]),
    "pool" -> result["candidate_group_pool"],
    "provider_output_is_acceptance" -> False|>
];
