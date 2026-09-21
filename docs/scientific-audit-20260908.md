# CANON static checks, focused runs, and scientific maturity assessment

> Historical scope: this audit records the checks and conclusions of 2026-09-08.
> It has not been rerun for this translation. For active work, follow
> [the current agent workflow](agent-workflow.md) and current skills.

Date: 2026-09-08. The audit baseline was `demo` commit
`de29b1b20550215f9285ed1fc8adf061b081a85c`; the conclusions include the workspace
corrections made during this audit.

**Conclusion: usable for canonical-basis research on simple MPL families with
explicit human-supplied inputs and controlled search domains.** The implementation
has a working chain of candidates, IBP, DE, prefix repair, and final verification.
It is not yet a fully automatic UT-basis discoverer for arbitrary families. This
audit found and corrected a flatness flaw that could incorrectly pass final checks.

## 1. Static checks and code simplification

The audit covered CANON's 29 scientific entry points/libraries and related
interfaces and skills. 20 Python files passed AST parsing, and 86 Wolfram
source files, scripts, and fixtures passed syntax checks. Two apparently unused
imports found by the Python static-reference scan were actually exported through
`__all__` and were retained. External packages' method boundaries were checked
against their recorded source commits; no upstream source was modified.

Production code decreased by a net 69 lines, excluding tests and documentation:

| Location | Change and retained scientific conditions |
| --- | --- |
| `methods/route-prepared-basis/run.wls` | `PreparedBasisRoute` already validates input, so remove the duplicate validation before the call; retain failure fields and error categories |
| `mma/lib/MethodCardCore.wl` | Remove redundant candidate-pool conditions already implied by `alternatives_remaining == Length[unattempted]`; run the dlog check, including the ε-factorization requirement, only once for the strictly single-variable repair prefix |
| `methods/canonica/run.wls` | CANON already performs a full symbolic curvature check, so remove the second CANONICA integrability check on the same input |
| `mma/BuildSectorCutDE.wls` | Remove defensive field-by-field checks of the validity record generated in a fixed form by the repository's internal DEBuilder; retain checks of the actual DE's dimensions, rationality, and unclosed integrals |
| `mma/CheckCanonical.wls` | Once the complete block-triangular system passes, its diagonal blocks are also flat and dlog, so reuse the result directly; if the complete system fails, still check the current block independently to distinguish `CORE_FAIL` from `TAIL_FAIL` |
| `mma/CheckStructuredRepair.wls` | Remove the curvature loop, which is always empty in one variable, and a duplicate ε check; make the ε-factorization flag actually check that `B/eps` is free of `eps` |

The audit retained external-input identity/basis order, transformation
invertibility, exact gauge checks, shared constant residues, protection against
overwriting formal files, and provider/checker authority boundaries. These
prevent acceptance of incorrect scientific objects. Independent verification
across provider and checker also must not be removed as if it were duplicate
code within one process. The existing compatibility branch for legacy
single-variable derivative inputs still has an explicit interface and regression
cases; this working capability was not removed.

## 2. Flatness flaw found and corrected

The repository uses the convention

\[
\partial_i I=A_i I,\qquad I=TJ,\qquad
B_i=T^{-1}(A_iT-\partial_iT).
\]

The required integrability condition is an identity in all kinematic variables:

\[
F_{ij}=\partial_i B_j-\partial_j B_i+B_jB_i-B_iB_j=0.
\]

This matches the connection conventions in
[Henn 2013, Eqs. (2)–(6)](https://arxiv.org/html/1304.1806v2#S1) and
[Libra, Eqs. (1)–(4)](https://arxiv.org/html/2012.00279v1#S2).

The old `FlatConnectionQ` evaluated only at a fixed rational point. The following
counterexample was constructed during this audit, with `Eij` denoting matrix units:

\[
f(y)=1+(y-3/5)^2,\qquad
B_x=\epsilon E_{12}/x,\qquad B_y=\epsilon E_{21} f'(y)/f(y).
\]

It already has alphabet `{x,f(y)}` and constant residues `E12,E21`, but

\[
F_{xy}=\epsilon^2\frac{f'(y)}{xf(y)}\operatorname{diag}(-1,1)
\]

is not identically zero; it vanishes only at the old sample point `y=3/5`.
Submitting this system to the original `FINAL_CHECK` did return `PASS/ALL_PASS`.
After the correction, it returned `FAIL/FULL_SYSTEM_FAIL`, with exactly
`flat_connection` failing; gauge and shared constant dlog residues still passed.
This shows that constant dlog residues alone cannot replace the integrability
check for a noncommuting matrix connection.

The implementation now uses a shorter symbolic curvature calculation while
retaining sparse matrix multiplication. The certificate's `check_scope` is now
`exact-global-gauge-symbolic-flatness-multivariable-shared-residue-declared-dlog-span`.
The counterexample was added to `tests/RunFullSystemUnitTests.wls`.
`DEBuilder.validity` retains its point-evaluation record with its explicit local
diagnostic meaning; it is not a substitute for final symbolic flatness.

A second correction concerns the structured-repair checker, which previously
labeled `B - eps*(B/eps) == 0` as ε factorization. For ordinary rational
expressions, this is only an identity. The old implementation also had another
valid check for absence of residual ε, so this issue mainly misrepresented a
diagnostic field. Both public fields now come from the same valid
`FreeQ[Together[B/eps],eps]` check.

## 3. Focused runs

All runs used stateless batch processing launched in the session and followed
the corresponding module's skill. Run data are in the local directory
`runs/static-audit-20260908-jrekfah2/`; existing persistent-research state was
not changed.

| Run | Result | Scope |
| --- | --- | --- |
| `RunFullSystemUnitTests.wls` | 16/16, 51.639 seconds | Complete gauge, shared residues, algebraic letters, and this audit's non-flat counterexample |
| `RunCanonicalCommitUnitTests.wls` | 8/8, 32.743 seconds | Cumulative prefix transformations and core/tail failure classification |
| `RunBuildCutDECompatibilityUnitTests.wls` | 3/3, 19.060 seconds | Supported derivative formats and rejection of invalid DEs |
| Focused method-card tests | 9/9, 151.239 seconds | Routing and input contradictions; real CANONICA and Libra providers with independent checkers; structured repair |
| `RunFullSectorTailUnitTests.wls` | 11/11, 120.786 seconds | Small two-variable systems, nonzero tails, algebraic primitives, and lower-sector ε normalization |
| `RunEndToEndWorkflowLiveTest.wls` | 12/12 acceptance items, 53.185 seconds | Real one-loop sector 5 with one master integral, from DlogBasis candidates through Kira to the final canonical DE |

The last run used the distributed DlogBasis-refine and FiniteFlow Wolfram source,
an existing local FiniteFlow native library, Wolfram 14.3, and `kira3`, whose
actual version was 3.0. It was not a fresh compilation test of the distributed
Kira 3.1 source. Kira used one thread.

For `d=2-2 eps`, this example produced

\[
J=\frac{(1+2\epsilon)s}{2}\,\mathrm{tri}[1,0,1],\qquad
\frac{dJ}{ds}=-\frac{\epsilon}{s}J.
\]

This is a real canonical-basis result for a one-master subfamily. It does not
establish a success rate for the entire triangle family or arbitrary two-loop
families. Detailed records in the directory above are `module-tests.json`,
`focused-methods.log`, `full-sector-tail.log`, `flatness-before/result.json`,
`flatness-after/result.json`, and `one-loop-live/end-to-end-receipt.wl`.

The existing 61-master / 46-sector pentabox result was also reviewed by checking
its report, final JSON, and SHA-256 hashes of three registered files; all matched
the original record. That historical report explicitly used only pointwise
flatness checks. This audit neither relabeled it as having passed the new full
symbolic curvature check nor reran the entire family.

## 4. Literature and implementation boundaries

| Literature | Scientific method supported | CANON implementation and boundary at the time of the audit |
| --- | --- | --- |
| [Henn 2013](https://arxiv.org/html/1304.1806v2) | Basis changes, ε form, dlog connections, and boundary conditions | Final checks require exact gauge, symbolic flatness, ε factorization, and constant residues shared across all directions; physical boundary constants are not computed |
| [Meyer 2017: algorithm](https://arxiv.org/abs/1611.01087), [CANONICA](https://arxiv.org/abs/1705.06252) | Finding a multiscale canonical form assuming a rational transformation exists | The `canonica` card directly consumes the raw rational DE and suits simple rational-transformation problems. An unsuccessful rational search does not imply that no algebraic or more general transformation exists |
| [Lee: Libra](https://arxiv.org/html/2012.00279v1) | Fuchsification, normalization, and ε-factor extraction; the paper also discusses multivariable methods | The automatic `libra` card accepts only one variable; the structured-repair card is further restricted to a `1x1 + 2x2` direct-sum slice. The upstream package's full capabilities must not be counted as already integrated into this project |
| [Henn et al.: dlog integrands](https://arxiv.org/abs/2002.09492), [Chen et al.: Baikov, §4.3](https://arxiv.org/html/2202.08127v2#S4.SS3) | Constructing candidates from logarithmic forms and converting generalized Baikov forms into the Feynman-integral subspace | DlogBasis-refine's finite affine maximal-cut evidence and module lift motivate candidates; IBP in the actual physical dimension and complete DE checks are still required. A finite search is not a proof of global LS/UT completeness |
| [Dlapa, Henn, Yan: INITIAL](https://arxiv.org/html/2002.02340v1) | Constructing a canonical DE starting from one known uniform-weight integral | This project's INITIAL card implements only evidence for the fixed official 26-element three-loop ladder; it is not a general UT verifier for arbitrary simple families |
| [He et al. 2022, Eq. (78)](https://arxiv.org/html/2206.04609v2#S3.SS2) | Correcting entries of the form `a+b eps` using primitives | Under `old=T.new`, `SolveTail`'s lower-triangular repair uses `dD=a`, giving the tail `eps*(b+C D-D A)`; the local algebraic-primitive ansatz is finite and the checker still verifies the final result |
| [Kira](https://arxiv.org/abs/2008.06494), [FiniteFlow](https://arxiv.org/abs/1905.08019) | IBP reduction and finite-field function reconstruction | The adapter relies on external reductions and declared derivative operators, checking available rules and matrices; it does not independently prove master completeness |
| [Adams, Weinzierl: elliptic case](https://arxiv.org/abs/1802.05020) | Non-MPL integrals may also admit ε form through non-algebraic basis transformations | The rational/algebraic dlog target does not integrate period normalization or elliptic kernels; a small master count does not guarantee that a problem lies within the current methods' scope |

`epsilon-zero` is a local bounded DE proposal: finite-field solving only proposes
horizontal rows, which are then substituted exactly into every original
direction. The two-dimensional rank-deficient completion also requires subsequent
full checks. It is not a complete implementation of an arbitrary-family
construction algorithm from the literature above.

## 5. Maturity assessment

The usable scope is a problem with trusted ordered masters, closed IBP rules, and
correct derivative operators, expected to belong to MPLs, whose required
transformation is rational or lies within the algebraic candidate classes already
handled. Complexity depends more on the number of scales, alphabet, and
transformation class than on loop order or master count alone. For such inputs,
the existing provider → core → tail → final process can search for and verify a
canonical basis.

Guarantees not yet provided include complete automatic discovery of an unknown
algebraic alphabet; an exhaustive search over all numerator/dot/dimension
candidates; elimination of every nonzero tail by the current ansatz; IBP master
completeness; elliptic and more general function classes; and physical boundary
conditions and UT normalization.

In particular, a rescaling `J -> (1+eps) J` that is constant in the kinematic
variables but depends on ε leaves the canonical DE unchanged while potentially
mixing weights in the ε expansion. A canonical-DE certificate therefore cannot
by itself prove UT boundary normalization. In practice, interpret `ALL_PASS` as
a verified canonical DE within the declared integral space and alphabet, and
`METHOD_EXHAUSTED` as exhaustion of the current search space.

This audit did not expand the research objective or introduce a new fallback
framework. Symbolic curvature checking is stricter than a single-point check and
may take longer for large multiscale systems; performance conclusions here cover
only the small focused runs above.
