#!/usr/bin/env wolframscript
$HistoryLength = 0;
work = First[Rest[$ScriptCommandLine]];
path = FileNameJoin[{work, "exact", "fit", "reconstruction.wl"}]; c = Get[path];
Put[Join[c, <|"frame_id" -> "changed-frame"|>], FileNameJoin[{DirectoryName[path], "wrong-frame.wl"}]];
r = c["residue_matrices"]; r[[1]] = SparseArray[Normal[r[[1]]] + {{0, 0}, {1, 0}}];
Put[Join[c, <|"residue_matrices" -> r|>], FileNameJoin[{DirectoryName[path], "changed-coefficients.wl"}]];
gradient = Table[D[w, v]/w, {v, c["variables"]}, {w, c["letters"]}];
m = Table[c["regulator"] Total[MapThread[#1 #2 &, {Normal /@ r, gradient[[k]]}]], {k, Length[c["variables"]]}];
a = Total[MapThread[#1 Log[#2] &, {Normal /@ r, c["letters"]}]];
Put[Join[c, <|"residue_matrices" -> r, "residue_digest" -> Hash[r, "SHA256", "HexString"], "matrices" -> m, "Atilde" -> a|>],
  FileNameJoin[{DirectoryName[path], "changed-coefficients-rebound.wl"}]];
l = Get[FileNameJoin[{work, "exact", "raw-letters.wl"}]]; changed = l["letters"]; changed[[1]] += 1;
Put[Join[l, <|"letters" -> changed|>], FileNameJoin[{work, "exact", "changed-raw-letters.wl"}]];
(* Verify structural claims in the positive artifact independently of JSON result summaries. *)
facts = <|"rational_residues" -> AllTrue[Flatten[Normal /@ c["residue_matrices"]], IntegerQ[#] || Head[#] === Rational &],
  "sparse_residues" -> AllTrue[c["residue_matrices"], Head[#] === SparseArray &],
  "redundant_letter_retained" -> Length[c["letters"]] === 4 && c["rank"] === 3,
  "raw_letters_have_no_log" -> FreeQ[c["letters"], _Log], "raw_letter_has_root" -> !FreeQ[c["letters"], Power[_, 1/2]],
  "all_positions_present" -> Dimensions[c["matrices"]] === {2, 2, 2},
  "training_only" -> c["evidence", "heldout_checked"] === False,
  "relative_sources" -> AllTrue[Lookup[Values[KeyTake[c["sources"], {"sample_set", "raw_letters"}]], "path"], !StringStartsQ[#, "/"] &]|>;
Export[FileNameJoin[{work, "artifact-facts.json"}], facts, "RawJSON"];
