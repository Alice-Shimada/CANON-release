#!/usr/bin/env wolframscript
$HistoryLength = 0;
repoRoot = DirectoryName[DirectoryName[ExpandFileName[$InputFileName]]];
Get[FileNameJoin[{repoRoot, "mma", "lib", "MethodCardCore.wl"}]];
Get[FileNameJoin[{repoRoot, "mma", "lib", "IBPReductionAudit.wl"}]];
arguments = CanonMethodCard`ScriptArguments[];
If[Length[arguments] =!= 2, Print["usage: CheckIBPReduction.wls INPUT.json OUTPUT_DIR"]; Exit[64]];
{inputPath, outputDir} = ExpandFileName /@ arguments;
task = CanonMethodCard`ReadTask[inputPath, "CHECK_IBP"];
If[FailureQ[task], Print[InputForm[task]]; Exit[1]];
(* A producer saves the file-bound receipt beside its final reduction. After
   artifact registration/renaming, pass the separately registered receipt. *)
If[!KeyExistsQ[task["payload"], "ibp_audit"] &&
    AssociationQ[Lookup[task["payload"], "ibp_reduction", None]] &&
    StringQ[Lookup[task["payload", "ibp_reduction"], "path", None]],
  adjacentReceipt = CanonMethodCard`ResolveInputPath[inputPath,
    task["payload", "ibp_reduction", "path"]] <> ".audit.wl";
  If[FileExistsQ[adjacentReceipt],
    task["payload", "ibp_audit"] = <|"path" -> adjacentReceipt|>]
];
inputBinding[name_] := Module[{descriptor, path, digest},
  descriptor = Lookup[task["payload"], name, None];
  If[!AssociationQ[descriptor] || !StringQ[Lookup[descriptor, "path", None]], Return[$Failed]];
  path = CanonMethodCard`ResolveInputPath[inputPath, descriptor["path"]];
  digest = Quiet @ Check[FileHash[path, "SHA256", "HexString"], $Failed];
  If[!StringQ[digest] || (KeyExistsQ[descriptor, "sha256"] && descriptor["sha256"] =!= digest),
    Return[$Failed]];
  <|"path" -> path, "sha256" -> digest|>
];
inputNames = {"ibp_reduction", "ibp_contract"};
If[KeyExistsQ[task["payload"], "ibp_audit"] && task["payload", "ibp_audit"] =!= Null,
  AppendTo[inputNames, "ibp_audit"]];
inputBindings = AssociationMap[inputBinding, inputNames];
If[MemberQ[Values[inputBindings], $Failed],
  CanonMethodCard`WriteResult[task, outputDir, "ERROR", "IBP_EXECUTION_FAILED",
    <||>, <|"reason_code" -> "INVALID_IBP_AUDIT_INPUT",
      "reason" -> "missing input or declared file hash mismatch"|>]; Exit[1]];
reduction = CanonMethodCard`LoadArtifact[task, inputPath, "ibp_reduction"];
contract = CanonMethodCard`LoadArtifact[task, inputPath, "ibp_contract"];
previousAudit = If[MemberQ[inputNames, "ibp_audit"],
  CanonMethodCard`LoadArtifact[task, inputPath, "ibp_audit"], Automatic];
If[FailureQ[reduction] || FailureQ[contract] || FailureQ[previousAudit],
  CanonMethodCard`WriteResult[task, outputDir, "ERROR", "IBP_EXECUTION_FAILED",
    <||>, <|"reason_code" -> "INVALID_IBP_AUDIT_INPUT",
      "reason" -> "ibp_reduction, ibp_contract and any declared receipt must be readable WL Associations"|>]; Exit[1]];
audit = CANON`IBPReductionAudit`AuditIBPReduction[reduction, contract, previousAudit,
  inputBindings["ibp_reduction", "sha256"]];
If[AssociationMap[inputBinding, Keys[inputBindings]] =!= inputBindings,
  audit["status"] = "ERROR"; audit["code"] = "IBP_EXECUTION_FAILED";
  audit["summary"] = Join[audit["summary"], <|"reason_code" -> "IBP_AUDIT_INPUT_CHANGED"|>]];
audit["inputs"] = inputBindings;
auditPath = CanonMethodCard`WriteWLArtifact[audit, outputDir, "ibp-audit.wl"];
If[!StringQ[auditPath], Print["could not write fresh audit output"]; Exit[1]];
resultPath = CanonMethodCard`WriteResult[task, outputDir, audit["status"], audit["code"],
  <|"ibp_audit" -> <|"type" -> "mathematica-expression", "path" -> FileNameTake[auditPath]|>|>,
  Join[audit["summary"], <|"checks" -> audit["checks"], "counts" -> audit["counts"],
    "reuse" -> audit["reuse"]|>]];
If[!StringQ[resultPath], Exit[1]];
Print[InputForm[KeyTake[audit, {"status", "code", "counts"}]]];
Exit[If[audit["status"] === "PASS", 0, 1]];
