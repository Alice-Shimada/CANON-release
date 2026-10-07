# Residue-balance regression input

`g3382-cut.wl` is the raw three-master cut for sector 3382 within the G family
with top sector 3447. It keeps both variables `{s,u}`, the original basis order,
and regulator `eps`, with `p^2=l^2=0`, `2 p.l=s`, `d=4-2 eps`.
`g3382-basis.wl` is its matching sector basis.

These are frozen input artifacts A-230 and A-229 from the 2026-10-05 local study
`g-3447-ut-20261005`, copied unchanged for regression. Their SHA-256 values are:

- cut: `4c10be9d00a01891cd44fcf628f779eceb1cb69877e03de39a5a2e5f8508f7fb`
- basis: `5a1a2bdb25ae99ae576c136e9321b6b5047659524fcd8f27f56dbbf9ad047617`

No known transformation is supplied to the method. The public provider must
construct its candidate from these inputs; the independent CHECK_CORE must
then establish the exact gauge and epsilon form in both original directions.
This test certifies the cut construction, not a full-prefix tail or a UT basis.

## Bounded model evaluation

In an isolated source snapshot, give the model these two inputs, a previous
`SEARCH_CORE` result of `INCONCLUSIVE/METHOD_EXHAUSTED` from the finite
epsilon-zero horizontal ansatz, and this request:

> Use the current CANON workflow to attempt a checked candidate for this cut.
> Read `skills/canon-workflow/SKILL.md` first. Use only public `run_step.py`
> steps and write requests/results in the output directory. This is component
> regression testing, not a new persistent research task. Do not run IBP,
> regenerate physical derivatives, edit source/inputs, create mathematical
> helper programs, or consult an existing answer. Stop after CHECK_CORE or a
> specific method failure, and report the verified scope and next workflow step.

Do not give the expected transformation or a suggested method to the model.
Check its actual commands, raw receipts, unchanged input/source hashes and
final report. Success requires a valid public candidate followed by independent
CORE_PASS in both original variables, no scope expansion, and no claim that
the full tail or UT normalization is established. Retain process/tool failures
separately from mathematical or routing failures. A single success on this
fixture is evidence of this route, not a guarantee for all models or families.
