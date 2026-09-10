#!/usr/bin/env wolframscript

$HistoryLength = 0;
repoRoot = DirectoryName[DirectoryName[ExpandFileName[$InputFileName]]];
Get[FileNameJoin[{repoRoot, "mma", "lib", "MethodCardCore.wl"}]];
{inputPath, outputDir} = ExpandFileName /@ CanonMethodCard`ScriptArguments[];
task = CanonMethodCard`ReadTask[inputPath, "SOLVE_TAIL"];
fullDE = CanonMethodCard`LoadArtifact[task, inputPath, "full_sector_de"];
core = CanonMethodCard`LoadArtifact[task, inputPath, "core_transform"];
selected = SelectFirst[fullDE["candidates"], #1["candidate_id"] === core["candidate_id"] &];
variables = fullDE["variables"];
regulator = fullDE["regulator"];
transformation = selected["full_transformation"];
matrices = selected["transformed_matrices"];
alphabet = DeleteDuplicates @ Join[fullDE["alphabet"],
  CanonMethodCard`DLogAlphabet[matrices, variables, regulator]];
method = "candidate-completion";
lowerDimension = fullDE["block_boundaries", "lower_dimension"];
dimension = Length[transformation];

regulatorFactor[expression_] := Times @@ (#[[1]]^#[[2]] & /@
  Select[Rest[FactorList[expression]],
    !FreeQ[First[#], regulator] && FreeQ[First[#], Alternatives @@ variables] &]);
commonTailScale[entries_] := With[{nonzero = DeleteCases[Flatten[entries], 0]},
  Together[(PolynomialGCD @@ (regulatorFactor[Numerator[#]] & /@ nonzero))/
    (PolynomialLCM @@ (regulatorFactor[Denominator[#]] & /@ nonzero))]];

If[!CanonMethodCard`EpsilonFactorizedQ[matrices, regulator],
  tailEntries = matrices[[All, lowerDimension + 1 ;; dimension, 1 ;; lowerDimension]];
  scale = commonTailScale[tailEntries];
  normalization = DiagonalMatrix[Join[ConstantArray[1, lowerDimension],
    ConstantArray[scale, dimension - lowerDimension]]];
  transformation = Map[Together, transformation.normalization, {2}];
  matrices = CanonMethodCard`GaugeTransform[matrices, variables, normalization];
];

(* arXiv:2206.04609, Eq. (78), in the convention old = T.new. *)
If[!CanonMethodCard`EpsilonFactorizedQ[matrices, regulator] &&
    And @@ (PolynomialQ[#, regulator] && Exponent[#, regulator] <= 1 & /@
      Flatten[matrices]),
  primitive[components_] := primitive[components] =
    CanonMethodCard`AlgebraicPrimitive[components, variables];
  correction = Table[primitive[matrices[[All, i, j]] /. regulator -> 0],
    {i, lowerDimension + 1, dimension}, {j, lowerDimension}];
  If[FreeQ[correction, $Failed],
    shear = IdentityMatrix[dimension];
    shear[[lowerDimension + 1 ;; dimension, 1 ;; lowerDimension]] = correction;
    transformation = Map[Together, transformation.shear, {2}];
    matrices = CanonMethodCard`GaugeTransform[matrices, variables, shear];
    method = "affine-epsilon-primitive"
  ];
];

(* One seed and its first derivatives; the cut is aligned by a small inverse. *)
firstDerivativeCompletion[] := Module[
  {current = Range[lowerDimension + 1, dimension], lower = Range[lowerDimension],
   sourceRoots, align, seed, trial, trialT, trialAlphabet, w, k, pivots, rows,
   correction, shear, scale, normalization},
  If[Length[current] < 2, Return[$Failed]];
  sourceRoots = DeleteDuplicates @ Cases[fullDE["source_matrices"],
    Power[b_, p_Rational] /; Denominator[p] === 2 :> Factor[b], Infinity];
  (* Generate in the source's root field; CHECK_CANONICAL checks the source gauge. *)
  align[value_] := Fold[Function[{expression, base}, With[{b = base},
    expression /. Power[a_, p_Rational] /;
      Denominator[p] === 2 && !MemberQ[sourceRoots, Factor[a]] &&
        Expand[a + b] === 0 :> I^(2 p) b^p]], value, sourceRoots];
  seed = current[[First @ Ordering[
    ({Count[#, Except[0]], LeafCount[#]} & /@
      selected["new_basis_rows"][[current]]), 1]]];
  trial = align[selected["transformed_matrices"]];
  trialT = align[selected["full_transformation"]];
  trialAlphabet = Together /@ align[alphabet];
  w = Prepend[trial[[All, seed]], UnitVector[dimension, seed]];
  k = w[[All, current]];
  pivots = (First @ FirstPosition[#, x_ /; x =!= 0, Missing[], {1}, Heads -> False] &) /@
    DeleteCases[RowReduce[Transpose[k]], {0..}];
  If[Length[pivots] =!= Length[current], Return[$Failed]];
  rows = Map[Together, Inverse[k[[pivots]]].w[[pivots]], {2}];
  correction = rows[[All, lower]];
  Do[trial[[v, current, lower]] = Map[Together,
    trial[[v, current, lower]] + D[correction, variables[[v]]] +
      correction.trial[[v, lower, lower]] -
      trial[[v, current, current]].correction, {2}], {v, Length[variables]}];
  shear = IdentityMatrix[dimension];
  shear[[current, lower]] = -correction;
  trialT = Map[Together, trialT.shear, {2}];
  If[!CanonMethodCard`EpsilonFactorizedQ[trial, regulator],
    scale = commonTailScale[trial[[All, current, lower]]]/regulator;
    normalization = DiagonalMatrix[Join[ConstantArray[1, lowerDimension],
      ConstantArray[scale, Length[current]]]];
    trialT = Map[Together, trialT.normalization, {2}];
    trial[[All, current, lower]] =
      Map[Together, trial[[All, current, lower]]/scale, {3}]
  ];
  If[CanonMethodCard`EpsilonFactorizedQ[trial, regulator] &&
      CanonMethodCard`DLogConnectionQ[trial, variables, regulator, trialAlphabet],
    {trialT, trial, trialAlphabet}, $Failed]
];

tailSolved = CanonMethodCard`DLogConnectionQ[matrices, variables, regulator, alphabet];
If[!tailSolved,
  completion = firstDerivativeCompletion[];
  If[completion =!= $Failed,
    {transformation, matrices, alphabet} = completion;
    method = "scalar-first-derivative-completion"; tailSolved = True]
];

unsolved[] := (CanonMethodCard`WriteResult[task, outputDir,
  "INCONCLUSIVE", "TAIL_UNSOLVED", <||>,
  <|"candidate_id" -> core["candidate_id"], "method" -> method|>]; Quit[0]);

If[!tailSolved,
  method = "canonica-off-diagonal";
  package = CanonMethodCard`ResolveMethodPackage[task, inputPath, "CANONICA`"];
  Get[package["entry"]];
  dependencies = Table[Union @@ (Flatten[Position[#[[i]],
      x_ /; x =!= 0, {1}, Heads -> False]] & /@ matrices), {i, dimension}];
  active = FixedPoint[Union[#, Flatten[dependencies[[#]]]] &,
    Range[lowerDimension + 1, dimension]];
  activeLower = Count[active, i_ /; i <= lowerDimension];
  boundaries = If[activeLower === 0, {{1, Length[active]}},
    {{1, activeLower}, {activeLower + 1, Length[active]}}];
  backendMatrices = matrices[[All, active, active]];
  result = CANONICA`TransformOffDiagonalBlock[
    variables, boundaries, IdentityMatrix[Length[active]],
    backendMatrices /. regulator -> CANONICA`eps, CANONICA`VerbosityLevel -> 0];
  If[!MatrixQ[result[[1]]], unsolved[]];
  embedding = IdentityMatrix[dimension][[active]];
  lifted = IdentityMatrix[dimension] +
    Transpose[embedding].(result[[1]] - IdentityMatrix[Length[active]]).embedding;
  backendMatrices = matrices /. regulator -> CANONICA`eps;
  boundaries = If[lowerDimension === 0, {{1, dimension}},
    {{1, lowerDimension}, {lowerDimension + 1, dimension}}];
  result = CANONICA`TransformDlogToEpsForm[
    variables, boundaries, lifted,
    CanonMethodCard`GaugeTransform[backendMatrices, variables, lifted],
    CANONICA`VerbosityLevel -> 0];
  If[!MatrixQ[result[[1]]], unsolved[]];
  backendTransformation = result[[1]] /. CANONICA`eps -> regulator;
  transformation = Map[Together, transformation.backendTransformation, {2}];
  matrices = CanonMethodCard`GaugeTransform[fullDE["source_matrices"], variables, transformation];
  alphabet = DeleteDuplicates @ Join[fullDE["alphabet"],
    CanonMethodCard`DLogAlphabet[matrices, variables, regulator]];
];

value = <|"schema" -> "canon-neu/sector-transform/v1",
  "sector" -> fullDE["sector"], "family_id" -> fullDE["family_id"],
  "current_basis_id" -> fullDE["current_basis_id"],
  "accepted_prefix_id" -> fullDE["accepted_prefix_id"],
  "coefficient_domain" -> "exact-algebraic-functions",
  "source_basis" -> fullDE["source_basis"], "variables" -> variables,
  "regulator" -> regulator, "alphabet" -> alphabet,
  "convention" -> fullDE["convention"], "candidate_id" -> core["candidate_id"],
  "member_candidate_ids" -> selected["member_candidate_ids"],
  "transformation" -> transformation, "transformed_matrices" -> matrices,
  "method" -> method|>;
path = CanonMethodCard`WriteWLArtifact[value, outputDir, "sector-transform.wl"];
CanonMethodCard`WriteResult[task, outputDir, "PASS", "TAIL_READY",
  <|"sector_transform" -> <|"type" -> "mathematica-expression",
    "path" -> FileNameTake[path]|>|>,
  <|"candidate_id" -> core["candidate_id"], "method" -> method|>];
