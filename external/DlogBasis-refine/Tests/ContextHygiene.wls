#!/usr/bin/env wolframscript

Clear[
  packageRoot, finiteFlowFile, globalNamesBefore, globalNamesAfter,
  family, result, summary, contextLoop
];
packageRoot = DirectoryName[DirectoryName[$InputFileName]];
finiteFlowFile = Last[$ScriptCommandLine];
globalNamesBefore = Names["Global`*"];
Get[FileNameJoin[{packageRoot, "DlogBasis.wl"}]];
family = DlogBasis`CreateDlogFamily[
  "LoopMomenta" -> {contextLoop},
  "Propagators" -> {contextLoop^2}
];
result = DlogBasis`DlogBasisSearch[
  family, {1},
  "LoopSpecifications" -> {
    <|"Momentum" -> contextLoop, "BaseDimension" -> 2|>
  },
  "DotDegreeBound" -> 1,
  "FiniteFlowPackageFile" -> finiteFlowFile
];
globalNamesAfter = Names["Global`*"];
summary = <|
  "ScientificStatus" -> result["ScientificStatus"],
  "PackageCreatedGlobalNames" -> Complement[globalNamesAfter, globalNamesBefore]
|>;
Print[InputForm[summary]];
Exit[If[summary === <|
  "ScientificStatus" -> "AffineFiniteMaximalCutCandidate",
  "PackageCreatedGlobalNames" -> {}
|>, 0, 1]];
