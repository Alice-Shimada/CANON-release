#!/usr/bin/env wolframscript
$HistoryLength = 0;
repoRoot = DirectoryName[DirectoryName[ExpandFileName[$InputFileName]]];
Get[FileNameJoin[{repoRoot, "mma", "lib", "MethodCardCore.wl"}]];
Get[FileNameJoin[{repoRoot, "mma", "lib", "DEBuilder.wl"}]];
Get[FileNameJoin[{repoRoot, "mma", "lib", "SectorDE.wl"}]];

{inputPath, outputDir} = ExpandFileName /@ CanonMethodCard`ScriptArguments[];
task = CanonMethodCard`ReadTask[inputPath, "BUILD_CUT_DE"];
fail[result_Failure] := (
  CanonMethodCard`WriteResult[task, outputDir, "ERROR", result[[1]], <||>,
    <|"reason" -> result[[2, "Message"]]|>]; Exit[1]
);

prepared = CanonMethodCard`LoadArtifact[task, inputPath, "prepared_family"];
If[FailureQ[prepared], fail[prepared]];
preparedPath = CanonMethodCard`ResolveInputPath[inputPath, task["payload", "prepared_family", "path"]];
masterBasis = CanonMethodCard`LoadArtifact[task, inputPath, "master_basis"];
If[FailureQ[masterBasis], fail[masterBasis]];
sectorManifest = CanonMethodCard`LoadArtifact[task, inputPath, "sector_manifest"];
If[FailureQ[sectorManifest], fail[sectorManifest]];
currentSector = CANON`SectorDE`CurrentSectorRecord[
  <|"family_id" -> prepared["family_ref"], "basis" -> masterBasis["masters"]|>,
  sectorManifest, task["sector"]];
If[FailureQ[currentSector], fail[currentSector]];
reduction = CanonMethodCard`LoadArtifact[task, inputPath, "ibp_reduction"];
If[FailureQ[reduction], fail[reduction]];
derivativePath = If[KeyExistsQ[task["payload"], "prepared_derivatives"],
  CanonMethodCard`ResolveArtifactPath[inputPath, task["payload", "prepared_derivatives"]], Automatic];
normalized = CANON`SectorDE`LoadPreparedDerivatives[prepared, preparedPath, masterBasis, derivativePath];
If[FailureQ[normalized], fail[normalized]];
orderedMasterDE = CANON`SectorDE`BuildOrderedMasterDE[prepared, masterBasis, reduction, normalized];
If[FailureQ[orderedMasterDE], fail[orderedMasterDE]];
sliced = CanonMethodCard`SectorDEArtifacts[orderedMasterDE, sectorManifest, currentSector];
If[sliced["resident_positions"] === {},
  fail[Failure["INVALID_DIFFERENTIAL_EQUATION", <|"Message" -> "requested sector has no resident masters"|>]]];

basisPath = CanonMethodCard`WriteWLArtifact[sliced["sector_basis"], outputDir, "sector-basis.wl"];
cutPath = CanonMethodCard`WriteWLArtifact[sliced["sector_cut_de"], outputDir, "sector-cut-de.wl"];
orderedPath = CanonMethodCard`WriteWLArtifact[orderedMasterDE, outputDir, "ordered-master-de.wl"];
If[!AllTrue[{basisPath, cutPath, orderedPath}, StringQ],
  fail[Failure["ARTIFACT_WRITE_FAILED", <|"Message" -> "could not write complete BUILD_CUT_DE artifacts"|>]]];
CanonMethodCard`WriteResult[task, outputDir, "PASS", "OK", <|
  "sector_basis" -> <|"type" -> "mathematica-expression", "path" -> FileNameTake[basisPath]|>,
  "sector_cut_de" -> <|"type" -> "mathematica-expression", "path" -> FileNameTake[cutPath]|>,
  "ordered_master_de" -> <|"type" -> "mathematica-expression", "path" -> FileNameTake[orderedPath]|>|>,
  <|"basis_size" -> Length[sliced["sector_basis", "basis"]],
    "full_master_count" -> Length[orderedMasterDE["basis"]],
    "resident_positions" -> sliced["resident_positions"],
    "de_validity_scope" -> orderedMasterDE["validity", "scope"],
    "de_flat" -> orderedMasterDE["validity", "flat"],
    "prepared_derivative_input" -> normalized["input_form"],
    "prepared_derivative_denominator_count" -> normalized["derivatives", "denominator_count"]|>];
