#!/usr/bin/env wolframscript
$HistoryLength = 0;
repoRoot = DirectoryName[DirectoryName[DirectoryName[ExpandFileName[$InputFileName]]]];
Get[FileNameJoin[{repoRoot, "mma", "lib", "MethodCardCore.wl"}]];
{inputPath, outputDir} = ExpandFileName /@ CanonMethodCard`ScriptArguments[];
task = CanonMethodCard`ReadTask[inputPath, "SEARCH_CORE"];
cut = CanonMethodCard`LoadArtifact[task, inputPath, "sector_cut_de"];
alphabet = If[Lookup[task["payload"], "declared_alphabet", Null] === Null, {},
  CanonMethodCard`LoadArtifact[task, inputPath, "declared_alphabet"]["letters"]];
variables = cut["variables"]; regulator = cut["regulator"];
matrices = cut["matrices"]; dimension = Length[cut["basis"]];
zero = Map[Factor, matrices /. regulator -> 0, {3}];
weights = -Diagonal[Map[Together, Total[MapThread[Times, {variables, zero}]], {2}]];
exhausted[] := (CanonMethodCard`WriteProviderResult[task, outputDir,
  "INCONCLUSIVE", "METHOD_EXHAUSTED", <||>,
  <|"method_id" -> "epsilon-zero-polynomial", "reason" -> "bounded horizontal ansatz exhausted"|>]; Quit[0]);

trace = ({{regulator Tr[#]}} &) /@ zero;
traceAlphabet = CanonMethodCard`DLogAlphabet[trace, variables, regulator];
traceResidues = CanonMethodCard`DLogResidues[trace, variables, regulator, traceAlphabet];
If[traceResidues === $Failed, exhausted[]];
traceResidues = Flatten[traceResidues];
determinant = Times @@ MapThread[Power, {traceAlphabet, -traceResidues}];
polePrefactor = Times @@ MapThread[If[#2 > 0, #1^(-#2), 1] &, {traceAlphabet, traceResidues}];
radicals = DeleteDuplicates @ Cases[{alphabet, polePrefactor},
  Power[b_, p_Rational] :> Factor[b]^(1/Denominator[p]), Infinity];
characters = Times @@@ Tuples[({1, #} &) /@ radicals];
prefactors = DeleteDuplicates[Join[1/characters, polePrefactor characters]];

prime = Lookup[Lookup[task["payload"], "method_options", <||>], "prime", 2147483647];
mod[expr_] := Mod[expr /. q_Rational :>
  Numerator[q] PowerMod[Denominator[q], -1, prime], prime];
reconstruct[a_] := Module[{r0 = prime, r1 = a, s0 = 0, s1 = 1, q},
  While[r1 > Sqrt[prime/2], q = Quotient[r0, r1];
    {r0, r1} = {r1, r0 - q r1}; {s0, s1} = {s1, s0 - q s1}]; r1/s1];
monomials[degree_] := DeleteDuplicates[Times @@@ Tuples[variables, degree]];
rows = {}; evidence = {};
Do[
  logarithmicDerivative = Together[D[prefactor, #]/prefactor] & /@ variables;
  degrees = Together[weights - variables.logarithmicDerivative];
  If[!And @@ (IntegerQ[#] && # >= 0 & /@ degrees), Continue[]];
  basisRows = Join @@ MapIndexed[Function[{degree, j},
    (UnitVector[dimension, First[j]] # &) /@ monomials[degree]], degrees];
  operators = MapThread[Map[Together, #1 + #2 IdentityMatrix[dimension], {2}] &,
    {zero, logarithmicDerivative}];
  derivatives = D[basisRows, #] & /@ variables;
  sampleCount = Ceiling[2 Length[basisRows]/(dimension Max[1, Length[variables] - 1])] + 5;
  equations = Join @@ Table[
    point = Thread[variables -> Prime[Range[Length[variables]] + k Length[variables]]];
    sampledBasis = mod[basisRows /. point];
    Join @@ MapThread[mod[Transpose[mod[#1 /. point]] +
        Transpose[mod[#2 /. point]].Transpose[sampledBasis]] &,
      {derivatives, operators}], {k, 0, sampleCount - 1}];
  polynomials = ((reconstruct /@ #).basisRows &) /@ NullSpace[equations, Modulus -> prime];
  verified = Select[polynomials, Function[row, And @@ Flatten[Table[
    (Together[#] === 0 & /@ (D[row, variables[[i]]] + row.operators[[i]])),
    {i, Length[variables]}]]]];
  rows = Join[rows, (Factor[prefactor #] &) /@ verified];
  AppendTo[evidence, <|"prefactor" -> prefactor, "degrees" -> degrees,
    "unknown_count" -> Length[basisRows], "exact_horizontal_rows" -> Length[verified]|>],
  {prefactor, prefactors}];
selection = Fold[If[MatrixRank[rows[[Append[#1, #2]]]] > Length[#1],
  Append[#1, #2], #1] &, {}, Range[Length[rows]]];
rows = rows[[selection]];

(* A two-dimensional rank defect may require an epsilon-singular completion. *)
If[dimension === 2 && Length[rows] === 1,
  horizontal = First[rows];
  complement = SelectFirst[IdentityMatrix[2], Together[Det[{horizontal, #}]] =!= 0 &];
  rows = {horizontal, Together[determinant/Det[{horizontal, complement}]] complement};
  frame = CanonMethodCard`GaugeTransform[matrices, variables, Map[Together, Inverse[rows], {2}]];
  primitive = CanonMethodCard`AlgebraicPrimitive[
    -(Together[#[[1, 2]]/regulator] /. regulator -> 0) & /@ frame, variables];
  entry = SelectFirst[frame[[All, 2, 1]], # =!= 0 &];
  profile = Together[entry/(entry /. regulator -> 0)];
  If[primitive === $Failed || !FreeQ[profile, Alternatives @@ variables], exhausted[]];
  rows = Map[Together, DiagonalMatrix[{1, regulator/profile}].
    {{1, regulator primitive/profile}, {0, 1}}.rows, {2}];
];
If[Length[rows] =!= dimension, exhausted[]];
transformation = Map[Together, Inverse[rows], {2}];
transformed = CanonMethodCard`GaugeTransform[matrices, variables, transformation];
value = Join[KeyTake[cut, {"sector", "family_id", "basis_id", "basis", "variables", "regulator"}], <|
  "schema" -> "canon-neu/core-candidates/v1", "source_basis" -> cut["basis"],
  "coefficient_domain" -> "exact-algebraic-functions",
  "convention" -> "old_basis = transformation . new_basis",
  "method" -> <|"id" -> "epsilon-zero-polynomial", "prime" -> prime, "evidence" -> evidence|>,
  "candidate_group_pool" -> <|"declared" -> 1, "eligible" -> 1, "remaining" -> 0,
    "unconsumed_candidates" -> 0, "pool_exhausted" -> True|>,
  "candidates" -> {<|"candidate_id" -> "epsilon-zero-polynomial:1",
    "member_candidate_ids" -> ("epsilon-zero:row:" <> ToString[#] & /@ Range[dimension]),
    "new_basis_rows" -> rows, "full_new_basis_rows" -> rows,
    "construction_rejection" -> None, "transformation" -> transformation,
    "transformed_matrices" -> transformed|>}|>];
path = CanonMethodCard`WriteWLArtifact[value, outputDir, "core-candidates.wl"];
CanonMethodCard`WriteProviderResult[task, outputDir, "PROVISIONAL", "CANDIDATE_TRANSFORMATION",
  <|"core_candidates" -> <|"type" -> "mathematica-expression", "path" -> FileNameTake[path]|>|>,
  <|"method_id" -> "epsilon-zero-polynomial", "candidate_count" -> 1|>];
