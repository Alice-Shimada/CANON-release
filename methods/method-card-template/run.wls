(*
CANON_neu role-aware interface-only provider template
Provider card:
  SKILL.md

Invocation:
  wolframscript -file run.wls <input.json> <output_dir>

Input envelope:
  schema  = "canon-neu/script-input/v1"
  step    = one declared stage, for example
              "PROPOSE_INTEGRAL_CANDIDATES" (pre-reduction integral generator), or
              "SEARCH_CORE" (post-reduction transformation generator)
  sector  = <|"id" -> integer, "propagator_count" -> integer|>
  payload = the exact role-specific contract in ../../INTERFACES.md

Required output:
  <output_dir>/result.json with schema "canon-neu/script-result/v1".
  A provider uses only its declared PROVISIONAL code, bounded INCONCLUSIVE codes,
  and concrete ERROR codes. PASS and FAIL are checker-only.

Replace this directory to add one bounded MethodCard and delete all inapplicable role
branches. A pre-reduction card must not consume sector_basis/sector_cut_de or emit a
core transformation. A SEARCH_CORE card must consume the ordered post-reduction basis
and cut DE and emit canon-neu/core-candidates/v1.
Scientific implementation is intentionally absent.
*)
