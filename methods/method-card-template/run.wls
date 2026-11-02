(*
CANON_neu interface-only method-card template with explicit roles
Method card:
  SKILL.md

Invocation:
  wolframscript -file run.wls <input.json> <output_dir>

Input envelope:
  schema  = "canon-neu/script-input/v1"
  step    = one declared stage, for example
              "PROPOSE_INTEGRAL_CANDIDATES" (integral generator before reduction), or
              "SEARCH_CORE" (transformation generator after reduction), or
              the documented router, screen, evidence, or checker stage
  sector  = <|"id" -> integer, "propagator_count" -> integer|>
  payload = the exact role-specific contract in ../../INTERFACES.md

Required output:
  <output_dir>/result.json with schema "canon-neu/script-result/v1".
  Providers and routers use declared PROVISIONAL codes, bounded INCONCLUSIVE
  codes, and specific ERROR codes. A screen/checker may publish PASS or FAIL
  only for its stated claim and scope. No result accepts a research task.

Instantiate a new directory for a bounded MethodCard and remove unused role
branches. A pre-reduction card must not read sector_basis/sector_cut_de or
output a core transformation. A SEARCH_CORE card reads the ordered reduced
basis and cut DE and outputs canon-neu/core-candidates/v1.
Declare activation, mutation boundaries, attempt limits, supported options,
and the next checker or operation in SKILL.md. Do not select another provider,
expand scope, or manage workflow state implicitly. Instruction-only cards
do not require a runner. The scientific implementation is intentionally empty.
*)
