(* Refactor-only equivalence of actual loaded source versions on neutral inputs. *)
$HistoryLength = 0;
{baseline, staged, fixtures, acceptedComparison, receiptPath, outputPath} = Rest[$ScriptCommandLine];
loadVersion[root_] := Scan[Get[FileNameJoin[{root,"mma","lib",#}]] &,
  {"MethodCardCore.wl","BaikovDerivative.wl","CandidateIBPBridge.wl","SectorDE.wl"}];
loadVersion[baseline];
read[name_] := CanonMethodCard`ReadWLData[FileNameJoin[{fixtures,name}]];
prepared = read["family.wl"]; masters = read["masters.wl"]; derivatives = read["derivatives.wl"];
proposal = read["staged-propose/integral-candidates.wl"];
coordinate = First[prepared["variables"]]; regulator = prepared["regulator"];
legacy = KeyDrop[proposal,{"coefficient_frame"}];
aliasFamily = Join[prepared,<|"operator_source_symbol_map"-><|
  "Global`x"->"x","Global`eps"->"eps","Global`d"->"d"|>|>];
sameFrame = legacy;
(* Construct an evaluated same-frame payload; keep original provider evidence.
   Replacing symbols inside an existing held product can leave noncanonical order. *)
roleRules = {Global`x->coordinate,Global`eps->regulator,
 Global`d->First[prepared["parameters"]]};
sameFrame["candidates"] = Function[candidate,Join[candidate,<|
 "normalization"->Join[candidate["normalization"],<|
   "factor"->regulator^2 (1+Constant`x) coordinate^(3/2)/(1+regulator)|>],
 "exact_definition"->(candidate["exact_definition"] /. roleRules)|>]] /@ legacy["candidates"];
zero = sameFrame; zero["candidates"] = {Join[First[sameFrame["candidates"]],<|"normalization"-><|"factor"->0|>|>]};
nonlinear = sameFrame; nonlinear["candidates"] = {Join[First[sameFrame["candidates"]],<|
  "normalization"-><|"factor"->1|>,"exact_definition"->HoldComplete[CANON`DEData`G[1]^2]|>]};
noIntegral = sameFrame; noIntegral["candidates"] = {Join[First[sameFrame["candidates"]],<|
  "normalization"-><|"factor"->1|>,"exact_definition"->HoldComplete[CANON`DEData`x]|>]};
mapFamily[map_] := Join[prepared,<|"operator_source_symbol_map"->map|>];
frameProposal[delta_] := Join[proposal,<|"coefficient_frame"->Join[proposal["coefficient_frame"],delta]|>];
candidateCases = <|
  "producer-frame"->{proposal,prepared},"legacy-exact-aliases"->{legacy,aliasFamily},
  "same-frame"->{sameFrame,prepared},"zero-coefficients"->{zero,prepared},
  "nonlinear-composition"->{nonlinear,prepared},"nonintegral-composition"->{noIntegral,prepared},
  "unmapped-context"->{legacy,prepared},"nonassociation-map"->{proposal,mapFamily[{}]},
  "nonstring-map-target"->{proposal,mapFamily[<|"Global`x"->1|>]},
  "nonsymbol-map-target"->{proposal,mapFamily[<|"Global`x"->"x+1"|>]},
  "system-map-target"->{proposal,mapFamily[<|"Global`x"->"Pi"|>]},
  "undeclared-map-target"->{proposal,mapFamily[<|"Global`x"->"missing"|>]},
  "ambiguous-map-source"->{proposal,mapFamily[<|"q"->"x","CANON`DEData`q"->"eps"|>]},
  "immutable-declared-symbol"->{proposal,mapFamily[<|"x"->"eps"|>]},
  "invalid-frame-shape"->{Join[proposal,<|"coefficient_frame"->1|>],prepared},
  "repeated-frame-role"->{frameProposal[<|"variables"->{Global`eps}|>],prepared},
  "frame-name-mismatch"->{frameProposal[<|"variables"->{Global`y}|>],prepared},
  "numeric-dimension-mismatch"->{frameProposal[<|"dimension"->4|>],prepared},
  "family-mismatch"->{frameProposal[<|"family_ref"->"wrong-family"|>],prepared},
  "chart-mismatch"->{frameProposal[<|"chart_id"->"wrong-chart"|>],prepared},
  "constant-role-collision"->{frameProposal[<|"constants"->{Global`x}|>],prepared},
  "alias-error-precedes-frame-error"->{frameProposal[<|"dimension"->4|>],mapFamily[{}]}
|>;

(* Existing derivative normalization inputs exercise exact mapping of keys and values. *)
sectorDirectory = FileNameJoin[{DirectoryName[receiptPath],"sector-inputs"}];
If[!DirectoryQ[sectorDirectory],CreateDirectory[sectorDirectory]];
sourceDerivative = <|"schema"->"canon.prepared-derivatives/v2","variables"->{Source`u},
  "denominator_count"->1,"operators"-><|Source`u->{<|"constant"->Source`u,"linear"->{}|>}|>|>;
sourcePath = CanonMethodCard`WriteWLArtifact[sourceDerivative,sectorDirectory,"source-derivative.wl"];
legacyDerivative = <|"denominators"->{1},"records"->{<|"constant"->0,"linear"->{}|>}|>;
legacyPath = CanonMethodCard`WriteWLArtifact[legacyDerivative,sectorDirectory,"legacy-derivative.wl"];
multiFamily = Join[prepared,<|"variables"->{CANON`DEData`y,coordinate}|>];
orderedDerivative = <|"schema"->"canon.prepared-derivatives/v2","denominator_count"->1,
  "operators"-><|Source`v->{<|"constant"->2 Source`v,"linear"->{}|>},
    Source`u->{<|"constant"->Source`u,"linear"->{}|>}|>|>;
orderedPath = CanonMethodCard`WriteWLArtifact[orderedDerivative,sectorDirectory,"ordered-derivative.wl"];
sectorCases = <|
  "mapped-keys-and-values"->{mapFamily[<|"Source`u"->"x"|>],sourcePath},
  "qualified-keys-and-values"->{mapFamily[<|"Source`u"->"CANON`DEData`x"|>],sourcePath},
  "unmapped-foreign-operator"->{prepared,sourcePath},
  "nonassociation-map"->{mapFamily[{}],sourcePath},
  "nonstring-map-target"->{mapFamily[<|"Source`u"->1|>],sourcePath},
  "nonsymbol-map-target"->{mapFamily[<|"Source`u"->"x+1"|>],sourcePath},
  "system-symbol-policy-is-consumer-specific"->{mapFamily[<|"True"->"False"|>],legacyPath},
  "single-variable-legacy"->{prepared,legacyPath},
  "ordered-multivariable"->{Join[multiFamily,<|"operator_source_symbol_map"-><|"Source`v"->"y","Source`u"->"x"|>|>],orderedPath},
  "wrong-operator-order"->{Join[multiFamily,<|"operator_source_symbol_map"-><|"Source`v"->"x","Source`u"->"y"|>|>],orderedPath},
  "multi-variable-legacy-rejected"->{multiFamily,legacyPath},
  "family-error-precedes-map-error"->{Join[mapFamily[{}],<|"family_ref"->"wrong"|>],sourcePath}
|>;
normalizationCases = <|
  "valid-v2"->{derivatives,{coordinate},1},
  "legacy"->{legacyDerivative,{coordinate},1},
  "multivariable-legacy"->{legacyDerivative,{coordinate,CANON`DEData`y},1},
  "bad-count"->{Join[derivatives,<|"denominator_count"->2|>],{coordinate},1},
  "missing-constant"->{<|"denominators"->{1},"records"->{<|"linear"->{}|>}|>,{coordinate},1},
  "missing-linear"->{<|"denominators"->{1},"records"->{<|"constant"->0|>}|>,{coordinate},1},
  "bad-denominator-index"->{<|"denominators"->{1},"records"->{<|"constant"->0,"linear"->{<|"coefficient"->1,"denominator"->2|>}|>}|>,{coordinate},1},
  "inexact-coefficient"->{<|"denominators"->{1},"records"->{<|"constant"->0.5,"linear"->{}|>}|>,{coordinate},1}
|>;
evaluate[] := <|
  "candidates"->Map[Function[input,CANON`CandidateIBPBridge`CompileCandidateIBPTargets[
    input[[1]],input[[2]],masters,derivatives,"prepared-affine"]],candidateCases],
  "derivatives"->Map[Function[input,CANON`SectorDE`LoadPreparedDerivatives[
    input[[1]],FileNameJoin[{fixtures,"family.wl"}],masters,input[[2]]]],sectorCases],
  "normalization"->Map[CANON`SectorDE`NormalizePreparedDerivatives @@ # &,normalizationCases]|>;
before = evaluate[];
loadVersion[staged];
after = evaluate[];
checks = Association @ Flatten[KeyValueMap[Function[{group, results},
  KeyValueMap[Function[{name, result},(group<>"/"<>name)->If[group==="candidates" && name==="zero-coefficients",
  First[after[group,name]["candidates"]]["targets"]==={} &&
  ListQ[after[group,name]["reducer_targets"]] &&
  (#1["integral"] & /@ after[group,name]["reducer_targets"])===
    CANON`CandidateIBPBridge`MasterDerivativeTargets[masters["masters"],derivatives] &&
  !ListQ[result["reducer_targets"]], result===after[group,name]]],results]],before]];
expectedOperators = <|coordinate->{<|"constant"->coordinate,"linear"->{}|>}|>;
checks["explicit/mapped-key-and-scalar-identities"] = after["derivatives","mapped-keys-and-values","derivatives","operators"]===expectedOperators;
checks["explicit/source-order-preserved"] = after["derivatives","ordered-multivariable","derivatives","variables"]==={CANON`DEData`y,coordinate};
checks["explicit/system-policy-remains-at-consumer"] = !FailureQ[after["derivatives","system-symbol-policy-is-consumer-specific"]] &&
 FailureQ[after["candidates","system-map-target"]];
checks["explicit/legacy-normalization-form"] = after["derivatives","single-variable-legacy","input_form"]==="legacy-single-variable-records";
accepted = CanonMethodCard`ReadWLData[acceptedComparison];
currentBridge = read["staged-reduce/candidate-ibp-bridge.wl"];
currentGroup = First[read["staged-route/core-candidates.wl"]["candidates"]];
record = First[currentBridge["candidates"]];
checks["saved/exact-ordered-source-basis"] = currentBridge["masters"]===accepted["ordered_source_basis"];
checks["saved/exact-coefficient-binding-order"] = currentBridge["coefficient_symbol_bindings"]===accepted["exact_coefficient_bindings"];
checks["saved/raw-provenance-and-bound-derivative-fields"] = KeyTake[record,Keys[accepted["bound_record"]]]===accepted["bound_record"];
checks["saved/full-proper-subsector-rows"] = currentGroup["full_new_basis_rows"]===accepted["bound_full_rows"];
checks["saved/exact-connection"] = currentGroup["transformed_matrices"]===accepted["bound_connection"];
(* JSON is collected by the public test driver; no extra scientific interpretation. *)
known = Import[FileNameJoin[{fixtures,"known-limitations.json"}],"RawJSON"];
checks["scope/indexed-selector-error-preserved"] = known["indexed_derivative_selector","binding_pass"]===True &&
 known["indexed_derivative_selector","compile_failure_tag"]==="DERIVATIVE_OPERATOR_INVALID";
packet = <|"before"->before,"after"->after|>;
written = CanonMethodCard`WriteWLArtifact[packet,DirectoryName[outputPath],FileNameTake[outputPath]];
loadedPacket = CanonMethodCard`ReadWLData[written];
(* Diagnostic aggregates compare scalar factors mathematically. All other fields
   and the exact identities inside the two scalar factors remain structural. *)
factorSlots = Table[{Key[side],Key["candidates"],Key["same-frame"],
 Key["candidates"],1,Key["normalization"],Key["factor"]},{side,{"before","after"}}];
factorValues = {Extract[packet,#],Extract[loadedPacket,#]} & /@ factorSlots;
factorSymbols[value_] := Sort[DeleteDuplicates[Cases[HoldComplete@@{value},
 symbol_Symbol :> HoldComplete[symbol],Infinity,Heads->True]]];
serializationFacts = <|
 "fresh-writer-return-and-file"->(StringQ[written] && FileExistsQ[written]),
 "all-other-fields-exact"->(ReplacePart[packet,Thread[factorSlots->0]]===
   ReplacePart[loadedPacket,Thread[factorSlots->0]]),
 "factor-symbol-identities-exact"->And@@(factorSymbols[First[#]]===factorSymbols[Last[#]] & /@ factorValues),
 "factor-differences-exact-zero"->And@@(Together[First[#]-Last[#]]===0 & /@ factorValues)|>;
checks["serialization/exact-comparison-packet"] = And@@Values[serializationFacts];
receipt = <|"all_pass"->And@@Values[checks],"checks"->checks,
 "counts"-><|"candidate-cases"->Length[candidateCases],"sector-loader-cases"->Length[sectorCases],"normalization-cases"->Length[normalizationCases]|>,
 "serialization"->serializationFacts,
 "bounded_correction"->"zero-coefficients is an explicit corrected target-list assertion, not before/after equality.",
 "scope"->"Generic source-refactor equality, one empty-target correction and accepted output reuse; no native or actual family replay."|>;
Export[receiptPath,receipt,"RawJSON"];
Print[InputForm[<|"checks"->Length[checks],"failed"->Keys[Select[checks,!TrueQ[#]&]]|>]];
Exit[If[TrueQ[receipt["all_pass"]],0,1]];
