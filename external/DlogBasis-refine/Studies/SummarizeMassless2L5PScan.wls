#!/usr/bin/env wolframscript

arguments = Rest[$ScriptCommandLine];
packageRoot = DirectoryName[DirectoryName[$InputFileName]];
sectorSource = Get[arguments[[1]]];
outputFile = arguments[[2]];
scanFiles = Drop[arguments, 2];
scans = Get /@ scanFiles;
sourceRelativeFiles = {
  "DlogBasis.wl", "Kernel/DlogBasis.wl", "Kernel/FamilyAndCandidates.wl",
  "Kernel/LBLBaikov.wl", "Kernel/ResidueSignature.wl",
  "Kernel/SingularModule.wl", "Kernel/ImplicitAlgebraicResidue.wl",
  "Kernel/Interface.wl"
};
sourceFiles = FileNameJoin[{packageRoot, #}]& /@ sourceRelativeFiles;
sha256[file_] := IntegerString[FileHash[file, "SHA256"], 16, 64];

runs = Fold[
  Function[{accumulated, scan},
    ids = DeleteDuplicates[Lookup[scan["Runs"], "SectorID"]];
    Join[Select[accumulated, !MemberQ[ids, #["SectorID"]]&], scan["Runs"]]
  ],
  {},
  scans
];

runSummary[run_] := KeyTake[run, {
  "LoopOrder", "LoopDimensions", "ScientificStatus", "CombinationCount",
  "CandidateCount", "RepresentedCount", "CandidateChartCompleteQ",
  "CandidateParities", "CoefficientDirections",
  "AffineFiniteConstantResiduesVerifiedQ"
}];

summary = Map[
  Function[sector,
    sectorRuns = Select[runs, #["SectorID"] === sector["SectorID"]&];
    targetDimension = Select[sectorRuns, #["LoopDimensions"] === {4, 4}&];
    uniformShift = Select[sectorRuns,
      SameQ@@#["LoopDimensions"] && #["LoopDimensions"] =!= {4, 4}&
    ];
    mixed = Select[sectorRuns, !SameQ@@#["LoopDimensions"]&];
    targetMaximum = Max[
      Append[Lookup[targetDimension, "CombinationCount"], 0]
    ];
    uniformShiftMaximum = Max[
      Append[Lookup[uniformShift, "CombinationCount"], 0]
    ];
    mixedMaximum = Max[Append[Lookup[mixed, "CombinationCount"], 0]];
    target = sector["ArticleMasterCount"];
    classification = Which[
      targetMaximum >= target, "TargetDimensionCountReached",
      targetMaximum > 0, "TargetDimensionPartial",
      uniformShiftMaximum >= target, "UniformDimensionShiftProposalOnly",
      uniformShiftMaximum > 0, "UniformDimensionShiftPartialProposal",
      mixedMaximum >= target, "MixedDimensionProposalOnly",
      mixedMaximum > 0, "MixedDimensionPartialProposal",
      MemberQ[Lookup[sectorRuns, "ScientificStatus"],
        "MultivariateAlgebraicCoverUnresolved"],
        "MethodUnresolvedMultivariateCover",
      True, "NoDirectionWithinScannedConfigurations"
    ];
    Join[KeyTake[sector, {
      "SectorID", "Sector", "ArticleMasterCount", "ArticleMasterIndices",
      "NumeratorDegreeBound", "DotDegreeBound"
    }], <|
      "TargetDimensionMaximum" -> targetMaximum,
      "UniformDimensionShiftMaximum" -> uniformShiftMaximum,
      "MixedMaximum" -> mixedMaximum,
      "Classification" -> classification,
      "BestTargetDimensionRuns" -> If[targetMaximum === 0, {}, runSummary /@
        Select[targetDimension, #["CombinationCount"] === targetMaximum&]],
      "BestUniformDimensionShiftRuns" -> If[
        targetMaximum > 0 || uniformShiftMaximum === 0,
        {},
        runSummary /@ Select[uniformShift,
          #["CombinationCount"] === uniformShiftMaximum&]
      ],
      "BestMixedRuns" -> If[
        targetMaximum > 0 || uniformShiftMaximum > 0 || mixedMaximum === 0,
        {},
        runSummary /@ Select[mixed,
          #["CombinationCount"] === mixedMaximum&]]
    |>]
  ],
  sectorSource["Sectors"]
];

result = <|
  "Metadata" -> <|
    "SectorCount" -> Length[summary],
    "ArticleMasterCount" -> Total[Lookup[summary, "ArticleMasterCount"]],
    "ConfigurationCount" -> Length[runs],
    "PaperBasisSHA256" -> sectorSource["Metadata"]["PaperBasisSHA256"],
    "PackageBaselineCommit" -> sectorSource["Metadata"]["PackageCommit"],
    "PackageSourceSHA256" -> AssociationThread[
      sourceRelativeFiles, sha256 /@ sourceFiles
    ],
    "WolframVersion" -> sectorSource["Metadata"]["WolframVersion"],
    "ScanSHA256" -> (sha256 /@ scanFiles)
  |>,
  "ClassificationCounts" -> Counts[Lookup[summary, "Classification"]],
  "Sectors" -> summary
|>;
Put[result, outputFile];
Print@InputForm[result["Metadata"]];
Print@InputForm[result["ClassificationCounts"]];
Scan[
  Print@InputForm@Lookup[#, {
    "SectorID", "Sector", "ArticleMasterCount", "NumeratorDegreeBound",
    "DotDegreeBound", "TargetDimensionMaximum",
    "UniformDimensionShiftMaximum", "MixedMaximum", "Classification"
  }]&,
  summary
];
