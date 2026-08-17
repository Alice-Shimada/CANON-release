#!/usr/bin/env wolframscript

(*
  Minimal Kira adapter.

  The collaborator supplies a prepared Kira project and the two job files.
  This script runs them, reads Kira's ordered masters and exported rules, and
  writes the only handoff needed by the differential-equation module.
*)

ClearAll[ibpFailure];
ibpFailure[tag_String, message_String] :=
  Failure[tag, <|"MessageTemplate" -> message|>];

$requestKeys = {"executable", "project", "jobs", "topology", "targets", "output", "options"};
$dataContext = "CANON`DEData`";
$allowedSystemSymbols = {
  "HoldComplete", "List", "Rule", "Plus", "Times", "Power", "Rational"
};

projectPath[project_String, relative_String] :=
  ExpandFileName[FileNameJoin[{project, relative}]];

pathInsideQ[root_String, path_String] := Module[{expandedRoot, expandedPath},
  expandedRoot = ExpandFileName[root];
  expandedPath = ExpandFileName[path];
  expandedPath === expandedRoot ||
    StringStartsQ[expandedPath, expandedRoot <> $PathnameSeparator]
];

insideProjectQ[project_String, relative_String] := Module[{root, path},
  root = ExpandFileName[project];
  path = projectPath[root, relative];
  pathInsideQ[root, path]
];

validateRequest[request_] := Module[{project, jobs, targets, output},
  If[
    !AssociationQ[request] || Sort[Keys[request]] =!= Sort[$requestKeys] ||
      !StringQ[request["executable"]] || request["executable"] === "" ||
      !StringQ[request["project"]] ||
      !MatchQ[request["jobs"], {_String, _String}] ||
      !StringQ[request["topology"]] ||
      !StringMatchQ[request["topology"], RegularExpression["[A-Za-z$][A-Za-z0-9$]*"]] ||
      !StringQ[request["targets"]] ||
      !StringQ[request["output"]] ||
      !VectorQ[request["options"], StringQ],
    Return[ibpFailure["IBP_INPUT_INVALID", "The request does not match the minimal Kira interface."]]
  ];
  project = ExpandFileName[request["project"]];
  jobs = request["jobs"];
  targets = request["targets"];
  output = ExpandFileName[request["output"]];
  If[FileType[project] =!= Directory,
    Return[ibpFailure["IBP_INPUT_INVALID", "The prepared Kira project does not exist."]]
  ];
  If[
    !AllTrue[Join[jobs, {targets}], insideProjectQ[project, #] &] ||
      !AllTrue[Join[jobs, {targets}], FileType[projectPath[project, #]] === File &],
    Return[ibpFailure["IBP_INPUT_INVALID", "A job or target file is outside the prepared project or missing."]]
  ];
  If[FileExistsQ[output],
    Return[ibpFailure["IBP_INPUT_INVALID", "The Kira output directory must be fresh."]]
  ];
  If[pathInsideQ[project, output],
    Return[ibpFailure["IBP_INPUT_INVALID", "The Kira output directory cannot be inside the prepared project."]]
  ];
  Join[request, <|"project" -> project, "output" -> output|>]
];

safeHeldExpression[text_String, topology_String] := Module[
  {held, symbols, callHeads},
  held = Quiet @ Check[
    Block[{$Context = $dataContext, $ContextPath = {"System`"}},
      ToExpression[text, InputForm, HoldComplete]
    ],
    $Failed
  ];
  If[held === $Failed,
    Return[ibpFailure["IBP_OUTPUT_INVALID", "A Kira expression could not be parsed."]]
  ];
  symbols = DeleteDuplicates @ Cases[
    held,
    symbol_Symbol :> {Context[Unevaluated[symbol]], SymbolName[Unevaluated[symbol]]},
    Infinity,
    Heads -> True
  ];
  callHeads = DeleteDuplicates @ Cases[
    held,
    HoldPattern[head_[___]] :> {Context[Unevaluated[head]], SymbolName[Unevaluated[head]]},
    Infinity
  ];
  If[
    Cases[held, _String | _Real, Infinity] =!= {} ||
      AnyTrue[
        symbols,
        (First[#] === "System`" && !MemberQ[$allowedSystemSymbols, Last[#]]) ||
          !MemberQ[{"System`", $dataContext}, First[#]] &
      ] ||
      AnyTrue[callHeads, First[#] =!= "System`" && Last[#] =!= topology &],
    Return[ibpFailure["IBP_OUTPUT_INVALID", "A Kira expression contains an unsupported construct."]]
  ];
  held
];

familyIntegralQ[expression_, head_Symbol] :=
  Head[expression] === head && Length[expression] > 0 &&
    VectorQ[List @@ expression, IntegerQ];

familyIntegrals[expression_, head_Symbol] := DeleteDuplicates @ Cases[
  expression,
  item_ /; !AtomQ[Unevaluated[item]] && Head[Unevaluated[item]] === head :> item,
  {0, Infinity}
];

stripComment[line_String] :=
  StringTrim @ StringReplace[line, RegularExpression["#.*$"] -> ""];

readIntegralList[path_String, topology_String] := Module[
  {lines, held, expressions, head},
  If[FileType[path] =!= File,
    Return[ibpFailure["IBP_OUTPUT_MISSING", "A required Kira integral list is missing."]]
  ];
  lines = Select[
    stripComment /@ StringSplit[Import[path, "Text"], {"\r\n", "\n", "\r"}],
    # =!= "" &
  ];
  If[lines === {}, Return[ibpFailure["IBP_OUTPUT_INVALID", "A Kira integral list is empty."]]];
  held = safeHeldExpression["{" <> StringRiffle[lines, ","] <> "}", topology];
  If[FailureQ[held], Return[held]];
  expressions = ReleaseHold[held];
  head = Symbol[$dataContext <> topology];
  If[
    !ListQ[expressions] || !AllTrue[expressions, familyIntegralQ[#, head] &] ||
      Length[DeleteDuplicates[Length /@ expressions]] =!= 1,
    Return[ibpFailure["IBP_OUTPUT_INVALID", "An integral list entry is not topology[integer,...]."]]
  ];
  expressions
];

readRules[path_String, topology_String] := Module[
  {held, rules, head, leftSides, calls},
  If[FileType[path] =!= File,
    Return[ibpFailure["IBP_OUTPUT_MISSING", "The exported Kira rule file is missing."]]
  ];
  held = safeHeldExpression[Import[path, "Text"], topology];
  If[FailureQ[held], Return[held]];
  rules = ReleaseHold[held];
  head = Symbol[$dataContext <> topology];
  If[!ListQ[rules] || !AllTrue[rules, MatchQ[#, _Rule] &],
    Return[ibpFailure["IBP_OUTPUT_INVALID", "The Kira export is not a list of immediate rules."]]
  ];
  leftSides = First[List @@ #] & /@ rules;
  calls = familyIntegrals[rules, head];
  If[
    !AllTrue[leftSides, familyIntegralQ[#, head] &] ||
      DuplicateFreeQ[leftSides] =!= True ||
      !AllTrue[calls, familyIntegralQ[#, head] &],
    Return[ibpFailure["IBP_OUTPUT_INVALID", "The Kira rules contain malformed family integrals."]]
  ];
  rules
];

verifyClosure[targets_List, masters_List, rules_List] := Module[
  {leftSides, residuals},
  leftSides = First[List @@ #] & /@ rules;
  If[
    Intersection[masters, leftSides] =!= {} ||
      !SubsetQ[Join[masters, leftSides], targets],
    Return[ibpFailure["IBP_REDUCTION_INCOMPLETE", "A requested target is neither a master nor a reduced left-hand side."]]
  ];
  residuals = DeleteDuplicates @ Flatten[
    familyIntegrals[Last[List @@ #], Head[First[masters]]] & /@ rules
  ];
  If[!SubsetQ[masters, residuals],
    Return[ibpFailure["IBP_REDUCTION_INCOMPLETE", "The exported rules are not fully reduced to the master basis."]]
  ];
  True
];

runJob[request_Association, job_String] := Module[{process},
  process = Quiet @ Check[
    RunProcess[
      Join[{request["executable"]}, request["options"], {job}],
      All,
      ProcessDirectory -> request["output"]
    ],
    $Failed
  ];
  If[process === $Failed || Lookup[process, "ExitCode", 1] =!= 0,
    ibpFailure["IBP_PROCESS_FAILED", "A Kira job exited unsuccessfully."],
    True
  ]
];

reduceKiraProject[rawRequest_] := Module[
  {request, jobResult, topology, targetName, masters, targets, rules, closure},
  request = validateRequest[rawRequest];
  If[FailureQ[request], Return[request]];
  Quiet[ClearAll["CANON`DEData`*"]];
  CopyDirectory[request["project"], request["output"]];
  Do[
    jobResult = runJob[request, job];
    If[FailureQ[jobResult], Return[jobResult]],
    {job, request["jobs"]}
  ];
  topology = request["topology"];
  targetName = FileNameTake[request["targets"]];
  masters = readIntegralList[
    FileNameJoin[{request["output"], "results", topology, "masters.final"}],
    topology
  ];
  If[FailureQ[masters], Return[masters]];
  rules = readRules[
    FileNameJoin[{request["output"], "results", topology, "kira_" <> targetName <> ".m"}],
    topology
  ];
  If[FailureQ[rules], Return[rules]];
  targets = readIntegralList[projectPath[request["project"], request["targets"]], topology];
  If[FailureQ[targets], Return[targets]];
  closure = verifyClosure[targets, masters, rules];
  If[FailureQ[closure], Return[closure]];
  <|"masters" -> masters, "rules" -> rules|>
];

arguments = Rest[$ScriptCommandLine];
If[Length[arguments] =!= 2,
  Print["Usage: wolframscript -file mma/ReduceIBP.wls REQUEST.json RESULT.wl"];
  Exit[2]
];

request = Quiet @ Check[Import[First[arguments], "RawJSON"], $Failed];
If[request === $Failed,
  Print[InputForm[ibpFailure["IBP_INPUT_INVALID", "The request is not valid JSON."]]];
  Exit[2]
];
If[FileExistsQ[Last[arguments]],
  Print[InputForm[ibpFailure["IBP_INPUT_INVALID", "The result file must be fresh."]]];
  Exit[2]
];

result = reduceKiraProject[request];
If[FailureQ[result], Print[InputForm[result]]; Exit[1]];
If[Quiet @ Check[Put[result, Last[arguments]]; True, False] =!= True,
  Print[InputForm[ibpFailure["IBP_OUTPUT_INVALID", "The result file could not be written."]]];
  Exit[1]
];
Print[InputForm[result]];
Exit[0];
