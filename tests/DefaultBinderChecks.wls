#!/usr/bin/env wolframscript
$HistoryLength = 0;
{canon, tree, receipt} = Rest[$ScriptCommandLine];
Get[FileNameJoin[{canon, "mma", "lib", "MethodCardCore.wl"}]];
preparedPath = FileNameJoin[{tree, "prepared outputs", "prepared-family.wl"}];
spec = CanonMethodCard`ReadWLData[FileNameJoin[{tree, "supplied data", "family-spec.wl"}]];
prepared = CanonMethodCard`ReadWLData[preparedPath];
masters = CanonMethodCard`ReadWLData[FileNameJoin[{tree, "discovered outputs", "master-basis.wl"}]];
sectors = CanonMethodCard`ReadWLData[FileNameJoin[{tree, "discovered outputs", "sector-manifest.wl"}]];
basis = CanonMethodCard`ReadWLData[FileNameJoin[{tree, "built outputs", "sector-basis.wl"}]];
cut = CanonMethodCard`ReadWLData[FileNameJoin[{tree, "built outputs", "sector-cut-de.wl"}]];
ordered = CanonMethodCard`ReadWLData[FileNameJoin[{tree, "built outputs", "ordered-master-de.wl"}]];
legacy = CanonMethodCard`ReadWLData[FileNameJoin[{tree, "legacy discovered outputs", "master-basis.wl"}]];
checks = <||>;
check[name_, condition_] := (checks[name] = TrueQ[condition]);
zero[expression_] := And @@ (TrueQ[Cancel[Together[#]] === 0] & /@ Flatten[{expression}]);
headContext[expression_] := With[{head = Head[expression]}, Context[head]];
sourceKeys = {"family_data", "prepared_derivatives", "ordered_masters"};
metadataKeys = Complement[Keys[spec], Join[{"schema"}, sourceKeys]];
sourcePaths = AssociationMap[
  ExpandFileName[FileNameJoin[{DirectoryName[preparedPath], prepared[#, "path"]}]] &,
  sourceKeys];
check["typed_preparation_preserves_every_declared_metadata_field",
  KeyTake[prepared, metadataKeys] === KeyTake[spec, metadataKeys]];
check["no_kira_configuration_required_or_emitted",
  !KeyExistsQ[spec, "kira"] && !KeyExistsQ[prepared, "kira"]];
check["distinct_topology_and_explicit_integral_head_preserved",
  prepared["topology"] === "scalar_bubble" && prepared["integral_head"] === "Q"];
check["prepared_source_references_are_relative",
  And @@ (prepared[#, "path"] ===
    FileNameJoin[{"..", "supplied data", spec[#]}] & /@ sourceKeys)];
check["all_prepared_sources_exist_after_relocation",
  And @@ (FileExistsQ /@ Values[sourcePaths])];
check["all_bound_source_hashes_match_exact_files",
  And @@ (FileHash[sourcePaths[#], "SHA256", "HexString"] === prepared[#, "sha256"] & /@ sourceKeys)];
check["discovery_consumes_the_bound_supplied_master_file",
  masters["source_sha256"] === prepared["ordered_masters", "sha256"] &&
  masters["masters"] === {CANON`DEData`Q[1,1]}];
check["discovery_explicit_head_uses_dedata_context",
  masters["topology"] === "Q" && headContext[First[masters["masters"]]] === "CANON`DEData`"];
check["legacy_discovery_retains_dedata_context",
  legacy["topology"] === "scalar_bubble" &&
  legacy["masters"] === {CANON`DEData`Q[1,1]} &&
  legacy["source_sha256"] === prepared["ordered_masters", "sha256"]];
check["discovered_sector_is_exactly_the_two_propagator_bubble",
  sectors["sectors"] === {<|"id" -> 3, "propagator_count" -> 2,
    "sector_bits" -> {1,1}, "master_count" -> 1|>} &&
  sectors["propagator_slots"] === {1,2} &&
  sectors["family_ref"] === spec["family_ref"]];
check["builder_consumes_actual_discovery_basis_and_identity",
  ordered["basis"] === masters["masters"] && cut["basis"] === masters["masters"] &&
  basis["basis"] === masters["masters"] &&
  ordered["basis_id"] === masters["basis_ref"] &&
  ordered["family_id"] === spec["family_ref"]];
check["variable_and_regulator_identity_survive_full_chain",
  ordered["variables"] === {CANON`DEData`u} && cut["variables"] === {CANON`DEData`u} &&
  ordered["regulator"] === CANON`DEData`eps && cut["regulator"] === CANON`DEData`eps];
check["ordered_connection_is_exact_analytic_minus_eps_over_u",
  Dimensions[ordered["matrices"]] === {1,1,1} && zero[ordered["matrices"] - {{{-CANON`DEData`eps/CANON`DEData`u}}}]];
check["cut_connection_is_exact_analytic_minus_eps_over_u",
  Dimensions[cut["matrices"]] === {1,1,1} && zero[cut["matrices"] - {{{-CANON`DEData`eps/CANON`DEData`u}}}]];
check["dimension_substitution_is_complete_and_exact",
  FreeQ[{ordered["matrices"], cut["matrices"]}, CANON`DEData`d | _Real] &&
  ordered["coefficient_domain"] === "exact-rational-functions"];
check["cut_sector_and_quotient_are_consistent",
  cut["sector"] === <|"id" -> 3, "propagator_count" -> 2|> &&
  cut["proper_subsectors"] === {} && cut["sector_boundaries"] === {{1,1}}];
receiptData = <|
  "checks" -> checks,
  "exact_readback" -> <|
    "ordered_matrices" -> ToString[ordered["matrices"], InputForm],
    "cut_matrices" -> ToString[cut["matrices"], InputForm],
    "expected_matrices" -> ToString[{{{-CANON`DEData`eps/CANON`DEData`u}}}, InputForm],
    "ordered_residual" -> ToString[Map[Cancel[Together[#]] &, ordered["matrices"] - {{{-CANON`DEData`eps/CANON`DEData`u}}}, {3}], InputForm],
    "cut_residual" -> ToString[Map[Cancel[Together[#]] &, cut["matrices"] - {{{-CANON`DEData`eps/CANON`DEData`u}}}, {3}], InputForm],
    "masters" -> ToString[masters["masters"], InputForm],
    "explicit_head_context" -> headContext[First[masters["masters"]]],
    "legacy_head_context" -> headContext[First[legacy["masters"]]],
    "de_validity_scope" -> ordered["validity", "scope"]|>,
  "runtime" -> <|"version" -> $Version, "system_id" -> $SystemID,
    "kernel_process_id" -> $ProcessID, "subkernel_count" -> Length[Kernels[]]|>,
  "all_pass" -> And @@ Values[checks]|>;
Export[receipt, receiptData, "RawJSON"];
Print[InputForm[checks]];
Exit[If[TrueQ[receiptData["all_pass"]], 0, 1]];
