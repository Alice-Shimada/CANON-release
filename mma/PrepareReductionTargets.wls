#!/usr/bin/env wolframscript
$HistoryLength = 0;
repoRoot = DirectoryName[DirectoryName[ExpandFileName[$InputFileName]]];
Get[FileNameJoin[{repoRoot, "mma", "lib", "MethodCardCore.wl"}]];
Get[FileNameJoin[{repoRoot, "mma", "lib", "CandidateIBPBridge.wl"}]];
Get[FileNameJoin[{repoRoot, "mma", "lib", "SectorDE.wl"}]];

{inputPath, outputDir} = ExpandFileName /@ CanonMethodCard`ScriptArguments[];
task = CanonMethodCard`ReadTask[inputPath, "PREPARE_REDUCTION_TARGETS"];
fail[result_Failure] := (
  CanonMethodCard`WriteResult[task, outputDir, "ERROR", result[[1]], <||>,
    <|"reason" -> result[[2, "Message"]]|>]; Exit[1]
);
prepared = CanonMethodCard`LoadArtifact[task, inputPath, "prepared_family"];
preparedPath = CanonMethodCard`ResolveInputPath[inputPath, task["payload", "prepared_family", "path"]];
masterBasis = CanonMethodCard`LoadArtifact[task, inputPath, "master_basis"];
derivativePath = If[KeyExistsQ[task["payload"], "prepared_derivatives"],
  CanonMethodCard`ResolveInputPath[inputPath, task["payload", "prepared_derivatives", "path"]], Automatic];
normalized = CANON`SectorDE`LoadPreparedDerivatives[prepared, preparedPath, masterBasis, derivativePath];
If[FailureQ[normalized], fail[normalized]];
targets = CANON`CandidateIBPBridge`MasterDerivativeTargets[
  masterBasis["masters"], normalized["derivatives"]];
targetPath = CanonMethodCard`WriteWLArtifact[<|
  "schema" -> "canon-neu/reduction-targets/v1", "family_ref" -> prepared["family_ref"],
  "basis_ref" -> masterBasis["basis_ref"], "targets" -> targets,
  "masters" -> masterBasis["masters"], "point" -> {}|>, outputDir, "reduction-targets.wl"];
If[!StringQ[targetPath],
  fail[Failure["ARTIFACT_WRITE_FAILED", <|"Message" -> "could not write reduction targets"|>]]];
CanonMethodCard`WriteResult[task, outputDir, "PASS", "REDUCTION_TARGETS_READY", <|
  "reduction_targets" -> <|"type" -> "mathematica-expression", "path" -> FileNameTake[targetPath]|>|>,
  <|"target_count" -> Length[targets], "master_count" -> Length[masterBasis["masters"]],
    "prepared_derivative_input" -> normalized["input_form"],
    "prepared_derivative_denominator_count" -> normalized["derivatives", "denominator_count"]|>];
