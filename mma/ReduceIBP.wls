#!/usr/bin/env wolframscript

arguments = Rest[$ScriptCommandLine];
request = Import[First[arguments], "RawJSON"];
CopyDirectory[request["project"], request["output"]];

Do[
  process = RunProcess[
    Join[{request["executable"]}, request["options"], {job}],
    All,
    ProcessDirectory -> request["output"]
  ];
  If[process["ExitCode"] =!= 0, Print[InputForm[process]]; Exit[process["ExitCode"]]],
  {job, request["jobs"]}
];

topology = request["topology"];
targetName = FileNameTake[request["targets"]];
masterLines = StringTrim @ StringReplace[
  StringSplit[
    Import[FileNameJoin[{request["output"], "results", topology, "masters.final"}], "Text"],
    {"\r\n", "\n", "\r"}
  ],
  RegularExpression["#.*$"] -> ""
];
masterLines = Select[masterLines, # =!= "" &];
result = Block[{$Context = "CANON`DEData`", $ContextPath = {"System`"}},
  <|
    "masters" -> ToExpression["{" <> StringRiffle[masterLines, ","] <> "}"],
    "rules" -> Get[FileNameJoin[{
      request["output"], "results", topology, "kira_" <> targetName <> ".m"
    }]]
  |>
];
Put[result, Last[arguments]];
Print[InputForm[Length /@ result]];
