#!/usr/bin/env wolframscript

$HistoryLength = 0;
repoRoot = DirectoryName[DirectoryName[ExpandFileName[$InputFileName]]];
Get[FileNameJoin[{repoRoot, "mma", "lib", "MethodCardCore.wl"}]];
arguments = CanonMethodCard`ScriptArguments[];
If[Length[arguments] =!= 2,
  Print["Usage: wolframscript -file tests/CheckPentaboxIBP.wls REDUCTION.wl FRESH_OUTPUT"];
  Exit[2]
];
{reductionPath, output} = ExpandFileName /@ arguments;
If[FileType[reductionPath] =!= File || FileExistsQ[output],
  Print["Require an existing reduction and a fresh check output directory."]; Exit[2]];
CreateDirectory[output, CreateIntermediateDirectories -> True];
fixture = FileNameJoin[{repoRoot, "tests", "fixtures",
  "kira-massless-two-loop-five-point-pentabox"}];
sourceLines[name_] := Select[
  StringTrim @ StringReplace[
    StringSplit[Import[FileNameJoin[{fixture, name}], "Text"], {"\r\n", "\n", "\r"}],
    RegularExpression["#.*$"] -> ""], # =!= "" &];
{expectedMasters, expectedTargets} = Block[
  {$Context = "CANON`DEData`", $ContextPath = {"System`"}},
  ToExpression["{" <> StringRiffle[sourceLines[#], ","] <> "}"] & /@
    {"preferred-masters", "targets"}];
prepared = CanonMethodCard`ReadWLData[
  FileNameJoin[{fixture, "prepared-derivatives-v2.wl"}]];
(* Declarations come from the frozen fixture, never the reduction being checked. *)
contractPath = CanonMethodCard`WriteWLArtifact[
  <|"schema" -> "canon-neu/ibp-audit-contract/v1",
    "integral_head" -> CANON`DEData`pentabox5,
    "index_count" -> prepared["denominator_count"],
    "coefficient_symbols" -> Prepend[prepared["variables"], CANON`DEData`d],
    "expected_masters" -> expectedMasters, "required_targets" -> expectedTargets,
    "master_order" -> "exact"|>, output, "ibp-contract.wl"];
input = FileNameJoin[{output, "audit-input.json"}];
auditOutput = FileNameJoin[{output, "audit"}];
Export[input, <|"schema" -> "canon-neu/script-input/v1",
  "task_id" -> "pentabox-ibp-check", "step" -> "CHECK_IBP", "sector" -> Null,
  "payload" -> <|"ibp_reduction" -> <|"path" -> reductionPath|>,
    "ibp_contract" -> <|"path" -> contractPath|>|>|>, "RawJSON"];
python = Environment["CANON_PYTHON"];
If[!StringQ[python], python = "python3"];
process = RunProcess[{python, FileNameJoin[{repoRoot, "run_step.py"}],
  input, auditOutput}, All, ProcessDirectory -> repoRoot];
auditResultPath = FileNameJoin[{auditOutput, "result.json"}];
If[FileType[auditResultPath] =!= File, Print[InputForm[process]]; Exit[1]];
auditResult = Import[auditResultPath, "RawJSON"];
If[process["ExitCode"] =!= 0 ||
    Lookup[auditResult, {"status", "code"}] =!= {"PASS", "IBP_AUDIT_PASS"},
  Print[InputForm[<|"passed" -> False, "audit" -> auditResult,
    "process" -> process|>]]; Exit[1]];
result = CanonMethodCard`ReadWLData[reductionPath];
(* Retain the fixture oracle independently of the common structural checker. *)
checks = <|"common_ibp_audit" -> True,
  "ordered_fixture_masters" -> (result["masters"] === expectedMasters),
  "ordered_fixture_targets" -> ((First /@ result["rules"]) === expectedTargets)|>;
passed = AllTrue[Values[checks], TrueQ];
summary = <|"passed" -> passed, "checks" -> checks,
  "masters" -> Length[result["masters"]], "rules" -> Length[result["rules"]],
  "audit_result" -> "audit/result.json"|>;
Export[FileNameJoin[{output, "checks.json"}], summary, "RawJSON"];
Print[InputForm[summary]];
Exit[If[passed, 0, 1]];
