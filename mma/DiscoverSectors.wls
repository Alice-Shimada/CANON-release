#!/usr/bin/env wolframscript

$HistoryLength = 0;

repoRoot = DirectoryName[DirectoryName[ExpandFileName[$InputFileName]]];
Get[FileNameJoin[{repoRoot, "mma", "lib", "MethodCardCore.wl"}]];

{inputPath, outputDir} = ExpandFileName /@ CanonMethodCard`ScriptArguments[];
task = CanonMethodCard`ReadTask[inputPath, "DISCOVER"];
fail[result_Failure] := (
  CanonMethodCard`WriteResult[task, outputDir, "ERROR", result[[1]], <||>,
    <|"reason" -> result[[2, "Message"]]|>]; Exit[1]
);
invalid[] := fail[Failure["INVALID_MASTER_SOURCE", <|"Message" ->
  "master text must contain unique integer-index integrals in the declared index order and a single integral head"|>]];
prepared = CanonMethodCard`LoadArtifact[task, inputPath, "prepared_family"];
If[FailureQ[prepared], fail[prepared]];
preparedPath = CanonMethodCard`ResolveInputPath[inputPath, task["payload", "prepared_family", "path"]];
masterPath = CanonMethodCard`ResolveArtifactPath[preparedPath, Lookup[prepared, "ordered_masters", None]];
If[FailureQ[masterPath], fail[masterPath]];
masterText = Quiet @ Check[Import[masterPath, "Text"], $Failed];
If[!StringQ[masterText], invalid[]];
masterLines = Select[
  (StringTrim[StringReplace[#, RegularExpression["#.*$"] -> ""]] &) /@ StringSplit[
    masterText, {"\r\n", "\n", "\r"}
  ],
  # =!= "" && !StringStartsQ[#, "#"] &
];
masters = Quiet @ Check[Block[{$Context = "CANON`DEData`", $ContextPath = {"System`"}},
  ToExpression["{" <> StringRiffle[masterLines, ","] <> "}", InputForm]
], $Failed];
indexOrder = Lookup[prepared, "index_order", None];
slots = Lookup[prepared, "propagator_slots", None];
If[!ListQ[indexOrder] || indexOrder === {} || !DuplicateFreeQ[indexOrder] ||
    !ListQ[slots] || !DuplicateFreeQ[slots] ||
    !AllTrue[slots, IntegerQ[#] && 1 <= # <= Length[indexOrder] &] ||
    !ListQ[masters] || !DuplicateFreeQ[masters] ||
    !AllTrue[masters, MatchQ[Head[#], _Symbol] && Context[Head[#]] =!= "System`" &&
      Length[#] === Length[indexOrder] && AllTrue[List @@ #, IntegerQ] &] ||
    Length[DeleteDuplicates[Head /@ masters]] > 1, invalid[]];
If[masters =!= {} && KeyExistsQ[prepared, "integral_head"],
  headMap = CanonMethodCard`ParseSymbolRules[<|prepared["integral_head"] -> prepared["integral_head"]|>];
  If[headMap === $Failed || Head[First[masters]] =!= First[First[headMap]], invalid[]]
];
formatted = CanonMethodCard`FormatMasterArtifacts[prepared, masters, FileHash[masterPath, "SHA256", "HexString"]];
sectorManifest = formatted["sector_manifest"];
masterBasis = formatted["master_basis"];

sectorPath = CanonMethodCard`WriteWLArtifact[
  sectorManifest, outputDir, "sector-manifest.wl"
];
masterPath = CanonMethodCard`WriteWLArtifact[
  masterBasis, outputDir, "master-basis.wl"
];
If[!AllTrue[{sectorPath, masterPath}, StringQ],
  fail[Failure["ARTIFACT_WRITE_FAILED", <|"Message" -> "could not write complete discovery artifacts"|>]]];
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
