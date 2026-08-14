(*
CANON_neu 可区分角色的仅接口提供者模板
提供者卡：
  SKILL.md

调用方式：
  wolframscript -file run.wls <input.json> <output_dir>

输入封装：
  schema  = "canon-neu/script-input/v1"
  step    = 一个已声明的阶段，例如
              "PROPOSE_INTEGRAL_CANDIDATES"（约化前积分生成器），或
              "SEARCH_CORE"（约化后变换生成器）
  sector  = <|"id" -> 整数, "propagator_count" -> 整数|>
  payload = ../../INTERFACES.md 中对应角色的精确合同

必需输出：
  <output_dir>/result.json，模式为 "canon-neu/script-result/v1"。
  提供者只能使用已声明的 PROVISIONAL 代码、有界 INCONCLUSIVE 代码和具体 ERROR 代码。
  PASS 与 FAIL 仅供检查器使用。

替换本目录以添加一个有界 MethodCard，并删除所有不适用的角色分支。约化前的卡不得
读取 sector_basis/sector_cut_de 或输出核心变换。SEARCH_CORE 卡必须读取有序的约化后基
与割 DE，并输出 canon-neu/core-candidates/v1。
科学实现有意留空。
*)
