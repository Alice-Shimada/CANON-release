(* Compatibility entry for fixed official-reference verification only. *)
repoRoot = DirectoryName[DirectoryName[ExpandFileName[$InputFileName]]];
Get[FileNameJoin[{repoRoot, "examples", "initial-official-ladder", "check.wls"}]];
