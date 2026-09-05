#!/usr/bin/env wolframscript
$HistoryLength = 0;
repoRoot = DirectoryName[DirectoryName[ExpandFileName[$InputFileName]]];
Get[FileNameJoin[{repoRoot, "mma", "lib", "MethodCardCore.wl"}]];
temporary = CreateDirectory[];
ClearAll[x, y, eps, j1, j2];
sector = <|"id" -> 3, "propagator_count" -> 2|>;
put[name_, value_] := (Put[value, temporary <> "/" <> name <> ".wl"];
  <|"type" -> "mathematica-expression", "path" -> temporary <> "/" <> name <> ".wl"|>);
runCase[name_, variables_, canonical_, rows_, letters_] := Module[
  {t, raw, cut, input, output, result, candidates, candidate, independent},
  t = Map[Together, Inverse[rows], {2}];
  raw = MapThread[Map[Together, (D[t, #2] + t.#1).rows, {2}] &,
    {canonical, variables}];
  cut = <|"schema" -> "canon-neu/sector-cut-de/v1", "sector" -> sector,
    "family_id" -> name, "basis_id" -> name <> "/raw", "basis" -> {j1, j2},
    "variables" -> variables, "regulator" -> eps,
    "coefficient_domain" -> "exact-rational-functions", "matrices" -> raw|>;
  input = temporary <> "/" <> name <> ".json";
  output = temporary <> "/" <> name;
  Export[input, <|"schema" -> "canon-neu/script-input/v1", "task_id" -> name,
    "step" -> "SEARCH_CORE", "sector" -> sector,
    "payload" -> <|"sector_cut_de" -> put[name <> "-cut", cut],
      "declared_alphabet" -> put[name <> "-alphabet", <|"letters" -> letters|>]|>|>, "RawJSON"];
  RunProcess[{"wolframscript", "-file", repoRoot <> "/methods/epsilon-zero/run.wls", input, output}];
  result = Import[output <> "/result.json", "RawJSON"];
  candidates = Get[output <> "/" <> result["artifacts", "core_candidates", "path"]];
  candidate = First[candidates["candidates"]];
  independent = CanonMethodCard`GaugeTransform[raw, variables, candidate["transformation"]];
  <|"result" -> result, "matrices" -> independent,
    "dlog" -> CanonMethodCard`DLogConnectionQ[independent, variables, eps, letters]|>
];

algebraic = runCase["algebraic-horizontal", {x, y},
  {eps IdentityMatrix[2]/x, eps IdentityMatrix[2]/y},
  {{x, y}, {0, Sqrt[x^2 + y^2]}}, {x, y, Sqrt[x^2 + y^2]}];
singular = runCase["epsilon-singular", {x},
  {eps {{1/x, 1/(1+x)}, {1/x, 2/x}}},
  DiagonalMatrix[{1, eps}].{{1, eps x/(1+x)}, {0, 1}}, {x, 1+x}];
tests = {
  VerificationTest[algebraic["result", "status"], "PROVISIONAL",
    TestID -> "algebraic-horizontal-provider-only-proposes"],
  VerificationTest[algebraic["dlog"], True,
    TestID -> "algebraic-horizontal-core-obeys-both-original-directions"],
  VerificationTest[singular["result", "status"], "PROVISIONAL",
    TestID -> "rank-defect-provider-only-proposes"],
  VerificationTest[singular["dlog"], True,
    TestID -> "epsilon-singular-complement-and-primitive-produce-an-exact-canonical-core"]
};
report = TestReport[tests];
Print[InputForm[<|"total" -> Length[tests], "succeeded" -> report["TestsSucceededCount"],
  "failed" -> report["TestsFailedCount"], "workspace" -> temporary|>]];
If[report["TestsFailedCount"] > 0, Print[InputForm[report["TestsFailed"]]],
  DeleteDirectory[temporary, DeleteContents -> True]];
Quit[If[report["TestsFailedCount"] === 0, 0, 1]];
