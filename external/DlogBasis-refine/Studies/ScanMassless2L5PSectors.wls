#!/usr/bin/env wolframscript

(* Scan the 46 master sectors in the canonical pentabox basis of arXiv:1807.09812. *)

packageRoot = DirectoryName[DirectoryName[$InputFileName]];
arguments = Rest[$ScriptCommandLine];
finiteFlowFile = arguments[[1]];
paperBasisFile = arguments[[2]];
outputFile = arguments[[3]];
requestedSectorIDs = ToExpression /@ Drop[arguments, 3];

Get[FileNameJoin[{packageRoot, "DlogBasis.wl"}]];
familyData = Get[FileNameJoin[
  {packageRoot, "Tests", "Families", "Massless2L5P.wl"}
]];
paperBasis = Get[paperBasisFile];

paperAtoms[expression_] := Cases[
  expression, G[2, indices_List] :> indices, Infinity
];

sectorBits[indices_] := Boole[# > 0]& /@ Take[indices, 8];
sectorID[indices_] := sectorBits[indices].(2^Range[0, 7]);
numeratorDegree[indices_] := Total[Max[0, -#]& /@ indices];
dotDegree[indices_] := Total[Max[0, # - 1]& /@ Take[indices, 8]];

masterIndices = DeleteDuplicates@Flatten[paperAtoms /@ paperBasis, 1];
sectorIDs = Sort[DeleteDuplicates[sectorID /@ masterIndices]];
sectorData = Table[
  sectorMasters = Select[masterIndices, sectorID[#] === id&];
  numeratorBound = Max[numeratorDegree /@ sectorMasters];
  dotBound = Max[dotDegree /@ sectorMasters];
  sector = Join[Reverse[IntegerDigits[id, 2, 8]], {0, 0, 0}];
  lattice = DlogBasis`EnumerateDlogCandidates[
    familyData["Family"], sector, numeratorBound, dotBound
  ];
  <|
    "SectorID" -> id,
    "Sector" -> sector,
    "ArticleMasterCount" -> Length[sectorMasters],
    "ArticleMasterIndices" -> sectorMasters,
    "NumeratorDegreeBound" -> numeratorBound,
    "DotDegreeBound" -> dotBound,
    "CandidateLatticeIndices" -> Lookup[lattice["Candidates"], "IndexVector"]
  |>,
  {id, sectorIDs}
];
If[requestedSectorIDs =!= {},
  sectorData = Select[sectorData, MemberQ[requestedSectorIDs, #["SectorID"]]&]
];

loops = familyData["Family"]["LoopMomenta"];
orderData = {{"Forward", loops}, {"Reverse", Reverse[loops]}};
configurations = Flatten@Table[
  <|
    "LoopOrder" -> order[[1]],
    "LoopDimensions" -> dimensions,
    "LoopSpecifications" -> (
      <|
        "Momentum" -> #,
        "BaseDimension" -> AssociationThread[loops -> dimensions][#]
      |>& /@ order[[2]]
    )
  |>,
  {order, orderData}, {dimensions, Tuples[{2, 4, 6}, 2]}
];

fullDirections[result_] := Module[
  {directions, latticeIndices, representedIndices, positions},
  directions = Lookup[Lookup[result, "ModuleLift", <||>],
    "CoefficientDirections", {}];
  latticeIndices = Lookup[result["CandidateLattice"]["Candidates"],
    "IndexVector"];
  representedIndices = Lookup[Lookup[result, "RepresentedCandidates", {}],
    "IndexVector"];
  positions = First@FirstPosition[latticeIndices, #]& /@ representedIndices;
  ReplacePart[
    ConstantArray[0, Length[latticeIndices]],
    Thread[positions -> #]
  ]& /@ directions
];

runs = {};
metadata = <|
  "Paper" -> "arXiv:1807.09812",
  "PaperBasisURL" ->
    "https://arxiv.org/src/1807.09812v1/anc/pentabox_basis2.txt",
  "PaperBasisSHA256" -> IntegerString[FileHash[paperBasisFile, "SHA256"], 16, 64],
  "PackageCommit" -> Replace[Environment["DLOGBASIS_REVISION"], $Failed -> Null],
  "PackageEntrySHA256" -> FileHash[
    FileNameJoin[{packageRoot, "DlogBasis.wl"}], "SHA256", "HexString"],
  "WolframVersion" -> $Version,
  "SectorCount" -> Length[sectorData],
  "ArticleMasterCount" -> Total[Lookup[sectorData, "ArticleMasterCount"]]
|>;

Do[
  {elapsed, result} = AbsoluteTiming[DlogBasis`DlogBasisSearch[
    familyData["Family"], data["Sector"],
    "LoopSpecifications" -> config["LoopSpecifications"],
    "NumeratorDegreeBound" -> data["NumeratorDegreeBound"],
    "DotDegreeBound" -> data["DotDegreeBound"],
    "FiniteFlowPackageFile" -> finiteFlowFile
  ]];
  run = <|
    "SectorID" -> data["SectorID"],
    "LoopOrder" -> config["LoopOrder"],
    "LoopDimensions" -> config["LoopDimensions"],
    "ElapsedSeconds" -> elapsed,
    "ScientificStatus" -> result["ScientificStatus"],
    "CandidateCount" -> result["CandidateLattice"]["CandidateCount"],
    "RepresentedCount" -> Length[Lookup[result, "RepresentedCandidates", {}]],
    "CandidateChartCompleteQ" -> Lookup[result, "CandidateChartCompleteQ", False],
    "CombinationCount" -> Length[Lookup[result, "CandidateCombinations", {}]],
    "CandidateParities" -> Lookup[result, "CandidateParities", {}],
    "CoefficientDirections" -> fullDirections[result],
    "AffineFiniteConstantResiduesVerifiedQ" ->
      Lookup[result, "AffineFiniteConstantResiduesVerifiedQ", False],
    "ConstantLeadingSingularityCertifiedQ" ->
      result["ConstantLeadingSingularityCertifiedQ"]
  |>;
  runs = Append[runs, run];
  Put[<|"Metadata" -> metadata, "Sectors" -> sectorData, "Runs" -> runs|>,
    outputFile];
  Print[InputForm[KeyTake[run, {
    "SectorID", "LoopOrder", "LoopDimensions", "ElapsedSeconds",
    "ScientificStatus", "CandidateCount", "RepresentedCount",
    "CombinationCount", "CandidateParities"
  }]]],
  {data, sectorData}, {config, configurations}
];
