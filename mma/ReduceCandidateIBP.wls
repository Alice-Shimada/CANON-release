#!/usr/bin/env wolframscript

repoRoot = DirectoryName[DirectoryName[ExpandFileName[$InputFileName]]];
Get[FileNameJoin[{repoRoot, "mma", "lib", "MethodCardCore.wl"}]];
Get[FileNameJoin[{repoRoot, "mma", "lib", "BaikovDerivative.wl"}]];
Get[FileNameJoin[{repoRoot, "mma", "lib", "CandidateIBPBridge.wl"}]];

{inputPath, outputDir} = ExpandFileName /@ CanonMethodCard`ScriptArguments[];
task = CanonMethodCard`ReadTask[inputPath, "REDUCE_CANDIDATE_IBP"];
If[FailureQ[task], Print[InputForm[task]]; Exit[1]];
If[FileExistsQ[FileNameJoin[{outputDir, "result.json"}]],
  Print["output paths must be fresh; publish changed reductions in a new directory"]; Exit[1]];
If[AnyTrue[{"candidate-ibp-bridge.wl", "candidate-ibp-bridge.wl.audit.wl", "ibp-audit.wl"},
    FileExistsQ[FileNameJoin[{outputDir, #}]] &],
  CanonMethodCard`WriteResult[task, outputDir, "ERROR", "ARTIFACT_WRITE_FAILED", <||>,
    <|"reason" -> "Output paths must be fresh; publish changed reductions in a new directory."|>]; Exit[1]];
{candidates, preparedFamily, masterBasis, preparedDerivatives} = Block[
  {$Context = "CANON`DEData`", $ContextPath = {"System`"}},
  CanonMethodCard`LoadArtifact[task, inputPath, #] & /@
    {"integral_candidates", "prepared_family", "master_basis", "prepared_derivatives"}
];
invalidInput = SelectFirst[{candidates, preparedFamily, masterBasis, preparedDerivatives}, FailureQ, None];
If[FailureQ[invalidInput],
  CanonMethodCard`WriteResult[task, outputDir, "ERROR", invalidInput[[1]], <||>, invalidInput[[2]]]; Exit[1]];
compiled = CANON`CandidateIBPBridge`CompileCandidateIBPTargets[
  candidates, preparedFamily, masterBasis, preparedDerivatives,
  Lookup[task["payload"], "derivative_operator_selection", "enhanced-first"],
  Lookup[task["payload"], "ibp_audit_options", <||>]
];
If[FailureQ[compiled],
  CanonMethodCard`WriteResult[task, outputDir, "ERROR", compiled[[1]], <||>,
    Join[KeyDrop[compiled[[2]], "MessageTemplate"],
      <|"reason" -> compiled[[2, "MessageTemplate"]]|>]]; Exit[1]];
targetsPath = CanonMethodCard`WriteWLArtifact[<|
  "schema" -> "canon-neu/reduction-targets/v1",
  "family_ref" -> compiled["family_ref"], "basis_ref" -> compiled["basis_ref"],
  "targets" -> (#1["integral"] & /@ compiled["reducer_targets"]),
  "masters" -> compiled["masters"]|>, outputDir, "reduction-targets.wl"];
If[!StringQ[targetsPath],
  CanonMethodCard`WriteResult[task, outputDir, "ERROR", "ARTIFACT_WRITE_FAILED", <||>,
    <|"reason" -> "Could not write the current reduction targets."|>]; Exit[1]];
bridgeArtifacts = <|"reduction_targets" -> <|"type" -> "mathematica-expression",
  "path" -> FileNameTake[targetsPath]|>|>;
If[KeyExistsQ[task["payload"], "ibp_reduction"],
  reduction = CanonMethodCard`LoadArtifact[task, inputPath, "ibp_reduction"],
  If[compiled["reducer_targets"] === {},
    reduction = <|"masters" -> compiled["masters"], "rules" -> {}|>,
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
      bridgeArtifacts, ibpResult["summary"]];
    Exit[If[MemberQ[{"ERROR", "FAIL"}, ibpResult["status"]], 1, 0]]];
  If[process["ExitCode"] =!= 0,
    CanonMethodCard`WriteResult[task, outputDir, "ERROR", "REDUCTION_FAILED", bridgeArtifacts, process];
    Exit[1]];
  reduction = CanonMethodCard`LoadArtifact[
    <|"payload" -> Lookup[ibpResult, "artifacts", <||>]|>,
    FileNameJoin[{ibpOutput, "result.json"}], "ibp_reduction"];
  ]
];
If[FailureQ[reduction],
  CanonMethodCard`WriteResult[task, outputDir, "ERROR", reduction[[1]], bridgeArtifacts, reduction[[2]]]; Exit[1]];
result = CANON`CandidateIBPBridge`AttachCandidateIBPReduction[compiled, reduction];
If[FailureQ[result],
  If[!KeyExistsQ[result[[2]], "audit"],
    CanonMethodCard`WriteResult[task, outputDir,
      If[result[[1]] === "IBP_CHECK_FAILED", "FAIL", "ERROR"],
      result[[1]], bridgeArtifacts, result[[2]]]; Exit[1]];
  audit = result[[2, "audit"]];
  auditPath = CanonMethodCard`WriteWLArtifact[audit, outputDir, "ibp-audit.wl"];
  bridgeArtifacts["ibp_audit"] = <|"type" -> "mathematica-expression", "path" -> FileNameTake[auditPath]|>;
  CanonMethodCard`WriteResult[task, outputDir, audit["status"], audit["code"], bridgeArtifacts,
    Join[audit["summary"], <|"ibp_audit" -> KeyTake[audit,
      {"status", "code", "checks", "counts", "reuse", "summary"}]|>]]; Exit[1]];
artifactPath = CanonMethodCard`WriteWLArtifact[result, outputDir, "candidate-ibp-bridge.wl"];
If[!StringQ[artifactPath],
  CanonMethodCard`WriteResult[task, outputDir, "ERROR", "ARTIFACT_WRITE_FAILED", bridgeArtifacts,
    <|"reason" -> "Could not write the candidate reduction bridge."|>]; Exit[1]];
resultSHA256 = Quiet @ Check[FileHash[artifactPath, "SHA256", "HexString"], $Failed];
If[!StringQ[resultSHA256], Print["could not identify final bridge"]; Exit[1]];
fileBoundAudit = result["ibp_audit"];
fileBoundAudit["binding", "reduction_sha256"] = resultSHA256;
auditPath = CanonMethodCard`WriteWLArtifact[fileBoundAudit, outputDir, "candidate-ibp-bridge.wl.audit.wl"];
If[!StringQ[auditPath], Print["could not publish file-bound audit receipt"]; Exit[1]];
bridgeArtifacts["ibp_audit"] = <|"type" -> "mathematica-expression", "path" -> FileNameTake[auditPath]|>;
bridgeArtifacts["candidate_ibp_bridge"] = <|"type" -> "mathematica-expression",
  "path" -> FileNameTake[artifactPath]|>;
CanonMethodCard`WriteResult[task, outputDir, "PASS", "CANDIDATES_REDUCED", bridgeArtifacts, <|
  "candidates" -> Length[result["candidates"]],
  "targets" -> Length[result["reducer_targets"]], "rules" -> Length[result["rules"]]
|>];
