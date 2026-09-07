#!/usr/bin/env wolframscript

$HistoryLength = 0;

repoRoot = DirectoryName[DirectoryName[ExpandFileName[$InputFileName]]];
fixture = FileNameJoin[{
  repoRoot, "tests", "fixtures", "kira-massless-two-loop-five-point-pentabox"
}];
resource = ExpandFileName[Last[$ScriptCommandLine]];
temporary = CreateDirectory[];
inputDirectory = CreateDirectory[FileNameJoin[{temporary, "input files"}]];
localFixture = FileNameJoin[{inputDirectory, "kira project"}];
CopyDirectory[fixture, localFixture];
CopyFile[FileNameJoin[{resource, "family.wl"}], FileNameJoin[{inputDirectory, "family.wl"}]];
variables = Get[FileNameJoin[{fixture, "prepared-derivatives-v2.wl"}]]["variables"];
dimension = Symbol["CANON`DEData`d"];
regulator = Symbol["CANON`DEData`eps"];
spec = <|
  "schema" -> "canon-neu/family-spec/v1",
  "family_ref" -> "massless-planar-two-loop-five-point-pentabox",
  "basis_ref" -> "kira3-pentabox5-preferred-masters-61",
  "topology" -> "pentabox5",
  "parameters" -> Prepend[variables, dimension],
  "variables" -> variables,
  "regulator" -> regulator,
  "dimension_rule" -> dimension -> 4 - 2 regulator,
  "index_order" -> {"D1", "D2", "D3", "D4", "D5", "D6", "D7", "D8", "N9", "N10", "N11"},
  "sector_convention" -> "Sector = Sum[Boole[a_i > 0] 2^(i-1), {i,1,8}]",
  "kira" -> <|
    "project" -> "kira project",
    "integral_families" -> "config/integralfamilies.yaml",
    "kinematics" -> "config/kinematics.yaml",
    "jobs" -> {"jobs.yaml", "export-math.yaml"},
    "targets" -> "targets"
  |>,
  "family_data" -> "family.wl",
  "prepared_derivatives" -> "kira project/prepared-derivatives-v2.wl",
  "ordered_masters" -> "kira project/preferred-masters",
  "propagator_slots" -> Range[8]
|>;
specPath = FileNameJoin[{inputDirectory, "family-spec.wl"}];
prepareInput = FileNameJoin[{temporary, "prepare.json"}];
Put[spec, specPath];
Export[prepareInput, <|
  "schema" -> "canon-neu/script-input/v1", "task_id" -> "PREPARE-TEST",
  "step" -> "PREPARE", "sector" -> Null,
  "payload" -> <|"family_spec" -> <|"type" -> "mathematica-expression", "path" -> "input files/family-spec.wl"|>|>
|>, "RawJSON"];

runs = Table[
  prepareOutput = FileNameJoin[{temporary, "prepare-" <> ToString[index]}];
  discoverOutput = FileNameJoin[{temporary, "discover-" <> ToString[index]}];
  discoverInput = FileNameJoin[{temporary, "discover-" <> ToString[index] <> ".json"}];
  prepareProcess = RunProcess[{
    "wolframscript", "-file", FileNameJoin[{repoRoot, "mma", "PrepareFamily.wls"}],
    prepareInput, prepareOutput
  }];
  Export[discoverInput, <|
    "schema" -> "canon-neu/script-input/v1", "task_id" -> "DISCOVER-TEST",
    "step" -> "DISCOVER", "sector" -> Null,
    "payload" -> <|"prepared_family" -> <|
      "type" -> "mathematica-expression",
      "path" -> FileNameJoin[{prepareOutput, "prepared-family.wl"}]
    |>|>
  |>, "RawJSON"];
  discoverProcess = RunProcess[{
    "wolframscript", "-file", FileNameJoin[{repoRoot, "mma", "DiscoverSectors.wls"}],
    discoverInput, discoverOutput
  }];
  <|
    "exit_codes" -> {prepareProcess["ExitCode"], discoverProcess["ExitCode"]},
    "prepared" -> FileNameJoin[{prepareOutput, "prepared-family.wl"}],
    "sectors" -> FileNameJoin[{discoverOutput, "sector-manifest.wl"}],
    "masters" -> FileNameJoin[{discoverOutput, "master-basis.wl"}],
    "result" -> FileNameJoin[{discoverOutput, "result.json"}]
  |>,
  {index, 2}
];
prepared = Get[runs[[1, "prepared"]]];
sectorManifest = Get[runs[[1, "sectors"]]];
masterBasis = Get[runs[[1, "masters"]]];
sectors = sectorManifest["sectors"];
sourceMasters = Block[{$Context = "CANON`DEData`", $ContextPath = {"System`"}},
  ToExpression["{" <> StringRiffle[Import[prepared["ordered_masters", "path"], "Lines"], ","] <> "}", InputForm]
];
masterKey[master_] := With[{bits = Boole[# > 0] & /@ Take[List @@ master, 8]},
  {Total[bits], Total[bits 2^Range[0, 7]]}];
expectedMasters = First /@ SortBy[
  MapIndexed[{#1, First[#2]} &, sourceMasters], {masterKey[First[#]], Last[#]} &];
masterSectors = Total[MapIndexed[Boole[#1 > 0] 2^(First[#2] - 1) &, Take[List @@ #, 8]]] & /@
  masterBasis["masters"];
hashes[name_] := FileHash[#[name], "SHA256", "HexString"] & /@ runs;

tests = {VerificationTest[
  Lookup[runs, "exit_codes"] === {{0, 0}, {0, 0}} &&
    And @@ (SameQ @@ hashes[#] & /@ {"prepared", "sectors", "masters", "result"}) &&
    prepared["family_ref"] === spec["family_ref"] &&
    prepared["basis_ref"] === spec["basis_ref"] && prepared["topology"] === "pentabox5" &&
    prepared["index_order"] === spec["index_order"] && prepared["variables"] === variables &&
    prepared["regulator"] === regulator &&
    prepared["dimension_rule"] === (dimension -> 4 - 2 regulator) &&
    prepared["kira", "project"] === localFixture &&
    prepared["ordered_masters", "sha256"] === FileHash[FileNameJoin[{localFixture, "preferred-masters"}], "SHA256", "HexString"] &&
    prepared["propagator_slots"] === Range[8] &&
    Length[sectors] === 46 && DuplicateFreeQ[Lookup[sectors, "id"]] &&
    ({#["propagator_count"], #["id"]} & /@ sectors) ===
      Sort[({#["propagator_count"], #["id"]} & /@ sectors)] &&
    AllTrue[sectors, #["id"] === Total[#["sector_bits"] 2^Range[0, 10]] &&
      #["propagator_count"] === Total[#["sector_bits"]] &] &&
    masterBasis["masters"] === expectedMasters && Length[sourceMasters] === 61 &&
    Sort[DeleteDuplicates[masterSectors]] === Sort[Lookup[sectors, "id"]],
  True,
  TestID -> "fresh-kernel-pentabox-prepare-discover-is-exact-and-deterministic"
]};

wideMasters = {wide[1,0,0,0,0,0,0,0,1,-2], wide[1,0,0,0,0,0,0,0,0,-1]};
widePath = FileNameJoin[{temporary, "wide-masters"}];
Export[widePath, StringRiffle[ToString[#,InputForm]&/@wideMasters,"\n"], "Text"];
widePrepared = Join[prepared, <|"topology" -> "wide", "index_order" -> Range[10],
  "propagator_slots" -> {1,9}, "ordered_masters" -> <|"path" -> widePath,
    "sha256" -> FileHash[widePath,"SHA256","HexString"]|>|>];
widePreparedPath = FileNameJoin[{temporary,"wide-prepared.wl"}];
Put[widePrepared,widePreparedPath];
wideInput = FileNameJoin[{temporary,"wide.json"}];
wideOutput = FileNameJoin[{temporary,"wide"}];
Export[wideInput,<|"schema"->"canon-neu/script-input/v1","task_id"->"wide",
  "step"->"DISCOVER","sector"->Null,"payload"-><|"prepared_family"->
    <|"type"->"mathematica-expression","path"->widePreparedPath|>|>|>,"RawJSON"];
RunProcess[{"wolframscript","-file",FileNameJoin[{repoRoot,"mma","DiscoverSectors.wls"}],wideInput,wideOutput}];
wideManifest = Get[FileNameJoin[{wideOutput,"sector-manifest.wl"}]];
AppendTo[tests,VerificationTest[Lookup[wideManifest["sectors"],"id"] === {1,257} &&
  Lookup[wideManifest["sectors"],"master_count"] === {1,1} &&
  Length[wideManifest["sectors"][[2,"sector_bits"]]] === 10, True,
  TestID->"noncontiguous-propagator-slots-beyond-eight-are-derived-from-masters"]];
report=TestReport[tests];

Print[InputForm[<|
  "total" -> report["TestsSucceededCount"] + report["TestsFailedCount"],
  "succeeded" -> report["TestsSucceededCount"], "failed" -> report["TestsFailedCount"]
|>]];
DeleteDirectory[temporary, DeleteContents -> True];
Exit[If[report["TestsFailedCount"] === 0, 0, 1]];
