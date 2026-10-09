#!/usr/bin/env wolframscript

$HistoryLength = 0;

repoRoot = DirectoryName[DirectoryName[ExpandFileName[$InputFileName]]];
Get[FileNameJoin[{repoRoot, "mma", "lib", "MethodCardCore.wl"}]];

{inputPath, outputDir} = ExpandFileName /@ CanonMethodCard`ScriptArguments[];
task = CanonMethodCard`ReadTask[inputPath, "DISCOVER"];
prepared = CanonMethodCard`LoadArtifact[task, inputPath, "prepared_family"];
preparedPath = CanonMethodCard`ResolveInputPath[inputPath, task["payload", "prepared_family", "path"]];
masterLines = Select[
  (StringTrim[StringReplace[#, RegularExpression["#.*$"] -> ""]] &) /@ StringSplit[
    Import[CanonMethodCard`ResolveInputPath[preparedPath, prepared["ordered_masters", "path"]], "Text"], {"\r\n", "\n", "\r"}
  ],
  # =!= "" && !StringStartsQ[#, "#"] &
];
masters = Block[{$Context = "CANON`DEData`", $ContextPath = {"System`"}},
  ToExpression["{" <> StringRiffle[masterLines, ","] <> "}", InputForm]
];
formatted = CanonMethodCard`FormatMasterArtifacts[prepared, masters, prepared["ordered_masters", "sha256"]];
sectorManifest = formatted["sector_manifest"];
masterBasis = formatted["master_basis"];

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
  <|"sectors" -> (KeyTake[#, {"id", "propagator_count"}] & /@ sectorManifest["sectors"])|>
];
