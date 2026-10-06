#!/usr/bin/env wolframscript
$HistoryLength = 0;
repoRoot = DirectoryName[DirectoryName[ExpandFileName[$InputFileName]]];
Get[FileNameJoin[{repoRoot, "mma", "lib", "MethodCardCore.wl"}]];
Get[FileNameJoin[{repoRoot, "mma", "lib", "PhysicalDerivative.wl"}]];
{inputPath, outputDir} = ExpandFileName /@ CanonMethodCard`ScriptArguments[];
task = CanonMethodCard`ReadTask[inputPath, "PREPARE_DERIVATIVES"];
family = CanonMethodCard`LoadArtifact[task, inputPath, "family_data"];
derivatives = CANON`PhysicalDerivative`PreparePhysicalDerivatives[family];
If[FailureQ[derivatives],
  CanonMethodCard`WriteResult[task, outputDir, "FAIL", derivatives[[1]], <||>,
    <|"reason" -> ToString[derivatives[[2]], InputForm]|>]; Exit[1]];
CanonMethodCard`WriteWLArtifact[derivatives, outputDir, "prepared-derivatives.wl"];
CanonMethodCard`WriteResult[task, outputDir, "PASS", "PHYSICAL_DERIVATIVES_READY",
  <|"prepared_derivatives" -> <|"type" -> "mathematica-expression", "path" -> "prepared-derivatives.wl"|>|>,
  <|"variables" -> (ToString[#, InputForm] & /@ derivatives["variables"]),
    "denominator_count" -> derivatives["denominator_count"],
    "method" -> "external-momentum-chain-rule"|>];
