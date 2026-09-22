(*
CANON_neu interface-only provider template with explicit roles
Provider card:
  SKILL.md

Invocation:
  wolframscript -file run.wls <input.json> <output_dir>

Input envelope:
  schema  = "canon-neu/script-input/v1"
  step    = one declared stage, for example
              "PROPOSE_INTEGRAL_CANDIDATES" (integral generator before reduction), or
              "SEARCH_CORE" (transformation generator after reduction)
  sector  = <|"id" -> integer, "propagator_count" -> integer|>
  payload = the exact role-specific contract in ../../INTERFACES.md

Required output:
  <output_dir>/result.json with schema "canon-neu/script-result/v1".
  Providers use only declared PROVISIONAL codes, bounded INCONCLUSIVE codes,
  and specific ERROR codes. PASS and FAIL are reserved for checkers.

Replace this directory to add a bounded MethodCard and remove unused role
branches. A pre-reduction card must not read sector_basis/sector_cut_de or
output a core transformation. A SEARCH_CORE card reads the ordered reduced
basis and cut DE and outputs canon-neu/core-candidates/v1.
The scientific implementation is intentionally empty.
*)
