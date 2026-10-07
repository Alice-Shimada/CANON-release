#!/usr/bin/env wolframscript

repoRoot = DirectoryName[DirectoryName[ExpandFileName[$InputFileName]]];
Get[FileNameJoin[{repoRoot, "mma", "lib", "MethodCardCore.wl"}]];
Get[FileNameJoin[{repoRoot, "mma", "lib", "BaikovDerivative.wl"}]];
Get[FileNameJoin[{repoRoot, "mma", "lib", "CandidateIBPBridge.wl"}]];

{inputPath, outputDir} = ExpandFileName /@ CanonMethodCard`ScriptArguments[];
task = CanonMethodCard`ReadTask[inputPath, "REDUCE_CANDIDATE_IBP"];
{candidates, preparedFamily, masterBasis, preparedDerivatives} = Block[
  {$Context = "CANON`DEData`", $ContextPath = {"System`"}},
  CanonMethodCard`LoadArtifact[task, inputPath, #] & /@
    {"integral_candidates", "prepared_family", "master_basis", "prepared_derivatives"}
];
compiled = CANON`CandidateIBPBridge`CompileCandidateIBPTargets[
  candidates, preparedFamily, masterBasis, preparedDerivatives,
  Lookup[task["payload"], "derivative_operator_selection", "enhanced-first"]
];
If[FailureQ[compiled],
  CanonMethodCard`WriteResult[task, outputDir, "ERROR", compiled[[1]], <||>,
    <|"reason" -> compiled[[2, "MessageTemplate"]]|>]; Exit[1]];
targetsPath = CanonMethodCard`WriteWLArtifact[<|
  "schema" -> "canon-neu/reduction-targets/v1",
  "family_ref" -> compiled["family_ref"], "basis_ref" -> compiled["basis_ref"],
  "targets" -> Lookup[compiled["reducer_targets"], "integral"],
  "masters" -> compiled["masters"]|>, outputDir, "reduction-targets.wl"];
bridgeArtifacts = <|"reduction_targets" -> <|"type" -> "mathematica-expression",
  "path" -> FileNameTake[targetsPath]|>|>;
If[KeyExistsQ[task["payload"], "ibp_reduction"],
  reduction = CanonMethodCard`LoadArtifact[task, inputPath, "ibp_reduction"];
  If[!FailureQ[reduction],
    reduction = CANON`CandidateIBPBridge`ValidateCandidateIBPReduction[compiled, reduction]];
  If[FailureQ[reduction],
    incomplete = reduction[[1]] === "INCOMPLETE_REDUCTION";
    CanonMethodCard`WriteResult[task, outputDir, If[incomplete, "INCONCLUSIVE", "ERROR"],
      reduction[[1]], bridgeArtifacts, reduction[[2]]]; Exit[If[incomplete, 0, 1]]],
  ibpRequestPath = FileNameJoin[{outputDir, "ibp-input.json"}];
  ibpOutput = FileNameJoin[{outputDir, "ibp"}];
  rebase[descriptor_] := Join[descriptor, <|"path" -> CanonMethodCard`RelativeArtifactPath[
    ibpRequestPath, CanonMethodCard`ResolveInputPath[inputPath, descriptor["path"]]]|>];
  forwardedKeys = Select[{"backend", "prepared_family", "family_data", "reducer_family",
    "master_basis", "sector_manifest", "prepared_derivatives"}, KeyExistsQ[task["payload"], #] &];
  ibpPayload = AssociationMap[rebase[task["payload", #]] &, forwardedKeys];
  If[!KeyExistsQ[ibpPayload, "backend"],
    ibpPayload["backend"] = <|"path" -> CanonMethodCard`RelativeArtifactPath[ibpRequestPath, inputPath],
      "payload_key" -> "reduction"|>
  ];
  ibpPayload["reduction_targets"] = bridgeArtifacts["reduction_targets"];
  Export[ibpRequestPath, <|"schema" -> "canon-neu/script-input/v1",
    "task_id" -> task["task_id"] <> "/ibp", "step" -> "REDUCE_IBP",
    "sector" -> Lookup[task, "sector", Null], "payload" -> ibpPayload|>, "RawJSON"];
  python = Environment["CANON_PYTHON"];
  If[!StringQ[python], python = "python3"];
  process = RunProcess[{python, FileNameJoin[{repoRoot, "run_step.py"}],
    ibpRequestPath, ibpOutput
  }, All, ProcessDirectory -> repoRoot];
  ibpResult = Quiet @ Check[Import[FileNameJoin[{ibpOutput, "result.json"}], "RawJSON"], $Failed];
  If[!AssociationQ[ibpResult] || ibpResult["schema"] =!= "canon-neu/script-result/v1" ||
      ibpResult["step"] =!= "REDUCE_IBP" || ibpResult["task_id"] =!= task["task_id"] <> "/ibp",
    CanonMethodCard`WriteResult[task, outputDir, "ERROR", "REDUCTION_FAILED", bridgeArtifacts, process];
    Exit[1]];
  If[ibpResult["status"] =!= "PASS",
    CanonMethodCard`WriteResult[task, outputDir, ibpResult["status"], ibpResult["code"],
      bridgeArtifacts, ibpResult["summary"]]; Exit[0]];
  If[process["ExitCode"] =!= 0,
    CanonMethodCard`WriteResult[task, outputDir, "ERROR", "REDUCTION_FAILED", bridgeArtifacts, process];
    Exit[1]];
  ibpResultPath = FileNameJoin[{ibpOutput, ibpResult["artifacts", "ibp_reduction", "path"]}];
  reduction = Block[{$Context = "CANON`DEData`", $ContextPath = {"System`"}}, Get[ibpResultPath]];
];
result = CANON`CandidateIBPBridge`AttachCandidateIBPReduction[compiled, reduction];
artifactPath = CanonMethodCard`WriteWLArtifact[result, outputDir, "candidate-ibp-bridge.wl"];
bridgeArtifacts["candidate_ibp_bridge"] = <|"type" -> "mathematica-expression",
  "path" -> FileNameTake[artifactPath]|>;
CanonMethodCard`WriteResult[task, outputDir, "PASS", "CANDIDATES_REDUCED", bridgeArtifacts, <|
  "candidates" -> Length[result["candidates"]],
  "targets" -> Length[result["reducer_targets"]], "rules" -> Length[result["rules"]]
|>];
