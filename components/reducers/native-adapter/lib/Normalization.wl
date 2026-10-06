(* Bind once, dispatch the import operation, then publish its scoped receipt. *)
normalize[task_, input_, out_, runtime_] := Module[
  {cfg, data, exports = runtime["exports"], imported, summary, receipt, receiptPath, sourcePaths, receiptArtifacts},
  cfg = Import[runtime["backend"], "RawJSON"]; data = boundInputs[task, input, cfg];
  need[AssociationQ[exports] && AllTrue[Values[exports], FileType[#] === File &], "MISSING_NATIVE_EXPORT", "Every declared native export must exist."];
  imported = Switch[task["step"],
    "DISCOVER", normalizeDiscovery[task, input, out, runtime, cfg, data],
    "REDUCE_IBP", normalizeReduction[task, input, out, runtime, cfg, data],
    "BUILD_CUT_DE", normalizeDE[task, input, out, runtime, cfg, data],
    _, stop["UNSUPPORTED_NATIVE_OPERATION", task["step"]]];
  summary = Join[<|"adapter" -> runtime["adapter"], "mode" -> runtime["mode"], "driver_executed" -> runtime["driver_executed"],
    "native_engine_validation" -> runtime["native_engine_validation"], "coefficient_domain" -> "exact-rational-functions"|>, imported["summary"]];
  receiptPath = FileNameJoin[{out, "normalization-receipt.wl"}];
  sourcePaths = Join[Association @ KeyValueMap[If[AssociationQ[#2] && StringQ[Lookup[#2, "path", None]], #1 -> resolve[input, #2["path"]], Nothing] &, task["payload"]],
    <|"backend" -> runtime["backend"], "family" -> data["family_path"]|>, exports];
  receipt = <|"schema" -> "canon-neu/native-normalization-receipt/v1", "family_ref" -> data["family", "family_ref"],
    "basis_ref" -> data["family", "basis_ref"], "step" -> task["step"], "sources" -> Map[source[receiptPath, #] &, sourcePaths],
    "summary" -> summary, "evidence_boundary" -> "Native export shape, exact coefficient domain, basis mapping and declared target coverage; no new independent IBP proof or canonical-form claim."|>;
  receiptArtifacts = write[receipt, out, "normalization-receipt.wl", "normalization_receipt"];
  CanonMethodCard`WriteResult[task, out, "PASS", Switch[task["step"], "DISCOVER", "SECTORS_READY", "REDUCE_IBP", "IBP_REDUCED", _, "OK"],
    Join[imported["artifacts"], receiptArtifacts], summary]
];

NormalizeStep[input_, out_, runtimePath_] := Module[{raw, task, runtime, result},
  raw = Import[input, "RawJSON"]; task = CanonMethodCard`ReadTask[input, raw["step"]]; runtime = Import[runtimePath, "RawJSON"];
  result = Catch[normalize[task, input, out, runtime], "native-adapter"];
  If[AssociationQ[result] && KeyExistsQ[result, "code"], CanonMethodCard`WriteResult[task, out, "ERROR", result["code"], <||>, <|"reason" -> result["reason"]|>], result]
];
DriverInputs[contextPath_] := Module[{context, task, cfg, result},
  context = Import[contextPath, "RawJSON"]; task = Import[context["request"], "RawJSON"]; cfg = Import[context["backend"], "RawJSON"];
  result = Catch[boundInputs[task, context["request"], cfg], "native-adapter"];
  If[KeyExistsQ[result, "code"], Return[Failure[result["code"], <|"Message" -> result["reason"]|>]]];
  Join[result, <|"context" -> context, "backend" -> cfg, "step" -> task["step"]|>]
];
