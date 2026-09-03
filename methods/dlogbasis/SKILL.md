---
name: canon-dlogbasis-integral-candidates
description: 用 DlogBasis-refine 的 DlogBasisSearch API 提出有界、维数延拓的 constant-LS 积分候选。
---

# DlogBasis-refine 约化前积分候选路线

本卡只处理 `PROPOSE_INTEGRAL_CANDIDATES`。它在 IBP、主积分排序和微分方程检查之前调用
``DlogBasis`DlogBasisSearch``，不生成或接受 canonical basis。

`prepared_family["family_data","path"]` 必须返回含有 `"Family"` 的关联；
`prepared_family["sector_source","path"]` 给出同一 family 的 sector manifest。
manifest 的 `BitsA1ToA8` 是实际传入包的 sector mask，尾随 ISP 位补零；`BasisIndices`
的长度只决定 CANON 后续要组装的 current-sector candidate group 大小。

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
`PROVIDER_CANDIDATE`。预算内候选按 sector rank 取全部子集形成 groups；
是否 IBP 独立和是否给出 canonical DE 均由后续 checker 决定。

保留 `ScientificStatus`、有限仿射覆盖和四个 certification flag。即使有候选，
`ConstantLeadingSingularityCertifiedQ`、`UniformTranscendentalityCertifiedQ` 与
`CanonicalBasisCertifiedQ` 通常仍为 `False`；工具 provenance 同时记录 package Git
revision 与 loader SHA-256。不得把 provisional 输出提升为 UT 结论。
