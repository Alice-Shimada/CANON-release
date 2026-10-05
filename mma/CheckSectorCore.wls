$HistoryLength = 0;

repoRoot = DirectoryName[DirectoryName[ExpandFileName[$InputFileName]]];
Get[FileNameJoin[{repoRoot, "mma", "lib", "MethodCardCore.wl"}]];

args = CanonMethodCard`ScriptArguments[];
If[Length[args] =!= 2, Print["Usage: CheckSectorCore.wls <input.json> <output_dir>"]; Quit[2]];
{inputPath, outputDir} = ExpandFileName /@ args;
task = CanonMethodCard`ReadTask[inputPath, "CHECK_CORE"];
If[FailureQ[task], Print[InputForm[task]]; Quit[2]];

invalid[code_String, reason_String] := (
  CanonMethodCard`WriteResult[task, outputDir, "ERROR", code, <||>,
    <|"reason" -> reason, "pool_exhausted" -> False,
      "repair_eligible" -> False, "repair_invoked" -> False,
      "preferred_next_route" -> "FIX_INPUT"|>];
  Quit[1]
);

sectorBasis = CanonMethodCard`LoadArtifact[task, inputPath, "sector_basis"];
cut = CanonMethodCard`LoadArtifact[task, inputPath, "sector_cut_de"];
candidates = CanonMethodCard`LoadArtifact[task, inputPath, "core_candidates"];

(* Bind a candidate to the declared ordered problem before checking its algebra.
   This boundary accepts exact algebraic inputs as well as rational ones; the
   rational-provider validators would exclude the IBP and epsilon-zero routes. *)
nonemptyStringQ[value_] := StringQ[value] && StringLength[value] > 0;
orderedBasisQ[value_] := ListQ[value] && value =!= {} && DuplicateFreeQ[value];
exactMatrixQ[value_, rows_Integer, columns_Integer] :=
  MatrixQ[value] && Dimensions[value] === {rows, columns} &&
  FreeQ[value, _Real | Indeterminate | ComplexInfinity | DirectedInfinity[___] |
    Undefined | _String | _Association | _Missing | _Failure | _Rule | _RuleDelayed | $Failed];
exactMatricesQ[value_, count_Integer, dimension_Integer] :=
  ListQ[value] && Length[value] === count &&
  And @@ (exactMatrixQ[#, dimension, dimension] & /@ value);
coefficientDomainQ[value_] := MemberQ[
  {"exact-rational-functions", "exact-algebraic-functions"}, value];
expressionDomain[entries_List] := Which[
  And @@ (CanonMethodCard`ExactRationalExpressionQ /@ entries), "exact-rational-functions",
  And @@ (CanonMethodCard`ExactAlgebraicExpressionQ /@ entries), "exact-algebraic-functions",
  True, Missing["unsupported-coefficient-domain"]
];
domainMatchesQ[actual_, declared_] := coefficientDomainQ[actual] &&
  (declared === Automatic || declared === "exact-algebraic-functions" || actual === declared);

If[!CanonMethodCard`ValidSectorBasisQ[sectorBasis] ||
    !nonemptyStringQ[Lookup[sectorBasis, "family_id", None]] ||
    !nonemptyStringQ[Lookup[sectorBasis, "basis_id", None]] ||
    !orderedBasisQ[Lookup[sectorBasis, "basis", None]],
  invalid["INVALID_INPUT", "sector_basis must identify a nonempty ordered basis"]
];
If[!AssociationQ[cut] ||
    Lookup[cut, "schema", None] =!= "canon-neu/sector-cut-de/v1" ||
    !AssociationQ[Lookup[cut, "sector", None]] ||
    !nonemptyStringQ[Lookup[cut, "family_id", None]] ||
    !nonemptyStringQ[Lookup[cut, "basis_id", None]] ||
    !orderedBasisQ[Lookup[cut, "basis", None]] ||
    (KeyExistsQ[cut, "coefficient_domain"] && !coefficientDomainQ[cut["coefficient_domain"]]),
  invalid["INVALID_DIFFERENTIAL_SYSTEM", "Invalid sector_cut_de schema, identity, or coefficient domain"]
];
variables = Lookup[cut, "variables", None];
regulator = Lookup[cut, "regulator", None];
dimension = Length[cut["basis"]];
If[!ListQ[variables] || variables === {} ||
    !And @@ (MatchQ[#, _Symbol] & /@ variables) || !DuplicateFreeQ[variables] ||
    !MatchQ[regulator, _Symbol] || MemberQ[variables, regulator] ||
    !exactMatricesQ[Lookup[cut, "matrices", None], Length[variables], dimension],
  invalid["INVALID_DIFFERENTIAL_SYSTEM", "Cut matrices must be finite exact square matrices for distinct variables and a separate regulator"]
];
cutDomain = expressionDomain[Flatten[cut["matrices"]]];
If[!domainMatchesQ[cutDomain, Lookup[cut, "coefficient_domain", Automatic]],
  invalid["INVALID_DIFFERENTIAL_SYSTEM", "Cut entries must belong to their declared exact rational or algebraic function domain"]
];
If[!AssociationQ[candidates] ||
    Lookup[candidates, "schema", None] =!= "canon-neu/core-candidates/v1" ||
    Lookup[candidates, "convention", None] =!= "old_basis = transformation . new_basis" ||
    (KeyExistsQ[candidates, "coefficient_domain"] &&
      !coefficientDomainQ[candidates["coefficient_domain"]]) ||
    !AssociationQ[Lookup[candidates, "method", None]] ||
    !nonemptyStringQ[Lookup[Lookup[candidates, "method", <||>], "id", None]] ||
    !ListQ[Lookup[candidates, "candidates", None]],
  invalid["INVALID_INPUT", "Invalid core_candidates schema, convention, domain, method, or candidate list"]
];
declaredDomain = Lookup[candidates, "coefficient_domain", Automatic];
If[!AssociationQ[Lookup[task, "sector", None]] ||
    Lookup[task, "sector", None] =!= cut["sector"] ||
    !And @@ (Lookup[sectorBasis, #, None] === Lookup[cut, #, None] & /@
      {"sector", "family_id", "basis_id", "basis"}) ||
    !And @@ (Lookup[candidates, #, None] === Lookup[cut, #, None] & /@
      {"sector", "family_id", "basis_id", "basis", "variables", "regulator"}),
  invalid["INVALID_INPUT", "Task, basis, cut DE, and candidates must agree on sector, family, ordered basis, variables, and regulator"]
];

(* A reduced integral proposal may also contain proper-subsector masters.
   source_basis need not equal the cut basis, but its columns must be explicit. *)
sourceBasis = Lookup[candidates, "source_basis", cut["basis"]];
If[!orderedBasisQ[sourceBasis] || !And @@ (MemberQ[sourceBasis, #] & /@ cut["basis"]),
  invalid["INVALID_INPUT", "source_basis must contain every current-sector master exactly once"]
];
candidateList = candidates["candidates"];
If[!And @@ (AssociationQ /@ candidateList),
  invalid["INVALID_INPUT", "Each candidate must be an Association"]
];
candidateIDs = Lookup[candidateList, "candidate_id", None];
If[!And @@ (nonemptyStringQ /@ candidateIDs) || !DuplicateFreeQ[candidateIDs],
  invalid["INVALID_INPUT", "Candidate IDs must be nonempty and unique within the ordered pool"]
];
pool = Lookup[candidates, "candidate_group_pool", None];
If[!AssociationQ[pool] ||
    !And @@ (IntegerQ[Lookup[pool, #, None]] && Lookup[pool, #, -1] >= 0 & /@
      {"declared", "eligible", "remaining", "unconsumed_candidates"}) ||
    !MemberQ[{True, False}, Lookup[pool, "pool_exhausted", None]],
  invalid["INVALID_INPUT", "Candidate group pool must declare nonnegative integer counts and a Boolean exhaustion flag"]
];
If[pool["eligible"] =!= Length[candidateList] ||
    pool["declared"] < pool["eligible"] + pool["remaining"] ||
    (TrueQ[pool["pool_exhausted"]] && pool["unconsumed_candidates"] =!= 0),
  invalid["INVALID_INPUT", "Candidate group pool counts or upstream exhaustion are inconsistent"]
];
candidateInputReason[candidate_Association] := Module[{construction, entries, domain},
  construction = Lookup[candidate, "construction_rejection", Missing["construction_rejection"]];
  If[construction =!= None && !nonemptyStringQ[construction],
    Return["construction_rejection must be None or a nonempty rejection signature"]];
  (* Rejected constructions intentionally have no matrix proposal to check. *)
  If[StringQ[construction], Return[None]];
  If[!exactMatrixQ[Lookup[candidate, "transformation", None], dimension, dimension] ||
      !exactMatricesQ[Lookup[candidate, "transformed_matrices", None], Length[variables], dimension] ||
      (KeyExistsQ[candidate, "new_basis_rows"] &&
        !exactMatrixQ[candidate["new_basis_rows"], dimension, dimension]) ||
      (KeyExistsQ[candidate, "full_new_basis_rows"] &&
        !exactMatrixQ[candidate["full_new_basis_rows"], dimension, Length[sourceBasis]]),
    Return["Candidate matrices must be finite exact matrices with the declared basis and direction dimensions"]];
  entries = Flatten[Lookup[candidate, Select[
    {"transformation", "transformed_matrices", "new_basis_rows", "full_new_basis_rows"},
    KeyExistsQ[candidate, #] &]]];
  domain = expressionDomain[entries];
  If[!domainMatchesQ[domain, declaredDomain],
    Return["Candidate entries must belong to their declared exact rational or algebraic function domain"]];
  domain
];

checks = {};
inputErrors = {};
accepted = Missing["not-found"];
Do[
  candidate = candidateList[[index]];
  candidateDomain = candidateInputReason[candidate];
  If[candidateDomain =!= None && !coefficientDomainQ[candidateDomain],
    check = <|"candidate_id" -> candidate["candidate_id"], "index" -> index,
      "pass" -> False, "input_valid" -> False,
      "rejection_signature" -> {"invalid_candidate_input"}, "reason" -> candidateDomain|>;
    AppendTo[inputErrors, candidate["candidate_id"]],
    check = Join[CanonMethodCard`CheckCoreCandidate[
      candidate, cut["matrices"], cut["variables"], cut["regulator"], index,
      If[KeyExistsQ[candidate, "full_new_basis_rows"],
        candidate["full_new_basis_rows"][[All,
          (First @ FirstPosition[sourceBasis, #] & /@ cut["basis"])]],
        Lookup[candidate, "new_basis_rows", Automatic]]],
      <|"input_valid" -> True|>,
      If[coefficientDomainQ[candidateDomain], <|"coefficient_domain" -> candidateDomain|>, <||>]]
  ];
  AppendTo[checks, check];
  If[TrueQ[check["pass"]], accepted = check; Break[]],
  {index, Length[candidateList]}
];
public[entry_] := KeyDrop[entry, {"transformation", "transformed_matrices"}];
attemptedIDs = #["candidate_id"] & /@ checks;
remaining = pool["remaining"] + pool["eligible"] - Length[checks];
domainSummary = <|
  "coefficient_domain_inferred" -> (declaredDomain === Automatic),
  "declared_coefficient_domain" -> If[declaredDomain === Automatic, Null, declaredDomain],
  "invalid_candidate_ids" -> inputErrors|>;

If[MissingQ[accepted],
  poolExhausted = inputErrors === {} && TrueQ[pool["pool_exhausted"]] && remaining === 0;
  CanonMethodCard`WriteResult[
    task, outputDir,
    If[inputErrors =!= {}, "ERROR", If[poolExhausted, "FAIL", "INCONCLUSIVE"]],
    If[inputErrors =!= {}, "INVALID_INPUT", If[poolExhausted, "CORE_FAIL", "CANDIDATE_BUDGET_EXHAUSTED"]],
    <||>,
    Join[domainSummary, <|"attempted_candidate_ids" -> attemptedIDs,
        "remaining_candidate_groups" -> remaining,
        "pool_exhausted" -> poolExhausted,
        "repair_eligible" -> poolExhausted,
        "repair_invoked" -> False,
        "attempts" -> (public /@ checks),
        "preferred_next_route" -> If[inputErrors === {}, "SELECT_CORE_METHOD", "FIX_INPUT"]|>]
  ];
  Quit[If[inputErrors === {}, 0, 1]]
];

coreTransform = <|
  "schema" -> "canon-neu/core-transform/v1",
  "sector" -> cut["sector"], "family_id" -> cut["family_id"],
  "basis_id" -> cut["basis_id"],
  "coefficient_domain" -> accepted["coefficient_domain"],
  "basis" -> sectorBasis["basis"], "variables" -> cut["variables"],
  "regulator" -> cut["regulator"],
  "convention" -> "old_basis = transformation . new_basis",
  "method" -> candidates["method"],
  "candidate_id" -> accepted["candidate_id"],
  "candidate_index" -> accepted["index"],
  "transformation" -> accepted["transformation"],
  "transformed_matrices" -> accepted["transformed_matrices"],
  "checks" -> public[accepted]
|>;
artifactPath = CanonMethodCard`WriteWLArtifact[coreTransform, outputDir, "core-transform.wl"];
CanonMethodCard`WriteResult[
  task, outputDir, "PASS", "CORE_PASS",
  <|"core_transform" -> <|
    "type" -> "mathematica-expression", "path" -> FileNameTake[artifactPath]|>|>,
  Join[domainSummary, <|"selected_candidate_id" -> accepted["candidate_id"],
    "coefficient_domain" -> accepted["coefficient_domain"],
    "candidate_index" -> accepted["index"],
    "attempted_candidate_ids" -> attemptedIDs,
    "remaining_candidate_groups" -> remaining,
    "pool_exhausted" -> False, "repair_eligible" -> False,
    "repair_invoked" -> False, "attempts" -> (public /@ checks)|>]
];
