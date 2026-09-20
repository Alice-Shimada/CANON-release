---
name: canon-gram-integral-candidates
description: 为不同圈数、外腿数、质量与参考维数的积分族构造有界 Gram 分子候选；用于 cut 与 d 维 IBP 秩不符、维数延拓待定或完整 DE 的低扇区耦合失败时。
---

# Gram 分子与离切代表选择

本卡是 `PROPOSE_INTEGRAL_CANDIDATES` 阶段的**积分生成指导**，包括重新提出当前
sector 的完整积分定义。它补充 [DlogBasis-refine 卡](../dlogbasis/SKILL.md)，
不另立 UT 判据，不运行约化后变换搜索，也没有独立的 `run.wls` 或自动路由。
使用者构造符合 [integral-candidates/v1](../../INTERFACES.md#integral-candidatesv1)
的产物，再交给现有 IBP/core/full-prefix 检查。候选只能是 provisional。

核心经验：所选 cut 的留数、d 维 IBP 类、完整积分的离切代表是三个不同层次。
Gram 形式应帮助选择维数延拓和 contact 项；仅把 cut 多项式写成行列式不够。
本卡不固定圈数、外腿数、质量、拓扑、参考维数、sector rank 或运动学坐标。
按当前 family 的几何选择适用结构，不要求它具有四维手征表示或椭圆之外的函数类型。
这是一套可迁移的构造与诊断原则，不保证任意 family 存在 MPL/UT 基或能被有限搜索解出。

## 输入与有限范围

固定 family 的传播子/ISP 顺序、动量路由、主积分及 sector 顺序、
圈数 L、`d = D0 - 2 epsilon`、外动量维数及独立外动量张成空间、
Gram 约定、存在时的宇称张量/代数支路和现有低扇区基。
使用当前 family 的独立运动学坐标；不预设 twistor、无质量外腿或固定数量的求导方向。
读当前失败报告，分别记录 IBP 秩、同 sector 块、低 sector 块的失败位置及精确
epsilon 依赖。无完整报告时只提出假设，不推断失败一定来自 tail。

为这次假设声明分子次数（标明按 loop momentum 还是 Baikov/ISP 计数）、dots、
外部前因子的次数/分母支持、epsilon 归一化、contact 的 pinch 支持和候选数。
优先使用已有约化覆盖的低次结构；预算不是“搜索完所有 Gram 分子”。
保留来源、结构上独立的候选，以及整个当前块的有序 bundle。

## 构造 Gram 候选

1. **先按实际外部空间定义横向 Gram。** 若外动量空间存在非退化基
   `E={e1,...,er}`，令 `M_ij=e_i.e_j`、`v_a=(l_a.e_i)`，可定义
   `tau_ab=l_a.l_b-v_a^T M^-1 v_b`，其中 `a,b=1,...,L`。
   对 `G(U;V)=det(2 u_i.v_j)`，Schur 补给出
   `tau_ab=G({l_a,E};{l_b,E})/(2 G(E;E))`。
   外部 Gram 为零的区域不使用该商；另选非退化运动学区域，或直接在不除该
   Gram 的标量积/多项式表示中工作。若来源使用 `det(u_i.v_j)`，
   n 阶 Gram 的换算因子是 `2^n`。
2. **先保留完整几何，再取 cut。** 从子圈的完整 Gram、横向投影、
   标量核出发；有适用的宇称/手征结构时再使用相应组合。
   用 cut/LS 固定合理的外部归一化，
   并检查所用 chart 的无穷远；不要先令传播子为零，再把剩余多项式当唯一离切延拓。
   乘积结构保留完整乘积，其交叉 contact 项可能正是需要的修正。
3. **按参考维数识别缺失方向。** 若候选在 IBP 后欠秩，在有界空间内试
   `tau_ab`、其子式/乘积、路由相关组合及外部 Gram 余子式。
   横向不等于 evanescent：当 `r<D0` 时，`tau_ab` 可包含真实的 D0 维横向分量。
   只有由严格 D0 维秩约束确实为零的组合才标记 evanescent，例如由 loop 和外部
   向量组成的适当 `(D0+1)` 阶 Gram；在正规化 d 维积分中不能据此置零。
   外部前因子按当前质量维数、奇点及对称性选择；尝试其他允许的余子式，
   不把某个固定宇称根、Mandelstam 次数或 epsilon 幂当作通用归一化。
4. **只在存在相应结构时使用宇称或 cut 分支。** 可按当前离散对称性组织候选，
   结合不同 cut 解构造配套行；代数根换支与物理宇称不是自动相同的操作。
   四维 chiral seed 是一个特例：成对试 parity-even/odd 部分，必要时试子圈
   chirality 换支，并明确 trace 的 full-d 配对及奇宇称张量的投影约定。
   不同 d 维延拓即使在整数维 cut 上相同，也仍是不同候选。
5. **有动机时试 Gram 余子式。** 对完整 Baikov Gram 多项式 `Delta(D,z)`，
   `K_i=partial_Di Delta` 可以给出低次候选。必须写明求导时固定的独立 ISP，
   变换坐标时加入链式项，先求导再取 cut。余子式通过 cut 检查后仍可能缺 contact 项。
   维数平移或径向 IBP 若能降次，先证明所用积分/割商空间的恒等式，记录其适用范围。

这些结构是有限候选语法，不是每个 sector 都必须逐项执行的固定搜索链。

## 由失败类型选择下一步

| 当前证据 | 下一步 | 不能据此断言 |
|---|---|---|
| 所用 cut 上的有限留数独立，但 d 维 IBP 投影为零/欠秩 | 检查 twisted-exact 方向、未覆盖的 residue/infinity 信息及维数延拓；按几何补独立行，再对解析 d 投影测秩 | cut 留数秩等于 master 数；欠秩必然需要 evanescent 行 |
| 同 sector 块仍有 epsilon 零次项 | 改当前块的 Gram 组合、外部余子式、手征延拓或归一化 | 只加低 sector 项能修复一个仍失败的对角块 |
| core 通过，低 sector 项带 epsilon 分母 | 定位极点的列支持，检查相应 pinch 积分的投影、epsilon 归一化与完整 gauge 残差 | 直接套用 affine-tail 原函数公式；所有此类极点都有 contact 解 |
| core 通过，tail 为 `a(x)+epsilon b(x)` | 从失败列的 pinch 几何选 contact 项或另一离切代表；联立全部方向 | 一点一方向的拟合已经给出多变量修正 |
| 单行替换改善但仍失败 | 同时替换相互配套的 Gram/对称性/分支候选，检查整个 bundle | 单行混合测试否定了整组新候选 |

对当前物理传播子集合 S，选有限多重指标集合 A，可用 ansatz

```text
N_new = N_seed + sum_{alpha in A} (product_{i in S} D_i^alpha_i) P_alpha
               + N_evanescent,    1 <= sum_i alpha_i <= k_max.
```

contact 部分在传播子同时置零的多项式限制下消失。对 unit-power 传播子，
取消相应分母后成为 pinch 积分；有 dots 时按实际剩余幂次判断，不能仅因分子
在 cut 上为零就断言高阶极点的留数为零或只改变低 sector。
单/双 contact 是较小的起始空间，不是任意圈数下的最高允许阶。
`N_evanescent` 只保证在声明的严格参考维数限制下消失，
通常会改变 d 维 cut 与当前 sector 的 IBP 投影，不能与 contact 项混同。

从坏列共同缺少的传播子出发缩小 `P_alpha` 支持；没有独立 master 的 pinch sector
也可能通过 IBP 给出所需 tail。优先解释整簇残差，不逐 entry 无界插值。
若常数系数 ansatz 在全部方向不相容，只排除该 ansatz；可扩大有几何依据的运动学
前因子，不能把这次失败解释成 contact 路线不成立。

检查修正时使用完整的矩阵方程。若 `J=(L,C)` 的联络为
`A={{A_LL,0},{A_CL,A_CC}}`，保持 L 不变并令 `C'=C+F L`，则

```text
A'_CL = A_CL + dF + F A_LL - A_CC F,   A'_CC = A_CC.
```

只有 `A_LL`、`A_CC` 都为 epsilon 形式且 F 与 epsilon 无关时，
`dF=-A_CL^(0)` 才是消去零次项的方程；仍须检查整个新块。
它同时解释了为什么 lower-only 修正不能消除坏的当前对角块。
同 sector 中与运动学和 epsilon 都无关的可逆换基，也不能把非零的
epsilon 零次 tail 整块变成零。

## 交给 demo 工作流

- 将 Gram/trace 精确展开并映回**本 family** 的有限积分线性组合；
  `exact_definition` 不能留下未解析的 `Gram`、cut roots 或私有缩写。
  将 epsilon/运动学因子放入定义或 `normalization.factor`，只计一次。
  保留稳定 candidate ID、有限范围及实际工具来源，不伪称调用了 DlogBasis-refine。
- `CandidateIBPBridge.wl` 的 `CompileCandidateIBPTargets` 包含候选及其全部方向导数。
  先求导再固定运动学；prefactor、根式、外基、contact 系数也要求导。
  先查已有完整约化的覆盖。可复用时通过 `AttachCandidateIBPReduction` 接入；
  确有缺项才补约化。`ReduceCandidateIBP.wls` 会启动约化，不是只读覆盖检查器。
- `RouteCoreCandidates.wls` 目前只选独立行基及单行交换。对必须同时改变多行的
  假设，提交单独的、完整且有序的 rank-size bundle，使其成为该次的行基，
  不期待单行交换枚举自动找到它。保留 `full_new_basis_rows` 的所有低 sector 列。
- 走 `CHECK_CORE -> BUILD_FULL_DE -> SOLVE_TAIL -> CHECK_CANONICAL`，最终
  `FINAL_CHECK` 重算整族累计变换。遵守这些现有接口的系数域和范围。
  本卡只重提当前积分，不修改已接受的低基；正式 `SOLVE_TAIL` 若调整低基
  epsilon 归一化，按其合同保留完整累计变换。
  不要求穷尽 Gram/dot 池后才能使用 demo 已有的 DE 方法或 `SOLVE_TAIL`。

每次试验至少返回：改变哪些行、完整离切公式、有限范围、当前 IBP 秩、同/低 sector
失败支持与 epsilon 形状、target 覆盖、完整 bundle 的检验范围和下一条可证伪假设。
原始 DE/约化未改变时复用已有数据，避免为每个分子重建整族 DE。

## 结论边界

秩、cut/LS、完整 epsilon 形式、dlog/字母表及 UT 归一化分别记录。
固定若干运动学点而保留解析 epsilon 的全方向检查，是强候选证据，不能写成
全运动学 `CANONICAL_PASS`。点上拟合后冻结公式，用未参与拟合的点检验，不重新拟合。
只过整体尺度方向尤其不够。epsilon 形式本身也不能确定边界的权重归一化。

若 cut 显示椭圆或更一般的非 MPL 周期，Gram 可以简化分子，不能自动移除周期归一化；
不要强行送入有理/MPL 路线或把 top-cut 结果提升为整族结果。
