#!/usr/bin/env wolframscript

$HistoryLength = 0;

repoRoot = DirectoryName[DirectoryName[ExpandFileName[$InputFileName]]];
Get[FileNameJoin[{repoRoot, "mma", "lib", "MethodCardCore.wl"}]];
Get[FileNameJoin[{repoRoot, "mma", "lib", "IBPReductionAudit.wl"}]];
temporary = CreateDirectory[];
ClearAll[f, d, eps, x, y];

derivativesPath = FileNameJoin[{temporary, "prepared-derivatives.wl"}];
preparedPath = FileNameJoin[{temporary, "prepared-family.wl"}];
mastersPath = FileNameJoin[{temporary, "master-basis.wl"}];
sectorsPath = FileNameJoin[{temporary, "sector-manifest.wl"}];
reductionPath = FileNameJoin[{temporary, "candidate-ibp-bridge.wl"}];
inputPath = FileNameJoin[{temporary, "input.json"}];

Put[<|
  "schema" -> "canon.prepared-derivatives/v2",
  "topology" -> "fixture",
  "variables" -> {x, y},
  "denominator_count" -> 1,
  "operators" -> <|
    x -> {<|"constant" -> 1, "linear" -> {}|>},
    y -> {<|"constant" -> 2, "linear" -> {}|>}
  |>
|>, derivativesPath];
Put[<|
  "schema" -> "canon-neu/prepared-family/v1",
  "family_ref" -> "fixture-lower-tail-family",
  "basis_ref" -> "fixture-resident-master-order",
  "topology" -> "fixture",
  "parameters" -> {d, x, y},
  "variables" -> {x, y},
  "regulator" -> eps,
  "dimension_rule" -> d -> 4 - 2 eps,
  "index_order" -> {"D1"},
  "sector_convention" -> "positive first propagator index",
  "prepared_derivatives" -> <|
    "path" -> derivativesPath,
    "sha256" -> FileHash[derivativesPath, "SHA256", "HexString"]
  |>
|>, preparedPath];
Put[<|
  "schema" -> "canon-neu/master-basis/v1",
  "family_ref" -> "fixture-lower-tail-family",
  "basis_ref" -> "fixture-resident-master-order",
  "topology" -> "fixture",
  "index_order" -> {"D1"},
  "ordering" -> "frozen fixture order",
  "masters" -> {f[0], f[1], f[2]}
|>, mastersPath];
Put[<|
  "schema" -> "canon-neu/sector-manifest/v1",
  "family_ref" -> "fixture-lower-tail-family",
  "sector_convention" -> "positive first propagator index",
  "propagator_slots" -> {1},
  "bit_order" -> "D1 is least-significant",
  "ordering" -> "ascending (propagator_count, id)",
  "sectors" -> {
    <|"id" -> 0, "propagator_count" -> 0, "sector_bits" -> {0}|>,
    <|"id" -> 1, "propagator_count" -> 1, "sector_bits" -> {1}|>
  }
|>, sectorsPath];
Put[<|
  "schema" -> "canon-neu/candidate-ibp-bridge/v1",
  "family_ref" -> "fixture-lower-tail-family",
  "basis_ref" -> "fixture-resident-master-order",
  "topology" -> "fixture",
  "masters" -> {f[0], f[1], f[2]},
  "rules" -> {f[3] -> d f[0] + d f[1] + f[2]}
|>, reductionPath];
fixtureReduction = Get[reductionPath];
fixtureReduction["ibp_audit"] = CANON`IBPReductionAudit`AuditIBPReduction[
  fixtureReduction, <|"schema" -> "canon-neu/ibp-audit-contract/v1",
    "integral_head" -> f, "index_count" -> 1, "coefficient_symbols" -> {d, x, y},
    "expected_masters" -> {f[0], f[1], f[2]}, "required_targets" -> {f[2], f[3]},
    "master_order" -> "exact"|>];
Put[fixtureReduction, reductionPath];
fileBoundAudit = fixtureReduction["ibp_audit"];
fileBoundAudit["binding", "reduction_sha256"] = FileHash[reductionPath, "SHA256", "HexString"];
Put[fileBoundAudit, reductionPath <> ".audit.wl"];
Export[inputPath, <|
  "schema" -> "canon-neu/script-input/v1",
  "task_id" -> "BUILD-CUT-DE-TEST",
  "step" -> "BUILD_CUT_DE",
  "sector" -> <|"id" -> 1, "propagator_count" -> 1|>,
  "payload" -> <|
    "prepared_family" -> <|"type" -> "mathematica-expression", "path" -> preparedPath|>,
    "master_basis" -> <|"type" -> "mathematica-expression", "path" -> mastersPath|>,
    "sector_manifest" -> <|"type" -> "mathematica-expression", "path" -> sectorsPath|>,
    "ibp_reduction" -> <|"type" -> "mathematica-expression", "path" -> reductionPath|>
  |>
|>, "RawJSON"];

runs = Table[
  output = FileNameJoin[{temporary, "run-" <> ToString[index]}];
  process = RunProcess[{
    "wolframscript", "-file", FileNameJoin[{repoRoot, "mma", "BuildSectorCutDE.wls"}],
    inputPath, output
  }];
  <|
    "exit_code" -> process["ExitCode"],
    "basis" -> FileNameJoin[{output, "sector-basis.wl"}],
    "cut" -> FileNameJoin[{output, "sector-cut-de.wl"}],
    "ordered" -> FileNameJoin[{output, "ordered-master-de.wl"}],
    "result" -> FileNameJoin[{output, "result.json"}]
  |>,
  {index, 2}
];

sectorBasis = Get[runs[[1, "basis"]]];
cut = Get[runs[[1, "cut"]]];
ordered = Get[runs[[1, "ordered"]]];
result = Import[runs[[1, "result"]], "RawJSON"];
expectedFullX = {{0, 0, 0}, {0, 0, -1}, {-2 d, -2 d, -2}};
expectedX = expectedFullX[[{2, 3}, {2, 3}]] /. d -> 4 - 2 eps;
expectedY = 2 expectedX;
independentResidual = Map[
  Together,
  D[expectedY, x] - D[expectedX, y] + expectedY . expectedX - expectedX . expectedY,
  {2}
];
pentaboxMasterPath = FileNameJoin[{
  repoRoot, "tests", "fixtures", "kira-massless-two-loop-five-point-pentabox",
  "preferred-masters"
}];
pentaboxMasters = Block[{$Context = "CANON`DEData`", $ContextPath = {"System`"}},
  ToExpression[
    "{" <> StringRiffle[Import[pentaboxMasterPath, "Lines"], ","] <> "}",
    InputForm
  ]
];
pentaboxSectorIDs = Total[
  (Boole[# > 0] & /@ Take[List @@ #, 8]) 2^Range[0, 7]
] & /@ pentaboxMasters;

tests = {
  VerificationTest[result["summary", "ibp_audit", "reuse", "used"], True,
    TestID -> "BUILD-CUT-DE-reuses-final-file-bound-audit-before-matrices"],
  VerificationTest[
    Lookup[runs, "exit_code"] === {0, 0} &&
      SameQ @@ (FileHash[#["basis"], "SHA256", "HexString"] & /@ runs) &&
      SameQ @@ (FileHash[#["cut"], "SHA256", "HexString"] & /@ runs) &&
      SameQ @@ (FileHash[#["ordered"], "SHA256", "HexString"] & /@ runs),
    True,
    TestID -> "fresh-kernel-sector-artifacts-are-byte-stable"
  ],
  VerificationTest[
    sectorBasis === <|
      "schema" -> "canon-neu/sector-basis/v1",
      "sector" -> <|"id" -> 1, "propagator_count" -> 1|>,
      "family_id" -> "fixture-lower-tail-family",
      "basis_id" -> "fixture-resident-master-order/sector-1",
      "basis" -> {f[1], f[2]}
    |> && CanonMethodCard`ValidSectorBasisQ[sectorBasis] &&
      cut["basis"] === sectorBasis["basis"] &&
      result["summary", "resident_positions"] === {2, 3},
    True,
    TestID -> "current-sector-basis-preserves-resident-master-order"
  ],
  VerificationTest[
    And @@ (# === 0 & /@
      Flatten[Map[Together, cut["matrices"] - {expectedX, expectedY}, {3}]]),
    True,
    TestID -> "independent-construction-reproduces-every-cut-entry-exactly"
  ],
  VerificationTest[
    expectedFullX[[3, 1]] === -2 d &&
      ordered["basis"] === {f[0], f[1], f[2]} &&
      ordered["matrices"][[1, 3, 1]] === -2 (4 - 2 eps) &&
      And @@ (# === 0 & /@ Flatten[Map[
        Together,
        cut["matrices"][[1]] -
          (expectedFullX[[{2, 3}, {2, 3}]] /. d -> 4 - 2 eps),
        {2}
      ]]) &&
      expectedX[[1, 2]] === -1 &&
      cut["proper_subsectors"] === {<|"id" -> 0, "propagator_count" -> 0|>} &&
      cut["regulator"] === eps && FreeQ[cut["matrices"], d | _Real] &&
      result["summary", "de_flat"] === True,
    True,
    TestID -> "dimension-rule-applies-after-full-de-and-cut-drops-only-lower-sector-tail"
  ],
  VerificationTest[
    And @@ (# === 0 & /@ Flatten[independentResidual]) &&
      CanonMethodCard`ValidCutDEQ[cut] &&
      DeleteDuplicates[Cases[cut["matrices"], _Symbol, Infinity]] === {eps},
    True,
    TestID -> "cut-connection-is-flat-over-the-declared-exact-rational-domain"
  ],
  VerificationTest[
    FileHash[pentaboxMasterPath, "SHA256", "HexString"] ===
      "27a6c8e24cabafe622d368baa1fcf9ca7784e1adc5fc07814178c50cfe71e420" &&
      Flatten[Position[pentaboxSectorIDs, 182]] === {15, 16} &&
      Flatten[Position[pentaboxSectorIDs, 255]] === {59, 60, 61} &&
      pentaboxMasters[[{15, 16}]] === {
        CANON`DEData`pentabox5[0, 1, 1, 0, 1, 1, 0, 1, 0, 0, 0],
        CANON`DEData`pentabox5[-1, 1, 1, 0, 1, 1, 0, 1, 0, 0, 0]
      },
    True,
    TestID -> "frozen-2l5p-block-positions-follow-kira-order-not-literature-indices"
  ]
};

report = TestReport[tests];
Print[InputForm[<|
  "total" -> report["TestsSucceededCount"] + report["TestsFailedCount"],
  "succeeded" -> report["TestsSucceededCount"],
  "failed" -> report["TestsFailedCount"]
|>]];
If[report["TestsFailedCount"] =!= 0, Print[InputForm[report["TestsFailed"]]]];
DeleteDirectory[temporary, DeleteContents -> True];
Exit[If[report["TestsFailedCount"] === 0, 0, 1]];
