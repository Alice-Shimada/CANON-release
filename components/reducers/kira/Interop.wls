#!/usr/bin/env wolframscript
$HistoryLength = 0;
{canon, action, input, output} = Rest[$ScriptCommandLine];
Get[FileNameJoin[{canon, "mma", "lib", "MethodCardCore.wl"}]];
raw = Import[input, "RawJSON"];
task = CanonMethodCard`ReadTask[input, raw["step"]];
familyPath = CanonMethodCard`ResolveInputPath[input, task["payload", "reducer_family", "path"]];
family = Import[familyPath, "RawJSON"];
interop = Import[FileNameJoin[{output, "interop.json"}], "RawJSON"];
nativeHead = family["topology"]; scientificName = family["integral_head"];
indexCount = Length[family["index_order"]];
need[condition_, code_, details_: <||>] := If[!TrueQ[condition], Throw[<|"code" -> code, "details" -> details|>]];
parse[s_String] := Block[{$Context = "CANON`DEData`", $ContextPath = {"System`"}}, ToExpression[s, InputForm]];
scientificHead = parse[scientificName];
scientificSymbolName = SymbolName[scientificHead];
integralQ[g_] := Head[Head[g]] === Symbol && SymbolName[Head[g]] === scientificSymbolName &&
  Length[g] === indexCount && AllTrue[List @@ g, IntegerQ];
load[key_] := With[{value = CanonMethodCard`LoadArtifact[task, input, key]},
  need[AssociationQ[value], "INVALID_REDUCTION_INPUT", <|"artifact" -> key|>]; value];
point = (parse[#["variable"]] -> parse[#["value"]]) & /@ family["point"];
kinematics = <|"schema" -> "canon-neu/reduction-kinematics/v1", "family_id" -> family["family_ref"],
  "variables" -> (parse /@ family["variables"]), "point" -> point|>;
save[value_, name_] := With[{path = CanonMethodCard`WriteWLArtifact[value, output, name]},
  <|"type" -> "mathematica-expression", "path" -> name, "sha256" -> FileHash[path, "SHA256", "HexString"]|>];
outcome = Catch[
If[action === "prepare",
  targetsData = load["reduction_targets"];
  need[MemberQ[{"canon-neu/reduction-targets/v1", "canon-neu/point-targets/v1"}, targetsData["schema"]], "INVALID_REDUCTION_TARGETS"];
  If[targetsData["schema"] === "canon-neu/reduction-targets/v1",
    need[targetsData["family_ref"] === family["family_ref"] && targetsData["basis_ref"] === family["basis_ref"], "TARGET_IDENTITY_MISMATCH"]];
  targets = targetsData["targets"]; masters = targetsData["masters"];
  need[ListQ[targets] && ListQ[masters] && masters =!= {} && AllTrue[Join[targets, masters], integralQ], "INTEGRAL_ENCODING_MISMATCH"];
  need[DuplicateFreeQ[masters], "DUPLICATE_SOURCE_MASTERS"];
  head = Head[First[masters]];
  canonical[g_] := head @@ (List @@ g);
  targets = canonical /@ targets; masters = canonical /@ masters;
  If[KeyExistsQ[task["payload"], "master_basis"],
    basis = load["master_basis"];
    need[basis["family_ref"] === family["family_ref"] && basis["basis_ref"] === family["basis_ref"], "SOURCE_BASIS_IDENTITY_MISMATCH"];
    need[AllTrue[basis["masters"], integralQ] && (canonical /@ basis["masters"]) === masters, "SOURCE_BASIS_ORDER_MISMATCH"];
    head = Head[First[basis["masters"]]];
    targets = canonical /@ targets; masters = basis["masters"]
  ];
  targetPoint = Lookup[targetsData, "point", {}];
  need[ListQ[targetPoint] && Length[targetPoint] === Length[point] &&
    Sort[First /@ targetPoint] === Sort[First /@ point] &&
    And @@ (Together[(First[#] /. targetPoint) - Last[#]] === 0 & /@ point), "REDUCTION_POINT_MISMATCH"];
  native[g_] := nativeHead <> "[" <> StringRiffle[ToString /@ (List @@ g), ","] <> "]";
  Export[FileNameJoin[{output, "kira", "targets"}], StringRiffle[native /@ DeleteDuplicates[Join[targets, masters]], "\n"] <> "\n", "Text"];
  Export[FileNameJoin[{output, "kira", "preferred-masters"}], StringRiffle[native /@ masters, "\n"] <> "\n", "Text"];
  save[<|"targets" -> targets, "masters" -> masters, "point" -> point|>, "request-data.wl"];
  save[kinematics, "reduction-kinematics.wl"];
  Export[FileNameJoin[{output, "target-summary.json"}], <|"targets" -> Length[targets], "masters" -> Length[masters]|>, "RawJSON"];
  <|"prepared" -> True|>,

  mastersPath = FileNameJoin[{output, interop["native_masters"]}];
  lines = Select[StringTrim[StringReplace[#, RegularExpression["#.*$"] -> ""]] & /@
    StringSplit[Import[mastersPath, "Text"], {"\r\n", "\n", "\r"}], # =!= "" &];
  marker = "CANONKiraImport`Integral";
  decode[text_] := parse[StringReplace[text, RegularExpression["(?<![A-Za-z0-9_])" <> nativeHead <> "\\["] -> marker <> "["]];
  importedMasters = decode["{" <> StringRiffle[lines, ","] <> "}"];
  need[ListQ[importedMasters] && importedMasters =!= {} && DuplicateFreeQ[importedMasters] &&
    AllTrue[importedMasters, Head[#] === CANONKiraImport`Integral && Length[#] === indexCount && AllTrue[List @@ #, IntegerQ] &], "INVALID_NATIVE_MASTERS"];
  If[task["step"] === "DISCOVER",
    head = scientificHead;
    masters = importedMasters /. CANONKiraImport`Integral -> head;
    prepared = Join[KeyTake[family, {"family_ref", "basis_ref", "topology", "integral_head", "index_order", "propagator_slots"}],
      <|"sector_convention" -> "positive physical propagator indices; a1 is the least-significant bit; ISP bits are zero"|>];
    formatted = CanonMethodCard`FormatMasterArtifacts[prepared, masters, FileHash[mastersPath, "SHA256", "HexString"]];
    need[AssociationQ[formatted], "MASTER_FORMATTER_UNAVAILABLE"];
    artifacts = <|"master_basis" -> save[formatted["master_basis"], "master-basis.wl"],
      "sector_manifest" -> save[formatted["sector_manifest"], "sector-manifest.wl"],
      "reduction_kinematics" -> save[kinematics, "reduction-kinematics.wl"]|>;
    <|"status" -> "PASS", "code" -> "SECTORS_READY", "artifacts" -> artifacts,
      "summary" -> <|"master_discovery_complete" -> True, "native_stage" -> "master initiation",
        "sectors" -> (KeyTake[#, {"id", "propagator_count"}] & /@ formatted["sector_manifest", "sectors"]), "masters" -> Length[masters]|>|>,

    data = CanonMethodCard`ReadWLData[FileNameJoin[{output, "request-data.wl"}]];
    targets = data["targets"]; masters = data["masters"]; head = Head[First[masters]];
    importedMasters = importedMasters /. CANONKiraImport`Integral -> head;
    need[SubsetQ[masters, importedMasters], "NATIVE_BASIS_MISMATCH",
      <|"expected" -> masters, "native" -> importedMasters|>];
    rulesPath = FileNameJoin[{output, interop["native_rules"]}];
    rules = decode[Import[rulesPath, "Text"]] /. CANONKiraImport`Integral -> head;
    need[ListQ[rules] && AllTrue[rules, MatchQ[#, _Rule] &], "INVALID_NATIVE_RULES"];
    need[AllTrue[First /@ rules, integralQ] && DuplicateFreeQ[First /@ rules], "INVALID_NATIVE_RULE_TARGETS"];
    (* Kira's dimension symbol is d; map it to the declared scientific dimension. *)
    rules = rules /. CANON`DEData`d -> parse[family["dimension"]];
    reduced = targets /. rules;
    remaining = Complement[DeleteDuplicates @ Cases[reduced, g_ /; Head[g] === head, Infinity], importedMasters];
    need[remaining === {}, "UNREDUCED_NATIVE_OUTPUT", <|"unreduced" -> remaining|>];
    sourceImages = masters /. rules;
    need[And @@ MapThread[Together[#1 - #2] === 0 &, {sourceImages, masters}], "SOURCE_BASIS_CHANGED"];
    zz = Array[Unique["source$"] &, Length[masters]];
    polynomials = reduced /. Thread[masters -> zz];
    need[And @@ (PolynomialQ[#, zz] && Together[# - Sum[Coefficient[#, zz[[j]]] zz[[j]], {j, Length[zz]}]] === 0 & /@ polynomials), "NATIVE_RULES_NOT_LINEAR"];
    coefficients = Flatten[Table[Coefficient[p, z], {p, polynomials}, {z, zz}]];
    allowed = DeleteDuplicates @ Cases[
      Join[parse /@ (#["name"] & /@ family["invariants"]), {parse[family["dimension"]]}],
      s_Symbol /; Context[s] =!= "System`", Infinity, Heads -> True];
    symbols = DeleteDuplicates @ Cases[coefficients, s_Symbol /; Context[s] =!= "System`", Infinity, Heads -> True];
    need[Complement[symbols, allowed] === {}, "UNDECLARED_NATIVE_COEFFICIENT", <|"symbols" -> Complement[symbols, allowed]|>];
    (* Keep the checked linear sum: a common denominator across independent
       master coefficients can cause unnecessary expression growth. *)
    finalRules = Thread[targets -> reduced];
    artifacts = <|"ibp_reduction" -> save[<|"masters" -> masters, "rules" -> finalRules|>, "ibp-reduction.wl"],
      "reduction_kinematics" -> <|"type" -> "mathematica-expression", "path" -> "reduction-kinematics.wl",
        "sha256" -> FileHash[FileNameJoin[{output, "reduction-kinematics.wl"}], "SHA256", "HexString"]|>|>;
    <|"status" -> "PASS", "code" -> "IBP_REDUCED", "artifacts" -> artifacts,
      "summary" -> <|"reduction_complete" -> True, "targets" -> Length[targets], "masters" -> Length[masters],
        "native_master_count" -> Length[importedMasters],
        "source_master_order_preserved" -> True, "complete_target_coverage" -> True,
        "point_binding" -> "matched neutral family and declared targets", "scope" -> "supplied target list and requested source basis"|>|>
  ]
]
];
If[KeyExistsQ[outcome, "prepared"], Exit[0]];
If[!KeyExistsQ[outcome, "status"],
  resultCheckFailed = action === "import" && task["step"] === "REDUCE_IBP";
  status = If[resultCheckFailed, "FAIL", "ERROR"];
  code = If[resultCheckFailed, "IBP_CHECK_FAILED", outcome["code"]];
  CanonMethodCard`WriteResult[task, output, status, code, <||>,
    <|"reason_code" -> outcome["code"], "diagnostic" -> ToString[outcome["details"], InputForm],
      "reduction_complete" -> False, "master_discovery_complete" -> False|>]; Exit[2]
];
CanonMethodCard`WriteResult[task, output, outcome["status"], outcome["code"], outcome["artifacts"], outcome["summary"]];
