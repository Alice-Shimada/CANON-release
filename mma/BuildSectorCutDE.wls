#!/usr/bin/env wolframscript

$HistoryLength = 0;

repoRoot = DirectoryName[DirectoryName[ExpandFileName[$InputFileName]]];
Get[FileNameJoin[{repoRoot, "mma", "lib", "MethodCardCore.wl"}]];
Get[FileNameJoin[{repoRoot, "mma", "lib", "DEBuilder.wl"}]];

{inputPath, outputDir} = ExpandFileName /@ CanonMethodCard`ScriptArguments[];
task = CanonMethodCard`ReadTask[inputPath, "BUILD_CUT_DE"];
prepared = CanonMethodCard`LoadArtifact[task, inputPath, "prepared_family"];
masterBasis = CanonMethodCard`LoadArtifact[task, inputPath, "master_basis"];
sectorManifest = CanonMethodCard`LoadArtifact[task, inputPath, "sector_manifest"];
reduction = CanonMethodCard`LoadArtifact[task, inputPath, "ibp_reduction"];
preparedDerivatives = Get[prepared["prepared_derivatives", "path"]];

operatorRow[record_, denominatorCount_] := Prepend[
  Table[
    Total @ Cases[
      record["linear"],
      item_ /; item["denominator"] === denominator :> item["coefficient"]
    ],
    {denominator, denominatorCount}
  ],
  record["constant"]
];
variables = prepared["variables"];
affineOperators = AssociationMap[
  Function[variable,
    operatorRow[#, preparedDerivatives["denominator_count"]] & /@
      preparedDerivatives["operators", variable]
  ],
  variables
];
fullDE = CANON`DEBuilder`BuildDifferentialEquations[
  <|"parameters" -> prepared["parameters"], "operators" -> affineOperators|>,
  masterBasis["masters"],
  reduction["rules"]
];
fullMatrices = fullDE["matrices"] /. prepared["dimension_rule"];
orderedMasterDE = <|
  "schema" -> "canon-neu/ordered-master-de/v1",
  "family_id" -> prepared["family_ref"],
  "basis_id" -> masterBasis["basis_ref"],
  "coefficient_domain" -> "exact-rational-functions",
  "basis" -> masterBasis["masters"],
  "variables" -> variables,
  "regulator" -> prepared["regulator"],
  "matrices" -> Lookup[fullMatrices, variables],
  "validity" -> fullDE["validity"]
|>;

currentSector = SelectFirst[
  sectorManifest["sectors"], #1["id"] === task["sector", "id"] &
];
currentBits = currentSector["sector_bits"];
masterBits = (CanonMethodCard`SectorBits[#, sectorManifest["propagator_slots"]] &) /@
  masterBasis["masters"];
positions = Flatten @ Position[masterBits, currentBits];
basis = masterBasis["masters"][[positions]];
lowerSectors = Select[
  sectorManifest["sectors"],
  #1["sector_bits"] =!= currentBits &&
    And @@ MapThread[LessEqual, {#1["sector_bits"], currentBits}] &
];
sector = KeyTake[currentSector, {"id", "propagator_count"}];
basisID = masterBasis["basis_ref"] <> "/sector-" <> ToString[sector["id"]];

sectorBasis = <|
  "schema" -> "canon-neu/sector-basis/v1",
  "sector" -> sector,
  "family_id" -> prepared["family_ref"],
  "basis_id" -> basisID,
  "basis" -> basis
|>;
sectorCutDE = <|
  "schema" -> "canon-neu/sector-cut-de/v1",
  "sector" -> sector,
  "family_id" -> prepared["family_ref"],
  "basis_id" -> basisID,
  "coefficient_domain" -> "exact-rational-functions",
  "basis" -> basis,
  "variables" -> variables,
  "regulator" -> prepared["regulator"],
  "matrices" -> (#[[positions, positions]] & /@
    Lookup[fullMatrices, variables]),
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
orderedPath = CanonMethodCard`WriteWLArtifact[
  orderedMasterDE, outputDir, "ordered-master-de.wl"
];
CanonMethodCard`WriteResult[
  task, outputDir, "PASS", "OK",
  <|
    "sector_basis" -> <|
      "type" -> "mathematica-expression", "path" -> FileNameTake[basisPath]
    |>,
    "sector_cut_de" -> <|
      "type" -> "mathematica-expression", "path" -> FileNameTake[cutPath]
    |>,
    "ordered_master_de" -> <|
      "type" -> "mathematica-expression", "path" -> FileNameTake[orderedPath]
    |>
  |>,
  <|
    "basis_size" -> Length[basis],
    "full_master_count" -> Length[masterBasis["masters"]],
    "resident_positions" -> positions,
    "de_validity_scope" -> fullDE["validity", "scope"],
    "de_flat" -> fullDE["validity", "flat"]
  |>
];
