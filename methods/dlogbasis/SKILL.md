---
name: canon-dlogbasis-integral-candidates
description: 用 DlogBasis-refine 的 DlogBasisSearch API 提出有界、维数延拓的 constant-LS 积分候选。
---

# DlogBasis-refine 约化前积分候选路线

本卡只处理 `PROPOSE_INTEGRAL_CANDIDATES`。它在候选 IBP 约化之前调用
``DlogBasis`DlogBasisSearch``，不生成或接受 canonical basis。

`prepared_family["family_data","path"]` 返回含有 `"Family"` 的关联。
sector mask 从请求中的 sector ID 按完整传播子/ISP 指标顺序展开，不读取文献 manifest。

在 `method_options` 中提供：

- `package_entry`：`DlogBasis-refine/DlogBasis.wl`；
- `finite_flow_package_file`：`FiniteFlow.m`；
- `loop_order`：按 `Family["LoopMomenta"]` 的一基位置排列，例如 `{2,1}`；
- `loop_dimensions`：与该顺序逐项对应的整数 `D0_i`，实际计算维数为
  `D0_i-2 epsilon`；
- 可选 `numerator_positions`、`residual_backend` 和 `singular_executable`。

分子总次数与新增 dot 总次数分别取自
`numerator_or_power_counting_policy.definition.numerator_degree` 和
`max_added_dots`。当前包没有独立的每传播子 dot 上界，因此调用方声明的
`max_dots_per_propagator` 应不小于总 dot bound。

包返回的每个 `CandidateCombinations` 元素都是一个 constant-LS 候选方向。运行器把
``DlogBasis`DlogIntegral[hash,{a1,...}]`` 映成 CANON 的 `j[topology,a1,...]`，再按首个
积分系数作 projective normalization；本卡只接受 `NORMALIZED_LINEAR_COMBINATION` 与
`first-integral-coefficient-outside-definition`，候选预算单位固定为
`PROVIDER_CANDIDATE`。预算仅截取候选方向。IBP 后由 `RouteCoreCandidates` 根据实际 master rank
选择独立基及单行替换，不枚举全部子集；完整 DE 决定 canonical 性。

保留 `ScientificStatus`、有限仿射覆盖和四个 certification flag。即使有候选，
`ConstantLeadingSingularityCertifiedQ`、`UniformTranscendentalityCertifiedQ` 与
`CanonicalBasisCertifiedQ` 通常仍为 `False`；工具 provenance 同时记录 package Git
revision 与 loader SHA-256。不得把 provisional 输出提升为 UT 结论。
