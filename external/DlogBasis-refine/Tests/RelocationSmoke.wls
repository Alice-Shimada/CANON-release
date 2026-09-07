#!/usr/bin/env wolframscript

Clear[
  root, globalNamesBefore, globalNamesAfterLoad,
  family, lattice, result, relocationLoop
];
root = Last[$ScriptCommandLine];
globalNamesBefore = Names["Global`*"];
Get[FileNameJoin[{root, "DlogBasis.wl"}]];
globalNamesAfterLoad = Names["Global`*"];
family = DlogBasis`CreateDlogFamily[
  "LoopMomenta" -> {relocationLoop},
  "Propagators" -> {relocationLoop^2}
];
lattice = DlogBasis`EnumerateDlogCandidates[family, {1}, 0, 1];
result = <|
  "CandidateCount" -> lattice["CandidateCount"],
  "PackageCreatedGlobalNames" -> Complement[globalNamesAfterLoad, globalNamesBefore]
|>;
Print[InputForm[result]];
Exit[If[result === <|"CandidateCount" -> 2,
  "PackageCreatedGlobalNames" -> {}|>, 0, 1]];
