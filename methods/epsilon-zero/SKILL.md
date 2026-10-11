---
name: canon-epsilon-zero-core
description: Propose a core transformation with a finite homogeneous-polynomial ansatz for a rational DE regular at epsilon zero, after choosing this direct-DE route.
---

# Epsilon-zero polynomial core candidates

## Trigger and inputs

Use this bounded DE proposal when the
[workflow entry](../../skills/canon-workflow/SKILL.md) selects it for an exact
rational core DE regular at epsilon zero, with homogeneous polynomial rows
after algebraic normalization. It is independent of the integral family and
sector number. Supply `sector_cut_de`; an optional `declared_alphabet` provides
algebraic generators. The trace connection supplies determinant normalization
and pole prefactors. `method_options.prime` selects the reconstruction prime
(default 2147483647).

## Command and finite ansatz

From `project_root`, run
`python3 run_step.py INPUT.json OUTPUT_DIR --method epsilon-zero`
with step `SEARCH_CORE` using the installed Wolfram script runner.
The method solves `dR + R A(0) = 0` in a
homogeneous polynomial ansatz. Modular equations propose coefficients, and
every reconstructed row is substituted exactly into every original differential
direction. Prefactors come from trace poles and declared algebraic generators.
This is a finite ansatz, not a completeness claim.

For each allowed prefactor, sampling keeps the required point count and selected
prime, trying at most eight times that count along the deterministic prime grid.
Only finite rational evaluations with denominators invertible modulo that prime
enter the linear system. The prime must be an integer prime; it is never silently
replaced. If incomplete sampling prevents a candidate, the result is
`INCONCLUSIVE/OUT_OF_SCOPE` with reason `regular finite-field sampling incomplete`
and per-prefactor counts and rejection causes. This is incomplete computational
evidence, not exhaustion of the mathematical ansatz. Clean finite-ansatz
exhaustion retains `INCONCLUSIVE/METHOD_EXHAUSTED`.

For a two-dimensional core with only one horizontal row, the method fixes a
complementary frame's determinant from the trace, integrates its leading
off-diagonal coefficient, and tries the epsilon profile read from the opposite
entry. No topology or regulator polynomial is hard-coded.
An unsupported leading primitive, or the absence of a finite nonzero
epsilon-zero opposite-entry value with a finite kinematics-independent profile,
returns `INCONCLUSIVE/OUT_OF_SCOPE` with its construction reason. No candidate
is published from a malformed, non-finite or identically singular row frame.
Generic meromorphic invertibility is sufficient: zeros or poles at epsilon zero
are allowed. A well-formed proposal must still pass independent `CHECK_CORE`.
That completion is implemented only for a two-dimensional core. A higher-rank
horizontal deficit is a method limitation: it does not rule out a rational
transformation with poles or a vanishing determinant at epsilon=0. In particular,
nilpotent epsilon-zero residues do not establish a no-go result for that class.

## Result and next action

The output is `core_candidates` with status `PROVISIONAL`. Run `CHECK_CORE`,
`BUILD_FULL_DE`, `SOLVE_TAIL`, and `CHECK_CANONICAL` before acceptance, then
`FINAL_CHECK` when the stated scope is complete. A core candidate has no claimed
subsector completion. `METHOD_EXHAUSTED` exhausts only this ansatz; return its
evidence to the workflow entry instead of inferring family-wide impossibility.
After a horizontal rank deficit, use `DIAGNOSE_CORE` and the
[residue-balance card](../residue-balance/SKILL.md) when applicable and untried.
