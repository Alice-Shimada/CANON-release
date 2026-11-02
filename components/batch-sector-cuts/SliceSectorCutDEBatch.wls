#!/usr/bin/env wolframscript
$HistoryLength = 0;
arguments = Quiet @ Check[$ScriptCommandLine, {}];
arguments = If[ListQ[arguments] && Length[arguments] > 1, Rest[arguments],
  position = FirstPosition[$CommandLine, "-script", Missing["not-found"]];
  If[MissingQ[position], position = FirstPosition[$CommandLine, "-file", Missing["not-found"]]];
  If[MissingQ[position], {}, Drop[$CommandLine, First[position] + 1]]];
If[Length[arguments] =!= 3, Print["usage: SliceSectorCutDEBatch.wls CANON INPUT OUTPUT"]; Exit[64]];
{canonRoot, inputPath, outputDir} = ExpandFileName /@ arguments;
Get[FileNameJoin[{canonRoot, "mma", "lib", "MethodCardCore.wl"}]];
Get[FileNameJoin[{canonRoot, "mma", "lib", "SectorDE.wl"}]];
task = CanonMethodCard`ReadTask[inputPath, "SLICE_CUT_DE_BATCH"];
If[FailureQ[task], Print[InputForm[task]]; Exit[1]];
fail[result_Failure] := (
  CanonMethodCard`WriteResult[task, outputDir, "ERROR", result[[1]], <||>,
    <|"reason" -> result[[2, "Message"]]|>]; Exit[1]);
invalid[reason_] := Failure["INVALID_DIFFERENTIAL_EQUATION", <|"Message" -> reason|>];

(* The full ordered input is loaded and checked once, outside the sector loop. *)
loadStarted = SessionTime[];
ordered = CanonMethodCard`LoadArtifact[task, inputPath, "ordered_master_de"];
loadSeconds = SessionTime[] - loadStarted;
If[FailureQ[ordered], fail[ordered]];
validationStarted = SessionTime[];
ordered = CANON`SectorDE`ValidateOrderedMasterDE[ordered];
validationSeconds = SessionTime[] - validationStarted;
If[FailureQ[ordered], fail[ordered]];
manifest = CanonMethodCard`LoadArtifact[task, inputPath, "sector_manifest"];
If[FailureQ[manifest], fail[manifest]];
sliceWriteStarted = SessionTime[];
sectors = Lookup[manifest, "sectors", None];
If[!ListQ[sectors] || sectors === {} || !AllTrue[sectors, AssociationQ],
  fail[invalid["sector manifest has no valid sector records"]]];
If[!DuplicateFreeQ[Lookup[sectors, "id"]] || !DuplicateFreeQ[Lookup[sectors, "sector_bits"]],
  fail[invalid["batch sector manifest must have unique sector ids and masks"]]];
sectors = SortBy[sectors, {Lookup[#, "propagator_count", None], Lookup[#, "id", None]} &];
checked = CANON`SectorDE`CurrentSectorRecord[ordered, manifest, KeyTake[#, {"id", "propagator_count"}]] & /@ sectors;
If[AnyTrue[checked, FailureQ], fail[SelectFirst[checked, FailureQ]]];
slices = CanonMethodCard`SectorDEArtifacts[ordered, manifest, #] & /@ checked;
resident = Select[MapThread[{#1, #2} &, {checked, slices}], Last[#]["resident_positions"] =!= {} &];
If[Sort[Flatten[(Last[#]["resident_positions"] & /@ resident)]] =!= Range[Length[ordered["basis"]]],
  fail[invalid["batch manifest must cover every resident master exactly once"]]];

indexPath = FileNameJoin[{outputDir, "sector-index.json"}];
If[FileExistsQ[indexPath], fail[Failure["ARTIFACT_WRITE_FAILED", <|"Message" -> "batch index already exists"|>]]];
sourceDescriptor[name_] := Module[{descriptor = task["payload", name], path, hash},
  path = CanonMethodCard`ResolveInputPath[inputPath, descriptor["path"]];
  hash = If[KeyExistsQ[descriptor, "sha256"], ToLowerCase[descriptor["sha256"]], FileHash[path, "SHA256", "HexString"]];
  Join[KeyDrop[descriptor, {"path", "sha256"}],
    <|"path" -> CanonMethodCard`RelativeArtifactPath[indexPath, path], "sha256" -> hash|>]];
artifactDescriptor[path_] := <|"type" -> "mathematica-expression",
  "path" -> CanonMethodCard`RelativeArtifactPath[indexPath, path], "sha256" -> FileHash[path, "SHA256", "HexString"]|>;
entries = {}; artifacts = <||>;
Do[
  current = pair[[1]]; sliced = pair[[2]]; id = current["id"];
  sectorDir = FileNameJoin[{outputDir, "sectors", "S" <> ToString[id]}];
  basisPath = CanonMethodCard`WriteWLArtifact[sliced["sector_basis"], sectorDir, "sector-basis.wl"];
  cutPath = CanonMethodCard`WriteWLArtifact[sliced["sector_cut_de"], sectorDir, "sector-cut-de.wl"];
  If[!AllTrue[{basisPath, cutPath}, StringQ],
    fail[Failure["ARTIFACT_WRITE_FAILED", <|"Message" -> "could not write complete batch cut/basis artifacts"|>]]];
  basisDescriptor = artifactDescriptor[basisPath]; cutDescriptor = artifactDescriptor[cutPath];
  artifacts["sector_basis_" <> ToString[id]] = basisDescriptor;
  artifacts["sector_cut_de_" <> ToString[id]] = cutDescriptor;
  AppendTo[entries, <|"sector" -> KeyTake[current, {"id", "propagator_count"}],
    "master_count" -> Length[sliced["sector_basis", "basis"]], "resident_positions" -> sliced["resident_positions"],
    "sector_basis" -> basisDescriptor, "sector_cut_de" -> cutDescriptor|>],
  {pair, resident}];
index = <|"schema" -> "canon-neu/sector-cut-de-batch/v1",
  "family_id" -> ordered["family_id"], "source_basis_id" -> ordered["basis_id"],
  "source_master_count" -> Length[ordered["basis"]], "ordering" -> "ascending (propagator_count, id); resident master order within each sector",
  "sources" -> AssociationMap[sourceDescriptor, {"ordered_master_de", "sector_manifest"}], "sectors" -> entries,
  "scope" -> "exact sector quotients of the checked original ordered DE; no canonical or UT certificate"|>;
If[!TrueQ[Quiet @ Check[Export[indexPath, index, "RawJSON"]; FileType[indexPath] === File, False]],
  fail[Failure["ARTIFACT_WRITE_FAILED", <|"Message" -> "could not publish the complete batch index"|>]]];
artifacts["sector_index"] = <|"type" -> "json", "path" -> "sector-index.json", "sha256" -> FileHash[indexPath, "SHA256", "HexString"]|>;
timingPath = FileNameJoin[{outputDir, "batch-timing.json"}];
timing = <|"schema" -> "canon-neu/batch-slice-timing/v1", "clock" -> "same-kernel SessionTime[] differences",
  "ordered_de_load_seconds" -> loadSeconds, "ordered_de_validation_seconds" -> validationSeconds,
  "all_sector_slice_and_write_seconds" -> (SessionTime[] - sliceWriteStarted),
  "ordered_de_load_calls" -> 1, "ordered_de_validation_calls" -> 1, "sector_count" -> Length[entries],
  "scope" -> "kernel startup/library loading excluded; loading includes declared hash check; slice/write includes manifest binding, projection and index publication"|>;
If[FileExistsQ[timingPath] || !TrueQ[Quiet @ Check[Export[timingPath, timing, "RawJSON"]; FileType[timingPath] === File, False]],
  fail[Failure["ARTIFACT_WRITE_FAILED", <|"Message" -> "could not publish batch timing record"|>]]];
artifacts["batch_timing"] = <|"type" -> "json", "path" -> "batch-timing.json", "sha256" -> FileHash[timingPath, "SHA256", "HexString"]|>;
CanonMethodCard`WriteResult[task, outputDir, "PASS", "BATCH_SLICED", artifacts,
  <|"sector_count" -> Length[entries], "full_master_count" -> Length[ordered["basis"]],
    "sector_ids" -> (Lookup[#, "id"] & /@ Lookup[entries, "sector"]),
    "resident_positions" -> Lookup[entries, "resident_positions"]|>];
