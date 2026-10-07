#!/usr/bin/env wolframscript
$HistoryLength = 0;
repoRoot = DirectoryName[DirectoryName[ExpandFileName[$InputFileName]]];
Get[FileNameJoin[{repoRoot, "mma", "lib", "MethodCardCore.wl"}]];
Get[FileNameJoin[{repoRoot, "mma", "lib", "DEBuilder.wl"}]];
Get[FileNameJoin[{repoRoot, "mma", "lib", "SectorDE.wl"}]];
Get[FileNameJoin[{repoRoot, "mma", "lib", "IBPReductionAudit.wl"}]];

{inputPath, outputDir} = ExpandFileName /@ CanonMethodCard`ScriptArguments[];
task = CanonMethodCard`ReadTask[inputPath, "BUILD_CUT_DE"];
fail[result_Failure] := (
  CanonMethodCard`WriteResult[task, outputDir, "ERROR", result[[1]], <||>,
    Join[KeyDrop[result[[2]], "Message"], <|"reason" -> result[[2, "Message"]]|>]]; Exit[1]
);
failClosed[reasonCode_String, reason_String] := fail[Failure["IBP_EXECUTION_FAILED",
  <|"reason_code" -> reasonCode, "Message" -> reason|>]];

prepared = CanonMethodCard`LoadArtifact[task, inputPath, "prepared_family"];
preparedPath = CanonMethodCard`ResolveInputPath[inputPath, task["payload", "prepared_family", "path"]];
masterBasis = CanonMethodCard`LoadArtifact[task, inputPath, "master_basis"];
sectorManifest = CanonMethodCard`LoadArtifact[task, inputPath, "sector_manifest"];
currentSector = CANON`SectorDE`CurrentSectorRecord[
  <|"family_id" -> prepared["family_ref"], "basis" -> masterBasis["masters"]|>,
  sectorManifest, task["sector"]];
If[FailureQ[currentSector], fail[currentSector]];
reduction = CanonMethodCard`LoadArtifact[task, inputPath, "ibp_reduction"];
derivativePath = If[KeyExistsQ[task["payload"], "prepared_derivatives"],
  CanonMethodCard`ResolveInputPath[inputPath, task["payload", "prepared_derivatives", "path"]], Automatic];
normalized = CANON`SectorDE`LoadPreparedDerivatives[prepared, preparedPath, masterBasis, derivativePath];
If[FailureQ[normalized], fail[normalized]];
deFamily = CANON`SectorDE`DifferentialEquationFamily[prepared, normalized];
reductionPath = CanonMethodCard`ResolveInputPath[inputPath,
  task["payload", "ibp_reduction", "path"]];
(* Standalone script boundary: verify file bytes once. Callers that already
   verified an immutable artifact can pass its identity directly to the library. *)
reductionSHA256 = Quiet @ Check[FileHash[reductionPath, "SHA256", "HexString"], $Failed];
If[!StringQ[reductionSHA256] ||
    (KeyExistsQ[task["payload", "ibp_reduction"], "sha256"] &&
      task["payload", "ibp_reduction", "sha256"] =!= reductionSHA256),
  failClosed["INVALID_IBP_AUDIT_INPUT", "reduction file identity could not be verified"]];
previousIBPAudit = If[KeyExistsQ[task["payload"], "ibp_audit"] &&
    task["payload", "ibp_audit"] =!= Null,
  CanonMethodCard`LoadArtifact[task, inputPath, "ibp_audit"],
  If[!KeyExistsQ[task["payload"], "ibp_audit"] &&
      FileExistsQ[reductionPath <> ".audit.wl"],
    Quiet @ Check[CanonMethodCard`ReadWLData[reductionPath <> ".audit.wl"], Automatic], Automatic]];
If[FailureQ[previousIBPAudit],
  failClosed["INVALID_IBP_AUDIT_INPUT", "declared ibp_audit could not be loaded"]];
ibpAudit = CANON`IBPReductionAudit`AuditIBPReduction[reduction,
  CANON`IBPReductionAudit`IBPAuditContract[prepared, masterBasis,
    CANON`DEBuilder`DifferentialEquationTargets[deFamily, masterBasis["masters"]],
    Lookup[task["payload"], "ibp_audit_options", <||>]], previousIBPAudit,
  reductionSHA256];
If[ibpAudit["status"] =!= "PASS",
  CanonMethodCard`WriteResult[task, outputDir, ibpAudit["status"], ibpAudit["code"],
    <||>, Join[ibpAudit["summary"], <|"ibp_audit" -> KeyTake[ibpAudit,
      {"status", "code", "checks", "counts", "master_permutation", "reuse", "summary"}]|>]];
  Exit[1]
];
orderedMasterDE = CANON`SectorDE`BuildOrderedMasterDE[prepared, masterBasis,
  Join[reduction, <|"masters" -> masterBasis["masters"]|>], normalized];
If[FailureQ[orderedMasterDE], fail[orderedMasterDE]];
sliced = CanonMethodCard`SectorDEArtifacts[orderedMasterDE, sectorManifest, currentSector];
If[sliced["resident_positions"] === {},
  fail[Failure["INVALID_DIFFERENTIAL_EQUATION", <|"Message" -> "requested sector has no resident masters"|>]]];

basisPath = CanonMethodCard`WriteWLArtifact[sliced["sector_basis"], outputDir, "sector-basis.wl"];
cutPath = CanonMethodCard`WriteWLArtifact[sliced["sector_cut_de"], outputDir, "sector-cut-de.wl"];
orderedPath = CanonMethodCard`WriteWLArtifact[orderedMasterDE, outputDir, "ordered-master-de.wl"];
If[!AllTrue[{basisPath, cutPath, orderedPath}, StringQ],
  fail[Failure["ARTIFACT_WRITE_FAILED", <|"Message" -> "could not write complete BUILD_CUT_DE artifacts"|>]]];
CanonMethodCard`WriteResult[task, outputDir, "PASS", "OK", <|
  "sector_basis" -> <|"type" -> "mathematica-expression", "path" -> FileNameTake[basisPath]|>,
  "sector_cut_de" -> <|"type" -> "mathematica-expression", "path" -> FileNameTake[cutPath]|>,
  "ordered_master_de" -> <|"type" -> "mathematica-expression", "path" -> FileNameTake[orderedPath]|>|>,
  <|"basis_size" -> Length[sliced["sector_basis", "basis"]],
    "full_master_count" -> Length[orderedMasterDE["basis"]],
    "resident_positions" -> sliced["resident_positions"],
    "de_validity_scope" -> orderedMasterDE["validity", "scope"],
    "de_flat" -> orderedMasterDE["validity", "flat"],
    "prepared_derivative_input" -> normalized["input_form"],
    "prepared_derivative_denominator_count" -> normalized["derivatives", "denominator_count"],
    "ibp_audit" -> KeyTake[ibpAudit, {"status", "code", "checks", "counts", "master_permutation", "reuse"}]|>];
