BeginPackage["CanonInitialCore`"];
PrepareSeedSystem::usage = "PrepareSeedSystem[A,x,rows,sourceBasis,currentBasis,counts] completes normalized seed rows and checks their exact derivative rank.";
ComposeCandidate::usage = "ComposeCandidate[prepared,T] composes INITIAL's intermediate transformation with the original full seed rows.";
BridgeRows::usage = "BridgeRows[bridge,preparedFamily,ids] extracts exactly reduced, dimension-substituted rows for explicitly selected candidate IDs.";
Begin["`Private`"];

bad[stage_, message_, details_: <||>] := Failure["SEED_PREPARATION", Join[
  <|"stage" -> stage, "reason" -> message|>, details]];
exactRowsQ[rows_, nr_, nc_] := MatrixQ[rows] && Dimensions[rows] === {nr, nc} &&
  And @@ (CanonMethodCard`ExactRationalExpressionQ /@ Flatten[rows]);
rat[value_] := Map[Together, value, {2}];

BridgeRows[bridge_Association, family_Association, ids_List] := Module[
  {source, records, recordIDs, dimensionRule, selected, expressions, rows, remainder},
  source = Lookup[bridge, "masters", None];
  records = Lookup[bridge, "candidates", None];
  dimensionRule = Lookup[family, "dimension_rule", None];
  If[Lookup[bridge, "schema", None] =!= "canon-neu/candidate-ibp-bridge/v1" ||
      !ListQ[source] || source === {} || !DuplicateFreeQ[source] ||
      !ListQ[records] || !And @@ (AssociationQ /@ records) ||
      !MatchQ[dimensionRule, _Rule | {_Rule ..}],
    Return[bad["bridge_input", "Invalid bridge masters, candidates, or prepared_family.dimension_rule"]]];
  recordIDs = Lookup[records, "candidate_id", None];
  If[!DuplicateFreeQ[recordIDs] || !And @@ (StringQ /@ recordIDs) ||
      !And @@ (MemberQ[recordIDs, #] & /@ ids),
    Return[bad["bridge_input", "Selected seed IDs must exist uniquely in the bridge"]]];
  selected = (records[[First @ FirstPosition[recordIDs, #]]]) & /@ ids;
  If[!And @@ (KeyExistsQ[#, "reduced_expression"] & /@ selected),
    Return[bad["bridge_input", "Every selected seed needs reduced_expression"]]];
  expressions = (#["reduced_expression"] /. dimensionRule) & /@ selected;
  rows = (Function[expression, Together[Coefficient[expression, #]] & /@ source]) /@ expressions;
  If[!exactRowsQ[rows, Length[ids], Length[source]],
    Return[bad["bridge_reduction", "Reduced seed coefficients must be exact rational functions"]]];
  remainder = MapThread[Together[#1 - #2.source] &, {expressions, rows}];
  If[!And @@ (TrueQ[# === 0] & /@ remainder) || !FreeQ[rows, Alternatives @@ source],
    Return[bad["bridge_reduction", "A seed is not a fully reduced linear combination of the declared masters"]]];
  <|"source_basis" -> source, "rows" -> rows,
    "reduced_expressions" -> expressions, "dimension_rule" -> dimensionRule|>
];
BridgeRows[___] := bad["bridge_input", "Invalid candidate bridge input"];

PrepareSeedSystem[a_?MatrixQ, x_Symbol, rows_, source_List, current_List, counts_List] := Module[
  {n = Length[current], m, positions, cutRows, selectedRows, fullRows, rank, row, reduced, pivots,
    rCut, aSeed, psi, derivativeRows, takeRow, symbols, point, sampled, witness = None},
  m = Length[rows];
  If[n < 1 || source === {} || !DuplicateFreeQ[source] || !DuplicateFreeQ[current] ||
      !And @@ (MemberQ[source, #] & /@ current) || Dimensions[a] =!= {n, n} ||
      !exactRowsQ[rows, m, Length[source]] || m < 1 || m > n ||
      Length[counts] =!= m || !And @@ (IntegerQ[#] && # > 0 & /@ counts) || Total[counts] =!= n,
    Return[bad["seed_input", "Seed dimensions, source order, or derivative counts are invalid"]]];
  positions = (First @ FirstPosition[source, #]) & /@ current;
  cutRows = rows[[All, positions]];
  reduced = RowReduce[cutRows];
  pivots = (First @ FirstPosition[#, entry_ /; !TrueQ[Together[entry] === 0],
    Missing["pivot"], {1}, Heads -> False]) & /@
    DeleteCases[reduced, {0 ..}];
  rank = Length[pivots];
  If[rank =!= m, Return[bad["seed_projection", "Selected seed projections are dependent",
    <|"rank" -> rank, "required_rank" -> m, "dimension" -> n|>]]];
  selectedRows = cutRows;
  fullRows = rows;
  Do[
    row = UnitVector[n, i];
    AppendTo[selectedRows, row];
    AppendTo[fullRows, ReplacePart[ConstantArray[0, Length[source]], positions[[i]] -> 1]],
    {i, Complement[Range[n], pivots]}];
  rCut = selectedRows;
  aSeed = rat[(D[rCut, x] + rCut.a).Inverse[rCut]];
  derivativeRows = Table[
    (* INITIAL's psi begins with D[f], not f. k means k derivatives. *)
    NestList[Map[Together, D[#, x] + #.aSeed] &, aSeed[[i]], counts[[i]] - 1],
    {i, m}];
  psi = Flatten[derivativeRows, 1];
  (* A full exact rank at a regular rational point proves the determinant is
     not the zero rational function. Failed points make no deficiency claim. *)
  symbols = DeleteDuplicates[Cases[psi, _Symbol, Infinity]];
  rank = 0;
  Do[
    point = Thread[symbols -> (Prime[Range[Length[symbols]] + offset]/
      Prime[Range[Length[symbols]] + offset + Length[symbols] + 2])];
    sampled = Quiet @ Check[psi /. point, $Failed];
    If[MatrixQ[sampled, NumberQ] &&
        FreeQ[sampled, _Real | Indeterminate | ComplexInfinity | DirectedInfinity[___]],
      rank = MatrixRank[sampled];
      If[rank === n, witness = point; Break[]]],
    {offset, 0, 2}];
  If[rank =!= n, rank = MatrixRank[psi]];
  If[rank =!= n, Return[bad["psi_rank", "The selected derivative allocation does not span the cut",
    <|"rank" -> rank, "required_rank" -> n, "dimension" -> n,
      "derivative_counts" -> counts, "seed_projection_rank" -> m|>]]];
  takeRow = If[m === 1, 1, Transpose[{Range[m], counts}]];
  <|"R_cut" -> rCut, "R_full" -> fullRows, "A_seed" -> aSeed,
    "source_basis" -> source, "current_positions" -> positions, "Psi" -> psi,
    "psi_rank" -> rank, "psi_rank_witness" -> witness,
    "seed_projection_rank" -> m, "take_row" -> takeRow,
    "derivative_counts" -> counts|>
];
PrepareSeedSystem[___] := bad["seed_input", "Unsupported seed system"];

ComposeCandidate[prepared_Association, t_?MatrixQ] :=
  ComposeCandidate[prepared, t, rat[Inverse[t].prepared["R_full"]]];
ComposeCandidate[prepared_Association, t_?MatrixQ, full_?MatrixQ] := Module[{n, tCore, projected},
  n = Length[prepared["R_cut"]];
  If[!exactRowsQ[t, n, n] || !exactRowsQ[full, n, Length[prepared["source_basis"]]],
    Return[bad["transformation_rank", "INITIAL did not return an exact invertible full transformation",
      <|"dimension" -> n|>]]];
  tCore = rat[Inverse[prepared["R_cut"]].t];
  projected = full[[All, prepared["current_positions"]]];
  If[!CanonMethodCard`ZeroMatrixQ[t.full - prepared["R_full"]] ||
      !CanonMethodCard`ZeroMatrixQ[projected.tCore - IdentityMatrix[n]] ||
      !CanonMethodCard`ZeroMatrixQ[tCore.projected - IdentityMatrix[n]],
    Return[bad["full_row_projection", "Full rows do not project to the inverse core transformation"]]];
  <|"transformation" -> tCore, "full_new_basis_rows" -> full|>
];
ComposeCandidate[___] := bad["transformation_rank", "INITIAL returned no matrix"];
End[];
EndPackage[];
