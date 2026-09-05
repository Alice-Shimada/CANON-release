#!/usr/bin/env wolframscript

$HistoryLength = 0;

repoRoot = DirectoryName[DirectoryName[ExpandFileName[$InputFileName]]];
Get[FileNameJoin[{repoRoot, "mma", "lib", "MethodCardCore.wl"}]];

{inputPath, outputDir} = ExpandFileName /@ CanonMethodCard`ScriptArguments[];
task = CanonMethodCard`ReadTask[inputPath, "SLICE_CUT_DE"];
orderedMasterDE = CanonMethodCard`LoadArtifact[
  task, inputPath, "ordered_master_de"
];
sectorManifest = CanonMethodCard`LoadArtifact[
  task, inputPath, "sector_manifest"
];

currentSector = SelectFirst[
  sectorManifest["sectors"], #1["id"] === task["sector", "id"] &
];
currentBits = currentSector["sector_bits"];
masterBits = (CanonMethodCard`SectorBits[#, sectorManifest["propagator_slots"]] &) /@
  orderedMasterDE["basis"];
positions = Flatten @ Position[masterBits, currentBits];
basis = orderedMasterDE["basis"][[positions]];
lowerSectors = Select[
  sectorManifest["sectors"],
  #1["sector_bits"] =!= currentBits &&
    And @@ MapThread[LessEqual, {#1["sector_bits"], currentBits}] &
];
sector = KeyTake[currentSector, {"id", "propagator_count"}];
basisID = orderedMasterDE["basis_id"] <> "/sector-" <>
  ToString[sector["id"]];
cutMatrices = (#[[positions, positions]] & /@ orderedMasterDE["matrices"]);

sectorBasis = <|
  "schema" -> "canon-neu/sector-basis/v1",
  "sector" -> sector,
  "family_id" -> orderedMasterDE["family_id"],
  "basis_id" -> basisID,
  "basis" -> basis
|>;
sectorCutDE = <|
  "schema" -> "canon-neu/sector-cut-de/v1",
  "sector" -> sector,
  "family_id" -> orderedMasterDE["family_id"],
  "basis_id" -> basisID,
  "coefficient_domain" -> orderedMasterDE["coefficient_domain"],
  "basis" -> basis,
  "variables" -> orderedMasterDE["variables"],
  "regulator" -> orderedMasterDE["regulator"],
  "matrices" -> cutMatrices,
  "sector_boundaries" -> {{1, Length[basis]}},
  "proper_subsectors" ->
    (KeyTake[#, {"id", "propagator_count"}] & /@ lowerSectors)
|>;

basisPath = CanonMethodCard`WriteWLArtifact[
  sectorBasis, outputDir, "sector-basis.wl"
];
cutPath = CanonMethodCard`WriteWLArtifact[
  sectorCutDE, outputDir, "sector-cut-de.wl"
];
CanonMethodCard`WriteResult[
  task, outputDir, "PASS", "OK",
  <|
    "sector_basis" -> <|
      "type" -> "mathematica-expression", "path" -> FileNameTake[basisPath]
    |>,
    "sector_cut_de" -> <|
      "type" -> "mathematica-expression", "path" -> FileNameTake[cutPath]
    |>
  |>,
  <|
    "basis_size" -> Length[basis],
    "full_master_count" -> Length[orderedMasterDE["basis"]],
    "resident_positions" -> positions,
    "matrix_dimensions" -> (Dimensions /@ cutMatrices)
  |>
];
