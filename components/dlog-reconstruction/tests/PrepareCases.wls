#!/usr/bin/env wolframscript
$HistoryLength = 0;
{package, work} = Rest[$ScriptCommandLine];
Get[FileNameJoin[{package, "examples", "Example.wl"}]];
MakeDLogExample[FileNameJoin[{work, "exact"}]];
MakeDLogExample[FileNameJoin[{work, "numeric"}], "high_precision"];
cases = {"missing-letter", "insufficient-rank", "epsilon", "missing-matrix", "wrong-frame", "role-overlap", "duplicate-point",
  "missing-validation", "validation-changed", "blind-changed", "rank-growth", "indexed", "sparse", "sparse-heldout", "zero"};
Do[CopyDirectory[FileNameJoin[{work, "exact"}], FileNameJoin[{work, name}]], {name, cases}];
Do[CopyDirectory[FileNameJoin[{work, "numeric"}], FileNameJoin[{work, name}]], {name, {"low-precision", "recognition-bound"}}];
update[name_, file_, fn_] := Module[{path = FileNameJoin[{work, name, file}], data}, data = Get[path]; Put[fn[data], path]];
Do[update["indexed", file, Function[a, a /. {x -> x[1], y -> x[2]}]],
  {file, {"train-1.wl", "train-2.wl", "train-3.wl", "validation-1.wl", "blind-1.wl", "sample-set.wl", "raw-letters.wl", "one-forms.wl"}}];
Do[update[name, file, Function[a, Join[a, <|"matrices" -> (SparseArray[Most[ArrayRules[SparseArray[#]]], {80, 80}] & /@ a["matrices"])|>]]],
  {name, {"sparse", "sparse-heldout"}}, {file, {"train-1.wl", "train-2.wl", "train-3.wl", "validation-1.wl", "blind-1.wl"}}];
update["sparse-heldout", "blind-1.wl", Function[a, Module[{m = a["matrices"]}, m[[2]] += SparseArray[{{80, 79} -> eps}, {80, 80}]; Join[a, <|"matrices" -> m|>]]]];
Do[update["zero", file, Function[a, Join[a, <|"matrices" -> ConstantArray[SparseArray[{}, {2, 2}], 2]|>]]],
  {file, {"train-1.wl", "train-2.wl", "train-3.wl", "validation-1.wl", "blind-1.wl"}}];
update["missing-letter", "raw-letters.wl", Function[a, Join[a, <|"letters" -> a["letters"][[{1, 2, 4}]], "labels" -> a["labels"][[{1, 2, 4}]]|>]]];
update["insufficient-rank", "sample-set.wl", Function[a, Join[a, <|"training" -> Take[a["training"], 1]|>]]];
update["epsilon", "train-1.wl", Function[a, Module[{m = a["matrices"]}, m[[1, 2, 1]] += eps^2; Join[a, <|"matrices" -> m|>]]]];
update["missing-matrix", "train-1.wl", Function[a, Module[{m = a["matrices"]}, m[[1]] = Drop[m[[1]], -1]; Join[a, <|"matrices" -> m|>]]]];
update["wrong-frame", "validation-1.wl", Function[a, Join[a, <|"frame_id" -> "opposite-root-frame"|>]]];
update["role-overlap", "sample-set.wl", Function[a, Join[a, <|"validation" -> {First[a["training"]]}|>]]];
train = Get[FileNameJoin[{work, "exact", "train-1.wl"}]];
update["duplicate-point", "validation-1.wl", Function[a, Join[a, KeyTake[train, {"point", "matrices"}]]]];
update["missing-validation", "sample-set.wl", Function[a, Join[a, <|"validation" -> {}|>]]];
Do[update[pair[[1]], pair[[2]], Function[a, Module[{m = a["matrices"]}, m[[2, 2, 1]] += eps; Join[a, <|"matrices" -> m|>]]]],
  {pair, {{"validation-changed", "validation-1.wl"}, {"blind-changed", "blind-1.wl"}}}];
(* Generate a training design with an accidental dependence that disappears on held-out points. *)
letterData = Get[FileNameJoin[{work, "exact", "raw-letters.wl"}]];
residues = {{{1, 2}, {0, 1}}, {{-1/3, 0}, {0, -1/3}}, {{2/5, 3/7}, {0, 2/5}}, ConstantArray[0, {2, 2}]};
de = Table[eps Total[MapThread[#1 D[#2, v]/#2 &, {residues, letterData["letters"]}]], {v, {x, y}}];
Do[point = {x -> i, y -> 3 i^2}; update["rank-growth", "train-" <> ToString[i] <> ".wl",
  Function[a, Join[a, <|"point" -> point, "matrices" -> FullSimplify[de /. point]|>]]], {i, 3}];
update["low-precision", "train-1.wl", Function[a, Join[a, <|"matrices" -> eps N[a["matrices"]/eps, MachinePrecision]|>]]];
requestPath = FileNameJoin[{work, "recognition-bound", "reconstruct.json"}];
request = Import[requestPath, "RawJSON"];
request = Join[request, <|"payload" -> Join[request["payload"], <|"arithmetic" -> Join[request["payload", "arithmetic"], <|"max_denominator" -> 2|>]|>]|>];
Export[requestPath, request, "RawJSON"];
