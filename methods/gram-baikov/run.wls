(*
CANON_neu interface-only provider template: PROPOSE_INTEGRAL_CANDIDATES / Gram-Baikov
Provider card:
  SKILL.md

Invocation:
  wolframscript -file run.wls <input.json> <output_dir>

Input envelope:
  schema  = "canon-neu/script-input/v1"
  step    = "PROPOSE_INTEGRAL_CANDIDATES"
  sector  = <|"id" -> integer, "propagator_count" -> integer|>
  payload = <|
    "family_identity" -> <stable family identity>,
    "sector_identity" -> <stable sector identity matching sector>,
    "prepared_family" -> <artifact descriptor>,
    "dimension_policy" -> <explicit dimension policy>,
    "numerator_or_power_counting_policy" -> <explicit independent policy>,
    "candidate_budget" -> <explicit budget and budget unit>,
    "candidate_unit" -> "INDIVIDUAL_G_INTEGRAL" | "NORMALIZED_LINEAR_COMBINATION",
    "normalization_policy" -> <explicit convention>,
    "method_options" -> <opaque options object>
  |>

Required output:
  <output_dir>/result.json with schema "canon-neu/script-result/v1".
  PROVISIONAL/INTEGRAL_CANDIDATES with artifact "integral_candidates" using
    "canon-neu/integral-candidates/v1".
  INCONCLUSIVE/OUT_OF_SCOPE or INCONCLUSIVE/METHOD_EXHAUSTED.
  Concrete ERROR codes for input, tool, or computation failure.

Checker-only outcomes, post-reduction transformations, and UT/canonical claims are
forbidden. No runner or scientific adapter is implemented.

Scientific implementation is intentionally absent.
*)
