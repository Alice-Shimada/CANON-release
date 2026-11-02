(* Loaded inside CanonTailCompletion`Private`. No task IO or new workflow controls.
   Normalize A = Sum[R_l(eps) dlog W_l] by a kinematically constant S(eps).
   The cleared equation is mu R_l(eps).S - eps S.R_l(mu) == 0, on the COMPLETE
   prefix. This is the CANONICA residue intertwiner, with algebraic letters and
   bounded sparse elimination instead of a dense symbolic Solve. *)

(* Capture the implementation actually loaded, separately from the D backend's
   checkpoint binding. A later disk edit must not relabel an already loaded hook. *)
dlogNormalizationImplementation = <|
  "normalizer_sha256" -> FileHash[$InputFileName, "SHA256", "HexString"],
  "complexity_sha256" -> residueComplexityImplementation,
  "pole_repair_sha256" -> FileHash[FileNameJoin[{DirectoryName[$InputFileName],
    "RationalPoleRepair.wl"}], "SHA256", "HexString"]|>;

dlogNormalizationStop[stage_String] := Throw[stage, dlogNormalizationBound];
dlogZeroQ[value_] := TrueQ[Together[value] === 0];
dlogMatrixZeroQ[value_] := AllTrue[Flatten[value], dlogZeroQ];

dlogSparseAdd[row_Association, column_Integer, term_] := Module[{value},
  value = Together[Lookup[row, column, 0] + term];
  If[value === 0, KeyDrop[row, column], Join[row, <|column -> value|>]]
];

(* Batch a row update before canonicalizing each field coefficient. Rational
   rows go first, with shorter rows first to reduce fill. These are invertible
   row operations over Q(eps), never a regulator specialization. *)
dlogSparseSubtract[row_Association, pivot_Association, factor_] :=
  Select[Map[Together, Merge[{row, Map[-factor # &, pivot]}, Total]], # =!= 0 &];
dlogRationalRowQ[row_] := AllTrue[Values[row], IntegerQ[#] || Head[#] === Rational &];

(* Keep every full-prefix coordinate, including inactive-to-active couplings.
   Only exact zero rows are omitted; unknown order and the full kernel remain. *)
dlogSparseKernel[residues_List, sampled_List, regulator_, reference_] := Module[
  {n = Length[First[residues]], pivots = <||>, work = 0, stored = 0,
   row, column, factor, pivot, left, right, free, order, vector, basis,
   rows = {}, inputStored = 0, rationalRows},
  rows = Reap[Do[
    left = Table[Select[Range[n], !dlogZeroQ[residues[[l, i, #]]] &], {i, n}];
    right = Table[Select[Range[n], !dlogZeroQ[sampled[[l, #, j]]] &], {j, n}];
    Do[
      row = Association[Table[((a - 1) n + j) -> Together[reference residues[[l, i, a]]],
        {a, left[[i]]}]];
      Do[row = dlogSparseAdd[row, (i - 1) n + b, -regulator sampled[[l, b, j]]],
        {b, right[[j]]}];
      If[Length[row] > 0,
        factor = row[Min[Keys[row]]];
        row = Map[Together[#/factor] &, row];
        Sow[row]; inputStored += Length[row]];
      If[inputStored > 2000000, dlogNormalizationStop["storage_bound"]],
      {i, n}, {j, n}], {l, Length[residues]}]][[2]];
  rows = If[rows === {}, {}, First[rows]];
  rationalRows = Count[rows, r_ /; dlogRationalRowQ[r]];
  rows = SortBy[rows, {Boole[!dlogRationalRowQ[#]], Length[#]} &];
  Do[
      row = input;
      While[Length[row] > 0,
        column = Min[Keys[row]];
        If[!KeyExistsQ[pivots, column],
          factor = row[column];
          pivot = Association @ KeyValueMap[#1 -> Together[#2/factor] &, row];
          AssociateTo[pivots, column -> pivot]; stored += Length[pivot];
          If[inputStored + stored > 2000000, dlogNormalizationStop["storage_bound"]];
          Break[]];
        pivot = pivots[column]; factor = row[column];
        work += Length[pivot];
        row = dlogSparseSubtract[row, pivot, factor];
        If[inputStored + stored + Length[row] > 2000000,
          dlogNormalizationStop["storage_bound"]];
      ], {input, rows}];
  free = Complement[Range[n n], Keys[pivots]];
  If[Length[free] n n > 2000000, dlogNormalizationStop["nullspace_storage_bound"]];
  order = Reverse[Sort[Keys[pivots]]];
  basis = Table[
    vector = ConstantArray[0, n n]; vector[[f]] = 1;
    Do[pivot = pivots[column];
      vector[[column]] = Together[-Total[KeyValueMap[#2 vector[[#1]] &, pivot]]],
      {column, order}]; vector, {f, free}];
  <|"basis" -> basis, "free_columns" -> free, "rank" -> Length[pivots],
    "row_operations" -> work, "rational_row_count" -> rationalRows,
    "input_nonzeros" -> inputStored, "stored_pivot_nonzeros" -> stored,
    "row_order" -> "rational_first_increasing_nonzeros"|>
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
  If[nonzero === {}, Return[<|"transformation" -> IdentityMatrix[n],
    "normalized_residues" -> residues, "diagnostics" -> diagnostics|>]];
  Do[
    sampled = Quiet[nonzero /. regulator -> reference];
    If[!AllTrue[Flatten[sampled], CanonMethodCard`ExactRationalExpressionQ], Continue[]];
    kernel = dlogSparseKernel[nonzero, sampled, regulator, reference];
    diagnostics = Join[diagnostics, KeyTake[kernel, {"rank", "row_operations",
      "rational_row_count", "input_nonzeros", "stored_pivot_nonzeros", "row_order"}],
      <|"nullity" -> Length[kernel["basis"]]|>];
    patterns = dlogCoefficientPatterns[kernel["free_columns"], n];
    Do[
      change = Map[Together, Partition[pattern.kernel["basis"], n], {2}];
      determinant = Together[Det[SparseArray[change]]];
      If[!CanonMethodCard`ExactRationalExpressionQ[determinant] || determinant === 0, Continue[]];
      If[!And @@ MapThread[dlogMatrixZeroQ[reference #1.change - regulator change.#2] &,
          {nonzero, sampled}], Continue[]];
      diagnostics = Join[diagnostics, <|"reference" -> ToString[reference, InputForm]|>];
      Throw[<|"transformation" -> change,
        "normalized_residues" -> Map[Together, (regulator/reference) (residues /. regulator -> reference), {3}],
        "diagnostics" -> diagnostics|>, dlogIntertwinerResult], {pattern, patterns}],
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
   outcome, alphabet, residues, normalization, change, transformation, matrices,
   residual, compact, stage = "not_dlog"},
  outcome = TimeConstrained[Catch[
    If[n > 128, dlogNormalizationStop["dimension_bound"]];
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
      normalization = If[residues === {} ||
          AllTrue[Flatten[residues], FreeQ[Together[#/regulator], regulator] &],
        <|"transformation" -> IdentityMatrix[n], "normalized_residues" -> residues, "diagnostics" -> <||>|>,
        dlogIntertwiner[residues, regulator]];
      diagnostics = Join[diagnostics, normalization["diagnostics"]];
      change = normalization["transformation"];
      If[change === $Failed, Continue[]];
      transformation = Map[Together, frame[[1]].change, {2}];
      matrices = Table[Total[MapThread[#1 Together[D[#2, v]/#2] &,
        {normalization["normalized_residues"], alphabet}]], {v, variables}];
      If[alphabet === {}, matrices = ConstantArray[ConstantArray[0, {n, n}], Length[variables]]];
      (* The exact differential identity checks the COMPLETE source without
         forming another inverse of its growing cumulative transformation. *)
      residual = MapThread[Normal[SparseArray[#1].SparseArray[transformation] -
        SparseArray[D[transformation, #3]] - SparseArray[transformation].SparseArray[#2]] &,
        {fullDE["source_matrices"], matrices, variables}];
      stage = "final_epsilon_or_dlog_check";
      If[dlogMatrixZeroQ[residual] &&
          CanonMethodCard`DLogConnectionQ[matrices, variables, regulator, alphabet],
        Throw[<|"solved" -> True, "transformation" -> transformation, "matrices" -> matrices,
          "alphabet" -> alphabet|>, dlogNormalizationBound]], {frame, frames}];
    stage, dlogNormalizationBound], maxWall, "wall_budget"];
  If[AssociationQ[outcome],
    (* The original exact solution is already available. Optional refinement
       cannot consume its success or reorder the main intertwiner search. *)
    compact = compactDLogAnchor[outcome, residues, normalization, variables, regulator,
      Max[0, Min[1/2, maxWall/50, maxWall - (AbsoluteTime[] - started)]]];
    outcome = compact["solution"];
    If[TrueQ[compact["diagnostics", "applied"]] || KeyExistsQ[compact["diagnostics"], "reason"],
      diagnostics = Join[diagnostics, <|"anchor_compaction" -> compact["diagnostics"]|>]];
    Join[outcome, <|"diagnostics" -> Join[diagnostics,
      <|"stage" -> "normalized", "wall_seconds" -> AbsoluteTime[] - started,
        "implementation" -> dlogNormalizationImplementation|>]|>],
    <|"solved" -> False, "diagnostics" -> Join[diagnostics,
      <|"stage" -> outcome, "wall_seconds" -> AbsoluteTime[] - started,
        "implementation" -> dlogNormalizationImplementation|>]|>
  ]
];

(* Shared post-D completion. Its proposals stay inside SOLVE_TAIL; a failure
   retains the native backend path and all independent acceptance gates. *)
CompleteDLogTail[matrices_List, variables_List, regulator_, lower_Integer,
    alphabet_List, maxWall_] := TimeConstrained[Module[
  {n = Length[First[matrices]], started = AbsoluteTime[], frame = matrices,
   change, repair, evidence = <||>, full, result},
  change = IdentityMatrix[n];
  If[Length[variables] === 1 && lower > 0 && n <= 128,
    repair = CanonRationalTailPoleRepair`Repair[First[frame], First[variables], regulator, lower];
    If[AssociationQ[repair],
      change = repair["transformation"]; frame = {repair["matrices"]};
      evidence = <|"pole_repair" -> <|"corrections" -> Length[repair["steps"]],
        "checks" -> repair["checks"]|>|>,
      evidence = <|"pole_repair" -> <|"reason" -> ToString[repair, InputForm]|>|>]
  ];
  full = <|"variables" -> variables, "regulator" -> regulator,
    "source_basis" -> Range[n], "source_matrices" -> matrices|>;
  result = completeDLogEpsilon[full, {{change, frame}}, alphabet,
    Max[0.001, maxWall - (AbsoluteTime[] - started)]];
  Join[result, <|"diagnostics" -> Join[result["diagnostics"], evidence]|>]
], maxWall, <|"solved" -> False, "diagnostics" -> <|"stage" -> "wall_budget",
  "implementation" -> dlogNormalizationImplementation|>|>];
