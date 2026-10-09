#!/usr/bin/env wolframscript
$HistoryLength = 0;
{canonRoot, inputPath, outputDir} = Rest[$ScriptCommandLine];
Get[FileNameJoin[{canonRoot, "mma", "lib", "MethodCardCore.wl"}]];
Get[FileNameJoin[{canonRoot, "mma", "lib", "PhysicalDerivative.wl"}]];
Get[FileNameJoin[{DirectoryName[$InputFileName], "Parameterization.wl"}]];
task = CanonMethodCard`ReadTask[inputPath, "PREPARE"];
spec = CanonMethodCard`LoadArtifact[task, inputPath, "family_spec"];
specPath = CanonMethodCard`ResolveInputPath[inputPath, task["payload", "family_spec", "path"]];
familyPath = FileNameJoin[{outputDir, "family-data.wl"}];
reducerPath = FileNameJoin[{outputDir, "reducer-family.json"}];
preparedPath = FileNameJoin[{outputDir, "prepared-family.wl"}];
fail[value_] := (CanonMethodCard`WriteResult[task, outputDir, "FAIL", value[[1]], <||>,
  <|"reason" -> ToString[value[[2]], InputForm]|>]; Exit[1]);
save[data_, name_] := Module[{path = CanonMethodCard`WriteWLArtifact[data, outputDir, name]},
  If[!StringQ[path], fail[Failure["ARTIFACT_WRITE_FAILED", <|"path" -> name|>]]]; path];
reference[from_, path_, type_] := (If[!FileExistsQ[path], fail[Failure["MISSING_SOURCE_ARTIFACT", <|"path" -> path|>]]];
  <|"type" -> type, "path" -> CanonMethodCard`RelativeArtifactPath[from, path],
    "sha256" -> FileHash[path, "SHA256", "HexString"]|>);
result = If[FailureQ[spec], spec, Block[
  {$Context = "CANON`DEData`", $ContextPath = {"System`"}},
  CanonParameterization`ParameterizeFamily[spec]]];
If[FailureQ[result], fail[result]];
If[KeyExistsQ[spec, "prepared_derivatives"], fail[Failure["DERIVATIVES_GENERATED_FROM_FAMILY",
  <|"reason" -> "Remove prepared_derivatives from this new-family spec; PREPARE generates physical derivatives. Reuse historical artifacts through their consumer bindings."|>]]];
family = result["family"];
derivatives = CANON`PhysicalDerivative`PreparePhysicalDerivatives[family];
If[FailureQ[derivatives], fail[derivatives]];
derivativePath = save[derivatives, "prepared-derivatives.wl"];
family["sources"] = <|"family_spec" -> reference[familyPath, specPath, "mathematica-expression"]|>;
save[family, "family-data.wl"];
reducer = Join[result["reducer"], <|"family_data" -> reference[reducerPath, familyPath, "mathematica-expression"]|>];
If[Export[reducerPath, reducer, "RawJSON"] === $Failed,
  fail[Failure["REDUCER_FAMILY_EXPORT_FAILED", <|"path" -> reducerPath|>]]];
prepared = Join[KeyTake[family, {"family_ref", "basis_ref", "chart_id", "topology", "integral_head", "parameters", "variables", "dimension",
    "regulator", "dimension_rule", "index_order", "propagator_slots", "top_level_sectors", "sector_convention"}],
  <|"schema" -> "canon-neu/prepared-family/v1", "family_data" -> reference[preparedPath, familyPath, "mathematica-expression"],
    "reducer_family" -> reference[preparedPath, reducerPath, "json"],
    "prepared_derivatives" -> reference[preparedPath, derivativePath, "mathematica-expression"],
    "available_inputs" -> <|"prepared_derivatives" -> True, "ordered_masters" -> KeyExistsQ[spec, "ordered_masters"]|>|>];
If[KeyExistsQ[spec, "operator_source_symbol_map"], prepared["operator_source_symbol_map"] = spec["operator_source_symbol_map"]];
Do[If[KeyExistsQ[spec, name],
  raw = If[StringQ[spec[name]], <|"path" -> spec[name]|>, spec[name]];
  sourcePath = CanonMethodCard`ResolveArtifactPath[specPath, raw];
  If[FailureQ[sourcePath], fail[sourcePath]];
  prepared[name] = reference[preparedPath, sourcePath,
    If[name === "ordered_masters", "text", "mathematica-expression"]]
], {name, {"ordered_masters"}}];
save[prepared, "prepared-family.wl"];
CanonMethodCard`WriteResult[task, outputDir, "PASS", "PARAMETERIZATION_READY", <|
  "family_data" -> <|"type" -> "mathematica-expression", "path" -> "family-data.wl"|>,
  "reducer_family" -> <|"type" -> "json", "path" -> "reducer-family.json"|>,
  "prepared_derivatives" -> <|"type" -> "mathematica-expression", "path" -> "prepared-derivatives.wl"|>,
  "prepared_family" -> <|"type" -> "mathematica-expression", "path" -> "prepared-family.wl"|>|>,
  <|"family_ref" -> family["family_ref"], "chart_id" -> family["chart_id"],
    "chart_type" -> family["chart_type"], "available_inputs" -> prepared["available_inputs"]|>];
