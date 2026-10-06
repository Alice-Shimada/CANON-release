ClearAll[MakeNativeAdapterExample];
MakeNativeAdapterExample[directory_String, alternate_: False] := Module[
  {dir = ExpandFileName[directory], family, masters, targets, targetRules, nilpotent, matrices, vars, substitution,
   nativeOrder, encode, nativeMasters, nativeRules, nativeDE, cfg, binding, base, formats, head, nativeFamily,
   adapter, request, put, indices = {"D1", "D2", "N1"}, manifest},
  If[!DirectoryQ[dir], CreateDirectory[dir, CreateIntermediateDirectories -> True]];
  put[value_, path_] := Block[{$Context = "Global`", $ContextPath = {"System`"}}, Put[value, FileNameJoin[{dir, path}]]];
  vars = If[TrueQ[alternate], {Global`u, Global`v}, {Global`x, Global`y}];
  substitution = If[TrueQ[alternate], {Global`x -> Global`u/(1 - Global`u), Global`y -> Global`v^2}, {}];
  family = <|"schema" -> "canon-neu/reducer-family/v1", "family_ref" -> "synthetic-neutral-family", "basis_ref" -> "declared-source-basis",
    "topology" -> "unrelated-native-label", "integral_head" -> "J", "index_order" -> indices, "propagator_slots" -> {1, 2}, "top_level_sectors" -> {3},
    "loop_momenta" -> {"l"}, "external_momenta" -> {"p", "q"},
    "propagators" -> {<|"momentum" -> "l", "mass_squared" -> "0"|>, <|"momentum" -> "l-p", "mass_squared" -> "0"|>, <|"momentum" -> "l-q", "mass_squared" -> "0"|>},
    "scalar_products" -> {<|"momenta" -> {"p", "p"}, "value" -> ToString[Global`x /. substitution, InputForm]|>,
      <|"momenta" -> {"q", "q"}, "value" -> ToString[Global`y /. substitution, InputForm]|>, <|"momenta" -> {"p", "q"}, "value" -> "0"|>},
    "invariants" -> (<|"name" -> ToString[#, InputForm], "mass_dimension" -> 0|> & /@ vars), "point" -> {}, "dimension" -> "d",
    "variables" -> (ToString[#, InputForm] & /@ vars), "regulator" -> "eps", "dimension_rule" -> "d -> 4 - 2 eps",
    "family_data" -> <|"path" -> "scientific-family.wl"|>|>;
  Export[FileNameJoin[{dir, "family.json"}], family, "RawJSON"];
  put[<|"schema" -> "canon-neu/parameterized-family/v1", "family_ref" -> family["family_ref"], "variables" -> vars,
    "description" -> "synthetic adapter fixture, no native IBP or physical integral claim"|>, "scientific-family.wl"];
  masters = {Global`J[1, 0, 0], Global`J[1, 1, -1], Global`J[1, 1, 0]};
  targets = {Global`J[2, 1, 0], Global`J[1, 2, -1], Global`J[0, 0, 0], First[masters]};
  targetRules = Thread[targets -> {((Global`d - 4)/Global`x) masters[[1]] + Global`y masters[[3]],
    ((Global`x + Global`y)/(Global`x Global`y)) masters[[2]], 0, First[masters]}] /. substitution;
  put[<|"schema" -> "canon-neu/master-basis/v1", "family_ref" -> family["family_ref"], "basis_ref" -> family["basis_ref"],
    "topology" -> "J", "index_order" -> indices, "masters" -> masters|>, "masters.wl"];
  put[<|"schema" -> "canon-neu/reduction-targets/v1", "family_ref" -> family["family_ref"], "basis_ref" -> family["basis_ref"],
    "targets" -> targets, "masters" -> masters|>, "targets.wl"];
  manifest = <|"schema" -> "canon-neu/sector-manifest/v1", "family_ref" -> family["family_ref"], "propagator_slots" -> {1, 2},
    "sector_convention" -> "positive physical propagator indices; a1 is the least-significant bit; ISP bits are zero",
    "sectors" -> {<|"id" -> 1, "propagator_count" -> 1, "sector_bits" -> {1, 0, 0}, "master_count" -> 1|>,
      <|"id" -> 3, "propagator_count" -> 2, "sector_bits" -> {1, 1, 0}, "master_count" -> 2|>}|>;
  put[manifest, "sectors.wl"];
  nilpotent = {{0, 0, 0}, {1, 0, 0}, {0, 1, 0}};
  matrices = {(Global`eps IdentityMatrix[3] + nilpotent)/Global`x,
    (2 Global`eps IdentityMatrix[3] + 3 nilpotent + nilpotent . nilpotent)/Global`y};
  If[TrueQ[alternate], matrices = {(matrices[[1]] /. substitution)/(1 - Global`u)^2, 2 Global`v (matrices[[2]] /. substitution)}];
  put[<|"masters" -> masters, "rules" -> targetRules, "variables" -> vars, "matrices" -> matrices|>, "expected.wl"];
  nativeOrder = {3, 1, 2};
  binding = <|"family_ref" -> family["family_ref"], "basis_ref" -> family["basis_ref"], "index_order" -> indices,
    "coefficient_domain" -> "exact-rational-functions", "point" -> {}|>;
  request[step_, backend_] := <|"schema" -> "canon-neu/script-input/v1", "task_id" -> "synthetic-" <> backend <> "-" <> step, "step" -> step,
    "sector" -> If[step === "BUILD_CUT_DE", <|"id" -> 3, "propagator_count" -> 2|>, Null],
    "payload" -> Join[<|"backend" -> <|"path" -> backend <> "/backend.json"|>, "reducer_family" -> <|"path" -> "family.json"|>|>,
      Switch[step, "DISCOVER", <||>, "REDUCE_IBP", <|"master_basis" -> <|"path" -> "masters.wl"|>, "reduction_targets" -> <|"path" -> "targets.wl"|>|>,
        _, <|"master_basis" -> <|"path" -> "masters.wl"|>, "sector_manifest" -> <|"path" -> "sectors.wl"|>|>]]|>;
  Do[
    CreateDirectory[FileNameJoin[{dir, adapter}]];
    {head, nativeFamily} = Switch[adapter, "blade", {Blade`BL, Global`toy}, "fire7", {Global`G, 7}, _, {Global`G, None}];
    encode[q_] := If[adapter === "neatibp", head @@ (List @@ q), head[nativeFamily, List @@ q]];
    nativeMasters = encode /@ masters[[nativeOrder]];
    nativeRules = targetRules /. q_Global`J :> encode[q];
    nativeDE = {nativeMasters, Reverse[vars], Reverse[(#[[nativeOrder, nativeOrder]] & /@ matrices)]};
    put[If[adapter === "fire7", List @@ # & /@ nativeMasters, nativeMasters], adapter <> "/native-masters.wl"];
    put[nativeRules, adapter <> "/native-rules.wl"];
    put[If[adapter === "blade", nativeDE, <|"masters" -> nativeDE[[1]], "variables" -> nativeDE[[2]], "matrices" -> nativeDE[[3]],
      "coefficient_domain" -> "exact-rational-functions", "point" -> {}, "convention" -> "D[basis, variables[[i]]] = matrices[[i]] . basis"|>], adapter <> "/native-de.wl"];
    cfg = <|"schema" -> "canon-neu/native-backend/v1", "adapter" -> adapter,
      "encoding" -> Join[<|"head" -> If[adapter === "blade", "Blade`BL", "G"], "layout" -> If[adapter === "neatibp", "indices", "family-list"]|>,
        If[adapter === "neatibp", <||>, <|"family" -> If[adapter === "blade", "toy", 7]|>]],
      "binding" -> binding, "masters_format" -> If[adapter === "fire7", "family-index-pairs", "integrals"],
      "source_kind" -> "synthetic native-format fixture; no native software executed",
      "operations" -> <|"DISCOVER" -> <|"mode" -> "import", "source_format" -> "native-masters", "exports" -> <|"masters" -> "native-masters.wl"|>|>,
        "REDUCE_IBP" -> <|"mode" -> "import", "source_format" -> Switch[adapter, "blade", "blade-rules", "fire7", "fire7-rules", _, "neatibp-solved-rules"],
          "exports" -> <|"masters" -> "native-masters.wl", "rules" -> "native-rules.wl"|>|>,
        "BUILD_CUT_DE" -> <|"mode" -> "import", "source_format" -> If[adapter === "blade", "blade-de-triple", "exact-de-association"], "exports" -> <|"de" -> "native-de.wl"|>|>|>|>;
    Export[FileNameJoin[{dir, adapter, "backend.json"}], cfg, "RawJSON"];
    Do[Export[FileNameJoin[{dir, adapter <> "-" <> step <> ".json"}], request[step, adapter], "RawJSON"], {step, {"DISCOVER", "REDUCE_IBP", "BUILD_CUT_DE"}}],
    {adapter, {"blade", "fire7", "neatibp"}}];
  dir
];
