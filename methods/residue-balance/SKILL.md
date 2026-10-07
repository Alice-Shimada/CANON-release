---
name: canon-residue-balance-core
description: Diagnose a rational core after an epsilon-zero or direct-DE failure, then construct a bounded epsilon-form candidate using exact scale separation, integer residue balances and regulator intertwiners.
---

# Rational residue balances

Use this card when [core selection](../../skills/canon-search-core/SKILL.md)
selects it. Supply the unchanged `sector_basis` and `sector_cut_de`, with their
original variables and regulator. It needs no integral reduction or external
method package. It proposes a cut transformation; it does not prove UT or solve
the lower-sector tail.

The complete envelope is in
[core-diagnosis-request.example.json](../../interfaces/core-diagnosis-request.example.json).
Use a fresh `task_id`, copy the actual `sector` object verbatim from your
`sector_basis`, and bind both artifact paths relative to the new request file.
The example's sector and paths belong only to its fixture. For construction,
change `step` to `SEARCH_CORE`; no `prepared_family`, package entry or new
derivative input is required.

Once these inputs and the declared Wolfram runner are available, invoke the
public step. Reading or reproducing the provider/checker implementation is not
a prerequisite. Investigate source or installation only for a concrete returned
error; a mathematical method limit returns to core selection.

## Diagnose, construct, check

1. Set `step: "DIAGNOSE_CORE"` and run
   `python3 run_step.py INPUT.json DIAGNOSIS_DIR` with the task's complete
   component selection. Read `result.json` and `core_diagnosis`.
2. For `PROVISIONAL/CORE_DIAGNOSIS`, use the same input artifacts with
   `step: "SEARCH_CORE"` and
   `python3 run_step.py INPUT.json CANDIDATE_DIR --method residue-balance`.
   Diagnosis establishes structural applicability, not guaranteed success.
3. Feed the returned `core_candidates` directly into `CHECK_CORE`. On CORE_PASS,
   continue BUILD_FULL_DE, SOLVE_TAIL and CHECK_CANONICAL with the accepted lower
   prefix. Do not perform candidate IBP for a direct-DE transformation.

Already known applicability permits step 2 directly. The diagnostic is useful
after a failed rational/horizontal ansatz or before evaluating an epsilon-zero
obstruction; it is not a compulsory preflight for every sector.

## Supported construction and bounds

The input must be an exact flat rational connection. The provider:

- retains every original variable, and tries to separate each spectator `v`
  only if `v A_v = diag(n_i + c epsilon)` with integer `n_i` and a common `c`;
  rows `diag(v^(-n_i))` must leave one essential variable and scalar epsilon
  spectator connections, verified symbolically;
- finds bounded diagonal shears from pole-order difference constraints;
- uses rational, regulator-independent finite poles and rank-one balances
  between residue eigenspaces to remove integer parts of eigenvalues
  `n + c epsilon`, including the residue at infinity;
- solves the exact simultaneous equations
  `R_a(epsilon) Q = (epsilon/e0) Q R_a(e0)` and selects a generically invertible
  member of the linear solution space. Reference values only select a frame;
  the final matrices retain symbolic epsilon and all original variables.

Optional `payload.method_options`:

```json
{
  "max_dimension": 6,
  "max_balance_steps": 12,
  "max_shear_power": 4,
  "reference_regulators": [[1, 2], [1, 3], [1, 5], [1, 7], [2, 7]]
}
```

JSON references are exact numerator/denominator pairs. Zero references and
machine reals are invalid; references at poles are skipped. These are finite
ansatz bounds, not runtime limits or a completeness guarantee. Spectator
separation, rational poles, integer shifts and rank-one balances do not cover
all rational gauges, algebraic gauges or general multivariable connections.

The candidate records scale rows, shears, projectors, regulator intertwiner,
reference trials and bounds. The convention is `old = T.new`; the equivalent
rows are `new = Inverse[T].old`. Output includes full rows in the original cut
source basis, so BUILD_FULL_DE can restore lower-sector couplings.

## Interpret failures correctly

`OUT_OF_SCOPE` identifies an unsupported structure. `METHOD_EXHAUSTED` names
the unsuccessful bounded stage. Both preserve `nonexistence_proved: false` and
return to core selection; neither requires changing the family or adding IBP
masters. Input errors must be repaired before selecting a new method.

Allowed transformations are invertible over the rational function field.
They may have poles in epsilon, and their determinant may vanish at epsilon=0.
A nonzero nilpotent residue or logarithms at epsilon=0 therefore cannot alone
exclude an epsilon form. For example, `A = {{0,1},{0,0}}/x` has such a residue,
but `T = diag(1,epsilon)` gives `B = epsilon A`. Apply this condition when
reviewing a proposed obstruction, not just when constructing candidates.

`DIAGNOSE_CORE` never publishes PASS or a nonexistence certificate.
The independent CHECK_CORE gauge, invertibility, flatness and epsilon checks
remain authoritative. A positive checked candidate for the same input settles
existence even if a previous diagnostic claimed otherwise.
