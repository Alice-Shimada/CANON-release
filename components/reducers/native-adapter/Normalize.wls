#!/usr/bin/env wolframscript
$HistoryLength = 0;
{canonRoot, inputPath, outputDir, runtimePath} = Rest[$ScriptCommandLine];
Get[FileNameJoin[{canonRoot, "mma", "lib", "MethodCardCore.wl"}]];
Get[FileNameJoin[{DirectoryName[$InputFileName], "NativeAdapter.wl"}]];
CanonNativeAdapter`NormalizeStep[inputPath, outputDir, runtimePath];
