(* Private completion routines for SOLVE_TAIL. No task or artifact IO. *)
BeginPackage["CanonTailCompletion`"];
CompleteAlgebraicTail; CompleteRationalTail; TailDiagnostics;
Begin["`Private`"];

regulatorFactor[expression_, variables_List, regulator_] := Times @@ (#[[1]]^#[[2]] & /@
  Select[Rest[FactorList[expression]],
    !FreeQ[First[#], regulator] && FreeQ[First[#], Alternatives @@ variables] &]);
commonTailScale[entries_, variables_List, regulator_] := With[
  {nonzero = DeleteCases[Flatten[entries], 0]},
  Together[(PolynomialGCD @@ (regulatorFactor[Numerator[#], variables, regulator] & /@ nonzero))/
    (PolynomialLCM @@ (regulatorFactor[Denominator[#], variables, regulator] & /@ nonzero))]];
affineEpsilonQ[value_, regulator_] := And @@ (PolynomialQ[#, regulator] &&
  Exponent[#, regulator] <= 1 & /@ Flatten[value]);

(* Resum a scalar affine primitive at a quadratic-root pole. A nonaffine
   input may first use the same cut normalization with a neutral lower lift. *)
scalarRootPrimitive[sourceMatrices_, variables_List, regulator_, lowerDimension_Integer,
    transformation_, matrices_, alphabet_List, method_String] := Module[
  {dimension = Length[transformation], trialT = transformation, trial = matrices, neutral, scale, normalization,
   roots, radicand, primitive, p, q, coordinate, marker, equations, solutions,
   c, change, trialAlphabet},
  If[dimension - lowerDimension =!= 1 || lowerDimension === 0, Return[$Failed]];
  roots = DeleteDuplicates @ Cases[trial,
    Power[b_, exponent_Rational] /; Denominator[exponent] === 2 &&
      !FreeQ[b, Alternatives @@ variables] :> Factor[b], Infinity];
  If[Length[roots] =!= 1, Return[$Failed]];
  trialAlphabet = DeleteDuplicates @ Join[alphabet,
    CanonMethodCard`QuadraticRootLetters[trial, variables]];
  If[CanonMethodCard`DLogConnectionQ[trial, variables, regulator, trialAlphabet],
    Return[{trialT, trial, trialAlphabet, method}]];
  neutral = !affineEpsilonQ[trial, regulator];
  If[neutral,
    trialT[[dimension, 1 ;; lowerDimension]] = ConstantArray[0, lowerDimension];
    trial = CanonMethodCard`GaugeTransform[sourceMatrices, variables, trialT]];
  If[CanonMethodCard`ZeroMatrixQ[{trial[[All, dimension, 1 ;; lowerDimension]]}],
    Return[$Failed]];
  scale = commonTailScale[trial[[All, dimension, 1 ;; lowerDimension]], variables, regulator];
  normalization = DiagonalMatrix[Join[ConstantArray[1, lowerDimension], {scale}]];
  trialT = Map[Factor, trialT.normalization, {2}];
  trial[[All, dimension, 1 ;; lowerDimension]] =
    Map[Together, trial[[All, dimension, 1 ;; lowerDimension]]/scale, {2}];
  If[!affineEpsilonQ[trial, regulator], Return[$Failed]];
  primitive = Table[CanonMethodCard`AlgebraicPrimitive[
    trial[[All, dimension, j]] /. regulator -> 0, variables], {j, lowerDimension}];
  If[!FreeQ[primitive, $Failed], Return[$Failed]];
  radicand = First[roots];
  p = Map[Together, trial[[All, 1 ;; lowerDimension, 1 ;; lowerDimension]]/regulator, {3}];
  q = Together /@ (trial[[All, dimension, dimension]]/regulator);
  coordinate = SelectFirst[Range[Length[variables]], D[radicand, variables[[#]]] =!= 0 &];
  marker = Unique["residue$"];
  equations = Last /@ CoefficientRules[Numerator[Together[PolynomialRemainder[
    Numerator[Together[q[[coordinate]] -
      marker D[radicand, variables[[coordinate]]]/radicand]],
    radicand, variables[[coordinate]]]]], variables];
  solutions = Solve[Thread[equations == 0], marker];
  If[solutions === {}, Return[$Failed]];
  c = marker /. First[solutions];
  If[!NumberQ[c], Return[$Failed]];
  change = IdentityMatrix[dimension];
  change[[dimension, 1 ;; lowerDimension]] = primitive/(1 + 2 c regulator);
  change[[dimension, dimension]] = 1/(1 + 2 c regulator);
  trial[[All, dimension, 1 ;; lowerDimension]] = Table[Factor /@ (
    (1 + 2 c regulator) trial[[v, dimension, 1 ;; lowerDimension]] +
    regulator (q[[v]] primitive - primitive.p[[v]]) - D[primitive, variables[[v]]]),
    {v, Length[variables]}];
  trialT = Map[Factor, trialT.change, {2}];
  trialAlphabet = DeleteDuplicates @ Join[alphabet,
    CanonMethodCard`DLogAlphabet[trial, variables, regulator],
    CanonMethodCard`QuadraticRootLetters[trial, variables]];
  If[CanonMethodCard`DLogConnectionQ[trial, variables, regulator, trialAlphabet],
    {trialT, trial, trialAlphabet,
      If[neutral, "scalar-cut-root-primitive", "scalar-root-primitive"]}, $Failed]
];

(* arXiv:2206.04609, Eq. (78), in the convention old = T.new. *)
affinePrimitive[variables_List, regulator_, lowerDimension_Integer, transformation_, matrices_] :=
 Module[{dimension = Length[transformation], primitive, correction, shear},
  primitive[components_] := primitive[components] =
    CanonMethodCard`AlgebraicPrimitive[components, variables];
  correction = Table[primitive[matrices[[All, i, j]] /. regulator -> 0],
    {i, lowerDimension + 1, dimension}, {j, lowerDimension}];
  If[!FreeQ[correction, $Failed], Return[$Failed]];
  shear = IdentityMatrix[dimension];
  shear[[lowerDimension + 1 ;; dimension, 1 ;; lowerDimension]] = correction;
  {Map[Together, transformation.shear, {2}],
    CanonMethodCard`GaugeTransform[matrices, variables, shear]}
];

(* One seed and its first derivatives; the cut is aligned by a small inverse. *)
firstDerivativeCompletion[sourceMatrices_, selected_Association, variables_List, regulator_,
    lowerDimension_Integer, alphabet_List] := Module[
  {dimension = Length[selected["full_transformation"]], current, lower = Range[lowerDimension],
   sourceRoots, align, seed, trial, trialT, trialAlphabet, w, k, pivots, rows,
   correction, shear, scale, normalization},
  current = Range[lowerDimension + 1, dimension];
  If[Length[current] < 2, Return[$Failed]];
  sourceRoots = DeleteDuplicates @ Cases[sourceMatrices,
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
    scale = commonTailScale[trial[[All, current, lower]], variables, regulator]/regulator;
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

CompleteAlgebraicTail[fullDE_Association, selected_Association] := Module[
  {variables = fullDE["variables"], regulator = fullDE["regulator"],
   lowerDimension = fullDE["block_boundaries", "lower_dimension"],
   transformation = selected["full_transformation"], matrices = selected["transformed_matrices"],
   alphabet, method = "candidate-completion", dimension, scale, normalization,
   completion, tailSolved = False},
  dimension = Length[transformation];
  alphabet = DeleteDuplicates @ Join[fullDE["alphabet"],
    CanonMethodCard`DLogAlphabet[matrices, variables, regulator]];
  If[!CanonMethodCard`EpsilonFactorizedQ[matrices, regulator],
    scale = commonTailScale[
      matrices[[All, lowerDimension + 1 ;; dimension, 1 ;; lowerDimension]], variables, regulator];
    normalization = DiagonalMatrix[Join[ConstantArray[1, lowerDimension],
      ConstantArray[scale, dimension - lowerDimension]]];
    transformation = Map[Together, transformation.normalization, {2}];
    matrices = CanonMethodCard`GaugeTransform[matrices, variables, normalization]
  ];
  completion = scalarRootPrimitive[fullDE["source_matrices"], variables, regulator,
    lowerDimension, transformation, matrices, alphabet, method];
  If[completion =!= $Failed,
    {transformation, matrices, alphabet, method} = completion; tailSolved = True];
  If[!CanonMethodCard`EpsilonFactorizedQ[matrices, regulator] && affineEpsilonQ[matrices, regulator],
    completion = affinePrimitive[variables, regulator, lowerDimension, transformation, matrices];
    If[completion =!= $Failed,
      {transformation, matrices} = completion; method = "affine-epsilon-primitive"]
  ];
  If[!tailSolved,
    tailSolved = CanonMethodCard`DLogConnectionQ[matrices, variables, regulator, alphabet]];
  If[!tailSolved && CanonMethodCard`EpsilonFactorizedQ[matrices, regulator],
    alphabet = DeleteDuplicates @ Join[alphabet,
      CanonMethodCard`QuadraticRootLetters[matrices, variables]];
    tailSolved = CanonMethodCard`DLogConnectionQ[matrices, variables, regulator, alphabet]
  ];
  If[!tailSolved,
    completion = firstDerivativeCompletion[fullDE["source_matrices"], selected,
      variables, regulator, lowerDimension, alphabet];
    If[completion =!= $Failed,
      {transformation, matrices, alphabet} = completion;
      method = "scalar-first-derivative-completion"; tailSolved = True]
  ];
  <|"transformation" -> transformation, "matrices" -> matrices, "alphabet" -> alphabet,
    "method" -> method, "solved" -> tailSolved|>
];

TailDiagnostics[fullDE_Association, solution_Association] := With[
  {matrices = solution["matrices"], regulator = fullDE["regulator"]},
  <|"current_master_count" -> Length[solution["transformation"]] -
      fullDE["block_boundaries", "lower_dimension"],
    "epsilon_factorized" -> CanonMethodCard`EpsilonFactorizedQ[matrices, regulator],
    "affine_in_epsilon" -> affineEpsilonQ[matrices, regulator],
    "rational_coefficients" -> And @@
      (CanonMethodCard`ExactRationalExpressionQ /@ Flatten[matrices]),
    "alphabet_candidate_count" -> Length[solution["alphabet"]]|>
];

(* The return is held at the call site, before passing it to this constructor. *)
backendFailure[stage_String, candidateID_, packageEntry_String, backendReturn_HoldComplete,
    variables_List, positions_List, boundaries_List, initialTransformation_, backendMatrices_] :=
  <|"schema" -> "canon-neu/tail-backend-failure/v1", "stage" -> stage,
    "candidate_id" -> candidateID, "package_entry" -> packageEntry,
    "backend_return" -> backendReturn,
    "call" -> <|"variables" -> variables, "regulator" -> CANONICA`eps,
      "active_positions" -> positions, "sector_boundaries" -> boundaries,
      "initial_transformation" -> initialTransformation, "matrices" -> backendMatrices,
      "options" -> {CANONICA`VerbosityLevel -> 0}|>|>;

CompleteRationalTail[fullDE_Association, candidateID_, solution_Association, packageEntry_String] := Module[
  {variables = fullDE["variables"], regulator = fullDE["regulator"],
   lowerDimension = fullDE["block_boundaries", "lower_dimension"],
   transformation = solution["transformation"], matrices = solution["matrices"],
   dimension, dependencies, active, activeLower, boundaries, backendMatrices,
   result, embedding, lifted, backendTransformation, alphabet},
  dimension = Length[transformation];
  Get[packageEntry];
  dependencies = Table[Union @@ (Flatten[Position[#[[i]],
      x_ /; x =!= 0, {1}, Heads -> False]] & /@ matrices), {i, dimension}];
  active = FixedPoint[Union[#, Flatten[dependencies[[#]]]] &,
    Range[lowerDimension + 1, dimension]];
  activeLower = Count[active, i_ /; i <= lowerDimension];
  boundaries = If[activeLower === 0, {{1, Length[active]}},
    {{1, activeLower}, {activeLower + 1, Length[active]}}];
  backendMatrices = matrices[[All, active, active]] /. regulator -> CANONICA`eps;
  result = CANONICA`TransformOffDiagonalBlock[
    variables, boundaries, IdentityMatrix[Length[active]],
    backendMatrices, CANONICA`VerbosityLevel -> 0];
  If[!MatrixQ[result[[1]]], Return[Join[solution,
    <|"method" -> "canonica-off-diagonal", "backend_failure" -> backendFailure[
      "TransformOffDiagonalBlock", candidateID, packageEntry,
      Extract[OwnValues[result], {1, 2}, HoldComplete], variables, active, boundaries,
      IdentityMatrix[Length[active]], backendMatrices]|>]]];
  embedding = IdentityMatrix[dimension][[active]];
  lifted = IdentityMatrix[dimension] +
    Transpose[embedding].(result[[1]] - IdentityMatrix[Length[active]]).embedding;
  backendMatrices = CanonMethodCard`GaugeTransform[
    matrices /. regulator -> CANONICA`eps, variables, lifted];
  boundaries = If[lowerDimension === 0, {{1, dimension}},
    {{1, lowerDimension}, {lowerDimension + 1, dimension}}];
  result = CANONICA`TransformDlogToEpsForm[
    variables, boundaries, lifted, backendMatrices, CANONICA`VerbosityLevel -> 0];
  If[!MatrixQ[result[[1]]], Return[Join[solution,
    <|"method" -> "canonica-off-diagonal", "backend_failure" -> backendFailure[
      "TransformDlogToEpsForm", candidateID, packageEntry,
      Extract[OwnValues[result], {1, 2}, HoldComplete], variables, Range[dimension],
      boundaries, lifted, backendMatrices]|>]]];
  backendTransformation = result[[1]] /. CANONICA`eps -> regulator;
  transformation = Map[Together, transformation.backendTransformation, {2}];
  matrices = CanonMethodCard`GaugeTransform[fullDE["source_matrices"], variables, transformation];
  alphabet = DeleteDuplicates @ Join[fullDE["alphabet"],
    CanonMethodCard`DLogAlphabet[matrices, variables, regulator]];
  <|"transformation" -> transformation, "matrices" -> matrices, "alphabet" -> alphabet,
    "method" -> "canonica-off-diagonal", "solved" -> True|>
];

End[];
EndPackage[];
