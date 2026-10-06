#!/usr/bin/env wolframscript
$HistoryLength = 0;
{canonRoot, inputPath, outputDir} = Rest[$ScriptCommandLine];
Get[FileNameJoin[{canonRoot, "mma", "lib", "MethodCardCore.wl"}]];
Get[FileNameJoin[{DirectoryName[$InputFileName], "PointDE.wl"}]];
task = Import[inputPath, "RawJSON"];
task = CanonMethodCard`ReadTask[inputPath, task["step"]];
descriptor[name_] := task["payload", name];
load[name_] := With[{data = CanonMethodCard`LoadArtifact[task, inputPath, name]}, If[FailureQ[data], Throw[data], data]];
relativeSource[name_, declaring_] := With[{path = CanonMethodCard`ResolveInputPath[inputPath, descriptor[name]["path"]]},
  <|"path" -> CanonMethodCard`RelativeArtifactPath[declaring, path], "sha256" -> FileHash[path, "SHA256", "HexString"]|>];
save[data_, name_] := (CanonMethodCard`WriteWLArtifact[data, outputDir, name];
  <|"type" -> "mathematica-expression", "path" -> name|>);
outcome = Catch[Switch[task["step"],
  "PREPARE_POINT",
    prepared = CanonPointDE`PreparePoint[load["family_data"], load["master_basis"], load["candidates"], load["point_spec"]];
    If[FailureQ[prepared], prepared,
      prepared["sources"] = AssociationMap[relativeSource[#, FileNameJoin[{outputDir, "prepared-point.wl"}]] &,
        {"family_data", "master_basis", "candidates", "point_spec"}];
      artifacts = <|"prepared_point" -> save[prepared, "prepared-point.wl"],
        "reduction_kinematics" -> save[prepared["reduction_kinematics"], "reduction-kinematics.wl"],
        "reduction_targets" -> save[<|"schema" -> "canon-neu/reduction-targets/v1", "family_ref" -> prepared["family_id"],
          "basis_ref" -> prepared["source_basis_id"], "targets" -> prepared["targets"],
          "masters" -> prepared["masters"], "point" -> prepared["point"]|>, "targets.wl"]|>;
      text[ints_] := StringRiffle[(SymbolName[Head[#]] <> "[" <>
        StringRiffle[ToString[#, InputForm] & /@ (List @@ #), ","] <> "]") & /@ ints, "\n"] <> "\n";
      Export[FileNameJoin[{outputDir, "targets"}], text[prepared["targets"]], "Text"];
      Export[FileNameJoin[{outputDir, "preferred-masters"}], text[prepared["masters"]], "Text"];
      artifacts["targets_text"] = <|"type" -> "text", "path" -> "targets"|>;
      artifacts["preferred_masters_text"] = <|"type" -> "text", "path" -> "preferred-masters"|>;
      {"PASS", "POINT_PREPARED", artifacts, <|"targets" -> Length[prepared["targets"]], "masters" -> Length[prepared["masters"]]|>}],
  "BUILD_POINT_DE",
    prepared = load["prepared_point"];
    reductionDescriptor = descriptor["ibp_reduction"];
    reduction = CanonMethodCard`ReadWLData[CanonMethodCard`ResolveInputPath[inputPath, reductionDescriptor["path"]]];
    rules = If[AssociationQ[reduction], reduction["rules"], reduction];
    If[!ListQ[rules], Throw[Failure["INVALID_REDUCTION_RULES", <||>]]];
    symbolicRules = TrueQ[Lookup[reductionDescriptor, "symbolic", False]];
    If[symbolicRules,
      If[KeyExistsQ[reductionDescriptor, "kinematics"], Throw[Failure["AMBIGUOUS_REDUCTION_SCOPE", <||>]]];
      reductionScope = <|"kind" -> "declared-symbolic-rules-specialized-at-point", "point" -> prepared["point"]|>,
      If[!StringQ[Lookup[reductionDescriptor, "kinematics", None]],
        Throw[Failure["MISSING_REDUCTION_KINEMATICS", <||>]]];
      kinematicsPath = CanonMethodCard`ResolveInputPath[inputPath, reductionDescriptor["kinematics"]];
      kinematics = CanonMethodCard`ReadWLData[kinematicsPath];
      If[AssociationQ[kinematics] && MemberQ[{"canon-neu/parameterized-family/v1", "canon-neu/twistor-family/v1"}, Lookup[kinematics, "schema", None]],
        kinematics = <|"family_id" -> kinematics["family_ref"], "variables" -> kinematics["variables"],
          "point" -> kinematics["point_rules"]|>];
      If[!AssociationQ[kinematics] || Lookup[kinematics, "family_id", None] =!= prepared["family_id"] ||
        Lookup[kinematics, "variables", None] =!= prepared["variables"] ||
        (kinematics["variables"] /. kinematics["point"]) =!= (prepared["variables"] /. prepared["point"]),
        Throw[Failure["REDUCTION_POINT_MISMATCH", <||>]]];
      If[!FreeQ[rules, Alternatives @@ prepared["variables"]], Throw[Failure["UNSPECIALIZED_POINT_RULES", <||>]]];
      reductionScope = <|"kind" -> "declared-point-reduction", "point" -> kinematics["point"],
        "kinematics" -> <|"path" -> CanonMethodCard`RelativeArtifactPath[FileNameJoin[{outputDir, "de-sample.wl"}], kinematicsPath],
          "sha256" -> FileHash[kinematicsPath, "SHA256", "HexString"]|>|>
    ];
    integralHead = Head[First[prepared["masters"]]];
    reducerHeadName = Lookup[reductionDescriptor, "integral_head", SymbolName[integralHead]];
    rules = rules /. (s_Symbol /; SymbolName[Unevaluated[s]] === reducerHeadName) :> integralHead;
    built = CanonPointDE`BuildPointDE[prepared, rules];
    If[FailureQ[built], built,
      built["sample", "sources"] = AssociationMap[relativeSource[#, FileNameJoin[{outputDir, "de-sample.wl"}]] &,
        {"prepared_point", "ibp_reduction"}];
      built["sample", "reduction_scope"] = reductionScope;
      artifacts = <|"de_sample" -> save[built["sample"], "de-sample.wl"],
        "point_projection" -> save[built["projection"], "projection.wl"],
        "point_check" -> save[built["check"], "point-check.wl"]|>;
      {"PASS", "POINT_DE_BUILT", artifacts, KeyDrop[built["check"], "schema"]}],
  "COLLECT_DE_SAMPLES",
    collection = CanonPointDE`CollectSamples[KeyTake[task["payload"], {"training", "validation", "blind"}],
      inputPath, FileNameJoin[{outputDir, "sample-set.wl"}]];
    If[FailureQ[collection], collection,
      {"PASS", "DE_SAMPLES_COLLECTED", <|"de_sample_set" -> save[collection, "sample-set.wl"]|>,
        <|"training" -> Length[collection["training"]], "validation" -> Length[collection["validation"]],
          "scope" -> "Index only; finite samples do not establish a global DE or UT basis."|>}],
  _, Failure["UNKNOWN_STEP", <||>]
]];
If[FailureQ[outcome],
  failurePath = save[<|"failure" -> outcome|>, "failure.wl"];
  CanonMethodCard`WriteResult[task, outputDir, "FAIL", outcome[[1]], <|"diagnostic" -> failurePath|>,
    <|"reason" -> ToString[outcome[[2]], InputForm]|>]; Exit[1],
  CanonMethodCard`WriteResult[task, outputDir, Sequence @@ outcome]
];
