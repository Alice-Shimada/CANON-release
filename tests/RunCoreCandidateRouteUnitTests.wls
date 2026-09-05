#!/usr/bin/env wolframscript
$HistoryLength = 0;
repoRoot = DirectoryName[DirectoryName[ExpandFileName[$InputFileName]]];
Get[repoRoot <> "/mma/lib/MethodCardCore.wl"];
Get[repoRoot <> "/mma/lib/CandidateIBPBridge.wl"];
temporary = CreateDirectory[];
ClearAll[l, j, k, x, eps];
sector = <|"id" -> 3, "propagator_count" -> 2|>;
basis = <|"schema" -> "canon-neu/sector-basis/v1", "sector" -> sector,
  "family_id" -> "rank-test", "basis_id" -> "rank-test/3", "basis" -> {j, k}|>;
cut = Join[KeyDrop[basis, "schema"], <|"schema" -> "canon-neu/sector-cut-de/v1",
  "variables" -> {x}, "regulator" -> eps,
  "matrices" -> {{{eps/x, 0}, {0, eps/(1-x)}}}|>];
bridge = <|"masters" -> {l, j, k}, "tool_provenance" -> <||>,
  "candidate_pool" -> <|"available" -> 4, "remaining" -> 0, "pool_exhausted" -> True|>,
  "candidates" -> MapIndexed[<|"candidate_id" -> ToString[First[#2]],
    "reduced_expression" -> #1|> &, {2 j, j+l, k+x j, k}]|>;
prepared = <|"dimension_rule" -> d -> 4-2 eps|>;
put[name_, value_] := (Put[value, temporary <> "/" <> name <> ".wl"];
  <|"type" -> "mathematica-expression", "path" -> temporary <> "/" <> name <> ".wl"|>);
run[name_, selectedBridge_] := Module[{input, output, payload, process, route, checkInput, checkOut},
  payload = <|"prepared_family" -> put[name <> "-family", prepared],
    "sector_basis" -> put[name <> "-basis", basis], "sector_cut_de" -> put[name <> "-cut", cut],
    "candidate_ibp_bridge" -> put[name <> "-bridge", selectedBridge]|>;
  input = temporary <> "/" <> name <> ".json"; output = temporary <> "/" <> name;
  Export[input, <|"schema" -> "canon-neu/script-input/v1", "task_id" -> name,
    "step" -> "ROUTE_CORE_CANDIDATES", "sector" -> sector, "payload" -> payload|>, "RawJSON"];
  process = RunProcess[{"wolframscript", "-file", repoRoot <> "/mma/RouteCoreCandidates.wls", input, output}];
  route = Get[output <> "/core-candidates.wl"];
  checkInput = temporary <> "/" <> name <> "-check.json"; checkOut = output <> "-check";
  Export[checkInput, <|"schema" -> "canon-neu/script-input/v1", "task_id" -> name <> "-check",
    "step" -> "CHECK_CORE", "sector" -> sector, "payload" -> Join[payload,
      <|"core_candidates" -> put[name <> "-core", route]|>]|>, "RawJSON"];
  RunProcess[{"wolframscript", "-file", repoRoot <> "/mma/CheckSectorCore.wls", checkInput, checkOut}];
  {route, Import[checkOut <> "/result.json", "RawJSON"]}
];
{routed, checked} = run["full-rank", bridge];
{short, rejected} = run["short-rank", Join[bridge, <|"candidates" -> Take[bridge["candidates"],2]|>]];
withTail = Select[routed["candidates"], MemberQ[#["member_candidate_ids"], "2"] &];
selected = SelectFirst[routed["candidates"], #["candidate_id"] === checked["summary", "selected_candidate_id"] &];
tests = {
  VerificationTest[routed["reduced_rank"], 2, TestID -> "IBP-rank-ignores-dependent-lower-tail-representatives"],
  VerificationTest[And @@ (Det[#["new_basis_rows"]] =!= 0 & /@ routed["candidates"]), True,
    TestID -> "every-routed-basis-is-independent"],
  VerificationTest[withTail =!= {} && MemberQ[Flatten[Lookup[withTail,"full_new_basis_rows"]],1], True,
    TestID -> "independent-bases-retain-proper-subsector-coefficients"],
  VerificationTest[{checked["status"], checked["code"]}, {"PASS", "CORE_PASS"},
    TestID -> "noncanonical-first-basis-is-replaced-by-an-independent-exchange"],
  VerificationTest[selected["member_candidate_ids"], {"1", "4"}, TestID -> "selected-canonical-integral-combination"],
  VerificationTest[short["reduced_rank"] === 1 && short["candidates"] === {}, True,
    TestID -> "insufficient-IBP-span-does-not-produce-a-square-basis"],
  VerificationTest[rejected["summary", "preferred_next_route"],
    "FIND_RATIONAL_CANONICAL_WITH_CANONICA", TestID -> "DE-search-is-available-without-a-complete-LS-basis"]
};
report=TestReport[tests];
Print[InputForm[<|"total"->Length[tests],"succeeded"->report["TestsSucceededCount"],"failed"->report["TestsFailedCount"]|>]];
If[report["TestsFailedCount"]>0,Print[InputForm[report["TestsFailed"]]]];
DeleteDirectory[temporary,DeleteContents->True];
Exit[If[report["TestsFailedCount"]===0,0,1]];
