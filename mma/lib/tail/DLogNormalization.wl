(* Loaded inside CanonTailCompletion`Private`. No task IO or new workflow controls.
   Normalize A = Sum[R_l(eps) dlog W_l] by a kinematically constant S(eps).
   The cleared equation is mu R_l(eps).S - eps S.R_l(mu) == 0, on the COMPLETE
   prefix. This is the CANONICA residue intertwiner, with algebraic letters and
   bounded sparse elimination instead of a dense symbolic Solve. *)

dlogNormalizationStop[stage_String] := Throw[stage, dlogNormalizationBound];
dlogZeroQ[value_] := TrueQ[Together[value] === 0];
dlogMatrixZeroQ[value_] := AllTrue[Flatten[value], dlogZeroQ];

dlogSparseAdd[row_Association, column_Integer, term_] := Module[{value},
  value = Together[Lookup[row, column, 0] + term];
  If[value === 0, KeyDrop[row, column], Join[row, <|column -> value|>]]
];

(* Rows retain global n^2 unknown indices, including inactive-to-active
   couplings. The smallest nonzero column is the pivot; no block partition or
   numerical rank test is used. Generate one row at a time to bound storage. *)
dlogSparseKernel[residues_List, sampled_List, regulator_, reference_] := Module[
  {n = Length[First[residues]], pivots = <||>, work = 0, stored = 0,
   row, column, factor, pivot, left, right, free, order, vector, basis},
  Do[
    left = Table[Select[Range[n], !dlogZeroQ[residues[[l, i, #]]] &], {i, n}];
    right = Table[Select[Range[n], !dlogZeroQ[sampled[[l, #, j]]] &], {j, n}];
    Do[
      row = Association[Table[((a - 1) n + j) -> Together[reference residues[[l, i, a]]],
        {a, left[[i]]}]];
      Do[row = dlogSparseAdd[row, (i - 1) n + b, -regulator sampled[[l, b, j]]],
        {b, right[[j]]}];
      While[Length[row] > 0,
        column = Min[Keys[row]];
        If[!KeyExistsQ[pivots, column],
          factor = row[column];
          pivot = Association @ KeyValueMap[#1 -> Together[#2/factor] &, row];
          AssociateTo[pivots, column -> pivot]; stored += Length[pivot];
          If[stored > 2000000, dlogNormalizationStop["storage_bound"]];
          Break[]];
        pivot = pivots[column]; factor = row[column];
        work += Length[pivot];
        If[work > 2000000, dlogNormalizationStop["row_operation_bound"]];
        KeyValueMap[(row = dlogSparseAdd[row, #1, -factor #2]) &, pivot];
      ], {i, n}, {j, n}], {l, Length[residues]}];
  free = Complement[Range[n n], Keys[pivots]];
  If[Length[free] n n > 2000000, dlogNormalizationStop["nullspace_storage_bound"]];
  order = Reverse[Sort[Keys[pivots]]];
  basis = Table[
    vector = ConstantArray[0, n n]; vector[[f]] = 1;
    Do[pivot = pivots[column];
      vector[[column]] = Together[-Total[KeyValueMap[#2 vector[[#1]] &, pivot]]],
      {column, order}]; vector, {f, free}];
  <|"basis" -> basis, "free_columns" -> free, "rank" -> Length[pivots],
    "row_operations" -> work|>
];

dlogCoefficientPatterns[free_List, n_Integer] := Module[{k = Length[free], patterns},
  If[k === 0, Return[{}]];
  patterns = {ConstantArray[1, k], Boole[Quotient[# - 1, n] === Mod[# - 1, n]] & /@ free};
  patterns = Join[patterns, Table[ReplacePart[ConstantArray[0, k], i -> 1], {i, Min[k, 128]}]];
  If[k <= 7, patterns = Join[patterns, Tuples[{0, 1}, k]]];
  If[k <= 4, patterns = Join[patterns, Tuples[{0, 1, 2}, k]]];
  Take[DeleteDuplicates[DeleteCases[patterns, {0..}]], UpTo[512]]
];

dlogIntertwiner[residues_List, regulator_] := Catch[Module[
  {n = Length[First[residues]], nonzero, sampled, kernel, patterns, change, determinant,
   diagnostics},
  nonzero = Select[residues, !dlogMatrixZeroQ[#] &];
  diagnostics = <|"nonzero_residues" -> Length[nonzero]|>;
  If[nonzero === {}, Return[<|"transformation" -> IdentityMatrix[n], "diagnostics" -> diagnostics|>]];
  Do[
    sampled = Quiet[nonzero /. regulator -> reference];
    If[!AllTrue[Flatten[sampled], CanonMethodCard`ExactRationalExpressionQ], Continue[]];
    kernel = dlogSparseKernel[nonzero, sampled, regulator, reference];
    diagnostics = Join[diagnostics, KeyTake[kernel, {"rank", "row_operations"}],
      <|"nullity" -> Length[kernel["basis"]]|>];
    patterns = dlogCoefficientPatterns[kernel["free_columns"], n];
    Do[
      change = Map[Together, Partition[pattern.kernel["basis"], n], {2}];
      determinant = Together[Det[change]];
      If[!CanonMethodCard`ExactRationalExpressionQ[determinant] || determinant === 0 ||
          MatrixRank[change] =!= n, Continue[]];
      If[!And @@ MapThread[dlogMatrixZeroQ[reference #1.change - regulator change.#2] &,
          {nonzero, sampled}], Continue[]];
      diagnostics = Join[diagnostics, <|"reference" -> ToString[reference, InputForm]|>];
      Throw[<|"transformation" -> change, "diagnostics" -> diagnostics|>, dlogIntertwinerResult], {pattern, patterns}],
    {reference, {1, -1, 2, -2, 1/2, -1/2, 3, 4, 5}}];
  <|"transformation" -> $Failed, "diagnostics" -> diagnostics|>
], dlogIntertwinerResult];

dlogFieldSize[expressions_, variables_] := Module[{powers, bases},
  powers = DeleteDuplicates @ Cases[expressions,
    Power[b_, p_Rational] /; !FreeQ[b, Alternatives @@ variables] :>
      {Factor[b], Denominator[p]}, Infinity];
  bases = DeleteDuplicates[First /@ powers];
  Times @@ ((LCM @@ Cases[powers, {#, order_} :> order]) & /@ bases)
];

completeDLogEpsilon[fullDE_, frames_List, initialAlphabet_List, maxWall_] := Module[
  {variables = fullDE["variables"], regulator = fullDE["regulator"],
   n = Length[fullDE["source_basis"]], started = AbsoluteTime[], diagnostics = <||>,
   outcome, alphabet, residues, normalization, change, transformation, matrices, stage = "not_dlog"},
  outcome = TimeConstrained[Catch[
    If[n > 64, dlogNormalizationStop["dimension_bound"]];
    Do[
      alphabet = DeleteDuplicates @ Join[initialAlphabet,
        CanonMethodCard`DLogAlphabet[frame[[2]], variables, regulator],
        CanonMethodCard`QuadraticRootLetters[frame[[2]], variables]];
      diagnostics = <|"dimension" -> n, "alphabet_size" -> Length[alphabet]|>;
      If[Length[alphabet] > 128 || Length[alphabet] n n > 400000,
        dlogNormalizationStop["system_bound"]];
      If[dlogFieldSize[{frame[[2]], alphabet}, variables] > 256,
        dlogNormalizationStop["field_bound"]];
      residues = CanonMethodCard`DLogFormResidues[frame[[2]], variables, regulator, alphabet];
      If[residues === $Failed, Continue[]];
      stage = "residue_domain";
      If[!AllTrue[Flatten[residues], CanonMethodCard`ExactRationalExpressionQ], Continue[]];
      stage = "finite_intertwiner_search";
      normalization = If[residues === {}, <|"transformation" -> IdentityMatrix[n], "diagnostics" -> <||>|>,
        dlogIntertwiner[residues, regulator]];
      diagnostics = Join[diagnostics, normalization["diagnostics"]];
      change = normalization["transformation"];
      If[change === $Failed, Continue[]];
      transformation = Map[Together, frame[[1]].change, {2}];
      matrices = CanonMethodCard`GaugeTransform[fullDE["source_matrices"], variables, transformation];
      stage = "final_epsilon_or_dlog_check";
      If[CanonMethodCard`DLogConnectionQ[matrices, variables, regulator, alphabet],
        Throw[<|"solved" -> True, "transformation" -> transformation, "matrices" -> matrices,
          "alphabet" -> alphabet|>, dlogNormalizationBound]], {frame, frames}];
    stage, dlogNormalizationBound], maxWall, "wall_budget"];
  If[AssociationQ[outcome],
    Join[outcome, <|"diagnostics" -> Join[diagnostics,
      <|"stage" -> "normalized", "wall_seconds" -> AbsoluteTime[] - started|>]|>],
    <|"solved" -> False, "diagnostics" -> Join[diagnostics,
      <|"stage" -> outcome, "wall_seconds" -> AbsoluteTime[] - started|>]|>
  ]
];
