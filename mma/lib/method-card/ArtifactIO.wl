(* Script envelopes, declared paths, artifact IO, and typed result publication.
   Loaded inside CanonMethodCard`Private` by MethodCardCore.wl. *)

failure[tag_String, message_String] := Failure[tag, <|"Message" -> message|>];

ScriptArguments[] := Module[{scriptArguments, position},
  scriptArguments = Quiet @ Check[$ScriptCommandLine, {}];
  If[ListQ[scriptArguments] && Length[scriptArguments] > 1,
    Return[Rest[scriptArguments]]
  ];
  position = FirstPosition[$CommandLine, "-script", Missing["not-found"]];
  If[MissingQ[position],
    position = FirstPosition[$CommandLine, "-file", Missing["not-found"]]
  ];
  If[MissingQ[position], {}, Drop[$CommandLine, First[position] + 1]]
];

ReadTask[path_String, expectedStep_String] := Module[{task},
  task = Quiet @ Check[Import[path, "RawJSON"], $Failed];
  If[!AssociationQ[task], Return[failure["INVALID_INPUT", "input is not a JSON object"]]];
  If[Lookup[task, "schema", None] =!= "canon-neu/script-input/v1",
    Return[failure["INVALID_INPUT", "unexpected input schema"]]
  ];
  If[Lookup[task, "step", None] =!= expectedStep,
    Return[failure["INVALID_INPUT", "unexpected workflow step"]]
  ];
  If[!StringQ[Lookup[task, "task_id", None]] || !AssociationQ[Lookup[task, "payload", None]],
    Return[failure["INVALID_INPUT", "task_id or payload is missing"]]
  ];
  task
];

artifactPath[inputPath_String, descriptor_Association] := Module[{raw},
  raw = Lookup[descriptor, "path", Missing["path"]];
  If[!StringQ[raw], Return[$Failed]];
  ResolveInputPath[inputPath, raw]
];

absolutePathQ[path_String] := If[
  $OperatingSystem === "Windows",
  StringMatchQ[path, LetterCharacter ~~ ":" ~~ ("/" | "\\") ~~ ___] ||
    StringStartsQ[path, "\\\\"] || StringStartsQ[path, "//"],
  StringStartsQ[path, $PathnameSeparator]
];

ResolveInputPath[inputPath_String, path_String] := ExpandFileName[
  If[absolutePathQ[path], path, FileNameJoin[{DirectoryName[ExpandFileName[inputPath]], path}]]
];

RelativeArtifactPath[declaringFile_String, target_String] := Module[
  {base, parts, common = 0},
  base = FileNameSplit[DirectoryName[ExpandFileName[declaringFile]]];
  parts = FileNameSplit[ExpandFileName[target]];
  While[common < Min[Length[base], Length[parts]] &&
    base[[common + 1]] === parts[[common + 1]], common++];
  If[common === 0, Return[ExpandFileName[target]]];
  FileNameJoin[Join[ConstantArray["..", Length[base] - common], Drop[parts, common]]]
];

ResolveMethodPackage[task_Association, inputPath_String, context_String] := Module[
  {options, requested, path, source},
  options = Lookup[Lookup[task, "payload", <||>], "method_options", <||>];
  If[!AssociationQ[options],
    Return[failure["INVALID_METHOD_OPTIONS", "method_options must be an Association"]]
  ];
  requested = Lookup[options, "package_entry", Automatic];
  Which[
    requested === Automatic,
      path = Quiet @ Check[FindFile[context], $Failed];
      source = "wolfram-package-path",
    StringQ[requested] && requested =!= "",
      path = ResolveInputPath[inputPath, requested];
      source = "method_options.package_entry",
    True,
      Return[failure["INVALID_METHOD_OPTIONS", "package_entry must be a non-empty path string"]]
  ];
  If[!StringQ[path] || FileType[path] =!= File,
    Return[failure["METHOD_PACKAGE_UNAVAILABLE", "declared method package could not be resolved"]]
  ];
  <|"entry" -> ExpandFileName[path], "source" -> source|>
];

symbolFromName[name_String] := Module[{held},
  held = Quiet @ Check[Block[{$Context = "CANON`DEData`", $ContextPath = {"System`"}},
    ToExpression[name, InputForm, HoldComplete]], $Failed];
  If[MatchQ[held, HoldComplete[_Symbol]], First[held], $Failed]
];

ParseSymbolRules[mapping_Association] := Module[{rules},
  rules = KeyValueMap[Function[{source, target},
    If[!StringQ[source] || !StringQ[target], $Failed,
      With[{from = symbolFromName[source], to = symbolFromName[target]},
        If[from === $Failed || to === $Failed, $Failed, from -> to]]]], mapping];
  If[MemberQ[rules, $Failed], $Failed, rules]
];
ParseSymbolRules[_] := $Failed;

ReadWLData[path_String] := Block[
  {$Context = "CANON`DEData`", $ContextPath = {"System`"}}, Get[path]];

ResolveArtifactPath[inputPath_String, descriptor_] := Module[{path},
  If[!AssociationQ[descriptor], Return[failure["MISSING_ARTIFACT", "missing file descriptor"]]];
  path = artifactPath[inputPath, descriptor];
  If[path === $Failed || FileType[path] =!= File,
    Return[failure["MISSING_ARTIFACT", "declared path is not a file"]]
  ];
  If[KeyExistsQ[descriptor, "sha256"] &&
      (!StringQ[descriptor["sha256"]] ||
        ToLowerCase[descriptor["sha256"]] =!= FileHash[path, "SHA256", "HexString"]),
    Return[failure["SOURCE_HASH_MISMATCH", path <> " does not match its declared SHA-256"]]];
  path
];

LoadArtifact[task_Association, inputPath_String, name_String] := Module[
  {descriptor, path, value},
  descriptor = Lookup[Lookup[task, "payload", <||>], name, Missing[name]];
  path = ResolveArtifactPath[inputPath, descriptor];
  If[FailureQ[path], Return[path]];
  value = Quiet @ Check[ReadWLData[path], $Failed];
  If[!AssociationQ[value], Return[failure["INVALID_ARTIFACT", name <> " is not an Association"]]];
  value
];

prepareOutput[outputDir_String] := Module[{dir = ExpandFileName[outputDir]},
  If[FileExistsQ[dir] && FileType[dir] =!= Directory, Return[$Failed]];
  If[!FileExistsQ[dir], Quiet @ Check[CreateDirectory[dir, CreateIntermediateDirectories -> True], Return[$Failed]]];
  If[FileExistsQ[FileNameJoin[{dir, "result.json"}]], Return[$Failed]];
  dir
];

WriteWLArtifact[expr_, outputDir_String, fileName_String] := Module[{dir, path},
  dir = prepareOutput[outputDir];
  If[dir === $Failed, Return[$Failed]];
  path = FileNameJoin[{dir, fileName}];
  If[FileExistsQ[path], Return[$Failed]];
  If[Quiet @ Check[Block[{$Context = "CANON`DEData`", $ContextPath = {"System`"}},
      Put[expr, path]]; FileType[path] === File, False], path, $Failed]
];

WriteResult[
  task_Association,
  outputDir_String,
  status_String,
  code_String,
  artifacts_Association,
  summary_Association : <||>
] := Module[{dir, result, path},
  If[
    !MemberQ[{"ERROR", "INCONCLUSIVE", "PROVISIONAL", "FAIL", "PASS"}, status] ||
      code === "",
    Return[$Failed]
  ];
  dir = prepareOutput[outputDir];
  If[dir === $Failed, Return[$Failed]];
  result = <|
    "schema" -> "canon-neu/script-result/v1",
    "task_id" -> task["task_id"],
    "step" -> task["step"],
    "status" -> status,
    "code" -> code,
    "artifacts" -> artifacts,
    "summary" -> summary
  |>;
  path = FileNameJoin[{dir, "result.json"}];
  If[Quiet @ Check[Export[path, result, "RawJSON"]; FileType[path] === File, False], path, $Failed]
];

WriteProviderResult[
  task_Association,
  outputDir_String,
  status_String,
  code_String,
  artifacts_Association,
  summary_Association : <||>
] := Module[{valid},
  valid = Switch[status,
    "ERROR", code =!= "ERROR",
    "INCONCLUSIVE", MemberQ[{"OUT_OF_SCOPE", "METHOD_EXHAUSTED"}, code],
    "PROVISIONAL", MemberQ[
      {
        {"PROPOSE_INTEGRAL_CANDIDATES", "INTEGRAL_CANDIDATES"},
        {"SEARCH_CORE", "CANDIDATE_TRANSFORMATION"},
        {"DIAGNOSE_CORE", "CORE_DIAGNOSIS"},
        {"REPAIR_WITH_LIBRA", "CANDIDATE_TRANSFORMATION"},
        {"PROVIDE_UT_EVIDENCE", "EVIDENCE_AWAITING_VERIFICATION"}
      },
      {Lookup[task, "step", None], code}
    ],
    _, False
  ];
  If[!TrueQ[valid], Return[$Failed]];
  WriteResult[task, outputDir, status, code, artifacts, summary]
];
