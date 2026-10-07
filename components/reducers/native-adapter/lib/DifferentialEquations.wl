(* Import a full symbolic connection, restore its frame, then use the shared sector slice. *)
normalizeDE[task_, input_, out_, runtime_, cfg_, data_] := Module[
  {f = data["family"], exports = runtime["exports"], format = runtime["source_format"],
   de, raw, variables, matrices, native, masters = data["masters"], map, conversion,
   directionOrder, manifest, current, ordered, sliced, positions, artifacts},
  need[data["point"] === {}, "POINT_ONLY_DE_EXPORT", "BUILD_CUT_DE requires a full symbolic DE, not matrices at a frozen or finite-field point."];
  need[masters =!= {} && KeyExistsQ[exports, "de"], "MISSING_NATIVE_EXPORT", "Direct DE import needs master_basis and the full DE export."];
  de = read[exports["de"]];
  If[format === "blade-de-triple" && runtime["adapter"] === "blade",
    need[ListQ[de] && Length[de] === 3, "INVALID_NATIVE_DE", "Expected {masters, variables, matrices}."];
    {raw, variables, matrices} = de,
    need[format === "exact-de-association" && AssociationQ[de] && Lookup[de, "coefficient_domain", None] === "exact-rational-functions" &&
      Lookup[de, "convention", None] === "D[basis, variables[[i]]] = matrices[[i]] . basis" && Lookup[de, "point", {}] === {},
      "INVALID_NATIVE_DE", "Supply an exact symbolic DE with its differentiation convention; no finite-field/point export."];
    {raw, variables, matrices} = Lookup[de, {"masters", "variables", "matrices"}]];
  native = nativeMasters[raw, "integrals", data["encoding"], f]; map = basisMap[task, input, native, masters, f];
  need[ListQ[variables] && DuplicateFreeQ[variables] && Sort[variables] === Sort[f["variables"]] && ListQ[matrices] && Length[matrices] === Length[variables] &&
    AllTrue[matrices, MatrixQ[#] && Dimensions[#] === {Length[native], Length[native]} &], "INCOMPLETE_NATIVE_DE", "Every source master and variable direction must be present."];
  need[AllTrue[Flatten[Normal /@ matrices], coefficientQ[#, f] &], "INVALID_COEFFICIENT_DOMAIN", "DE coefficients must be exact rational functions in declared parameters."];
  directionOrder = First@FirstPosition[variables, #] & /@ f["variables"];
  matrices = matrices[[directionOrder]] /. f["dimension_rule"];
  conversion = map["matrix"] /. f["dimension_rule"];
  matrices = CanonMethodCard`GaugeTransform[matrices, f["variables"], conversion];
  (* This remains necessary: supplied dimension rules and differentiation expressions
     can leave the declared domain or an unevaluated/singular gauge operation. *)
  need[AllTrue[Flatten[Normal /@ matrices], coefficientQ[#, f] &] && FreeQ[matrices, f["dimension"]],
    "INVALID_COEFFICIENT_DOMAIN", "Dimension substitution or basis conversion left an unsupported coefficient."];
  manifest = First[load[task, input, "sector_manifest"]];
  need[manifest["family_ref"] === f["family_ref"] && manifest["propagator_slots"] === f["propagator_slots"], "SECTOR_BINDING_MISMATCH", "Sector manifest belongs to another family/index convention."];
  current = SelectFirst[manifest["sectors"], #["id"] === task["sector", "id"] &, Missing[]];
  need[AssociationQ[current] && current["propagator_count"] === task["sector", "propagator_count"], "UNKNOWN_SECTOR", "Requested sector must match the supplied manifest."];
  ordered = <|"schema" -> "canon-neu/ordered-master-de/v1", "family_id" -> f["family_ref"], "basis_id" -> f["basis_ref"], "coefficient_domain" -> "exact-rational-functions",
    "basis" -> masters, "variables" -> f["variables"], "regulator" -> f["regulator"], "matrices" -> matrices,
    "validity" -> <|"scope" -> "exact native DE import, identity/order/domain checked; native DE derivation and flatness not independently re-proved", "flat" -> Missing["not-checked"]|>|>;
  sliced = CanonMethodCard`SectorDEArtifacts[ordered, manifest, current]; positions = sliced["resident_positions"];
  need[positions =!= {} && Length[positions] === current["master_count"], "SECTOR_BASIS_MISMATCH", "Sector master coverage disagrees with the source basis."];
  artifacts = Join[write[ordered, out, "ordered-master-de.wl", "ordered_master_de"],
    write[sliced["sector_cut_de"], out, "sector-cut-de.wl", "sector_cut_de"],
    write[sliced["sector_basis"], out, "sector-basis.wl", "sector_basis"]];
  <|"artifacts" -> artifacts, "summary" -> <|"full_master_count" -> Length[masters], "basis_size" -> Length[positions],
    "directions" -> Length[matrices], "resident_positions" -> positions, "basis_mapping" -> map["kind"]|>|>
];
