#!/usr/bin/env wolframscript
(* Configured native driver. Loading a source checkout alone does not validate its installed dependencies. *)
$HistoryLength = 0;
contextPath = First[Rest[$ScriptCommandLine]];
context = Import[contextPath, "RawJSON"];
Get[FileNameJoin[{context["canon"], "mma", "lib", "MethodCardCore.wl"}]];
Get[FileNameJoin[{context["normalizer"], "NativeAdapter.wl"}]];
data = CanonNativeAdapter`DriverInputs[contextPath];
If[FailureQ[data], Print[data]; Exit[2]];
cfg = data["backend"]; settingsPath = CanonMethodCard`ResolveInputPath[context["backend"], cfg["settings"]];
settings = Get[settingsPath];
entry = CanonMethodCard`ResolveInputPath[context["backend"], cfg["package_entry"]];
Get[entry];
If[!And @@ ((Names[#] =!= {}) & /@ {"Blade`BLFamilyDefine", "Blade`BLReduce", "Blade`BLDifferentialEquation"}), Exit[3]];
SetDirectory[context["output"]];
parse[text_] := Block[{$Context = "Global`", $ContextPath = {"System`"}}, ToExpression[text, InputForm]];
(* Match the native geometry's symbol frame for regulator, derivatives, points
   and integral encodings as well. Explicit foreign contexts remain explicit. *)
native[value_] := value /. (s_Symbol /; Context[s] === "CANON`DEData`" :> parse[SymbolName[s]]);
f = native[data["family"]]; nativeFamily = native[data["encoding", "family"]];
If[!And @@ (KeyExistsQ[f, #] & /@ {"propagators", "loop_momenta", "external_momenta", "scalar_products", "top_level_sectors"}) || Length[f["top_level_sectors"]] =!= 1,
  Print["This native template requires the neutral reducer_family and one declared top-level sector."]; Exit[4]];
propagators = (parse[#["momentum"]]^2 - parse[#["mass_squared"]]) & /@ f["propagators"];
scalarProducts = (Times @@ (parse /@ #["momenta"]) -> parse[#["value"]]) & /@ f["scalar_products"];
top = Reverse[IntegerDigits[First[f["top_level_sectors"]], 2, Length[propagators]]];
(* Only method/resource options remain in backend settings; scientific geometry comes from the neutral family. *)
Blade`BLNthreads = cfg["threads"];
Blade`BLSSolveNthreads = cfg["threads"];
Blade`BLFamilyDefine[nativeFamily, f["dimension"] /. f["dimension_rule"], propagators, parse /@ f["loop_momenta"],
  parse /@ f["external_momenta"], parse /@ Lookup[f, "momentum_conservation", {}], scalarProducts, top, native[data["point"]]];
preferred = native[data["native_masters"]]; targets = native[data["native_targets"]];
If[targets === {}, targets = Lookup[settings, "discovery_targets", {}]];
If[targets === {} && data["step"] =!= "BUILD_CUT_DE", Print["Supply explicit discovery or reduction targets."]; Exit[4]];
write[value_, name_] := Block[{$Context = "Global`", $ContextPath = {"System`"}}, Put[value, FileNameJoin[{context["output"], name}]]];
Switch[data["step"],
  "DISCOVER" | "REDUCE_IBP",
    reduced = Blade`BLReduce[targets, preferred, "canon_native", Sequence @@ Lookup[settings, "reduce_options", {}]];
    masterRules = Blade`BLFamilyInf[nativeFamily]["MastersRules"];
    masters = Blade`BLFamilyInf[nativeFamily]["Masters"] /. masterRules;
    write[masters, "masters.wl"];
    If[data["step"] === "REDUCE_IBP", write[Thread[targets -> (reduced /. masterRules)], "rules.wl"]],
  "BUILD_CUT_DE",
    de = Blade`BLDifferentialEquation[f["variables"], preferred, "canon_de", Sequence @@ Lookup[settings, "de_options", {}]];
    write[de, "de.wl"],
  _, Exit[5]
];
Export[FileNameJoin[{context["output"], "driver-receipt.json"}], <|"driver" -> "Blade native APIs", "declared_revision" -> cfg["software_revision"],
  "entry_sha256" -> FileHash[entry, "SHA256", "HexString"], "settings_sha256" -> FileHash[settingsPath, "SHA256", "HexString"], "threads" -> cfg["threads"],
  "new_reduction_executed" -> MemberQ[{"DISCOVER", "REDUCE_IBP", "BUILD_CUT_DE"}, data["step"]]|>, "RawJSON"];
