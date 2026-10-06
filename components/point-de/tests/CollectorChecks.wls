#!/usr/bin/env wolframscript
$HistoryLength = 0;
{canon, package, tree, receipt} = Rest[$ScriptCommandLine];
Get[FileNameJoin[{canon, "mma", "lib", "MethodCardCore.wl"}]];
Get[FileNameJoin[{package, "PointDE.wl"}]];
checks = <||>;
requestFile = FileNameJoin[{tree, "collect.json"}];
roles = Import[requestFile, "RawJSON"]["payload"];
index = CanonPointDE`CollectSamples[roles, requestFile, FileNameJoin[{tree, "collector-fixtures", "index.wl"}]];
checks["streamed_collection_matches_identity_and_roles"] = !FailureQ[index] &&
  Length[index["training"]] === 2 && Length[index["validation"]] === 1 && index["variables"] === {x};
checks["streamed_index_references_resolve"] = And @@ (FileExistsQ[CanonMethodCard`ResolveInputPath[
  FileNameJoin[{tree, "collector-fixtures", "index.wl"}], #["path"]]] & /@ Join[index["training"], index["validation"]]);
directory = FileNameJoin[{tree, "collector-fixtures"}];
If[!DirectoryQ[directory], CreateDirectory[directory]];
training = Get[FileNameJoin[{tree, "training", "de-sample.wl"}]];
Put[training, FileNameJoin[{directory, "duplicate.wl"}]];
duplicateRoles = Join[roles, <|"validation" -> {<|"id" -> "duplicate-point", "path" -> "collector-fixtures/duplicate.wl"|>}|>];
duplicate = CanonPointDE`CollectSamples[duplicateRoles, requestFile, FileNameJoin[{directory, "duplicate-index.wl"}]];
checks["distinct_files_with_same_point_rejected"] = FailureQ[duplicate] && duplicate[[1]] === "OVERLAPPING_SAMPLE_POINTS";
changed = Get[FileNameJoin[{tree, "validation", "de-sample.wl"}]];
changed["scope"] = <|"included_sectors" -> {7}|>;
Put[changed, FileNameJoin[{directory, "changed-scope.wl"}]];
changedRoles = Join[roles, <|"validation" -> {<|"id" -> "changed-scope", "path" -> "collector-fixtures/changed-scope.wl"|>}|>];
bad = CanonPointDE`CollectSamples[changedRoles, requestFile, FileNameJoin[{directory, "bad-index.wl"}]];
checks["scope_mismatch_rejected"] = FailureQ[bad] && bad[[1]] === "SAMPLE_IDENTITY_MISMATCH";
Export[receipt, checks, "RawJSON"];
Print[InputForm[checks]];
Exit[If[And @@ Values[checks], 0, 1]];
