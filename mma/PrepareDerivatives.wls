#!/usr/bin/env wolframscript
$HistoryLength = 0;
repoRoot = DirectoryName[DirectoryName[ExpandFileName[$InputFileName]]];
Get[FileNameJoin[{repoRoot, "mma", "lib", "MethodCardCore.wl"}]];
Get[FileNameJoin[{repoRoot, "mma", "lib", "PhysicalDerivative.wl"}]];
{inputPath, outputDir} = ExpandFileName /@ CanonMethodCard`ScriptArguments[];
task = CanonMethodCard`ReadTask[inputPath, "PREPARE_DERIVATIVES"];
fail[result_Failure] := (
  CanonMethodCard`WriteResult[task, outputDir, "FAIL", result[[1]], <||>,
    <|"reason" -> ToString[result[[2]], InputForm]|>]; Exit[1]
);
family = CanonMethodCard`LoadArtifact[task, inputPath, "family_data"];
If[FailureQ[family], fail[family]];
derivatives = CANON`PhysicalDerivative`PreparePhysicalDerivatives[family];
If[FailureQ[derivatives], fail[derivatives]];
path = CanonMethodCard`WriteWLArtifact[derivatives, outputDir, "prepared-derivatives.wl"];
If[!StringQ[path], fail[Failure["ARTIFACT_WRITE_FAILED", <|"path" -> "prepared-derivatives.wl"|>]]];
CanonMethodCard`WriteResult[task, outputDir, "PASS", "PHYSICAL_DERIVATIVES_READY",
  <|"prepared_derivatives" -> <|"type" -> "mathematica-expression", "path" -> "prepared-derivatives.wl"|>|>,
  <|"variables" -> (ToString[#, InputForm] & /@ derivatives["variables"]),
    "denominator_count" -> derivatives["denominator_count"],
    "method" -> "external-momentum-chain-rule"|>];
