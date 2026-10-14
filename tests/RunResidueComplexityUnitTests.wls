#!/usr/bin/env wolframscript
$HistoryLength = 0;
repoRoot = DirectoryName[DirectoryName[ExpandFileName[$InputFileName]]];
Get[FileNameJoin[{repoRoot, "mma", "lib", "MethodCardCore.wl"}]];
Get[FileNameJoin[{repoRoot, "mma", "lib", "TailCompletion.wl"}]];
ClearAll[x, y, z, eps];
checks = {};
assert[name_, ok_] := AppendTo[checks, <|"name" -> name, "pass" -> TrueQ[ok]|>];
zeroQ[m_] := AllTrue[Flatten[m], TrueQ[Together[#] === 0] &];
cost[r_] := CanonTailCompletion`Private`residueCost[r];
condition[r_] := CanonTailCompletion`Private`conditionConstantResidues[r];
solution[r_, t_:Automatic] := <|"solved" -> True, "method" -> "fixed-canonical-fixture",
  "transformation" -> If[t === Automatic, IdentityMatrix[Length[First[r]]], t],
  "matrices" -> {eps (r[[1]]/x + r[[2]]/(x-1))}, "alphabet" -> {x, x-1}|>;

base = {{{1, 2, 0}, {0, 3, 4}, {5, 0, 6}}, {{2, 0, 1}, {0, 1, 0}, {0, 0, 4}}};
distortion = DiagonalMatrix[{1, 10^30, 10^-20}];
distorted = distortion.#.Inverse[distortion] & /@ base;
c = condition[distorted]; d = DiagonalMatrix[c["scales"]];
assert["diagonal-trials-bounded", c["trials"] <= 96];
assert["diagonal-total-bits-improve", c["after"][[1]] < c["before"][[1]]/2];
assert["diagonal-max-bits-do-not-grow", c["after"][[2]] <= c["before"][[2]]];
assert["diagonal-noncommuting-residues-exact", And @@ MapThread[zeroQ[#1.d-d.#2] &, {distorted, c["residues"]}]];
assert["diagonal-zero-pattern-preserved", Map[# === 0 &, distorted, {3}] === Map[# === 0 &, c["residues"], {3}]];
compact = solution[base];
assert["compact-output-is-exact-no-op", CanonTailCompletion`SimplifyCanonicalTail[compact, {x}, eps, 1] === compact];
assert["compact-output-never-refits-residues", Catch[Block[
  {CanonMethodCard`DLogResidues = (Throw["unnecessary_fit"] &)},
  CanonTailCompletion`SimplifyCanonicalTail[compact, {x}, eps, 1]]] === compact];
changed = CanonTailCompletion`SimplifyCanonicalTail[solution[distorted], {x}, eps, 1];
assert["canonical-postlude-applied", TrueQ[changed["representation_simplification", "applied"]]];
assert["canonical-postlude-source-gauge", zeroQ[First[CanonMethodCard`GaugeTransform[
  solution[distorted]["matrices"], {x}, changed["transformation"]]]-First[changed["matrices"]]]];
assert["canonical-postlude-shared-dlog", CanonMethodCard`DLogConnectionQ[changed["matrices"], {x}, eps, {x, x-1}]];
assert["zero-budget-preserves-original", CanonTailCompletion`SimplifyCanonicalTail[solution[distorted], {x}, eps, 0] === solution[distorted]];
short = CanonTailCompletion`SimplifyCanonicalTail[solution[distorted], {x}, eps, 10^-9];
assert["optional-timeout-retains-valid-map", short["transformation"] === IdentityMatrix[3] && short["matrices"] === solution[distorted]["matrices"]];
assert["optional-timeout-is-not-scientific-failure", TrueQ[short["solved"]]];
assert["dimension-skip-preserves-original", With[{s = <|"transformation" -> IdentityMatrix[129], "matrices" -> {}|>},
  CanonTailCompletion`SimplifyCanonicalTail[s, {x}, eps, 1] === s]];
assert["alphabet-storage-skip-precedes-fitting", With[{s = <|"transformation" -> IdentityMatrix[64],
  "alphabet" -> Range[98], "matrices" -> {}|>},
  CanonTailCompletion`SimplifyCanonicalTail[s, {x}, eps, 1] === s]];
memoryInput = Join[solution[distorted], <|"matrices" -> Join[solution[distorted]["matrices"],
  {ConstantArray[0,{3,3}]}]|>];
memoryBound = Block[{CanonMethodCard`DLogResidues = (ConstantArray[1,10000000] &)},
  CanonTailCompletion`SimplifyCanonicalTail[memoryInput, {x,y}, eps, 1]];
assert["optional-memory-limit-retains-success", TrueQ[memoryBound["solved"]] &&
  memoryBound["transformation"] === IdentityMatrix[3] && memoryBound["matrices"] === memoryInput["matrices"] &&
  memoryBound["representation_simplification", "reason"] === "memory_bound"];
assert["constant-field-outside-QQ-is-skipped", condition[{{{10^30 Sqrt[2]}}}] === $Failed];
assert["residue-storage-bound-before-search", condition[ConstantArray[IdentityMatrix[64], 98]] === $Failed];
invariant = condition[{{{10^40, 1}, {1, 10^40}}}];
assert["similarity-invariant-height-is-not-forced", invariant["accepted"] === 0 && invariant["before"] === invariant["after"]];
assert["scalar-has-no-artificial-gauge", condition[{{{10^40}}}]["scales"] === {1}];
assert["zero-residues-stay-zero", condition[ConstantArray[0, {2, 3, 3}]]["accepted"] === 0];
assert["transform-growth-rejected", !CanonTailCompletion`Private`smallTransformGrowthQ[{{1}}, {Range[10000]}]];
growth = Block[{CanonTailCompletion`Private`smallTransformGrowthQ = (False &)},
  CanonTailCompletion`SimplifyCanonicalTail[solution[distorted], {x}, eps, 1]];
assert["transform-growth-keeps-valid-original", growth["transformation"] === IdentityMatrix[3] &&
  growth["matrices"] === solution[distorted]["matrices"] && TrueQ[growth["solved"]]];
kinematicLetter = 1+10^30 x;
kinematic = <|"solved" -> True, "transformation" -> {{1}}, "alphabet" -> {kinematicLetter},
  "matrices" -> {{{eps 10^30/(1+10^30 x)}}}|>;
kinematicNew = CanonTailCompletion`SimplifyCanonicalTail[kinematic, {x}, eps, 1];
assert["large-letter-constant-does-not-force-basis-change", kinematicNew["matrices"] === kinematic["matrices"] &&
  kinematicNew["transformation"] === kinematic["transformation"]];
linearLetters = {3x-6,7x+7}; linearMatrices = {eps(base[[1]]/(x-2)+base[[2]]/(x+1))};
assert["direct-linear-residues-match-general-independent-fit",
  CanonTailCompletion`Private`linearLetterResidues[linearMatrices,{x},eps,linearLetters] ===
  CanonMethodCard`DLogResidues[linearMatrices,{x},eps,linearLetters]];
duplicateResidues = CanonTailCompletion`Private`linearLetterResidues[linearMatrices,{x},eps,{3x-6,6x-12,7x+7}];
assert["proportional-linear-letters-counted-once", duplicateResidues[[1]] === base[[1]] &&
  duplicateResidues[[2]] === ConstantArray[0,{3,3}] && duplicateResidues[[3]] === base[[2]]];
assert["nonlinear-letter-keeps-general-provider", CanonTailCompletion`Private`linearLetterResidues[
  linearMatrices,{x},eps,{x^2+1}] === $Failed];
assert["multivariable-keeps-general-provider", CanonTailCompletion`Private`linearLetterResidues[
  linearMatrices,{x,y},eps,linearLetters] === $Failed];

(* Independent dense similarities across dimensions and several letters. *)
SeedRandom[731];
Do[
  randomBase = RandomInteger[{-3,3}, {3, dimension, dimension}];
  randomD = DiagonalMatrix[Table[(7^30)^Mod[i,3], {i,dimension}]];
  randomResidues = randomD.#.Inverse[randomD] & /@ randomBase;
  randomConditioned = condition[randomResidues]; randomScale = DiagonalMatrix[randomConditioned["scales"]];
  assert["independent-dense-similarity-"<>ToString[dimension], And @@ MapThread[
    zeroQ[Inverse[randomScale].#1.randomScale-#2] &, {randomResidues,randomConditioned["residues"]}]];
  assert["bounded-nonworsening-cost-"<>ToString[dimension], randomConditioned["after"][[1]] <= randomConditioned["before"][[1]] &&
    randomConditioned["after"][[2]] <= randomConditioned["before"][[2]] && randomConditioned["trials"] <= 96],
  {dimension,2,6}];

(* Many variables and two algebraic letters share the same constant similarity. *)
letters = {(x+Sqrt[x^2+y])/(x-Sqrt[x^2+y]), (x+Sqrt[x^2+z])/(x-Sqrt[x^2+z])};
rs = Normal /@ {SparseArray[{{1, 2} -> 10^30, {4, 2} -> 10^30}, {4, 4}],
  SparseArray[{{4, 3} -> 1}, {4, 4}]};
multi = <|"solved" -> True, "transformation" -> IdentityMatrix[4], "alphabet" -> letters,
  "matrices" -> CanonTailCompletion`Private`residueMatrices[rs, {x, y, z}, eps, letters]|>;
multiNew = CanonTailCompletion`SimplifyCanonicalTail[multi, {x, y, z}, eps, 1];
assert["multivariate-algebraic-postlude-applied", TrueQ[multiNew["representation_simplification", "applied"]]];
assert["multivariate-algebraic-exact-gauge", zeroQ[CanonMethodCard`GaugeTransform[
  multi["matrices"], {x, y, z}, multiNew["transformation"]]-multiNew["matrices"]]];
assert["multivariate-algebraic-shared-residues", CanonMethodCard`DLogConnectionQ[multiNew["matrices"], {x, y, z}, eps, letters]];
assert["algebraic-upper-right-stays-zero", zeroQ[multiNew["matrices"][[All, 1;;3, 4;;4]]]];

(* Keep the successful solver anchor. Only the optional post-success constant
   similarity changes the final representative. Meromorphic gauges stay valid. *)
big = 10^25; known = DiagonalMatrix[{1+big (eps-2), 1}];
small = {{{0, 1}, {1, 0}}, {{1, 0}, {0, 2}}};
raw = Map[Together, known.(eps #).Inverse[known], {2}] & /@ small;
normalization = CanonTailCompletion`Private`dlogIntertwiner[raw, eps];
baseline = <|"solved" -> True, "transformation" -> normalization["transformation"],
  "alphabet" -> {x, x-1}, "matrices" ->
    CanonTailCompletion`Private`residueMatrices[Map[Together[#/eps] &, normalization["normalized_residues"], {3}], {x}, eps, {x, x-1}]|>;
anchor = CanonTailCompletion`Private`compactDLogAnchor[baseline, raw, normalization, {x}, eps, 1];
assert["original-first-feasible-anchor-retained", normalization["diagnostics", "reference"] === "1"];
assert["post-success-reanchor-applied", TrueQ[anchor["diagnostics", "applied"]]];
assert["post-success-reanchor-no-second-solve", anchor["diagnostics", "additional_linear_solves"] === 0];
assert["post-success-reanchor-finds-small-target", anchor["diagnostics", "reference"] === "2"];
assert["post-success-reanchor-gauge-exact", zeroQ[CanonMethodCard`GaugeTransform[
  {raw[[1]]/x+raw[[2]]/(x-1)}, {x}, anchor["solution", "transformation"]]-anchor["solution", "matrices"]]];
assert["post-success-reanchor-residue-height-improves", anchor["diagnostics", "after"][[1]] < anchor["diagnostics", "before"][[1]]];
assert["post-success-zero-budget-is-no-op", CanonTailCompletion`Private`compactDLogAnchor[
  baseline, raw, normalization, {x}, eps, 0]["solution"] === baseline];
anchorTimeout = CanonTailCompletion`Private`compactDLogAnchor[baseline, raw, normalization, {x}, eps, 10^-9];
assert["post-success-timeout-retains-baseline", anchorTimeout["solution"] === baseline];
fillGauge = known.{{1,eps-1},{0,1}};
fillRaw = Map[Together,fillGauge.(eps #).Inverse[fillGauge],{2}] & /@ small;
fillNormalization = CanonTailCompletion`Private`dlogIntertwiner[fillRaw,eps];
fillBaseline = <|"solved"->True,"transformation"->fillNormalization["transformation"],"alphabet"->{x,x-1},
  "matrices"->{fillNormalization["normalized_residues"][[1]]/x+fillNormalization["normalized_residues"][[2]]/(x-1)}|>;
fillAnchor = CanonTailCompletion`Private`compactDLogAnchor[fillBaseline,fillRaw,fillNormalization,{x},eps,1];
assert["smaller-anchors-do-not-introduce-residue-couplings", fillAnchor["solution"] === fillBaseline];
assert["residue-count-cannot-grow-for-bit-gain", !CanonTailCompletion`Private`betterResidueCostQ[{10,3,4},{100,40,3}]];
singularRaw = {eps {{0,10^25 (eps-2)},{0,0}}};
singularNormalization = CanonTailCompletion`Private`dlogIntertwiner[singularRaw,eps];
singularBaseline = <|"solved"->True,"transformation"->singularNormalization["transformation"],
  "alphabet"->{x},"matrices"->{First[singularNormalization["normalized_residues"]]/x}|>;
singularAnchor = CanonTailCompletion`Private`compactDLogAnchor[singularBaseline,singularRaw,singularNormalization,{x},eps,1];
assert["regular-residue-but-singular-specialization-rejected", singularAnchor["solution"] === singularBaseline];
full = <|"variables" -> {x}, "regulator" -> eps, "source_basis" -> {j1, j2},
  "source_matrices" -> {raw[[1]]/x+raw[[2]]/(x-1)}|>;
completed = CanonTailCompletion`Private`completeDLogEpsilon[full,
  {{IdentityMatrix[2], full["source_matrices"]}}, {x, x-1}, 30];
assert["existing-normalizer-integrates-reanchor", TrueQ[completed["solved"]] && TrueQ[completed["diagnostics", "anchor_compaction", "applied"]]];
assert["integrated-reanchor-full-source-gauge", zeroQ[CanonMethodCard`GaugeTransform[
  full["source_matrices"], {x}, completed["transformation"]]-completed["matrices"]]];
assert["loaded-complexity-helper-identity", completed["diagnostics", "implementation", "complexity_sha256"] ===
  FileHash[FileNameJoin[{repoRoot, "mma", "lib", "tail", "ResidueComplexity.wl"}], "SHA256", "HexString"]];

summary = <|"total" -> Length[checks], "succeeded" -> Count[Lookup[checks, "pass"], True],
  "failed" -> Count[Lookup[checks, "pass"], False]|>;
Print[InputForm[summary]];
If[summary["failed"] > 0, Print[InputForm[Select[checks, !TrueQ[#["pass"]] &]]]];
If[CanonMethodCard`ScriptArguments[] =!= {}, Export[Last[CanonMethodCard`ScriptArguments[]], summary, "RawJSON"]];
Quit[If[summary["failed"] === 0, 0, 1]];
