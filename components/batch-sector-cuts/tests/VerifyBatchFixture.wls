#!/usr/bin/env wolframscript
$HistoryLength = 0;
arguments = Quiet @ Check[$ScriptCommandLine, {}];
arguments = If[ListQ[arguments] && Length[arguments] > 1, Rest[arguments],
  position = FirstPosition[$CommandLine, "-script", Missing["not-found"]];
  If[MissingQ[position], position = FirstPosition[$CommandLine, "-file", Missing["not-found"]]];
  If[MissingQ[position], {}, Drop[$CommandLine, First[position] + 1]]];
{canonRoot, inputPath, outputDir} = ExpandFileName /@ arguments;
Get[FileNameJoin[{canonRoot, "mma", "lib", "MethodCardCore.wl"}]];
task = CanonMethodCard`ReadTask[inputPath, "VERIFY_BATCH_FIXTURE"];
indexPath = CanonMethodCard`ResolveArtifactPath[inputPath, task["payload", "batch_index"]];
index = Import[indexPath, "RawJSON"];
f = CANON`DEData`f; x = CANON`DEData`x; y = CANON`DEData`y; eps = CANON`DEData`eps;
bases = <|0 -> {f[0,0]}, 1 -> {f[2,0], f[1,0]}, 2 -> {f[0,1]}, 3 -> {f[1,1]}|>;
blocks = <|0 -> {{1}}, 1 -> {{3,4},{5,6}}, 2 -> {{14}}, 3 -> {{9}}|>;
lower = <|0 -> {}, 1 -> {<|"id"->0,"propagator_count"->0|>}, 2 -> {<|"id"->0,"propagator_count"->0|>},
  3 -> {<|"id"->2,"propagator_count"->1|>,<|"id"->0,"propagator_count"->0|>,<|"id"->1,"propagator_count"->1|>}|>;
checks = <||>;
Do[
  id = row["sector", "id"];
  basis = CanonMethodCard`ReadWLData[CanonMethodCard`ResolveArtifactPath[indexPath, row["sector_basis"]]];
  cut = CanonMethodCard`ReadWLData[CanonMethodCard`ResolveArtifactPath[indexPath, row["sector_cut_de"]]];
  checks["expected_basis_" <> ToString[id]] = basis["basis"] === bases[id] && cut["basis"] === bases[id];
  checks["expected_matrices_" <> ToString[id]] = cut["matrices"] === {(eps/x) blocks[id], (eps/(y+1)) blocks[id]};
  checks["expected_lower_quotient_" <> ToString[id]] = cut["proper_subsectors"] === lower[id];
  checks["standard_contract_" <> ToString[id]] = CanonMethodCard`ValidSectorBasisQ[basis] && CanonMethodCard`ValidCutDEQ[cut],
  {row,index["sectors"]}];
checks["all_source_positions_covered"] = Sort[Flatten[Lookup[index["sectors"], "resident_positions"]]] === Range[5];
checks["nontrivial_same_sector_mixture_retained"] = blocks[1] === {{3,4},{5,6}};
CanonMethodCard`WriteResult[task,outputDir,If[And @@ Values[checks],"PASS","FAIL"],
  If[And @@ Values[checks],"EXPECTED_BLOCKS_MATCH","EXPECTED_BLOCKS_DIFFER"],<||>,<|"checks"->checks|>];
Exit[If[And @@ Values[checks],0,1]];
