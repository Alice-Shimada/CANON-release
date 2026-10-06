#!/usr/bin/env wolframscript
$HistoryLength = 0;
{canonRoot, inputPath, outputDir} = Rest[$ScriptCommandLine];
Get[FileNameJoin[{canonRoot, "mma", "lib", "MethodCardCore.wl"}]];
Get[FileNameJoin[{DirectoryName[$InputFileName], "Reconstruction.wl"}]];
CanonDLogReconstruction`RunStep[inputPath, outputDir];
