#!/usr/bin/env wolframscript
$HistoryLength = 0;
{package, work} = Rest[$ScriptCommandLine];
Get[FileNameJoin[{package, "examples", "Example.wl"}]];
MakeNativeAdapterExample[FileNameJoin[{work, "base"}]];
MakeNativeAdapterExample[FileNameJoin[{work, "alternate"}], True];
cases = {"missing-target", "unresolved", "wrong-family", "wrong-head", "wrong-order", "equations", "finite-field", "inexact",
  "de-incomplete", "de-variable", "de-point", "de-finite-field", "binding", "conversion", "unsupported", "backend-mismatch", "driver", "legacy-point", "master-relation", "dimension-rule"};
Do[CopyDirectory[FileNameJoin[{work, "base"}], FileNameJoin[{work, name}]], {name, cases}];
update[name_, file_, fn_] := Module[{path = FileNameJoin[{work, name, file}], q},
  q = Get[path]; Block[{$Context = "Global`", $ContextPath = {"System`"}}, Put[fn[q], path]]];
jsonUpdate[name_, file_, fn_] := Module[{path = FileNameJoin[{work, name, file}]}, Export[path, fn[Import[path, "RawJSON"]], "RawJSON"]];
update["missing-target", "fire7/native-rules.wl", Rest];
update["unresolved", "fire7/native-rules.wl", Function[r, ReplacePart[r, {1, 2} -> G[7, {9, 9, 0}]]]];
update["wrong-family", "fire7/native-masters.wl", Function[m, ReplacePart[m, {1, 1} -> 8]]];
update["wrong-head", "targets.wl", Function[t, Join[t, <|"targets" -> (t["targets"] /. J -> Other)|>]]];
update["wrong-order", "masters.wl", Function[m, Join[m, <|"masters" -> Reverse[m["masters"]]|>]]];
update["equations", "neatibp/native-rules.wl", Function[r, r /. Rule -> Equal]];
jsonUpdate["finite-field", "fire7/backend.json", Function[c, Join[c, <|"binding" -> Join[c["binding"], <|"coefficient_domain" -> "finite-field"|>]|>]]];
update["inexact", "fire7/native-rules.wl", Function[r, ReplacePart[r, {1, 2} -> (r[[1, 2]] + 0.1 G[7, {1, 0, 0}])]]];
update["master-relation", "fire7/native-rules.wl", Function[r, ReplacePart[r, {4, 2} -> G[7, {1, 0, 0}]/2]]];
update["dimension-rule", "blade/native-de.wl", Function[deValue, deValue /. eps -> (4 - d)/2]];
update["de-incomplete", "blade/native-de.wl", Function[d, ReplacePart[d, 3 -> Take[d[[3]], 1]]]];
update["de-variable", "blade/native-de.wl", Function[d, ReplacePart[d, 2 -> {x, x}]]];
jsonUpdate["de-point", "blade/backend.json", Function[c, Join[c, <|"binding" -> Join[c["binding"], <|"point" -> {<|"variable" -> "x", "value" -> "2"|>}|>]|>]]];
jsonUpdate["de-point", "family.json", Function[f, Join[f, <|"point" -> {<|"variable" -> "x", "value" -> "2"|>}|>]]];
update["de-finite-field", "fire7/native-de.wl", Function[d, Join[d, <|"coefficient_domain" -> "finite-field"|>]]];
jsonUpdate["binding", "fire7/backend.json", Function[c, Join[c, <|"binding" -> Join[c["binding"], <|"family_ref" -> "unrelated-family"|>]|>]]];
jsonUpdate["unsupported", "fire7/backend.json", Function[c, Join[c, <|"operations" -> KeyDrop[c["operations"], "REDUCE_IBP"]|>]]];
jsonUpdate["backend-mismatch", "fire7/backend.json", Function[c, Join[c, <|"adapter" -> "blade"|>]]];
update["legacy-point", "targets.wl", Function[t, <|"schema" -> "canon-neu/point-targets/v1", "targets" -> t["targets"], "masters" -> t["masters"], "point" -> {}|>]];

(* A real, variable-dependent supplied basis conversion, checked by exact readback. *)
expected = Get[FileNameJoin[{work, "base", "expected.wl"}]];
masters = expected["masters"]; native = {J[1, 1, 0], J[1, 0, 0], J[1, 2, 0]};
c = {{0, 0, 1}, {1, 0, 0}, {0, x, 0}};
encode[q_] := Blade`BL[toy, List @@ q];
targetData = Get[FileNameJoin[{work, "base", "targets.wl"}]];
conversionRules = Table[encode[t] -> ((Together[(t /. expected["rules"]) /. Thread[masters -> Inverse[c] . native]]) /. q_J :> encode[q]), {t, targetData["targets"]}];
nativeDE = Table[Together /@ ((D[c, expected["variables"][[k]]] + c . expected["matrices"][[k]]) . Inverse[c]), {k, 2}];
Block[{$Context = "Global`", $ContextPath = {"System`"}},
  Put[encode /@ native, FileNameJoin[{work, "conversion", "blade", "native-masters.wl"}]];
  Put[conversionRules, FileNameJoin[{work, "conversion", "blade", "native-rules.wl"}]];
  Put[{encode /@ native, Reverse[expected["variables"]], Reverse[nativeDE]}, FileNameJoin[{work, "conversion", "blade", "native-de.wl"}]];
  Put[<|"schema" -> "canon-neu/master-basis-conversion/v1", "family_ref" -> "synthetic-neutral-family", "basis_ref" -> "declared-source-basis",
    "native_masters" -> native, "masters" -> masters, "matrix" -> c, "convention" -> "native_masters = matrix . masters"|>, FileNameJoin[{work, "conversion", "conversion.wl"}]]
];
CopyDirectory[FileNameJoin[{work, "conversion"}], FileNameJoin[{work, "no-conversion"}]];
Do[jsonUpdate["conversion", "blade-" <> step <> ".json", Function[r, Join[r, <|"payload" -> Join[r["payload"], <|"basis_conversion" -> <|"path" -> "conversion.wl"|>|>]|>]]],
  {step, {"REDUCE_IBP", "BUILD_CUT_DE"}}];
Export[FileNameJoin[{work, "runtime.json"}], <|"wolfram_version" -> $Version, "system_id" -> $SystemID, "native_engine_executed" -> False|>, "RawJSON"];
