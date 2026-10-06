#!/usr/bin/env wolframscript
$HistoryLength = 0;
contextPath = First[Rest[$ScriptCommandLine]]; context = Import[contextPath, "RawJSON"];
Get[FileNameJoin[{context["canon"], "mma", "lib", "MethodCardCore.wl"}]];
Get[FileNameJoin[{context["normalizer"], "NativeAdapter.wl"}]];
data = CanonNativeAdapter`DriverInputs[contextPath]; If[FailureQ[data], Print[data]; Exit[2]];
If[data["encoding", "layout"] =!= "family-list", Exit[3]];
targets = data["native_targets"];
If[targets === {},
  targetPath = CanonMethodCard`ResolveInputPath[context["backend"], data["backend", "discovery_targets"]]; targets = Get[targetPath]];
Put[List @@ # & /@ targets, FileNameJoin[{context["output"], "targets.m"}]];
Put[List @@ # & /@ data["native_masters"], FileNameJoin[{context["output"], "preferred.m"}]];
