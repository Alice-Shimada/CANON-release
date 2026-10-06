#!/usr/bin/env wolframscript
$HistoryLength = 0;
repoRoot = DirectoryName[DirectoryName[ExpandFileName[$InputFileName]]];
Get[FileNameJoin[{repoRoot, "mma", "lib", "MethodCardCore.wl"}]];
Get[FileNameJoin[{repoRoot, "mma", "lib", "SectorDE.wl"}]];

{inputPath, outputDir} = ExpandFileName /@ CanonMethodCard`ScriptArguments[];
task = CanonMethodCard`ReadTask[inputPath, "SLICE_CUT_DE"];
fail[result_Failure] := (
  CanonMethodCard`WriteResult[task, outputDir, "ERROR", result[[1]], <||>,
    <|"reason" -> result[[2, "Message"]]|>]; Exit[1]
);
orderedMasterDE = CANON`SectorDE`ValidateOrderedMasterDE[
  CanonMethodCard`LoadArtifact[task, inputPath, "ordered_master_de"]];
If[FailureQ[orderedMasterDE], fail[orderedMasterDE]];
sectorManifest = CanonMethodCard`LoadArtifact[task, inputPath, "sector_manifest"];
currentSector = CANON`SectorDE`CurrentSectorRecord[orderedMasterDE, sectorManifest, task["sector"]];
If[FailureQ[currentSector], fail[currentSector]];
sliced = CanonMethodCard`SectorDEArtifacts[orderedMasterDE, sectorManifest, currentSector];
If[sliced["resident_positions"] === {},
  fail[Failure["INVALID_DIFFERENTIAL_EQUATION", <|"Message" -> "requested sector has no resident masters"|>]]];

basisPath = CanonMethodCard`WriteWLArtifact[sliced["sector_basis"], outputDir, "sector-basis.wl"];
cutPath = CanonMethodCard`WriteWLArtifact[sliced["sector_cut_de"], outputDir, "sector-cut-de.wl"];
If[!AllTrue[{basisPath, cutPath}, StringQ],
  fail[Failure["ARTIFACT_WRITE_FAILED", <|"Message" -> "could not write complete SLICE_CUT_DE artifacts"|>]]];
CanonMethodCard`WriteResult[task, outputDir, "PASS", "OK", <|
  "sector_basis" -> <|"type" -> "mathematica-expression", "path" -> FileNameTake[basisPath]|>,
  "sector_cut_de" -> <|"type" -> "mathematica-expression", "path" -> FileNameTake[cutPath]|>|>,
  <|"basis_size" -> Length[sliced["sector_basis", "basis"]],
    "full_master_count" -> Length[orderedMasterDE["basis"]],
    "resident_positions" -> sliced["resident_positions"],
    "matrix_dimensions" -> (Dimensions /@ sliced["sector_cut_de", "matrices"])|>];
