#!/usr/bin/env wolframscript
$HistoryLength = 0;
repoRoot = DirectoryName[DirectoryName[ExpandFileName[$InputFileName]]];
Get[FileNameJoin[{repoRoot, "mma", "lib", "MethodCardCore.wl"}]];
Get[FileNameJoin[{repoRoot, "mma", "lib", "IBPReductionAudit.wl"}]];
ClearAll[h, d, x, y, zz];
contract = <|"schema" -> "canon-neu/ibp-audit-contract/v1",
  "integral_head" -> h, "index_count" -> 2,
  "coefficient_symbols" -> {d, x, y},
  "expected_masters" -> {h[1, 0], h[0, 1]},
  "required_targets" -> {h[1, 0], h[2, -1]}, "master_order" -> "exact"|>;
reduction = <|"masters" -> contract["expected_masters"],
  "rules" -> {h[2, -1] -> (x + y)/(d - 4) h[1, 0] + 2 h[0, 1]}|>;
audit[rhs_, changes_Association : <||>] := CANON`IBPReductionAudit`AuditIBPReduction[
  Join[reduction, <|"rules" -> {h[2, -1] -> rhs}|>], Join[contract, changes]];
case[name_, actual_, status_, reasonCode_] := VerificationTest[
  {actual["status"], actual["code"], Lookup[actual["summary"], "reason_code", None]},
  {status, Switch[status, "PASS", "IBP_AUDIT_PASS", "ERROR", "IBP_EXECUTION_FAILED",
    _, "IBP_CHECK_FAILED"], If[status === "PASS", None, reasonCode]}, TestID -> name];
points = Table[Prime[2 + k]/Prime[3 + k], {k, {0, 7, 14}}];
zeroBase = (x + 1)^2 - x^2 - 2 x - 1;
fallbackBase = Times @@ (x - points);
passed = CANON`IBPReductionAudit`AuditIBPReduction[reduction, contract];
permuted = CANON`IBPReductionAudit`AuditIBPReduction[
  Join[reduction, <|"masters" -> Reverse[reduction["masters"]]|>],
  Join[contract, <|"master_order" -> "permutation"|>]];
tests = {
  case["exact-rational-linear-signed-indices", passed, "PASS", "IBP_AUDIT_PASS"],
  VerificationTest[passed["checks", "denominators_not_identically_zero"] &&
    passed["counts", "denominator_witnesses"] === 1, True, TestID -> "exact-nonzero-witness"],
  case["zero-RHS", audit[0], "PASS", "IBP_AUDIT_PASS"],
  case["atomic-master-RHS", audit[h[1, 0]], "PASS", "IBP_AUDIT_PASS"],
  case["missing-target", CANON`IBPReductionAudit`AuditIBPReduction[
    Join[reduction, <|"rules" -> {}|>], contract], "FAIL", "IBP_MISSING_TARGETS"],
  case["duplicate-rule-LHS", CANON`IBPReductionAudit`AuditIBPReduction[
    Join[reduction, <|"rules" -> Join[reduction["rules"], reduction["rules"]]|>], contract],
    "FAIL", "IBP_DUPLICATE_LHS"],
  case["duplicate-masters", CANON`IBPReductionAudit`AuditIBPReduction[
    Join[reduction, <|"masters" -> {h[1, 0], h[1, 0]}|>], contract], "FAIL", "IBP_INVALID_MASTERS"],
  case["wrong-master-space", CANON`IBPReductionAudit`AuditIBPReduction[
    Join[reduction, <|"masters" -> {h[1, 0], h[0, 2]}|>], contract], "FAIL", "IBP_MASTER_MISMATCH"],
  case["strict-source-order", CANON`IBPReductionAudit`AuditIBPReduction[
    Join[reduction, <|"masters" -> Reverse[reduction["masters"]]|>], contract],
    "FAIL", "IBP_MASTER_ORDER_MISMATCH"],
  VerificationTest[permuted["status"] === "PASS" && permuted["master_permutation"] === {2, 1},
    True, TestID -> "explicit-permutation-preserves-workflow-order"],
  case["unreduced-target-on-RHS", audit[h[3, 0]], "FAIL", "IBP_UNREDUCED_INTEGRALS"],
  case["bad-integral-arity", audit[h[1, 0, 0]], "FAIL", "IBP_UNREDUCED_INTEGRALS"],
  case["noninteger-integral-index", audit[h[1, 1/2]], "FAIL", "IBP_UNREDUCED_INTEGRALS"],
  case["undeclared-atomic-coefficient", audit[zz h[1, 0]], "FAIL", "IBP_UNDECLARED_SYMBOL"],
  case["inexact-real", audit[0.5 h[1, 0]], "FAIL", "IBP_INEXACT_OR_UNDEFINED"],
  case["inexact-complex-in-Qi", audit[(1. + I) h[1, 0],
    <|"options" -> <|"coefficient_field" -> "Q(i)"|>|>], "FAIL", "IBP_INEXACT_OR_UNDEFINED"],
  case["undefined", audit[Indeterminate], "FAIL", "IBP_INEXACT_OR_UNDEFINED"],
  case["exact-complex-outside-Q", audit[I h[1, 0]], "FAIL", "IBP_COEFFICIENT_FIELD_MISMATCH"],
  case["declared-exact-complex-field", audit[I h[1, 0],
    <|"options" -> <|"coefficient_field" -> "Q(i)"|>|>], "PASS", "IBP_AUDIT_PASS"],
  case["nonlinear-syntax-requires-further-work", audit[h[1, 0]^2],
    "FAIL", "IBP_UNSUPPORTED_STRUCTURE"],
  case["scalar-offset-cannot-pass", audit[x + h[1, 0]], "FAIL", "IBP_UNSUPPORTED_STRUCTURE"],
  case["transcendental-coefficient", audit[Sin[x] h[1, 0]], "FAIL", "IBP_UNSUPPORTED_STRUCTURE"],
  case["algebraic-coefficient", audit[Sqrt[x] h[1, 0]], "FAIL", "IBP_UNSUPPORTED_STRUCTURE"],
  case["symbolic-power", audit[x^d h[1, 0]], "FAIL", "IBP_UNSUPPORTED_STRUCTURE"],
  case["string-is-not-a-rational-scalar", audit["scalar" h[1, 0]], "FAIL", "IBP_UNSUPPORTED_STRUCTURE"],
  case["unevaluated-rational-constructor", Quiet[audit[Rational[x, y] h[1, 0]]],
    "FAIL", "IBP_UNSUPPORTED_STRUCTURE"],
  case["unevaluated-integer-constructor", audit[Integer[x] h[1, 0]],
    "FAIL", "IBP_UNSUPPORTED_STRUCTURE"],
  case["hidden-identically-zero-denominator", audit[h[1, 0]/zeroBase], "FAIL", "IBP_ZERO_DENOMINATOR"],
  case["all-zero-samples-are-not-a-zero-proof", audit[h[1, 0]/fallbackBase], "PASS", "IBP_AUDIT_PASS"],
  case["invalid-options", audit[h[1, 0], <|"options" -> <|"time_limit_seconds" -> -1|>|>],
    "ERROR", "INVALID_IBP_AUDIT_OPTIONS"],
  case["invalid-option-type", audit[h[1, 0], <|"options" -> 7|>],
    "ERROR", "INVALID_IBP_AUDIT_OPTIONS"],
  case["unbounded-audit-is-not-accepted", audit[h[1, 0],
    <|"options" -> <|"time_limit_seconds" -> Infinity|>|>],
    "ERROR", "INVALID_IBP_AUDIT_OPTIONS"],
  case["unknown-option-is-not-ignored", audit[h[1, 0], <|"options" -> <|"typo" -> 1|>|>],
    "ERROR", "INVALID_IBP_AUDIT_OPTIONS"],
  case["missing-independent-declaration", CANON`IBPReductionAudit`AuditIBPReduction[
    reduction, KeyDrop[contract, "coefficient_symbols"]], "ERROR", "INVALID_IBP_AUDIT_CONTRACT"],
  case["delayed-rule-not-accepted", CANON`IBPReductionAudit`AuditIBPReduction[
    Join[reduction, <|"rules" -> {h[2, -1] :> h[1, 0]}|>], contract], "FAIL", "IBP_INVALID_RULES"],
  case["master-redefinition", CANON`IBPReductionAudit`AuditIBPReduction[
    Join[reduction, <|"rules" -> Append[reduction["rules"], h[1, 0] -> 0]|>], contract],
    "FAIL", "IBP_MASTER_REDEFINED"],
  VerificationTest[CanonMethodCard`DeclaredCoefficientDomainQ[zz, {x}], False,
    TestID -> "shared-helper-includes-level-zero-symbol"],
  VerificationTest[CanonMethodCard`DeclaredCoefficientDomainQ[x, {x}] &&
    CanonMethodCard`DeclaredCoefficientDomainQ[I x, {x}] &&
    CanonMethodCard`DeclaredCoefficientDomainQ[1/3, {}], True,
    TestID -> "shared-helper-preserves-declared-symbol-and-exact-complex-policy"]
};

(* Library callers supply an identity already verified at a file boundary;
   real SHA256 verification and changed-file rejection are exercised below. *)
verifiedIdentity = StringRepeat["a", 64];
boundPassed = CANON`IBPReductionAudit`AuditIBPReduction[reduction, contract, None, verifiedIdentity];
reuse[r_, c_ : contract, prior_ : boundPassed, identity_ : verifiedIdentity] :=
  CANON`IBPReductionAudit`AuditIBPReduction[r, c, prior, identity];
matching = reuse[reduction];
extendedReduction = Join[reduction, <|"rules" -> Append[reduction["rules"], h[3, -1] -> h[0, 1]]|>];
extendedReceipt = CANON`IBPReductionAudit`AuditIBPReduction[extendedReduction, contract, None, verifiedIdentity];
extendedTargets = Join[contract, <|"required_targets" -> Append[contract["required_targets"], h[3, -1]]|>];
staleChecker = Join[boundPassed, <|"binding" -> Join[boundPassed["binding"],
  <|"checker_sha256" -> StringRepeat["0", 64]|>]|>];
staleRuntime = Join[boundPassed, <|"binding" -> Join[boundPassed["binding"],
  <|"wolfram_version" -> "another-runtime"|>]|>];
legacyReceipt = Join[boundPassed, <|"binding" -> Join[boundPassed["binding"],
  <|"schema" -> "canon-neu/ibp-audit-binding/v1"|>]|>];
badChecks = Join[boundPassed, <|"checks" -> Join[boundPassed["checks"],
  <|"denominators_not_identically_zero" -> False|>]|>];
complexReduction = Join[reduction, <|"rules" -> {h[2, -1] -> I h[1, 0]}|>];
complexContract = Join[contract, <|"options" -> <|"coefficient_field" -> "Q(i)"|>|>];
complexReceipt = CANON`IBPReductionAudit`AuditIBPReduction[complexReduction, complexContract, None, verifiedIdentity];
reuseTests = {
  VerificationTest[matching["status"] === "PASS" && matching["reuse", "used"] &&
    matching["counts"] === passed["counts"], True, TestID -> "matching-receipt-reuses-RHS-proof"],
  VerificationTest[CANON`IBPReductionAudit`AuditIBPReduction[
      Join[reduction, <|"ibp_audit" -> boundPassed|>], contract]["reuse", "used"],
    False, TestID -> "in-memory-receipt-without-verified-file-identity-is-not-reused"],
  VerificationTest[reuse[reduction, contract, None]["reuse", "used"], False,
    TestID -> "None-forces-full-audit"],
  VerificationTest[With[{a = reuse[extendedReduction, extendedTargets, extendedReceipt]},
    a["status"] === "PASS" && a["reuse", "used"] && a["counts", "required_targets"] === 3],
    True, TestID -> "new-targets-are-covered-by-extra-previously-audited-rules"],
  case["missing-new-target-still-fails-before-reuse", reuse[reduction, extendedTargets], "FAIL", "IBP_MISSING_TARGETS"],
  VerificationTest[With[{a = reuse[reduction,
      Join[contract, <|"expected_masters" -> Reverse[reduction["masters"]], "master_order" -> "permutation"|>]]},
    a["status"] === "PASS" && a["reuse", "used"] && a["master_permutation"] === {2, 1}],
    True, TestID -> "same-file-permutation-is-rechecked-for-changed-consumer-order"],
  case["strict-order-is-still-enforced-before-reuse", reuse[
    Join[reduction, <|"masters" -> Reverse[reduction["masters"]]|>]], "FAIL", "IBP_MASTER_ORDER_MISMATCH"],
  case["changed-RHS-with-old-receipt-is-checked", reuse[
    Join[reduction, <|"rules" -> {h[2, -1] -> zz h[1, 0]}|>], contract, boundPassed,
    StringRepeat["b", 64]], "FAIL", "IBP_UNDECLARED_SYMBOL"],
  case["changed-coefficient-symbols-invalidate-reuse", reuse[reduction,
    Join[contract, <|"coefficient_symbols" -> {d, x}|>]], "FAIL", "IBP_UNDECLARED_SYMBOL"],
  case["changed-coefficient-field-invalidate-reuse", reuse[complexReduction, contract, complexReceipt],
    "FAIL", "IBP_COEFFICIENT_FIELD_MISMATCH"],
  case["changed-master-space-invalidate-reuse", reuse[
    Join[reduction, <|"masters" -> {h[1, 0], h[0, 2]}|>],
    Join[contract, <|"expected_masters" -> {h[1, 0], h[0, 2]}|>]],
    "FAIL", "IBP_UNREDUCED_INTEGRALS"],
  VerificationTest[And @@ (With[{a = reuse[reduction, contract, #]},
    a["status"] === "PASS" && !a["reuse", "used"]] & /@
    {passed, KeyDrop[boundPassed, "binding"], staleChecker, staleRuntime, legacyReceipt, badChecks,
      Join[boundPassed, <|"status" -> "INCONCLUSIVE"|>]}),
    True, TestID -> "old-incomplete-stale-and-nonpassing-receipts-trigger-full-audit"],
  VerificationTest[reuse[reduction, Join[contract, <|"options" -> <|"time_limit_seconds" -> 1|>|>]]["reuse", "used"],
    True, TestID -> "new-finite-budget-does-not-invalidate-completed-proof"]
};
tests = Join[tests, reuseTests];

(* Give the audit a large input but a finite tiny budget. Creating the input
   occurs before the timed check, so an interrupted audit cannot claim FAIL. *)
large = <|"masters" -> reduction["masters"], "rules" -> Table[
  h[i, -1] -> h[1, 0], {i, 2, 100001}]|>;
AppendTo[tests, case["time-budget-is-inconclusive",
  CANON`IBPReductionAudit`AuditIBPReduction[large,
    Join[contract, <|"options" -> <|"time_limit_seconds" -> 0.001|>|>]],
  "FAIL", "IBP_AUDIT_TIMEOUT"]];

(* Exercise the common step, JSON-relative paths and file-bound receipt. *)
temporary = CreateDirectory[];
Put[contract, FileNameJoin[{temporary, "contract.wl"}]];
Put[reduction, FileNameJoin[{temporary, "reduction.wl"}]];
Export[FileNameJoin[{temporary, "input.json"}], <|
  "schema" -> "canon-neu/script-input/v1", "task_id" -> "IBP-AUDIT-TEST", "step" -> "CHECK_IBP",
  "payload" -> <|"ibp_contract" -> <|"path" -> "contract.wl"|>,
    "ibp_reduction" -> <|"path" -> "reduction.wl"|>|>|>, "RawJSON"];
process = RunProcess[{"wolframscript", "-file",
  FileNameJoin[{repoRoot, "mma", "CheckIBPReduction.wls"}],
  FileNameJoin[{temporary, "input.json"}], FileNameJoin[{temporary, "pass"}]}];
receipt = Get[FileNameJoin[{temporary, "pass", "ibp-audit.wl"}]];
result = Import[FileNameJoin[{temporary, "pass", "result.json"}], "RawJSON"];
AppendTo[tests, VerificationTest[process["ExitCode"] === 0 && result["status"] === "PASS" &&
  receipt["inputs", "ibp_reduction", "sha256"] ===
    FileHash[FileNameJoin[{temporary, "reduction.wl"}], "SHA256", "HexString"],
  True, TestID -> "CHECK-IBP-positive-receipt-binds-files"]];
Put[receipt, FileNameJoin[{temporary, "prior.wl"}]];
cachedRequest = Import[FileNameJoin[{temporary, "input.json"}], "RawJSON"];
cachedRequest["payload"] = Join[cachedRequest["payload"],
  <|"ibp_audit" -> <|"path" -> "prior.wl"|>|>];
Export[FileNameJoin[{temporary, "cached.json"}], cachedRequest, "RawJSON"];
process = RunProcess[{"wolframscript", "-file",
  FileNameJoin[{repoRoot, "mma", "CheckIBPReduction.wls"}],
  FileNameJoin[{temporary, "cached.json"}], FileNameJoin[{temporary, "cached"}]}];
cachedReceipt = Get[FileNameJoin[{temporary, "cached", "ibp-audit.wl"}]];
AppendTo[tests, VerificationTest[process["ExitCode"] === 0 && cachedReceipt["reuse", "used"] &&
  KeyExistsQ[cachedReceipt["inputs"], "ibp_audit"],
  True, TestID -> "CHECK-IBP-reuses-file-receipt-with-input-binding"]];
(* A same-sized file edit must invalidate the old PASS, even though all targets
   and left sides still match. No per-rule fingerprint is needed. *)
Put[Join[reduction, <|"rules" -> {h[2, -1] -> zz h[1, 0]}|>],
  FileNameJoin[{temporary, "reduction.wl"}]];
process = RunProcess[{"wolframscript", "-file",
  FileNameJoin[{repoRoot, "mma", "CheckIBPReduction.wls"}],
  FileNameJoin[{temporary, "cached.json"}], FileNameJoin[{temporary, "changed-invalid"}]}];
changedReceipt = Get[FileNameJoin[{temporary, "changed-invalid", "ibp-audit.wl"}]];
AppendTo[tests, VerificationTest[process["ExitCode"] =!= 0 &&
  changedReceipt["code"] === "IBP_CHECK_FAILED" &&
    changedReceipt["summary", "reason_code"] === "IBP_UNDECLARED_SYMBOL" && !changedReceipt["reuse", "used"],
  True, TestID -> "changed-file-with-same-rule-count-is-fully-checked"]];
Put[Join[reduction, <|"rules" -> {h[2, -1] -> 3 h[1, 0]}|>],
  FileNameJoin[{temporary, "reduction.wl"}]];
process = RunProcess[{"wolframscript", "-file",
  FileNameJoin[{repoRoot, "mma", "CheckIBPReduction.wls"}],
  FileNameJoin[{temporary, "cached.json"}], FileNameJoin[{temporary, "changed-valid"}]}];
changedReceipt = Get[FileNameJoin[{temporary, "changed-valid", "ibp-audit.wl"}]];
AppendTo[tests, VerificationTest[process["ExitCode"] === 0 && !changedReceipt["reuse", "used"],
  True, TestID -> "valid-new-file-is-fully-audited-and-gets-new-PASS"]];
Put[changedReceipt, FileNameJoin[{temporary, "reduction.wl.audit.wl"}]];
process = RunProcess[{"wolframscript", "-file",
  FileNameJoin[{repoRoot, "mma", "CheckIBPReduction.wls"}],
  FileNameJoin[{temporary, "input.json"}], FileNameJoin[{temporary, "adjacent"}]}];
adjacentReceipt = Get[FileNameJoin[{temporary, "adjacent", "ibp-audit.wl"}]];
AppendTo[tests, VerificationTest[process["ExitCode"] === 0 && adjacentReceipt["reuse", "used"],
  True, TestID -> "producer-adjacent-receipt-is-used-automatically"]];
Put[Join[contract, <|"required_targets" -> Append[contract["required_targets"], h[4, -1]]|>],
  FileNameJoin[{temporary, "contract.wl"}]];
process = RunProcess[{"wolframscript", "-file",
  FileNameJoin[{repoRoot, "mma", "CheckIBPReduction.wls"}],
  FileNameJoin[{temporary, "input.json"}], FileNameJoin[{temporary, "new-target"}]}];
newTargetReceipt = Get[FileNameJoin[{temporary, "new-target", "ibp-audit.wl"}]];
AppendTo[tests, VerificationTest[process["ExitCode"] =!= 0 &&
  newTargetReceipt["code"] === "IBP_CHECK_FAILED" &&
    newTargetReceipt["summary", "reason_code"] === "IBP_MISSING_TARGETS",
  True, TestID -> "unchanged-file-PASS-does-not-cover-missing-new-target"]];
Put[contract, FileNameJoin[{temporary, "contract.wl"}]];
CopyFile[FileNameJoin[{temporary, "reduction.wl"}], FileNameJoin[{temporary, "copied.wl"}]];
copiedRequest = Import[FileNameJoin[{temporary, "input.json"}], "RawJSON"];
copiedRequest["payload", "ibp_reduction", "path"] = "copied.wl";
copiedRequest["payload", "ibp_audit"] = <|"path" -> "reduction.wl.audit.wl"|>;
Export[FileNameJoin[{temporary, "copied.json"}], copiedRequest, "RawJSON"];
process = RunProcess[{"wolframscript", "-file",
  FileNameJoin[{repoRoot, "mma", "CheckIBPReduction.wls"}],
  FileNameJoin[{temporary, "copied.json"}], FileNameJoin[{temporary, "copied"}]}];
copiedReceipt = Get[FileNameJoin[{temporary, "copied", "ibp-audit.wl"}]];
AppendTo[tests, VerificationTest[process["ExitCode"] === 0 && copiedReceipt["reuse", "used"],
  True, TestID -> "registered-renamed-identical-file-uses-explicit-receipt"]];
Put[Join[reduction, <|"rules" -> {}|>], FileNameJoin[{temporary, "reduction.wl"}]];
process = RunProcess[{"wolframscript", "-file",
  FileNameJoin[{repoRoot, "mma", "CheckIBPReduction.wls"}],
  FileNameJoin[{temporary, "input.json"}], FileNameJoin[{temporary, "fail"}]}];
result = Import[FileNameJoin[{temporary, "fail", "result.json"}], "RawJSON"];
AppendTo[tests, VerificationTest[process["ExitCode"] =!= 0 && result["status"] === "FAIL" &&
  result["code"] === "IBP_CHECK_FAILED" && result["summary", "reason_code"] === "IBP_MISSING_TARGETS",
  True, TestID -> "CHECK-IBP-negative-result-is-readable"]];
request = Import[FileNameJoin[{temporary, "input.json"}], "RawJSON"];
request["payload", "ibp_reduction", "sha256"] = StringRepeat["0", 64];
Export[FileNameJoin[{temporary, "input.json"}], request, "RawJSON"];
process = RunProcess[{"wolframscript", "-file",
  FileNameJoin[{repoRoot, "mma", "CheckIBPReduction.wls"}],
  FileNameJoin[{temporary, "input.json"}], FileNameJoin[{temporary, "hash-mismatch"}]}];
result = Import[FileNameJoin[{temporary, "hash-mismatch", "result.json"}], "RawJSON"];
AppendTo[tests, VerificationTest[process["ExitCode"] =!= 0 && result["status"] === "ERROR" &&
  result["code"] === "IBP_EXECUTION_FAILED" && result["summary", "reason_code"] === "INVALID_IBP_AUDIT_INPUT",
  True, TestID -> "CHECK-IBP-rejects-stale-declared-hash"]];
report = TestReport[tests];
Print[InputForm[<|"total" -> report["TestsSucceededCount"] + report["TestsFailedCount"],
  "succeeded" -> report["TestsSucceededCount"], "failed" -> report["TestsFailedCount"]|>]];
If[report["TestsFailedCount"] =!= 0, Print[InputForm[report["TestsFailed"]]]];
DeleteDirectory[temporary, DeleteContents -> True];
Exit[If[report["TestsFailedCount"] === 0, 0, 1]];
