#!/usr/bin/env wolframscript
$HistoryLength = 0;
Get[FileNameJoin[{DirectoryName[$InputFileName], "Example.wl"}]];
args = Rest[$ScriptCommandLine];
MakeDLogExample[args[[1]], If[Length[args] > 1, args[[2]], "exact"]];
