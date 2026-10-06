(* External inputs, explicit integral encoding and artifact IO. *)
stop[code_, reason_] := Throw[<|"code" -> code, "reason" -> reason|>, "native-adapter"];
need[test_, code_, reason_] := If[!TrueQ[test], stop[code, reason]];
wl[q_String] := Block[{$Context = "CANON`DEData`", $ContextPath = {"System`"}}, ToExpression[q, InputForm]];
wl[q_] := q;
read[path_] := Module[{q},
  need[FileType[path] === File, "MISSING_NATIVE_INPUT", path];
  q = Quiet @ Check[CanonMethodCard`ReadWLData[path], $Failed];
  need[q =!= $Failed, "INVALID_NATIVE_INPUT", path]; q
];
resolve[declaring_, path_] := CanonMethodCard`ResolveInputPath[declaring, path];
load[task_, input_, name_, format_: "WL"] := Module[{d, path, q},
  d = Lookup[task["payload"], name, None];
  need[AssociationQ[d] && StringQ[Lookup[d, "path", None]], "MISSING_INPUT", name];
  path = resolve[input, d["path"]];
  need[FileType[path] === File, "MISSING_INPUT", name];
  If[KeyExistsQ[d, "sha256"], need[FileHash[path, "SHA256", "HexString"] === d["sha256"], "SOURCE_HASH_MISMATCH", name]];
  q = If[format === "JSON", Import[path, "RawJSON"], read[path]];
  need[AssociationQ[q], "INVALID_INPUT", name <> " must be an Association"];
  {q, path}
];
source[declaring_, path_] := <|"path" -> CanonMethodCard`RelativeArtifactPath[declaring, path], "sha256" -> FileHash[path, "SHA256", "HexString"]|>;
jsonPoint[records_] := (
  need[ListQ[records] && AllTrue[records, AssociationQ[#] && StringQ[Lookup[#, "variable", None]] && StringQ[Lookup[#, "value", None]] &],
    "INVALID_POINT_SCOPE", "A JSON point must list variable/value WL-expression strings; use [] for symbolic scope."];
  (wl[#["variable"]] -> wl[#["value"]]) & /@ records
);

familyData[task_, input_] := Module[{f, path},
  If[KeyExistsQ[task["payload"], "reducer_family"],
    {f, path} = load[task, input, "reducer_family", "JSON"];
    need[Lookup[f, "schema", None] === "canon-neu/reducer-family/v1", "INVALID_FAMILY", "Expected neutral reducer_family JSON."],
    {f, path} = load[task, input, "prepared_family"]];
  need[And @@ (KeyExistsQ[f, #] & /@ {"family_ref", "basis_ref", "topology", "integral_head", "index_order", "propagator_slots", "variables", "regulator", "dimension", "dimension_rule"}), "INVALID_FAMILY", "Missing declared family, head, order, or coefficient metadata."];
  f = Join[f, <|"variables" -> (wl /@ f["variables"]), "regulator" -> wl[f["regulator"]], "dimension" -> wl[f["dimension"]],
    "dimension_rule" -> wl[f["dimension_rule"]], "integral_head" -> wl[f["integral_head"]],
    "sector_convention" -> Lookup[f, "sector_convention", "positive physical propagator indices; a1 is the least-significant bit; ISP bits are zero"]|>];
  need[Head[f["integral_head"]] === Symbol && Head[f["regulator"]] === Symbol && ListQ[f["index_order"]] && f["index_order"] =!= {} &&
    DuplicateFreeQ[f["variables"]] && ListQ[f["propagator_slots"]] && AllTrue[f["propagator_slots"], IntegerQ[#] && 1 <= # <= Length[f["index_order"]] &], "INVALID_FAMILY", "Invalid head, variables or propagator slots."];
  {f, path}
];
canonicalIntegralQ[q_, f_] := Head[q] === f["integral_head"] && Length[q] === Length[f["index_order"]] && AllTrue[List @@ q, IntegerQ];
encoding[cfg_] := Module[{e = Lookup[cfg, "encoding", <||>]},
  need[MemberQ[{"family-list", "indices"}, Lookup[e, "layout", None]] && StringQ[Lookup[e, "head", None]], "INVALID_ENCODING", "Declare the native head and layout explicitly."];
  e = Join[e, <|"head" -> wl[e["head"]]|>];
  need[Head[e["head"]] === Symbol, "INVALID_ENCODING", "The native head must be a symbol."];
  If[e["layout"] === "family-list", need[KeyExistsQ[e, "family"], "INVALID_ENCODING", "Declare the native family/problem identifier."]; e = Join[e, <|"family" -> wl[e["family"]]|>]];
  e
];
decode[q_, e_, f_] := Module[{indices},
  need[Head[q] === e["head"], "NATIVE_HEAD_MISMATCH", ToString[q, InputForm]];
  If[e["layout"] === "family-list",
    need[Length[q] === 2 && q[[1]] === e["family"], "NATIVE_FAMILY_MISMATCH", ToString[q, InputForm]]; indices = q[[2]],
    indices = List @@ q];
  need[ListQ[indices] && Length[indices] === Length[f["index_order"]] && AllTrue[indices, IntegerQ], "NATIVE_INDEX_MISMATCH", ToString[q, InputForm]];
  f["integral_head"] @@ indices
];
encode[q_, e_, f_] := (need[canonicalIntegralQ[q, f], "CANONICAL_HEAD_MISMATCH", ToString[q, InputForm]];
  If[e["layout"] === "family-list", e["head"][e["family"], List @@ q], e["head"] @@ (List @@ q)]);
decodeExpression[q_, e_, f_] := q /. integral_ /; Head[integral] === e["head"] :> decode[integral, e, f];

boundInputs[task_, input_, cfg_] := Module[{f, path, binding, targets = {}, masters = {}, t, tp, mb, mp, point = {}, e},
  {f, path} = familyData[task, input]; binding = Lookup[cfg, "binding", <||>]; e = encoding[cfg];
  need[AssociationQ[binding] && And @@ (Lookup[binding, #, None] === f[#] & /@ {"family_ref", "basis_ref", "index_order"}), "FAMILY_BINDING_MISMATCH", "Native export binding must match family, basis identity, and index order."];
  need[Lookup[binding, "coefficient_domain", None] === "exact-rational-functions", "UNSUPPORTED_COEFFICIENT_DOMAIN", "Only declared reconstructed exact rational-function exports are accepted; finite-field tables are not exact reductions."];
  point = jsonPoint[Lookup[binding, "point", {}]];
  If[KeyExistsQ[task["payload"], "reducer_family"],
    need[KeyExistsQ[f, "point"], "INVALID_POINT_SCOPE", "The neutral reducer_family must explicitly declare its point or [] symbolic scope."];
    need[jsonPoint[f["point"]] === point, "POINT_SCOPE_MISMATCH", "Native export binding.point differs from the actual reducer_family.point."]];
  If[KeyExistsQ[task["payload"], "reduction_targets"],
    {t, tp} = load[task, input, "reduction_targets"];
    need[MemberQ[{"canon-neu/reduction-targets/v1", "canon-neu/point-targets/v1"}, Lookup[t, "schema", None]], "INVALID_TARGETS", "Use a declared reduction-targets or point-targets artifact."];
    If[t["schema"] === "canon-neu/point-targets/v1",
      need[KeyExistsQ[task["payload"], "master_basis"], "TARGET_BINDING_MISMATCH", "Legacy point targets require an explicit master_basis identity."],
      need[Lookup[t, "family_ref", None] === f["family_ref"] && Lookup[t, "basis_ref", None] === f["basis_ref"], "TARGET_BINDING_MISMATCH", "Targets belong to another family or basis."]];
    targets = Lookup[t, "targets", {}]; masters = Lookup[t, "masters", Lookup[t, "source_basis", {}]];
    need[Lookup[t, "point", {}] === point, "POINT_SCOPE_MISMATCH", "Native export and target point scopes differ."]];
  If[KeyExistsQ[task["payload"], "master_basis"],
    {mb, mp} = load[task, input, "master_basis"];
    need[Lookup[mb, "family_ref", None] === f["family_ref"] && Lookup[mb, "basis_ref", None] === f["basis_ref"], "MASTER_BINDING_MISMATCH", "The supplied source basis has another identity."];
    If[masters =!= {}, need[masters === mb["masters"], "MASTER_ORDER_MISMATCH", "Targets and master_basis must agree in order."]]; masters = mb["masters"]];
  need[ListQ[targets] && ListQ[masters] && DuplicateFreeQ[targets] && DuplicateFreeQ[masters] &&
    AllTrue[Join[targets, masters], canonicalIntegralQ[#, f] &], "INVALID_TARGETS", "Targets and source masters must use the declared canonical head and integer index order."];
  <|"family" -> f, "family_path" -> path, "encoding" -> e, "targets" -> targets, "masters" -> masters, "point" -> point,
    "native_targets" -> (encode[#, e, f] & /@ targets), "native_masters" -> (encode[#, e, f] & /@ masters)|>
];

write[data_, out_, filename_, key_] := Module[{path = CanonMethodCard`WriteWLArtifact[data, out, filename]},
  need[StringQ[path], "OUTPUT_EXISTS_OR_UNWRITABLE", filename];
  <|key -> <|"type" -> "mathematica-expression", "path" -> filename, "sha256" -> FileHash[path, "SHA256", "HexString"]|>|>
];
