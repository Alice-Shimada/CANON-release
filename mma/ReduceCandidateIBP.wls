#!/usr/bin/env wolframscript

repoRoot = DirectoryName[DirectoryName[$InputFileName]];
Get[FileNameJoin[{repoRoot, "mma", "lib", "BaikovDerivative.wl"}]];
Get[FileNameJoin[{repoRoot, "mma", "lib", "CandidateIBPBridge.wl"}]];

arguments = Rest[$ScriptCommandLine];
{candidates, preparedFamily, masterBasis, preparedDerivatives} = Block[
  {$Context = "CANON`DEData`", $ContextPath = {"System`"}},
  Get /@ Take[arguments, 4]
];
request = Import[arguments[[5]], "RawJSON"];
resultPath = arguments[[6]];

compiled = CANON`CandidateIBPBridge`CompileCandidateIBPTargets[
  candidates, preparedFamily, masterBasis, preparedDerivatives
];
stage = request["output"] <> ".project";
CopyDirectory[request["project"], stage];
integralText[integral_] := SymbolName[Head[integral]] <> "[" <>
  StringRiffle[ToString[#, InputForm] & /@ (List @@ integral), ","] <> "]";
Export[
  FileNameJoin[{stage, request["targets"]}],
  StringRiffle[integralText /@ Lookup[compiled["reducer_targets"], "integral"], "\n"] <> "\n",
  "Text"
];

ibpRequest = <|
  "executable" -> request["executable"], "project" -> stage,
  "jobs" -> request["jobs"], "topology" -> request["topology"],
  "targets" -> request["targets"], "output" -> request["output"],
  "options" -> request["options"]
|>;
ibpRequestPath = resultPath <> ".ibp.json";
ibpResultPath = resultPath <> ".ibp.wl";
Export[ibpRequestPath, ibpRequest, "RawJSON"];
process = RunProcess[{
  "wolframscript", "-file", FileNameJoin[{repoRoot, "mma", "ReduceIBP.wls"}],
  ibpRequestPath, ibpResultPath
}, All, ProcessDirectory -> repoRoot];
If[process["ExitCode"] =!= 0, Print[InputForm[process]]; Exit[process["ExitCode"]]];
reduction = Block[{$Context = "CANON`DEData`", $ContextPath = {"System`"}}, Get[ibpResultPath]];
result = CANON`CandidateIBPBridge`AttachCandidateIBPReduction[compiled, reduction];
Put[result, resultPath];
Print[InputForm[<|
  "candidates" -> Length[result["candidates"]],
  "targets" -> Length[result["reducer_targets"]], "rules" -> Length[result["rules"]]
|>]];
