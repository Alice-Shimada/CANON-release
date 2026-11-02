---
name: canon-build-cut-de
description: Build the exact current-sector quotient basis and cut differential equation from accepted preparation, discovery, and reduction artifacts.
---

# Build the sector cut differential equation

In the assigned run workspace, invoke:

```text
python3 run_step.py INPUT.json FRESH_OUTPUT_DIR
```

The `BUILD_CUT_DE` payload contains `prepared_family`, `master_basis`,
`sector_manifest`, and `ibp_reduction`. The prepared family explicitly
declares `regulator` and `dimension_rule`; never infer either from a symbol name.
An optional `prepared_derivatives` descriptor selects a separately stored source,
resolved from the request. Otherwise use the prepared family's embedded
descriptor, resolved from that artifact. Target preparation and DE construction
share this source loading and normalization.
The selected descriptor's optional SHA-256 is checked before loading. An explicit
descriptor overrides the embedded source; the unused embedded reference is not
loaded or checked.

Before constructing matrices, the script audits every reduction rule against the
family parameters, complete master space and targets of the same affine master
derivatives. The audit records the explicit permutation from reducer order to
the declared basis order. Optional `payload.ibp_audit_options` sets the finite
limits or coefficient field defined in the [IBP audit contract](../../INTERFACES.md#ibp-reduction-audit).
A non-PASS returns `ERROR/IBP_EXECUTION_FAILED` or `FAIL/IBP_CHECK_FAILED` and
publishes no DE. Read `summary.reason_code` and details to fix the invocation,
extend named missing targets, correct the data, or finish a limited check first.
The passing build summary retains the audit; a separate CHECK_IBP call is unnecessary.
An unchanged candidate bridge's trusted passing receipt is reused after verifying
its final file identity, domain, current target coverage and master-order mapping.
The producer writes `candidate-ibp-bridge.wl.audit.wl`; the script discovers this adjacent file,
or takes `payload.ibp_audit`. After registration/renaming, supply the separately
registered receipt explicitly. No per-rule fingerprint scan is performed. Missing
or mismatched receipts trigger a full audit. The summary's `ibp_audit.reuse.used`
records the path.

The script converts the accepted affine denominator records to the one
`DEBuilder` family object and calls `BuildDifferentialEquations` exactly once on
the complete ordered master basis and fully reduced rules. It then finds every
master whose positive propagator bits equal the requested sector bits, in the
resident master order, and takes the same positions from the rows and columns of
each ordered matrix. The column projection quotients only strict proper-subsector
tails; no same-sector entry or mixture is removed. Apply the declared dimension
rule only after constructing the complete differential equation.

PASS writes `canon-neu/sector-basis/v1`, `canon-neu/sector-cut-de/v1`, and the
same call's complete `canon-neu/ordered-master-de/v1` for downstream prefix
construction. The convention is
`D[basis, variable[[i]]] == matrices[[i]].basis`. `sector_boundaries` contains matrix index intervals; `proper_subsectors` lists
the strict proper subsectors defining the quotient. This result certifies the exact
ordered cut block and the recorded DE validity scope; it does not establish a UT
basis, canonical form, global IBP completeness, or a full-system certificate.

For each later resident sector, use the same runner with step
`SLICE_CUT_DE`. It consumes only the accepted `ordered_master_de` and
`sector_manifest`, directly slices the matching rows and columns, and emits only
`sector_basis` and `sector_cut_de` without rebuilding the differential equation.

When several later sectors need slices from the same ordered DE, the optional
[batch-sector-cuts component](../../components/batch-sector-cuts/README.md)
provides `SLICE_CUT_DE_BATCH`. It loads and validates that DE once and writes the
same standard cut/basis artifacts with a direct sector index. Reuse those
hash-bound outputs in subsequent requests; batching does not advance canonical
acceptance.

For a DE-only route, run
[PREPARE_REDUCTION_TARGETS](../canon-prepare-reduction-targets/SKILL.md) on the
ordered masters and prepared family, then pass its `reduction_targets` to
`REDUCE_IBP`. No integral candidate artifact is needed.
