BeginPackage["CANON`IBPReductionAudit`"];

AuditIBPReduction::usage = "AuditIBPReduction[reduction, contract, previousAudit:Automatic, verifiedReductionSHA256:None] audits CANON masters/rules against independent declarations. A trusted PASS bound to a file SHA256 verified by the caller can be reused after checking current master order and target coverage. Without verified file identity, or with previousAudit None, it performs a full audit. Returns PASS/IBP_AUDIT_PASS, FAIL/IBP_CHECK_FAILED or ERROR/IBP_EXECUTION_FAILED, with failure reasons in summary.reason_code. A failed gate is not a proof that IBP identities are false.";
IBPAuditContract::usage = "IBPAuditContract[preparedFamily, masterBasis, targets, options] builds an audit declaration with an explicit permutation into the workflow master order.";
ValidateIBPAuditOptions::usage = "ValidateIBPAuditOptions[options] validates the exact coefficient field and finite audit budgets, returning resolved options or Failure before an expensive producer is launched.";

Begin["`Private`"];

(* Bind receipts to the actual checker source, not a manually maintained version.
   Receipts are trusted workflow artifacts, not signed certificates. *)
checkerSHA256 = Quiet @ Check[
  FileHash[ExpandFileName[$InputFileName], "SHA256", "HexString"], None];
rhsCheckNames = {"rhs_closed_homogeneous_linear", "declared_exact_coefficient_syntax",
  "denominators_not_identically_zero"};
allCheckNames = Join[{"master_space_and_order", "unique_rule_lhs", "target_coverage"}, rhsCheckNames];
denominatorCountNames = {"distinct_denominators", "denominator_witnesses",
  "denominator_symbolic_fallbacks"};

passingReceiptQ[value_, masterCount_, ruleCount_] :=
  AssociationQ[value] &&
    Lookup[value, "schema", None] === "canon-neu/ibp-audit/v1" &&
    Lookup[value, "scope", None] === "declared-targets-and-reduction-structure" &&
    Lookup[value, "status", None] === "PASS" &&
    Lookup[value, "code", None] === "IBP_AUDIT_PASS" &&
    AssociationQ[Lookup[value, "checks", None]] &&
    AllTrue[Lookup[value["checks"], allCheckNames, False], TrueQ] &&
    AssociationQ[Lookup[value, "binding", None]] &&
    Lookup[value["binding"], "schema", None] === "canon-neu/ibp-audit-binding/v2" &&
    StringQ[Lookup[value["binding"], "reduction_sha256", None]] &&
    ListQ[Lookup[value["binding"], "covered_integrals", None]] &&
    Length[value["binding", "covered_integrals"]] === masterCount + ruleCount &&
    AssociationQ[Lookup[value, "counts", None]] &&
    Lookup[value["counts"], "masters", None] === masterCount &&
    Lookup[value["counts"], "rules", None] === ruleCount &&
    AllTrue[Lookup[value["counts"], denominatorCountNames, -1], IntegerQ[#] && # >= 0 &] &&
    Total[Lookup[value["counts"], Rest[denominatorCountNames]]] ===
      value["counts", "distinct_denominators"];

ValidateIBPAuditOptions[options_] := Module[{resolved},
  If[!AssociationQ[options] ||
      Complement[Keys[options], {"coefficient_field", "time_limit_seconds",
        "denominator_time_limit_seconds"}] =!= {},
    Return[Failure["IBP_EXECUTION_FAILED", <|"reason_code" -> "INVALID_IBP_AUDIT_OPTIONS", "MessageTemplate" ->
      "IBP audit options must be an Association of supported keys."|>]]];
  resolved = Join[<|"coefficient_field" -> "Q", "time_limit_seconds" -> 150,
    "denominator_time_limit_seconds" -> 3|>, options];
  If[!MemberQ[{"Q", "Q(i)"}, resolved["coefficient_field"]] ||
      !AllTrue[Lookup[resolved, {"time_limit_seconds", "denominator_time_limit_seconds"}],
        NumberQ[#] && TrueQ[0 < # < Infinity] &],
    Return[Failure["IBP_EXECUTION_FAILED", <|"reason_code" -> "INVALID_IBP_AUDIT_OPTIONS", "MessageTemplate" ->
      "IBP audit requires Q or Q(i) and positive finite time budgets."|>]]];
  resolved
];

IBPAuditContract[prepared_Association, basis_Association, targets_List,
    options_ : <||>] := <|
  "schema" -> "canon-neu/ibp-audit-contract/v1",
  "integral_head" -> If[ListQ[Lookup[basis, "masters", None]] &&
    basis["masters"] =!= {}, Head[First[basis["masters"]]], None],
  "index_count" -> Length[Lookup[basis, "index_order", {}]],
  "coefficient_symbols" -> Lookup[prepared, "parameters", None],
  "expected_masters" -> Lookup[basis, "masters", None],
  "required_targets" -> targets,
  "master_order" -> "permutation",
  "options" -> options
|>;

AuditIBPReduction[reduction_, contract_, previousAudit_ : Automatic,
    verifiedReductionSHA256_ : None] := Module[
  {head, arity, symbols, expected, targets, order, options, field, limit,
   denominatorLimit, masters = {}, rules = {}, checks = <||>, counts = <||>,
   permutation = {}, started = AbsoluteTime[], tag = Unique["audit$"],
   report, stop, validIntegralQ, body, masterSet, masterPattern, scalarPattern,
   foreignPattern, inexactPattern, complexPattern, scalarQ, linearClass, classification,
   lhs, rhs, missing, invalid, bases,
   assignments, witnessCount = 0, fallbackCount = 0, denominatorState, state,
   previous, binding = None, reuseUsed = False,
   reuseReason = "not-reached"},

  (* Route only execution failure versus a nonpassing result check. Specific
     defects and unfinished checks are diagnostic reasons, not workflow codes. *)
  report[status_, reasonCode_, details_Association : <||>] := <|
    "schema" -> "canon-neu/ibp-audit/v1", "status" -> status,
    "code" -> Switch[status, "PASS", "IBP_AUDIT_PASS",
      "ERROR", "IBP_EXECUTION_FAILED", _, "IBP_CHECK_FAILED"],
    "scope" -> "declared-targets-and-reduction-structure",
    "checks" -> checks, "counts" -> counts,
    "master_permutation" -> permutation,
    "binding" -> binding,
    "reuse" -> <|"used" -> reuseUsed, "reason" -> reuseReason|>,
    "summary" -> Join[<|"elapsed_seconds" -> N[AbsoluteTime[] - started]|>,
      If[status === "PASS", <||>, <|"reason_code" -> reasonCode|>], details]
  |>;
  stop[status_, code_, details_Association : <||>] := Throw[report[status, code, details], tag];

  If[!AssociationQ[contract] ||
      Lookup[contract, "schema", None] =!= "canon-neu/ibp-audit-contract/v1",
    Return[report["ERROR", "INVALID_IBP_AUDIT_CONTRACT"]]];
  {head, arity, symbols, expected, targets, order, options} = Lookup[contract,
    {"integral_head", "index_count", "coefficient_symbols", "expected_masters",
     "required_targets", "master_order", "options"}, None];
  If[options === None, options = <||>];
  options = ValidateIBPAuditOptions[options];
  If[FailureQ[options],
    Return[report["ERROR", "INVALID_IBP_AUDIT_OPTIONS"]]];
  {field, limit, denominatorLimit} = Lookup[options,
    {"coefficient_field", "time_limit_seconds", "denominator_time_limit_seconds"}];
  validIntegralQ[e_] := Head[e] === head && Length[e] === arity &&
    AllTrue[List @@ e, IntegerQ];
  If[!MatchQ[head, _Symbol] || Context[head] === "System`" ||
      !IntegerQ[arity] || arity < 1 || !ListQ[symbols] ||
      !AllTrue[symbols, MatchQ[#, _Symbol] && Context[#] =!= "System`" && # =!= head &] ||
      !DuplicateFreeQ[symbols] || !ListQ[expected] || expected === {} ||
      !AllTrue[expected, validIntegralQ] || !DuplicateFreeQ[expected] ||
      !ListQ[targets] || !AllTrue[targets, validIntegralQ] || !DuplicateFreeQ[targets] ||
      !MemberQ[{"exact", "permutation"}, order],
    Return[report["ERROR", "INVALID_IBP_AUDIT_CONTRACT"]]];

  (* Native matching scans scalar blocks; recursion visits only the small
     master-bearing skeleton. No Together/CoefficientRules on complete RHSs. *)
  masterPattern = Blank[head];
  foreignPattern = With[{allowed = Alternatives @@ symbols}, Except[allowed, _Symbol]];
  complexPattern = If[field === "Q", _Complex,
    (c_Complex /; !NumberQ[c] || !FreeQ[{Re[c], Im[c]}, _Real])];
  scalarPattern = With[{foreign = foreignPattern, complex = complexPattern},
    foreign | complex |
      Except[_Integer | _Rational | _Complex | _Symbol | _Plus | _Times |
        HoldPattern[Verbatim[Power][_, _Integer]]] |
      Except[HoldPattern[Rational[_Integer, _Integer]], _Rational] |
      HoldPattern[Integer[___]]];
  inexactPattern = _Real | Indeterminate | _DirectedInfinity |
    (c_Complex /; !FreeQ[{Re[c], Im[c]}, _Real]);
  scalarQ[e_] := FreeQ[e, scalarPattern, {0, Infinity}, Heads -> False];
  linearClass[e_] := Module[{classes}, Which[
    e === 0, -1,
    Head[e] === head, 1,
    FreeQ[e, masterPattern, {0, Infinity}, Heads -> False], If[scalarQ[e], 0, 2],
    Head[e] === Plus,
      classes = DeleteCases[linearClass /@ List @@ e, -1];
      If[MemberQ[classes, 2] || (MemberQ[classes, 0] && MemberQ[classes, 1]), 2,
        If[MemberQ[classes, 1], 1, 0]],
    Head[e] === Times,
      classes = linearClass /@ List @@ e;
      If[MemberQ[classes, 2] || Count[classes, 1] > 1, 2,
        If[MemberQ[classes, -1], -1, If[MemberQ[classes, 1], 1, 0]]],
    True, 2
  ]];
  assignments = Table[Thread[symbols -> Table[
    Prime[j + k]/Prime[j + k + 1], {j, Length[symbols]}]], {k, {0, 7, 14}}];
  denominatorState[base_] := Module[{value, witnessed = False, proof},
    Do[
      value = Quiet[base /. point];
      If[NumberQ[value] && FreeQ[value, _Real | Indeterminate | _DirectedInfinity] &&
          value =!= 0, witnessed = True; Break[]],
      {point, assignments}];
    If[witnessed, witnessCount++; Return["nonzero"]];
    fallbackCount++;
    (* All-zero samples prove nothing. Canonical polynomial expansion is the
       bounded exact fallback; generic kinematic poles are allowed. *)
    proof = TimeConstrained[Quiet @ Check[Module[{normalized = Together[base], polynomials},
      polynomials = {Expand[Numerator[normalized]], Expand[Denominator[normalized]]};
      If[!AllTrue[polynomials, PolynomialQ[#, symbols] &] ||
          !FreeQ[polynomials, inexactPattern] || Last[polynomials] === 0,
        "unknown", If[First[polynomials] === 0, "zero", "nonzero"]]
    ], $Failed], denominatorLimit, $Aborted];
    If[MemberQ[{"zero", "nonzero"}, proof], proof, "unknown"]
  ];

  body[] := (
    If[!AssociationQ[reduction] || !ListQ[Lookup[reduction, "masters", None]] ||
        !ListQ[Lookup[reduction, "rules", None]], stop["FAIL", "INVALID_IBP_REDUCTION"]];
    masters = reduction["masters"]; rules = reduction["rules"];
    counts = <|"masters" -> Length[masters], "rules" -> Length[rules],
      "required_targets" -> Length[targets]|>;
    If[!AllTrue[masters, validIntegralQ] || !DuplicateFreeQ[masters],
      stop["FAIL", "IBP_INVALID_MASTERS"]];
    If[Length[masters] =!= Length[expected] || !SubsetQ[masters, expected],
      stop["FAIL", "IBP_MASTER_MISMATCH"]];
    If[order === "exact" && masters =!= expected, stop["FAIL", "IBP_MASTER_ORDER_MISMATCH"]];
    permutation = (First @ FirstPosition[masters, #]) & /@ expected;
    checks["master_space_and_order"] = True;
    masterSet = AssociationThread[masters, ConstantArray[True, Length[masters]]];
    (* The caller verifies file identity at the artifact boundary. In-memory
       values without such an identity are always audited in full. *)
    previous = If[previousAudit === Automatic,
      Lookup[reduction, "ibp_audit", None], previousAudit];
    binding = <|
      "schema" -> "canon-neu/ibp-audit-binding/v2",
      "reduction_sha256" -> verifiedReductionSHA256,
      "checker_sha256" -> checkerSHA256, "wolfram_version" -> $Version,
      "masters" -> Sort[masters], "integral_head" -> head, "index_count" -> arity,
      "coefficient_symbols" -> Sort[symbols], "coefficient_field" -> field
    |>;
    reuseReason = Which[
      previousAudit === None, "forced-full-audit",
      !StringQ[verifiedReductionSHA256] ||
        !StringMatchQ[verifiedReductionSHA256, RegularExpression["[0-9a-f]{64}"]],
        "no-verified-file-identity",
      !AssociationQ[previous], "no-receipt",
      !passingReceiptQ[previous, Length[masters], Length[rules]], "incomplete-or-nonpassing-receipt",
      !StringQ[checkerSHA256] || KeyDrop[previous["binding"], "covered_integrals"] =!= binding,
        "identity-or-domain-mismatch",
      True, "matching-artifact-and-scope"
    ];
    If[reuseReason === "matching-artifact-and-scope",
      binding["covered_integrals"] = previous["binding", "covered_integrals"];
      missing = Complement[targets, binding["covered_integrals"]];
      If[missing =!= {}, stop["FAIL", "IBP_MISSING_TARGETS", <|
        "missing_count" -> Length[missing],
        "missing_targets" -> (ToString[#, InputForm] & /@ Take[missing, UpTo[20]])|>]];
      checks = Join[checks, KeyTake[previous["checks"],
        Join[{"unique_rule_lhs"}, rhsCheckNames]], <|"target_coverage" -> True|>];
      counts = Join[counts, KeyTake[previous["counts"], denominatorCountNames]];
      reuseUsed = True;
      Return[report["PASS", "IBP_AUDIT_PASS", <|"coefficient_field" -> field,
        "master_order" -> order, "time_limit_seconds" -> limit|>]]
    ];
    If[!AllTrue[rules, MatchQ[#, _Rule] && validIntegralQ[First[#]] &],
      stop["FAIL", "IBP_INVALID_RULES"]];
    lhs = First /@ rules;
    If[!DuplicateFreeQ[lhs], stop["FAIL", "IBP_DUPLICATE_LHS"]];
    If[Intersection[lhs, masters] =!= {}, stop["FAIL", "IBP_MASTER_REDEFINED"]];
    checks["unique_rule_lhs"] = True;
    missing = Complement[targets, Join[masters, lhs]];
    If[missing =!= {}, stop["FAIL", "IBP_MISSING_TARGETS", <|
      "missing_count" -> Length[missing],
      "missing_targets" -> (ToString[#, InputForm] & /@ Take[missing, UpTo[20]])|>]];
    checks["target_coverage"] = True;
    binding["covered_integrals"] = Sort[Join[masters, lhs]];
    rhs = Last /@ rules;
    Do[
      invalid = Select[Cases[rhs[[i]], masterPattern, {0, Infinity}, Heads -> False],
        !validIntegralQ[#] || !TrueQ[Lookup[masterSet, #, False]] &];
      If[invalid =!= {}, stop["FAIL", "IBP_UNREDUCED_INTEGRALS", <|
        "rule_index" -> i,
        "integrals" -> (ToString[#, InputForm] & /@ Take[DeleteDuplicates[invalid], UpTo[20]])|>]];
      classification = linearClass[rhs[[i]]];
      If[!MemberQ[{-1, 1}, classification],
        (* The common valid path has already proved these syntax conditions.
           Additional scans only diagnose a rejected row. *)
        If[!FreeQ[rhs[[i]], inexactPattern, {0, Infinity}, Heads -> False],
          stop["FAIL", "IBP_INEXACT_OR_UNDEFINED", <|"rule_index" -> i|>]];
        If[field === "Q" && !FreeQ[rhs[[i]], _Complex, {0, Infinity}, Heads -> False],
          stop["FAIL", "IBP_COEFFICIENT_FIELD_MISMATCH", <|"rule_index" -> i|>]];
        If[!FreeQ[rhs[[i]], foreignPattern, {0, Infinity}, Heads -> False],
          stop["FAIL", "IBP_UNDECLARED_SYMBOL", <|"rule_index" -> i|>]];
        stop["FAIL", "IBP_UNSUPPORTED_STRUCTURE", <|"rule_index" -> i|>]],
      {i, Length[rules]}];
    checks["rhs_closed_homogeneous_linear"] = True;
    checks["declared_exact_coefficient_syntax"] = True;
    bases = DeleteDuplicates[Cases[rhs, (Power[b_, n_Integer] /; n < 0) :> b,
      {0, Infinity}, Heads -> False]];
    counts["distinct_denominators"] = Length[bases];
    Do[
      state = denominatorState[bases[[i]]];
      If[state === "zero", stop["FAIL", "IBP_ZERO_DENOMINATOR", <|"denominator_index" -> i|>]];
      If[state === "unknown", stop["FAIL", "IBP_DENOMINATOR_UNRESOLVED", <|"denominator_index" -> i|>]],
      {i, Length[bases]}];
    counts["denominator_witnesses"] = witnessCount;
    counts["denominator_symbolic_fallbacks"] = fallbackCount;
    checks["denominators_not_identically_zero"] = True;
    report["PASS", "IBP_AUDIT_PASS", <|"coefficient_field" -> field,
      "master_order" -> order, "time_limit_seconds" -> limit|>]
  );
  TimeConstrained[Catch[body[], tag], limit,
    report["FAIL", "IBP_AUDIT_TIMEOUT", <|"time_limit_seconds" -> limit|>]]
];

End[];
EndPackage[];
