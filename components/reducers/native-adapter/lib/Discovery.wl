(* Import a native catalogue and preserve its resident master order. *)
normalizeDiscovery[task_, input_, out_, runtime_, cfg_, data_] := Module[
  {f = data["family"], exports = runtime["exports"], native, formatted, artifacts},
  need[KeyExistsQ[exports, "masters"], "MISSING_NATIVE_EXPORT", "DISCOVER requires masters."];
  native = nativeMasters[read[exports["masters"]], Lookup[cfg, "masters_format", "integrals"], data["encoding"], f];
  formatted = CanonMethodCard`FormatMasterArtifacts[
    Join[f, <|"integral_head" -> ToString[f["integral_head"], InputForm]|>], native, FileHash[exports["masters"], "SHA256", "HexString"]];
  artifacts = Join[write[formatted["master_basis"], out, "master-basis.wl", "master_basis"],
    write[formatted["sector_manifest"], out, "sector-manifest.wl", "sector_manifest"]];
  <|"artifacts" -> artifacts, "summary" -> <|"master_count" -> Length[native],
    "sectors" -> (KeyTake[#, {"id", "propagator_count"}] & /@ formatted["sector_manifest", "sectors"])|>|>
];
