# Reconstruction workflow

Start with a sample set in one declared family, basis, chart, root frame and
scope. Keep full matrices and symbolic epsilon. Use the point-DE producer or an
independent producer of the documented schema; this package does not launch it.

1. Supply raw analytic letters. If only bounded exact one-forms are available,
   call `PROPOSE_LETTERS`, inspect its provisional output, and use it as the
   letter input. Extra user one-forms/seeds are the supported completion hook.
2. Call `RECONSTRUCT_DLOG` with explicit exact or high-precision arithmetic.
3. On `DLOG_RECONSTRUCTED`, call `CHECK_RECONSTRUCTION` with the original sample
   and raw-letter inputs and the reconstruction descriptor. Preserve hashes and
   keep training/validation/blind roles disjoint.
4. On `PASS/RECONSTRUCTION_VALIDATED`, deliver the reconstruction and check
   receipt for their declared finite-sample scope. Do not repeat the fit or claim
   CANON `ALL_PASS`. A global canonical/gauge result requires its own exact
   original-DE and transformation inputs and existing scientific checkers.

| Code | Next input repair |
| --- | --- |
| `INSUFFICIENT_TRAINING_RANK` | Add independent, nonsingular training points or reduce a justified candidate span. Keep independent validation after changing the training set. Rank growth on held-out points requires a new training design. |
| `MISSING_LETTERS_OR_INCONSISTENT_TRAINING` | Check the common frame, basis, data and arithmetic. If these agree, add analytically justified letters/one-forms and make a new bounded fit. |
| `RATIONAL_RECOGNITION_BOUND_EXCEEDED` | The supplied residue coefficients exceed the declared numerator/denominator bounds. Rebuild the bounded proposal or explicitly revise its arithmetic contract. |
| `RATIONAL_RECOGNITION_FAILED` | Review coefficient precision and justified rational bounds; change the declared precision/bounds or the ansatz based on evidence. |
| `EPSILON_NOT_FACTORIZED` | Repair the basis/frame or point-DE input; no letter fit can remove residual symbolic epsilon dependence. |
| `IDENTITY_OR_FRAME_MISMATCH`, `SOURCE_BINDING_MISMATCH`, `SOURCE_HASH_MISMATCH` | Resolve the actual changed identity/source before any downstream claim. Do not relabel a different frame to force agreement. |
| `SAMPLE_ROLE_OVERLAP`, `MISSING_VALIDATION` | Supply genuinely disjoint points and a nonempty validation set. Renaming a repeated point does not create independent evidence. |
| `INCOMPLETE_MATRICES`, `INCOMPLETE_RESIDUE_MATRICES` | Supply every matrix direction, row and column. Partial fits never count as complete. |
| `NONZERO_SPARSE_DEFAULT` | Supply an equivalent matrix with a zero SparseArray default (or explicit rows); implicit nonzero backgrounds are outside this sparse input contract. |
| `INSUFFICIENT_INPUT_PRECISION`, `INEXACT_DATA_IN_EXACT_MODE` | Regenerate only the affected inputs with the declared arithmetic, or explicitly select suitable arithmetic. |
| `SINGULAR_LETTER_POINT` | Replace the singular point while preserving roles and frame. |
| `RECONSTRUCTION_MISMATCH` | Inspect the named sample and role. Repair the data, frame or letter hypothesis; preserve the failed receipt. |
| `RAW_LETTER_BINDING_MISMATCH`, `COEFFICIENT_BINDING_MISMATCH`, `EXPLICIT_FORM_BINDING_MISMATCH`, `ARITHMETIC_BINDING_MISMATCH`, `RANK_BINDING_MISMATCH` | Treat the changed reconstruction as a new proposal and resolve the inconsistent fields before checking it. |
| `NO_LETTERS_PROPOSED` | Supply further justified exact one-forms or seed letters; this bounded proposal method is exhausted on the current input. |

Never repeat the same fit unchanged after a failed gate. A source-basis repair
belongs to the basis/DE producer, a missing-letter hypothesis to the analytic
letter provider, and a point-rank failure to sample selection.

Precision checks include both real and complex numeric atoms. Exact mode rejects
inexact complex values; high-precision mode checks the precision of complex
coefficients too. Raw analytic letters and point coordinates remain exact in
both modes. CHECK_RECONSTRUCTION independently enforces the declared rational
recognition bounds as well as the sample residual checks.
