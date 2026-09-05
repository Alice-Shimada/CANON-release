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

If[!CanonMethodCard`EpsilonFactorizedQ[matrices, regulator],
  tailEntries = DeleteCases[Flatten[
    matrices[[All, lowerDimension + 1 ;; dimension, 1 ;; lowerDimension]]], 0];
  regulatorFactor[expression_] := Times @@ (#[[1]]^#[[2]] & /@
    Select[Rest[FactorList[expression]],
      !FreeQ[First[#], regulator] && FreeQ[First[#], Alternatives @@ variables] &]);
  scale = Together[(PolynomialGCD @@ (regulatorFactor[Numerator[#]] & /@ tailEntries))/
    (PolynomialLCM @@ (regulatorFactor[Denominator[#]] & /@ tailEntries))];
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

unsolved[] := (CanonMethodCard`WriteResult[task, outputDir,
  "INCONCLUSIVE", "TAIL_UNSOLVED", <||>,
  <|"candidate_id" -> core["candidate_id"], "method" -> method|>]; Quit[0]);

If[!CanonMethodCard`DLogConnectionQ[matrices, variables, regulator, alphabet],
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
