(* Compatibility entry for fixed official-reference verification only. *)
repoRoot = DirectoryName[DirectoryName[ExpandFileName[$InputFileName]]];
Get[FileNameJoin[{repoRoot, "methods", "initial", "reference", "check.wls"}]];
