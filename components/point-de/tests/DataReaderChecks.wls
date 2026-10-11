#!/usr/bin/env wolframscript
$HistoryLength = 0;
{canon, work, mode, receipt} = Rest[$ScriptCommandLine];
Get[FileNameJoin[{canon, "mma", "lib", "MethodCardCore.wl"}]];
cases = <|
  "canonical" -> {CANON`DEData`x, CANON`DEData`eps, CANON`DEData`M},
  "global" -> {Global`x, Global`eps, Global`M},
  "foreign" -> {Foreign`x, Foreign`eps, Foreign`M},
  "qualified-canonical" -> {CANON`DEData`x, CANON`DEData`eps, CANON`DEData`M}
|>;
identity[v_, e_] := <|"family_id" -> "reader-fixture", "basis_id" -> "reader-basis",
  "chart_id" -> "reader-chart", "frame_id" -> "reader-frame",
  "scope" -> <|"included_sectors" -> {1}|>, "variables" -> {v}, "regulator" -> e,
  "convention" -> "D[basis, variables[[i]]] = matrices[[i]] . basis"|>;
sample[v_, e_, m_, p_] := Join[identity[v, e], <|"schema" -> "canon-neu/de-sample/v1",
  "point" -> {v -> p}, "matrices" -> {e/p SparseArray[{{1, 1} -> 1, {2, 2} -> 2}, {2, 2}]},
  "masters" -> {m[2], m[1]}|>];
save[data_, dir_, name_, qualified_: False] := Module[{path},
  path = CanonMethodCard`WriteWLArtifact[data, dir, name];
  If[TrueQ[qualified], Block[{$Context = "ReaderFixture`", $ContextPath = {"System`"}}, Put[data, path]]];
  path
];
request[dir_, name_, step_, payload_] := Export[FileNameJoin[{dir, name}],
  <|"schema" -> "canon-neu/script-input/v1", "task_id" -> "DATA-READER-TEST",
    "step" -> step, "sector" -> Null, "payload" -> payload|>, "RawJSON"];
roles = <|"training" -> {<|"id" -> "t0", "path" -> "t0.wl"|>, <|"id" -> "t1", "path" -> "t1.wl"|>},
  "validation" -> {<|"id" -> "v0", "path" -> "v0.wl"|>},
  "blind" -> {<|"id" -> "b0", "path" -> "b0.wl"|>}|>;
checks = <||>;
If[mode === "prepare",
  KeyValueMap[Function[{name, symbols}, Module[{dir, v, e, m, qualified},
    dir = FileNameJoin[{work, name}]; {v, e, m} = symbols; qualified = name === "qualified-canonical";
    MapThread[save[sample[v, e, m, #2], dir, #1 <> ".wl", qualified] &,
      {{"t0", "t1", "v0", "b0"}, {2, 3, 5, 7}}];
    save[Join[identity[v, e], <|"schema" -> "canon-neu/raw-letters/v1", "labels" -> {"L1"},
      "letters" -> {v}|>], dir, "letters.wl", qualified];
    request[dir, "collect.json", "COLLECT_DE_SAMPLES", roles];
    request[dir, "fit.json", "RECONSTRUCT_DLOG", <|"sample_set" -> <|"path" -> "collect/sample-set.wl"|>,
      "raw_letters" -> <|"path" -> "letters.wl"|>, "arithmetic" -> <|"mode" -> "exact"|>|>];
    request[dir, "check.json", "CHECK_RECONSTRUCTION", <|"sample_set" -> <|"path" -> "collect/sample-set.wl"|>,
      "raw_letters" -> <|"path" -> "letters.wl"|>, "reconstruction" -> <|"path" -> "fit/reconstruction.wl"|>|>]
  ]], cases];
  dir = FileNameJoin[{work, "canonical"}];
  save[sample[Foreign`x, CANON`DEData`eps, CANON`DEData`M, 11], dir, "foreign-variable.wl"];
  save[sample[CANON`DEData`x, Foreign`eps, CANON`DEData`M, 13], dir, "foreign-regulator.wl"];
  Do[request[dir, tag <> ".json", "COLLECT_DE_SAMPLES", Join[roles,
    <|"validation" -> {<|"id" -> tag, "path" -> tag <> ".wl"|>}|>]],
    {tag, {"foreign-variable", "foreign-regulator"}}];
  save[Join[identity[Foreign`x, CANON`DEData`eps], <|"schema" -> "canon-neu/raw-letters/v1",
    "labels" -> {"L1"}, "letters" -> {Foreign`x}|>], dir, "foreign-letters.wl"];
  request[dir, "foreign-letters.json", "CHECK_RECONSTRUCTION", <|
    "sample_set" -> <|"path" -> "collect/sample-set.wl"|>,
    "raw_letters" -> <|"path" -> "foreign-letters.wl"|>,
    "reconstruction" -> <|"path" -> "fit/reconstruction.wl"|>|>];
  checks["canonical_writer_uses_unqualified_symbols"] =
    !StringContainsQ[Import[FileNameJoin[{dir, "t0.wl"}], "Text"], "Global`"];
  checks["explicit_canonical_fixture_is_qualified"] = StringContainsQ[
    Import[FileNameJoin[{work, "qualified-canonical", "t0.wl"}], "Text"], "CANON`DEData`x"],
  KeyValueMap[Function[{name, symbols}, Module[{dir, v, e, m, original, index, fit, checked},
    dir = FileNameJoin[{work, name}]; {v, e, m} = symbols;
    original = CanonMethodCard`ReadWLData[FileNameJoin[{dir, "t0.wl"}]];
    index = CanonMethodCard`ReadWLData[FileNameJoin[{dir, "collect", "sample-set.wl"}]];
    fit = CanonMethodCard`ReadWLData[FileNameJoin[{dir, "fit", "reconstruction.wl"}]];
    checked = CanonMethodCard`ReadWLData[FileNameJoin[{dir, "check", "reconstruction-check.wl"}]];
    checks[name <> "_variable_identity"] = And @@ (#["variables"] === {v} & /@ {original, index, fit, checked});
    checks[name <> "_regulator_identity"] = And @@ (#["regulator"] === e & /@ {original, index, fit, checked});
    checks[name <> "_master_order_and_head"] = original["masters"] === {m[2], m[1]} &&
      CanonMethodCard`ReadWLData[CanonMethodCard`ResolveInputPath[
        FileNameJoin[{dir, "fit", "reconstruction.wl"}], First[fit["sources", "training"]]["path"]]]["masters"] === original["masters"];
    checks[name <> "_persisted_sample_roles"] = Length[index["training"]] === 2 &&
      Length[index["validation"]] === 1 && Length[index["blind"]] === 1;
    checks[name <> "_scope_stays_finite"] = fit["evidence", "heldout_checked"] === False &&
      checked["global_gauge_checked"] === False && checked["alphabet_complete"] === False &&
      checked["code"] === "RECONSTRUCTION_VALIDATED"
  ]], cases]
];
Export[receipt, checks, "RawJSON"];
Print[InputForm[checks]];
Exit[If[And @@ Values[checks], 0, 1]];
