#!/usr/bin/env wolframscript

$HistoryLength = 0;
repoRoot = DirectoryName[DirectoryName[ExpandFileName[$InputFileName]]];
Get[FileNameJoin[{repoRoot, "mma", "lib", "MethodCardCore.wl"}]];
{inputPath, outputDir} = ExpandFileName /@ CanonMethodCard`ScriptArguments[];
task = CanonMethodCard`ReadTask[inputPath, "NEXT_SECTOR"];
manifest = CanonMethodCard`LoadArtifact[task, inputPath, "sector_manifest"];
accepted = If[task["payload", "accepted_prefix"] === Null, Null,
  CanonMethodCard`LoadArtifact[task, inputPath, "accepted_prefix"]];

trace = If[accepted === Null, {}, accepted["sector_trace"]];
remaining = Drop[manifest["sectors"], Length[trace]];
cursor = <|
  "schema" -> "canon-neu/sector-cursor/v1",
  "accepted_prefix_id" -> If[accepted === Null, Null, accepted["prefix_id"]],
  "sector_trace" -> trace,
  "remaining_sectors" -> remaining,
  "next_sector" -> If[remaining === {}, Null, First[remaining]],
  "complete" -> (remaining === {})|>;
path = CanonMethodCard`WriteWLArtifact[cursor, outputDir, "sector-cursor.wl"];
CanonMethodCard`WriteResult[task, outputDir, "PASS", "OK",
  <|"sector_cursor" -> <|
    "type" -> "mathematica-expression", "path" -> FileNameTake[path]|>|>,
  <|"accepted_sector_ids" -> (#1["id"] & /@ trace),
    "remaining_sector_count" -> Length[remaining],
    "next_sector" -> cursor["next_sector"], "complete" -> cursor["complete"]|>];
