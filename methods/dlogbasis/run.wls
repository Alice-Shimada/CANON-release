(*
CANON_neu 仅接口的提供者模板：PROPOSE_INTEGRAL_CANDIDATES / DLogBasis
提供者卡：
  SKILL.md

调用方式：
  wolframscript -file run.wls <input.json> <output_dir>

输入封装：
  schema  = "canon-neu/script-input/v1"
  step    = "PROPOSE_INTEGRAL_CANDIDATES"
  sector  = <|"id" -> 整数, "propagator_count" -> 整数|>
  payload = <|
    "family_identity" -> <稳定族身份>,
    "sector_identity" -> <与扇区匹配的稳定扇区身份>,
    "prepared_family" -> <产物描述符>,
    "dimension_policy" -> <显式维数策略>,
    "numerator_or_power_counting_policy" -> <显式独立策略>,
    "candidate_budget" -> <显式预算与预算单位>,
    "candidate_unit" -> "INDIVIDUAL_G_INTEGRAL" | "NORMALIZED_LINEAR_COMBINATION",
    "normalization_policy" -> <显式约定>,
    "method_options" -> <不透明选项对象>
  |>

必需输出：
  <output_dir>/result.json，模式为 "canon-neu/script-result/v1"。
  PROVISIONAL/INTEGRAL_CANDIDATES，并包含采用
    "canon-neu/integral-candidates/v1" 的产物 "integral_candidates"。
  INCONCLUSIVE/OUT_OF_SCOPE 或 INCONCLUSIVE/METHOD_EXHAUSTED。
  输入、工具或计算故障使用具体 ERROR 代码。

禁止仅供检查器使用的结果、约化后变换和 UT/典范形式结论。尚未实现运行器或 DLogBasis
适配器。

科学实现有意留空。
*)
