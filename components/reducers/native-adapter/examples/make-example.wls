#!/usr/bin/env wolframscript
$HistoryLength = 0;
Get[FileNameJoin[{DirectoryName[$InputFileName], "Example.wl"}]];
args = Rest[$ScriptCommandLine];
MakeNativeAdapterExample[args[[1]], Length[args] > 1 && args[[2]] === "alternate"];
