# Basis definition diagnostic

Public step PROFILE_BASIS_DEFINITION accepts the usual JSON envelope and payload.mode = fixture, baseline, or export. payload.accepted_prefix is an optional WL association path; baseline/export require it and read only basis, source_basis and transformation. No original DE is loaded. Inputs use exact old = T.new convention.

payload.phase_seconds bounds each measured phase. payload.wall_seconds bounds the whole child kernel. payload.memory_bytes bounds its resident process-group memory. payload.cpu supplies one allocated CPU. Threads are fixed to one. Every invocation writes result.json, process-receipt.json and events.jsonl including phase start/end and index; hard termination writes INCONCLUSIVE. A result only reports diagnostic completion and never PASS/ALL_PASS.

Baseline duplicates IntegralCoefficientRows operations exactly, recording Expand, selection, residual Together, unit-vector substitution, sparse product, and entrywise FullSimplify[Together]. It does not identify the call stack of another kernel. Timing includes logging overhead. Export validates homogeneous linear structure recursively without expanding scalar coefficients, then obtains a specified row/column coefficient or residual cell. Unsupported integral structures are rejected, not projected.

The optional flint_pair.cpp utility consumes a checked postfix stream: number n, variable v index, root r, add a count, multiply m count, integer power p exponent, end e. First line is number of variables; first expression is rational lambda, second expression lies in Q(v)[r]/(r^2-lambda). Output contains canonical rational a and b for a+b*r. A shared root symbol represents the same supplied square-root branch; no PowerExpand or numerical identity test is used. Division requires nonzero norm. Only exact integers/rationals, declared symbols, sums, products, integer powers and the one declared nonnested square-root base are supported. Zero and nonzero are distinguished exactly. Variable names are v0,... in serialized outputs.

Compile with explicitly supplied coherent FLINT include and library paths; never infer version from a different pkg-config record. Native measurements must include WL conversion/export, native startup/evaluation/output, WL readback and exact comparison. This optional diagnostic does not replace any of the 14 FINAL_CHECK gates.

Compare mode consumes operand_path, expected_path and postfix_path from a prior export, plus an explicit executable. It measures native parse/evaluate/serialize including process startup, WL readback, and exact output equality. All paths resolve from the declaring request.

## Tests and optional FINAL integration

TEST_FLINT_PAIR uses supplied executable and cpu with SymPy for independent exact expected pairs; it tests nonzero/zero, signs, denominators and unsupported opcodes. TEST_FINAL_FLINT uses a supplied fixture directory, executable and patched manifest, preserving the complete ordered component selection on every public FINAL call. The profile finalfixtures mode constructs tiny explicit and intentionally invalid copies of the repository's existing final-check fixture; backendfixture exercises the WL serialization and batch path, including a single branch-consistent quadratic inverse.

Compile flint_pair.cpp against one explicitly selected FLINT installation, using the caller's include directory, exact shared-library filename and matching runtime search path:
c++ -O2 -std=c++17 -I<include> flint_pair.cpp <libflint> -Wl,-rpath,<library-directory> -lgmp -o <executable>
The utility's --version prints compile-header then runtime versions. INPUT --batch evaluates every expression after the initial lambda and returns one canonical a/b pair per cell; the stderr receipt binds count, versions and elapsed native time. It uses one FLINT thread. Coherent library hashes must be recorded by the installing task. No external libraries or system installations are changed by this package.

FINAL_CHECK accepts method_options.basis_backend="flint", flint_executable=<explicit installed path>, and optional progress=true. It preserves IntegralCoefficientRows, old=T.new, the source-order gate, and all fourteen checks. Only the exact zero test of T.basisRows-I changes. The scalar domain is Q(variables,epsilon) with at most one explicit nonnested quadratic generator; unsupported expressions or native failures return ERROR/UNSUPPORTED_BASIS_ARITHMETIC. A nonzero result returns the existing FULL_SYSTEM_FAIL with basis_definition=false. No silent fallback occurs. Default basis_backend="wolfram" retains the existing mathematical operations. Gauge backend selection is independent.

Progress=true records dlog_residues, basis_coefficients, basis_product, basis_zero_flint or individual Wolfram zero cells, and flat_connection in final-progress.jsonl. A start without an end identifies the last started operation for that invocation; it does not identify another process's stack.

This diagnostic does not run a complete FINAL_CHECK or certify the source DE.
For the independent gauge backend and full-check contract, see
[Exact FLINT final check](../flint-final/README.md).

Profile mode basis_flint is the isolated full basis-definition gate only. It accepts accepted_prefix, helper_entry, executable, and optional save_intermediates=true in addition to resource caps. It preserves the original coefficient extractor, constructs the entire sparse residual matrix, and checks every cell using FLINT. It does not import or recheck the source DE. Saved rows and residuals are optional new artifacts; the receipt separately reports frame, serialization, export, native, readback and zero-test timings.
