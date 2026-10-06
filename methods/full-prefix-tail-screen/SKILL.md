---
name: canon-full-prefix-tail-screen
description: Independently screen a bounded ordered pool of exact single-variable current-sector candidates against a frozen accepted lower-sector prefix before a separately scoped repair.
---

# Full-prefix tail screen

## Trigger

Use this opt-in card only when the task requests its frozen-prefix screening
contract, after constructing the complete prefix DE for each candidate.
It screens candidates without changing the accepted lower prefix or invoking
Libra, CANONICA, Fuchsia, or another repair algorithm. It is a separate
diagnostic method; the general `SOLVE_TAIL` route does not call it or require
this screen's pool-exhaustion gate. General studies start at the
[workflow entry](../../skills/canon-workflow/SKILL.md).

## Inputs and command

Run `python3 run_step.py INPUT.json OUTPUT_DIR`. The step is `SCREEN_TAIL` and requires
`sector_basis`, `sector_cut_de`, `core_candidates`, `accepted_prefix`, and
`full_prefix_candidates`. `screen_options.candidate_budget` is optional.

The full-prefix pool must contain exactly one completion for each declared
core candidate ID. Candidates are checked in pool order, stopping immediately
at the first pass.

The supported scope is exact rational coefficients, one variable, and an
explicit rational alphabet. Acceptance requires independent checks of the
cut-core transformation, full-prefix gauge transformation, frozen lower block,
flatness, epsilon factorization, and an exact constant-residue dlog decomposition
in the declared alphabet.

## Result and next action

`TAIL_SCREEN_PASS` returns the first passing candidate and attempts through
that item. `CANDIDATE_BUDGET_EXHAUSTED` means untested candidates remain and
does not authorize this screen's repair route. `CANDIDATE_POOL_EXHAUSTED` means
every core candidate had a declared completion and all completions were tested;
only then can a separately authorized bounded repair be eligible under this
contract. It does not establish family-wide impossibility. Every result keeps
`repair_invoked` equal to `false`. Submit the scoped screen result; invoke no
repair unless the task separately authorizes its required contract.
