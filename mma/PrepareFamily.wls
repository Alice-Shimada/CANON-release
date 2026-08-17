#!/usr/bin/env wolframscript

(* Demo only. The production preparation step belongs to the collaborator. *)

scriptDirectory = DirectoryName[$InputFileName];
source = FileNameJoin[{
  DirectoryName[scriptDirectory], "tests", "fixtures", "kira-one-loop-box"
}];
arguments = Rest[$ScriptCommandLine];

If[Length[arguments] =!= 1,
  Print["Usage: wolframscript -file mma/PrepareFamily.wls OUTPUT_DIR"];
  Exit[2]
];

output = ExpandFileName[First[arguments]];
If[
  $VersionNumber < 14 || FileType[source] =!= Directory || FileExistsQ[output],
  Print[InputForm @ Failure[
    "PREPARE_DEMO_FAILED",
    <|"MessageTemplate" -> "The demo requires Wolfram 14+, its bundled fixture, and a fresh output directory."|>
  ]];
  Exit[1]
];

CopyDirectory[source, output];
result = <|
  "project" -> output,
  "family" -> FileNameJoin[{output, "prepared-derivatives-v2.wl"}]
|>;
Print[InputForm[result]];
Exit[0];
