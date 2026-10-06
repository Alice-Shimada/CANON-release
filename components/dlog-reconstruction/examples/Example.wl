(* Synthetic commuting 2 x 2 connection in two variables; no physical-family claim. *)
ClearAll[MakeDLogExample];
MakeDLogExample[directory_String, mode_String : "exact"] := Module[
  {dir = ExpandFileName[directory], base, letters, residues, matrices, points, roles, names, arithmetic, request},
  If[!DirectoryQ[dir], CreateDirectory[dir, CreateIntermediateDirectories -> True]];
  base = <|"family_id" -> "synthetic-two-variable", "basis_id" -> "synthetic-two-master", "chart_id" -> "positive-real-x-y",
    "frame_id" -> "principal-square-root", "scope" -> <|"included" -> {"synthetic full 2x2 system"}, "excluded" -> {"physical integral family"}|>,
    "variables" -> {Global`x, Global`y}, "regulator" -> Global`eps,
    "convention" -> "D[basis, variables[[i]]] = matrices[[i]] . basis"|>;
  letters = {Global`x, Global`y, Global`x + Sqrt[Global`x^2 + Global`y], Global`x^2};
  residues = {{{1, 2}, {0, 1}}, {{-1/3, 0}, {0, -1/3}}, {{2/5, 3/7}, {0, 2/5}}, ConstantArray[0, {2, 2}]};
  matrices = Table[Global`eps Total[MapThread[#1 D[#2, v]/#2 &, {residues, letters}]], {v, base["variables"]}];
  points = {{Global`x -> 1, Global`y -> 2}, {Global`x -> 2, Global`y -> 3}, {Global`x -> 3, Global`y -> 5},
    {Global`x -> 4, Global`y -> 7}, {Global`x -> 5, Global`y -> 11}};
  names = {"train-1", "train-2", "train-3", "validation-1", "blind-1"};
  Do[Put[Join[base, <|"schema" -> "canon-neu/de-sample/v1", "point" -> points[[i]],
    "matrices" -> If[mode === "exact", FullSimplify[matrices /. points[[i]]], Global`eps N[FullSimplify[matrices/Global`eps /. points[[i]]], 90]]|>],
    FileNameJoin[{dir, names[[i]] <> ".wl"}]], {i, Length[points]}];
  roles = Map[<|"id" -> #, "path" -> # <> ".wl"|> &, names];
  Put[Join[base, <|"schema" -> "canon-neu/de-sample-set/v1", "training" -> Take[roles, 3], "validation" -> {roles[[4]]}, "blind" -> {roles[[5]]}|>], FileNameJoin[{dir, "sample-set.wl"}]];
  Put[Join[base, <|"schema" -> "canon-neu/raw-letters/v1", "labels" -> {"x", "y", "root-letter", "redundant-x-squared"}, "letters" -> letters|>], FileNameJoin[{dir, "raw-letters.wl"}]];
  Put[Join[base, <|"schema" -> "canon-neu/analytic-one-forms/v1", "one_forms" -> Table[D[w, v]/w, {w, Take[letters, 3]}, {v, base["variables"]}], "seed_letters" -> {}|>], FileNameJoin[{dir, "one-forms.wl"}]];
  arithmetic = If[mode === "exact", <|"mode" -> "exact"|>, <|"mode" -> "high_precision", "precision" -> 70,
    "residual_tolerance" -> "10^-40", "rank_tolerance" -> "10^-45", "recognition_tolerance" -> "10^-45", "max_denominator" -> 1000, "max_numerator" -> 1000|>];
  request[step_, payload_] := <|"schema" -> "canon-neu/script-input/v1", "task_id" -> "synthetic-" <> step, "step" -> step, "sector" -> Null, "payload" -> payload|>;
  Export[FileNameJoin[{dir, "reconstruct.json"}], request["RECONSTRUCT_DLOG", <|"sample_set" -> <|"path" -> "sample-set.wl"|>, "raw_letters" -> <|"path" -> "raw-letters.wl"|>, "arithmetic" -> arithmetic|>], "RawJSON"];
  Export[FileNameJoin[{dir, "check.json"}], request["CHECK_RECONSTRUCTION", <|"sample_set" -> <|"path" -> "sample-set.wl"|>, "raw_letters" -> <|"path" -> "raw-letters.wl"|>, "reconstruction" -> <|"path" -> "fit/reconstruction.wl"|>|>], "RawJSON"];
  Export[FileNameJoin[{dir, "propose.json"}], request["PROPOSE_LETTERS", <|"one_forms" -> <|"path" -> "one-forms.wl"|>, "max_letters" -> 8|>], "RawJSON"];
  dir
];
