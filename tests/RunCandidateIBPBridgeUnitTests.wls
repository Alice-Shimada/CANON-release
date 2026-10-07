#!/usr/bin/env wolframscript

repoRoot = DirectoryName[DirectoryName[$InputFileName]];
Get[FileNameJoin[{repoRoot, "mma", "lib", "BaikovDerivative.wl"}]];
Get[FileNameJoin[{repoRoot, "mma", "lib", "CandidateIBPBridge.wl"}]];
prepared = Get[FileNameJoin[{
  repoRoot, "tests", "fixtures", "kira-one-loop-box", "prepared-derivatives-v2.wl"
}]];

preparedFamily = <|
  "family_ref" -> "fixture-one-loop-box", "topology" -> "box",
  "parameters" -> {d, s, t}, "variables" -> {s, t},
  "sector_convention" -> "positive slots 1 through 4"
|>;
orderedMasters = {
  box[1, 0, 0, 0], box[1, 0, 1, 0], box[0, 1, 0, 1],
  box[1, 1, 0, 1], box[1, 1, 1, 1]
};
masterBasis = <|
  "basis_ref" -> "fixture-one-loop-box-masters",
  "index_order" -> {"D1", "D2", "D3", "D4"},
  "masters" -> orderedMasters
|>;
candidates = <|
  "proposal_id" -> "box-proposal",
  "candidate_pool" -> <|"available" -> 2, "remaining" -> 0, "pool_exhausted" -> True|>,
  "method_evidence" -> <||>, "tool_provenance" -> <|"tool" -> "fixture"|>,
  "candidates" -> {
  <|
    "candidate_id" -> "box-rational-combination", "normalization" -> <|"factor" -> 1|>,
    "exact_definition" -> HoldComplete[
      (s + t)/t j[box, 1, 1, 1, 1] + s^2 j[box, 1, 0, 1, 0]
    ]
  |>,
  <|
    "candidate_id" -> "box-signed-index", "normalization" -> <|"factor" -> 1|>,
    "exact_definition" -> HoldComplete[j[box, 1, 1, 1, -1]]
  |>
}|>;

compiled = CANON`CandidateIBPBridge`CompileCandidateIBPTargets[
  candidates, preparedFamily, masterBasis, prepared
];
record = First[compiled["candidates"]];
physical = record["expression"];
strategy = prepared["exact_strategy"];
z = strategy["baikov_variables"];
polynomial = Expand[
  strategy["baikov_polynomial"] /. strategy["fixed_scale_substitutions"]
];

oracleAffine[integral_, variable_] := Module[{a, rows},
  a = List @@ integral;
  rows = prepared["operators", variable];
  Together @ Sum[
    -a[[i]] (
      rows[[i, "constant"]] Apply[box, a + UnitVector[4, i]] +
      Sum[
        With[{entry = rows[[i, "linear", k]]},
          entry["coefficient"] Apply[
            box, a + UnitVector[4, i] - UnitVector[4, entry["denominator"]]
          ]
        ],
        {k, Length[rows[[i, "linear"]]]}
      ]
    ),
    {i, 4}
  ]
];

choice = compiled["operators", t];
vectors = z choice["cofactors"];
oracleWeight[integral_] := Module[{a = List @@ integral}, Together[
  (4 - d)/2 D[strategy["external_gram_determinant"], t]/
      strategy["external_gram_determinant"] +
    (d - 5)/2 choice["f_cofactor"] +
    Sum[a[[i]] vectors[[i]]/z[[i]] - D[vectors[[i]], z[[i]]], {i, 4}]
]];
oracleBaikov[integral_] := Module[{a = List @@ integral, monomials},
  monomials = CoefficientRules[Together[oracleWeight[integral] Times @@ z], z];
  Together @ Total[(Last[#] Apply[
    box, a - First[#] + ConstantArray[1, 4]
  ]) & /@ monomials]
];
sourceIntegrals = DeleteDuplicates[
  Cases[physical, item_box :> item, {0, Infinity}], SameQ
];
oracleS = Together[D[physical, s] + Total[
  Coefficient[physical, #] oracleAffine[#, s] & /@ sourceIntegrals
]];
oracleT = Together[D[physical, t] + Total[
  Coefficient[physical, #] oracleBaikov[#] & /@ sourceIntegrals
]];

targetIntegrals = Lookup[compiled["reducer_targets"], "integral"];
masterDerivativeTargets = Select[DeleteDuplicates@Flatten[
  Cases[oracleAffine[#1, #2], item_box :> item, Infinity] & @@@
    Tuples[{orderedMasters, {s, t}}]], !MemberQ[orderedMasters, #] &];
reductionRules = MapIndexed[
  #1 -> (First[#2] orderedMasters[[1]] + orderedMasters[[2]]) &,
  targetIntegrals
];
final = CANON`CandidateIBPBridge`AttachCandidateIBPReduction[
  compiled, <|"masters" -> Reverse[orderedMasters], "rules" -> reductionRules|>
];
reducedExpressions = Join[
  Lookup[final["candidates"], "reduced_expression"],
  Flatten[Values /@ Lookup[final["candidates"], "reduced_derivatives"]]
];
reducedIntegrals = DeleteDuplicates[
  Cases[reducedExpressions, item_box :> item, {0, Infinity}], SameQ
];
fullBoxTail = Select[
  First[compiled["candidates"]]["targets"],
  #1["sector_mask"] < 15 && MemberQ[
    Cases[record["derivatives", t], item_box :> item, {0, Infinity}], #1["integral"]
  ] &
];
cofactorResidual = Together[
  D[polynomial, t] - Total[vectors (D[polynomial, #] & /@ z)] -
    choice["f_cofactor"] polynomial
];

(* Independent formal-integrand chain rule, including normalization derivatives. *)
affineCandidates = candidates;
affineCandidates["candidates"] = MapIndexed[
  Join[#1, <|"normalization" -> <|"factor" -> If[First[#2] === 1, s t, t^2]|>|>] &,
  candidates["candidates"]];
affinePrepared = Join[KeyTake[prepared, {"variables", "operators", "denominator_count"}],
  <|"exact_strategy" -> <|"propagator_slots" -> {1,2,3,4}|>|>];
searchCalled = False;
affineCompiled = Block[{CANON`BaikovDerivative`Private`findZeroGrowth},
  CANON`BaikovDerivative`Private`findZeroGrowth[___] := (searchCalled = True; $Failed);
  CANON`CandidateIBPBridge`CompileCandidateIBPTargets[
    affineCandidates, preparedFamily, masterBasis, affinePrepared, "prepared-affine"]
];
toIntegrand[expr_] := expr /. HoldPattern[box[a__Integer]] :> Times @@ (z^-{a});
chainRule[expr_, variable_] := Module[{integrand = toIntegrand[expr], rows = prepared["operators", variable]},
  D[integrand, variable] + Sum[D[integrand, z[[i]]] (rows[[i, "constant"]] +
    Total[(#["coefficient"] z[[#["denominator"]]]) & /@ rows[[i, "linear"]]]), {i,4}]
];
affineResiduals = Flatten[Table[Together[toIntegrand[record["derivatives", variable]] -
  chainRule[record["expression"], variable]],
  {record, affineCompiled["candidates"]}, {variable, {s,t}}]];

(* A selected reducer can exit successfully while exporting incomplete data.
   Exercise the common JSON/component entry and the final-file audit handoff. *)
temporary = CreateDirectory[];
project = CreateDirectory[FileNameJoin[{temporary, "project"}]];
Put[candidates, FileNameJoin[{temporary, "candidates.wl"}]];
Put[preparedFamily, FileNameJoin[{temporary, "family.wl"}]];
Put[masterBasis, FileNameJoin[{temporary, "masters.wl"}]];
Put[prepared, FileNameJoin[{temporary, "derivatives.wl"}]];
integralText[e_] := SymbolName[Head[e]] <> "[" <>
  StringRiffle[ToString[#, InputForm] & /@ List @@ e, ","] <> "]";
Export[FileNameJoin[{project, "fake-masters"}],
  StringRiffle[integralText /@ orderedMasters, "\n"] <> "\n", "Text"];
Export[FileNameJoin[{project, "fake-rules"}], ToString[Most[reductionRules], InputForm], "Text"];
adapterPath = FileNameJoin[{temporary, "fake-adapter.py"}];
Export[adapterPath, StringRiffle[{
  "import json, pathlib, sys",
  "source, output = map(pathlib.Path, sys.argv[1:])",
  "task = json.loads(source.read_text())",
  "project = pathlib.Path(__file__).parent / 'project'",
  "masters = ','.join((project / 'fake-masters').read_text().splitlines())",
  "rules = (project / 'fake-rules').read_text()",
  "output.mkdir()",
  "(output / 'ibp-reduction.wl').write_text('<|\"masters\" -> {' + masters + '}, \"rules\" -> ' + rules + '|>')",
  "(output / 'result.json').write_text(json.dumps({'schema':'canon-neu/script-result/v1', 'task_id':task['task_id'], 'step':'REDUCE_IBP', 'status':'PASS', 'code':'IBP_REDUCED', 'artifacts':{'ibp_reduction':{'type':'mathematica-expression', 'path':'ibp-reduction.wl'}}, 'summary':{}}))"
}, "\n"], "Text"];
manifestPath = FileNameJoin[{temporary, "components.json"}];
Export[FileNameJoin[{temporary, "instructions.md"}], "Synthetic reducer boundary fixture.\n", "Text"];
Export[manifestPath, <|"schema" -> "canon-neu/components/v1", "steps" -> <|
  "REDUCE_IBP" -> <|"command" -> {"{python}", "{package}/fake-adapter.py"},
    "instructions" -> "instructions.md"|>|>|>, "RawJSON"];
requestPath = FileNameJoin[{temporary, "request.json"}];
Export[requestPath, <|"schema" -> "canon-neu/script-input/v1",
  "task_id" -> "CANDIDATE-AUDIT-FIXTURE", "step" -> "REDUCE_CANDIDATE_IBP",
  "payload" -> <|
    "integral_candidates" -> <|"path" -> "candidates.wl"|>,
    "prepared_family" -> <|"path" -> "family.wl"|>,
    "master_basis" -> <|"path" -> "masters.wl"|>,
    "prepared_derivatives" -> <|"path" -> "derivatives.wl"|>,
    "backend" -> <|"path" -> "backend.json"|>|>|>, "RawJSON"];
Export[FileNameJoin[{temporary, "backend.json"}], <||>, "RawJSON"];
outputPath = FileNameJoin[{temporary, "failed-output"}];
resultPath = FileNameJoin[{outputPath, "candidate-ibp-bridge.wl"}];
publicCommand[out_] := {"python3", FileNameJoin[{repoRoot, "run_step.py"}],
  requestPath, out, "--components", manifestPath};
process = RunProcess[publicCommand[outputPath]];
failedAudit = Get[FileNameJoin[{outputPath, "ibp-audit.wl"}]];

(* A complete reversed reducer order is mapped by the audited bridge. *)
Export[FileNameJoin[{project, "fake-masters"}],
  StringRiffle[integralText /@ Reverse[orderedMasters], "\n"] <> "\n", "Text"];
Export[FileNameJoin[{project, "fake-rules"}], ToString[reductionRules, InputForm], "Text"];
successfulOutput = FileNameJoin[{temporary, "successful-output"}];
successfulPath = FileNameJoin[{successfulOutput, "candidate-ibp-bridge.wl"}];
successfulCommand = publicCommand[successfulOutput];
successfulProcess = RunProcess[successfulCommand];
successfulBridge = Get[successfulPath];
successfulAudit = Get[successfulPath <> ".audit.wl"];
successfulSHA256 = FileHash[successfulPath, "SHA256", "HexString"];
consumerAudit = CANON`IBPReductionAudit`AuditIBPReduction[successfulBridge,
  successfulBridge["ibp_audit_contract"], successfulAudit, successfulSHA256];
overwriteProcess = RunProcess[successfulCommand];

report = TestReport[{
  VerificationTest[successfulProcess["ExitCode"] === 0 &&
    successfulAudit["binding", "reduction_sha256"] === successfulSHA256 &&
    consumerAudit["reuse", "used"] &&
    consumerAudit["master_permutation"] === Range[Length[orderedMasters]],
    True, TestID -> "candidate-command-binds-PASS-to-final-reordered-bridge-file"],
  VerificationTest[overwriteProcess["ExitCode"] =!= 0 &&
    FileHash[successfulPath, "SHA256", "HexString"] === successfulSHA256,
    True, TestID -> "candidate-command-keeps-published-bridge-unchanged"],
  VerificationTest[With[{a = CANON`IBPReductionAudit`AuditIBPReduction[
      final, compiled["ibp_audit_contract"]]},
    a["status"] === "PASS" && !a["reuse", "used"] &&
      a["master_permutation"] === Range[Length[orderedMasters]]],
    True, TestID -> "in-memory-bridge-needs-file-identity-before-reusing-proof"],
  VerificationTest[process["ExitCode"] =!= 0 && !FileExistsQ[resultPath] &&
    Lookup[failedAudit, {"status", "code"}] === {"FAIL", "IBP_CHECK_FAILED"} &&
      failedAudit["summary", "reason_code"] === "IBP_MISSING_TARGETS",
    True, TestID -> "candidate-command-writes-audit-failure-without-publishing-bridge"],
  VerificationTest[
    FailureQ[CANON`CandidateIBPBridge`AttachCandidateIBPReduction[
      compiled, <|"masters" -> orderedMasters, "rules" -> Most[reductionRules]|>]],
    True,
    TestID -> "candidate-bridge-rejects-incomplete-reduction-before-substitution"
  ],
  VerificationTest[
    !searchCalled && AllTrue[Values[affineCompiled["operators"]],
      #["kind"] === "prepared-affine" && #["enhanced_search_attempted"] === False &],
    True, TestID -> "explicit-affine-retains-honest-per-variable-choice"],
  VerificationTest[
    affineResiduals === ConstantArray[0, 4], True,
    TestID -> "explicit-affine-equals-independent-integrand-chain-rule-all-candidates-and-variables"],
  VerificationTest[
    Lookup[affineCompiled["candidates"], "candidate_id"] === Lookup[candidates["candidates"], "candidate_id"] &&
      Last[affineCompiled["candidates"]]["targets"][[1, "indices", 4]] === -1 &&
      AnyTrue[Flatten[Lookup[affineCompiled["candidates"], "targets"], 1], #["sector_mask"] < 15 &] &&
      SubsetQ[Lookup[affineCompiled["reducer_targets"], "integral"], masterDerivativeTargets],
    True, TestID -> "explicit-affine-keeps-ids-signed-indices-subsectors-and-master-targets"],
  VerificationTest[
    CANON`CandidateIBPBridge`CompileCandidateIBPTargets[
      candidates, preparedFamily, masterBasis, prepared, "unknown"][[1]],
    "DERIVATIVE_OPERATOR_INVALID", TestID -> "compiler-propagates-invalid-selection"],
  VerificationTest[
    CANON`CandidateIBPBridge`CompileCandidateIBPTargets[
      candidates, preparedFamily, masterBasis, KeyDrop[affinePrepared, {"exact_strategy"}], "prepared-affine"][[1]],
    "DERIVATIVE_OPERATOR_INVALID", TestID -> "explicit-affine-requires-used-propagator-metadata"],
  VerificationTest[
    Lookup[compiled["operators"], {s, t}][[All, "kind"]] ===
      {"affine-fallback", "enhanced-baikov"} && cofactorResidual === 0,
    True,
    TestID -> "selected-affine-and-enhanced-operators-reconstruct-the-baikov-identity"
  ],
  VerificationTest[
    Together[record["derivatives", s] - oracleS] === 0 &&
      Together[record["derivatives", t] - oracleT] === 0 &&
      Coefficient[record["derivatives", s], box[1, 0, 1, 0]] =!= 0,
    True,
    TestID -> "candidate-derivatives-match-independent-oracles-including-prefactor-derivatives"
  ],
  VerificationTest[
    fullBoxTail =!= {} && AnyTrue[fullBoxTail, #1["integral"] === box[0, 1, 1, 1] &] &&
      Last[compiled["candidates"]]["targets"][[1, "indices", 4]] === -1,
    True,
    TestID -> "proper-subsector-tail-and-signed-index-survive-target-compilation"
  ],
  VerificationTest[
    SubsetQ[targetIntegrals, masterDerivativeTargets],
    True,
    TestID -> "raw-ordered-master-affine-derivatives-are-reducer-targets"
  ],
  VerificationTest[
    First /@ reductionRules === targetIntegrals &&
      final["masters"] === orderedMasters && SubsetQ[orderedMasters, reducedIntegrals] &&
      Lookup[final["candidates"], "candidate_id"] ===
        {"box-rational-combination", "box-signed-index"} &&
      final["candidate_pool"] === candidates["candidate_pool"],
    True,
    TestID -> "exact-target-coverage-closes-on-ordered-masters-with-lossless-candidate-ids"
  ]
}];
Print[InputForm[<|
  "total" -> report["TestsSucceededCount"] + report["TestsFailedCount"],
  "succeeded" -> report["TestsSucceededCount"],
  "failed" -> report["TestsFailedCount"]
|>]];
If[report["TestsFailedCount"] =!= 0, Print[InputForm[report["TestsFailed"]]]];
DeleteDirectory[temporary, DeleteContents -> True];
Exit[If[report["TestsFailedCount"] === 0, 0, 1]];
