(* Check native solved rules once, then form the requested source-basis rules. *)
normalizeReduction[task_, input_, out_, runtime_, cfg_, data_] := Module[
  {f = data["family"], exports = runtime["exports"], native, masters = data["masters"], map,
   raw, rules, lhs, coeffs, targetRules, artifacts},
  need[data["targets"] =!= {} && masters =!= {}, "MISSING_TARGETS_OR_MASTERS", "Reduction requires explicit targets and ordered source masters."];
  need[KeyExistsQ[exports, "rules"] && KeyExistsQ[exports, "masters"], "MISSING_NATIVE_EXPORT", "Reduction requires masters and fully solved rules, not equations."];
  need[runtime["source_format"] === Lookup[<|"blade" -> "blade-rules", "fire7" -> "fire7-rules", "neatibp" -> "neatibp-solved-rules"|>, runtime["adapter"]],
    "UNSOLVED_NATIVE_EXPORT", "Declare this adapter's solved-rule format; equations and unconverted/finite-field tables are not reduced rules."];
  native = nativeMasters[read[exports["masters"]], Lookup[cfg, "masters_format", "integrals"], data["encoding"], f];
  map = basisMap[task, input, native, masters, f]; raw = read[exports["rules"]];
  need[MatchQ[raw, {___Rule}], "UNSOLVED_NATIVE_EXPORT", "Expected explicit solved Rule expressions."];
  rules = decodeExpression[raw, data["encoding"], f]; lhs = First /@ rules;
  need[AllTrue[lhs, canonicalIntegralQ[#, f] &] && DuplicateFreeQ[lhs], "INVALID_NATIVE_RULES", "Each rule needs one distinct integral on its left."];
  coeffs = linear[#, native, f] & /@ (Last /@ rules);
  Do[If[MemberQ[native, lhs[[i]]],
    need[AllTrue[coeffs[[i]] - UnitVector[Length[native], First@FirstPosition[native, lhs[[i]]]], zero],
      "NATIVE_MASTER_RELATION", "An imported rule contradicts the declared independent native master basis."]], {i, Length[lhs]}];
  need[AllTrue[data["targets"], MemberQ[lhs, #] || MemberQ[masters, #] &], "MISSING_TARGETS", "Native exports do not cover every declared target."];
  (* Exact linear combinations of checked coefficients/maps are already closed in the source basis. *)
  rules = Thread[lhs -> (Together /@ ((# . map["matrix"]) . masters & /@ coeffs))];
  targetRules = (# -> If[MemberQ[masters, #], #, # /. rules]) & /@ data["targets"];
  artifacts = write[<|"masters" -> masters, "rules" -> targetRules|>, out, "ibp-reduction.wl", "ibp_reduction"];
  <|"artifacts" -> artifacts, "summary" -> <|"target_count" -> Length[targetRules], "master_count" -> Length[masters], "basis_mapping" -> map["kind"],
    "new_reduction_executed" -> TrueQ[Lookup[Lookup[runtime, "driver_receipt", <||>], "new_reduction_executed", False]],
    "execution_evidence" -> "import mode or configured driver receipt; no independent reduction proof"|>|>
];
