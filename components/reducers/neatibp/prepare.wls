#!/usr/bin/env wolframscript
(* Prepare native input files; this command generates neither IBP solutions nor a scientific result.json. *)
$HistoryLength = 0;
contextPath = First[Rest[$ScriptCommandLine]]; context = Import[contextPath, "RawJSON"];
Get[FileNameJoin[{context["canon"], "mma", "lib", "MethodCardCore.wl"}]];
Get[FileNameJoin[{context["normalizer"], "NativeAdapter.wl"}]];
data = CanonNativeAdapter`DriverInputs[contextPath]; If[FailureQ[data], Print[data]; Exit[2]];
f = data["family"]; cfg = data["backend"];
parse[text_] := Block[{$Context = "Global`", $ContextPath = {"System`"}}, ToExpression[text, InputForm]];
If[!And @@ (KeyExistsQ[f, #] & /@ {"propagators", "loop_momenta", "external_momenta", "scalar_products"}), Exit[3]];
records = <|"LoopMomenta" -> (parse /@ f["loop_momenta"]), "ExternalMomenta" -> (parse /@ f["external_momenta"]),
  "Propagators" -> ((parse[#["momentum"]]^2 - parse[#["mass_squared"]]) & /@ f["propagators"]),
  "Kinematics" -> ((Times @@ (parse /@ #["momenta"]) -> parse[#["value"]]) & /@ f["scalar_products"]),
  "GenericPoint" -> parse[cfg["generic_point"]], "GenericD" -> parse[cfg["generic_dimension"]]|>;
text = StringRiffle[KeyValueMap[#1 <> "=" <> ToString[#2, InputForm] <> ";" &, records], "\n"] <> "\n";
Export[FileNameJoin[{context["output"], "kinematics.txt"}], text, "Text"];
(* The neutral reader's data context is not NeatIBP's native integral head. *)
nativeTargets = data["native_targets"] /. data["encoding", "head"] -> parse[cfg["encoding", "head"]];
Put[nativeTargets, FileNameJoin[{context["output"], "targetIntegrals.txt"}]];
CopyFile[CanonMethodCard`ResolveInputPath[context["backend"], cfg["native_config"]], FileNameJoin[{context["output"], "config.txt"}]];
