#!/usr/bin/env wolframscript

$HistoryLength = 0;

repoRoot = DirectoryName[DirectoryName[ExpandFileName[$InputFileName]]];
Get[FileNameJoin[{repoRoot, "mma", "lib", "MethodCardCore.wl"}]];

{inputPath, outputDir} = ExpandFileName /@ CanonMethodCard`ScriptArguments[];
task = CanonMethodCard`ReadTask[inputPath, "DISCOVER"];
prepared = CanonMethodCard`LoadArtifact[task, inputPath, "prepared_family"];
masterLines = Select[
  (StringTrim[StringReplace[#, RegularExpression["#.*$"] -> ""]] &) /@ StringSplit[
    Import[prepared["ordered_masters", "path"], "Text"], {"\r\n", "\n", "\r"}
  ],
  # =!= "" && !StringStartsQ[#, "#"] &
];
masters = Block[{$Context = "CANON`DEData`", $ContextPath = {"System`"}},
  ToExpression["{" <> StringRiffle[masterLines, ","] <> "}", InputForm]
];
bits[master_] := CanonMethodCard`SectorBits[master, prepared["propagator_slots"]];
sectorID[mask_] := mask . 2^Range[0, Length[mask] - 1];
sectors = (<|"id" -> sectorID[bits[First[#]]],
    "propagator_count" -> Total[bits[First[#]]],
    "sector_bits" -> bits[First[#]], "master_count" -> Length[#]|> &) /@
  GatherBy[masters, bits];
sectors = SortBy[sectors, {#["propagator_count"], #["id"]} &];
sectorRank = AssociationThread[Lookup[sectors, "id"] -> Range[Length[sectors]]];
masters = First /@ SortBy[
  MapIndexed[{#1, First[#2]} &, masters],
  {
    sectorRank[sectorID[bits[First[#]]]],
    Last[#]
  } &
];

sectorManifest = <|
  "schema" -> "canon-neu/sector-manifest/v1",
  "family_ref" -> prepared["family_ref"],
  "source_sha256" -> prepared["ordered_masters", "sha256"],
  "propagator_slots" -> prepared["propagator_slots"],
  "sector_convention" -> prepared["sector_convention"],
  "bit_order" -> "integral index order; a1 is the least-significant bit; ISP bits are zero",
  "ordering" -> "ascending (propagator_count, id)",
  "sectors" -> sectors
|>;
masterBasis = <|
  "schema" -> "canon-neu/master-basis/v1",
  "family_ref" -> prepared["family_ref"],
  "basis_ref" -> prepared["basis_ref"],
  "topology" -> prepared["topology"],
  "source_sha256" -> prepared["ordered_masters", "sha256"],
  "index_order" -> prepared["index_order"],
  "ordering" -> "ascending sector-manifest rank (propagator_count, id); original Kira position within sector",
  "masters" -> masters
|>;

sectorPath = CanonMethodCard`WriteWLArtifact[
  sectorManifest, outputDir, "sector-manifest.wl"
];
masterPath = CanonMethodCard`WriteWLArtifact[
  masterBasis, outputDir, "master-basis.wl"
];
CanonMethodCard`WriteResult[
  task, outputDir, "PASS", "SECTORS_READY",
  <|
    "sector_manifest" -> <|
      "type" -> "mathematica-expression", "path" -> FileNameTake[sectorPath]
    |>,
    "master_basis" -> <|
      "type" -> "mathematica-expression", "path" -> FileNameTake[masterPath]
    |>
  |>,
  <|"sectors" -> (KeyTake[#, {"id", "propagator_count"}] & /@ sectors)|>
];
