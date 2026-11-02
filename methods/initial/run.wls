(* Stable INITIAL entry: the declared step selects a contract, never a fallback. *)
$HistoryLength = 0;
repoRoot = DirectoryName[DirectoryName[DirectoryName[ExpandFileName[$InputFileName]]]];
Get[FileNameJoin[{repoRoot, "mma", "lib", "MethodCardCore.wl"}]];
args = CanonMethodCard`ScriptArguments[];
If[Length[args] =!= 2, Print["Usage: run.wls <input.json> <new-output-dir>"]; Quit[2]];
initialEnvelope = Quiet @ Check[Import[ExpandFileName[First[args]], "RawJSON"], $Failed];
initialStep = If[AssociationQ[initialEnvelope], Lookup[initialEnvelope, "step", None], None];
If[!MemberQ[{"SEARCH_CORE", "PROVIDE_UT_EVIDENCE"}, initialStep],
  Print[InputForm[Failure["INVALID_INITIAL_STEP", <|"reason" ->
    "INITIAL accepts SEARCH_CORE or the explicit legacy PROVIDE_UT_EVIDENCE contract"|>]]];
  Quit[2]];
If[FailureQ[CanonMethodCard`ReadTask[ExpandFileName[First[args]], initialStep]],
  Print["INITIAL requires a valid canon-neu/script-input/v1 envelope"]; Quit[2]];
initialImplementation = If[initialStep === "SEARCH_CORE",
  FileNameJoin[{repoRoot, "methods", "initial-core", "run.wls"}],
  FileNameJoin[{repoRoot, "methods", "initial", "reference", "run.wls"}]];
Get[initialImplementation];
