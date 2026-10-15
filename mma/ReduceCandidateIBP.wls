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
If[AnyTrue[{"candidate-ibp-bridge.wl", "candidate-ibp-bridge.wl.audit.wl", "ibp-audit.wl",
    "ibp-rule-view.wl", "ibp-rule-view-input.json"},
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

(* Bind before reading, and recheck after auditing. Only the native audit may
   reuse a receipt; a changed target view gets its own file binding. *)
checkedBindings = <||>;
previousAudit = Automatic;
reductionSHA256 = None;
ruleView = None;
bindInput[base_, descriptor_] := Module[{path, digest},
  path = CanonMethodCard`ResolveArtifactPath[base,
    If[AssociationQ[descriptor], KeyDrop[descriptor, "sha256"], descriptor]];
  If[FailureQ[path], Return[path]];
  digest = Quiet @ Check[FileHash[path, "SHA256", "HexString"], $Failed];
  If[!StringQ[digest] || (KeyExistsQ[descriptor, "sha256"] &&
      (!StringQ[descriptor["sha256"]] || ToLowerCase[descriptor["sha256"]] =!= digest)),
    Return[Failure["SOURCE_HASH_MISMATCH", <|"reason" -> "Input file does not match its declared SHA-256."|>]]];
  checkedBindings[path] = digest;
  <|"path" -> path, "sha256" -> digest|>
];
readBinding[binding_, label_] := Module[{value},
  If[FailureQ[binding], Return[binding]];
  value = Quiet @ Check[CanonMethodCard`ReadWLData[binding["path"]], $Failed];
  If[AssociationQ[value], value,
    Failure["INVALID_ARTIFACT", <|"reason" -> label <> " is not an Association."|>]]
];
dataSymbolName[s_Symbol] := If[Context[s] === "CANON`DEData`", SymbolName[s],
  Context[s] <> SymbolName[s]];
loadReduction[base_, descriptor_, receipt_ : Automatic] := Module[
  {binding, receiptDescriptor = receipt, path, contract, viewContract, viewInput,
   viewPath, python, process, report, viewBinding},
  binding = bindInput[base, descriptor];
  If[FailureQ[binding], Return[binding]];
  path = binding["path"];
  reductionSHA256 = binding["sha256"];
  If[receiptDescriptor === Automatic && FileExistsQ[path <> ".audit.wl"],
    receiptDescriptor = <|"path" -> path <> ".audit.wl"|>];
  If[!MemberQ[{Automatic, Null}, receiptDescriptor],
    previousAudit = readBinding[bindInput[base, receiptDescriptor], "ibp_audit"];
    If[FailureQ[previousAudit], Return[previousAudit]]];
  contract = compiled["ibp_audit_contract"];
  (* Small files keep the cheap native path. Other formats and coefficient
     fields keep that same reader when this restricted representation declines. *)
  If[FileByteCount[path] >= 64*1024*1024 &&
      Lookup[contract["options"], "coefficient_field", "Q"] === "Q",
    viewContract = <|"source_sha256" -> reductionSHA256,
      "family_ref" -> compiled["family_ref"], "basis_ref" -> compiled["basis_ref"],
      "integral_head" -> dataSymbolName[contract["integral_head"]],
      "index_count" -> contract["index_count"],
      "coefficient_symbols" -> (dataSymbolName /@ contract["coefficient_symbols"]),
      "expected_masters" -> (List @@ # & /@ contract["expected_masters"]),
      "required_targets" -> (List @@ # & /@ contract["required_targets"])|>;
    viewInput = FileNameJoin[{outputDir, "ibp-rule-view-input.json"}];
    viewPath = FileNameJoin[{outputDir, "ibp-rule-view.wl"}];
    Export[viewInput, viewContract, "RawJSON"];
    python = Environment["CANON_PYTHON"];
    If[!StringQ[python], python = "python3"];
    process = RunProcess[{python, FileNameJoin[{repoRoot, "mma", "lib", "ibp_rule_view.py"}],
      path, viewInput, viewPath}];
    report = Quiet @ Check[ImportString[process["StandardOutput"], "RawJSON"], $Failed];
    If[process["ExitCode"] =!= 0 || !AssociationQ[report] ||
        !MemberQ[{"VIEW_EXTRACTED_UNCHECKED", "UNSUPPORTED", "INPUT_CHANGED"}, Lookup[report, "status", None]],
      Return[Failure["IBP_EXECUTION_FAILED", <|"reason" -> "Could not read the internal reduction view result."|>]]];
    If[report["status"] === "INPUT_CHANGED",
      Return[Failure["IBP_EXECUTION_FAILED", <|"reason_code" -> "IBP_AUDIT_INPUT_CHANGED",
        "reason" -> report["reason"]|>]]];
    If[report["status"] === "VIEW_EXTRACTED_UNCHECKED",
      viewBinding = bindInput[base, <|"path" -> viewPath, "sha256" -> report["output_sha256"]|>];
      If[FailureQ[viewBinding], Return[viewBinding]];
      reductionSHA256 = viewBinding["sha256"];
      ruleView = KeyTake[report, {"schema", "source", "source_sha256", "source_bytes",
        "source_rules", "output", "output_sha256", "output_bytes", "selected_rules"}];
      binding = viewBinding
    ]
  ];
  readBinding[binding, "ibp_reduction"]
];

If[KeyExistsQ[task["payload"], "ibp_reduction"],
  reduction = loadReduction[inputPath, task["payload", "ibp_reduction"],
    Lookup[task["payload"], "ibp_audit", Automatic]],
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
  reduction = loadReduction[FileNameJoin[{ibpOutput, "result.json"}],
    Lookup[ibpResult["artifacts"], "ibp_reduction", None],
    Lookup[ibpResult["artifacts"], "ibp_audit", Automatic]];
  ]
];
If[FailureQ[reduction],
  CanonMethodCard`WriteResult[task, outputDir, "ERROR", reduction[[1]], bridgeArtifacts, reduction[[2]]]; Exit[1]];
result = CANON`CandidateIBPBridge`AttachCandidateIBPReduction[
  compiled, reduction, previousAudit, reductionSHA256];
If[!AllTrue[Keys[checkedBindings],
    Quiet @ Check[FileHash[#, "SHA256", "HexString"] === checkedBindings[#], False] &],
  CanonMethodCard`WriteResult[task, outputDir, "ERROR", "IBP_EXECUTION_FAILED", bridgeArtifacts,
    <|"reason_code" -> "IBP_AUDIT_INPUT_CHANGED", "reason" -> "A bound reduction or receipt changed during use."|>]; Exit[1]];
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
If[AssociationQ[ruleView], result["reduction_view"] = ruleView];
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
  "targets" -> Length[result["reducer_targets"]], "rules" -> Length[result["rules"]],
  "ibp_audit" -> KeyTake[result["ibp_audit"], {"status", "code", "reuse", "counts"}]
|>];
