# CANON 历史 scientific worklist（非状态看板）

> 本文件保留尚有参考价值的 remote scientific design intent；checkbox 与旧
> `workflow.py` 里程碑不是当前任务状态或 authority，不得用于推进状态。当前研究状态
> 只通过根目录 `AGENTS.md` 与 `README.md` 所定义的 `statemng` 管理。

## 背景

持续研究由 `statemng` MCP 管理；科学计算由 agent 调用显式 Mathematica 接口完成。

## 目标

按 sector 逐步构造并验证 canonical/UT basis，保持流程简洁、可恢复、可检查。

## 1. 编排框架

- [x] 完成按总体任务隔离的 `statemng` 状态目录、MCP 接口与 Codex Local adapter
- [x] 跑通 claim/show/workspace/artifact/submit/review 的持久研究闭环

## 2. 预处理和Family 准备

- [x] 接入 production typed family-spec
    `PrepareFamily.wls` 绑定合作者声明的 family/basis identity、Kira/project sources、
    ordered masters、sector source、显式 regulator 与 dimension rule，不推断科学输入

## 3. IBP Reduction和DE构建

- [x] 进行IBP约化
    最小 Kira adapter 运行显式的 reduction/export jobs，只输出 Kira 原序 masters
    与完全回代 rules；正向测试核对精确 target 覆盖与 master-only RHS 闭合
- [x] 进行DE构建并检验
    纯内存 `BuildDifferentialEquations[family, masters, rules]` 只保留 affine master
    derivative、一次 rule vectorization、ordered matrix assembly 与 exact curvature；
    多变量只记录一个显式 exact spectator slice，不重试
- [x] 构造当前扇区 cut DE
    `BuildSectorCutDE.wls` 对完整 ordered master basis 调用 DEBuilder 一次，再按 resident
    sector positions 取同-sector 行列 block；proper-subsector tail 才被 quotient 丢弃
- [x] enhanced-Baikov zero-growth 优先与逐变量显式 fallback
    `ChooseDerivativeOperator` 在声明次数内搜索 exact membership；miss 时直接返回
    affine operator，不报错
- [x] 接入 exact Baikov cofactor 到 reducer targets 的合作者转换
    候选桥保留 measure prefactor、protected-slot subsector tails、有符号 numerator indices
    与 candidate identity；其约化结果仍不构成 UT 或 canonical 证明
- [ ] 两圈五点无质量解析回归
    已冻结 61-master Kira project 和五变量 operator 输入；真实 20-thread Kira
    reduction、完整 derivative rules、五张 DE 矩阵及十个 bivariate slices
    必须在不纳入版本控制的 fresh workspace 中验收
    当前 fresh 枚举为 305 个 master derivatives、874 个 master+target union 与 813 个
    nonmaster targets；当前 DlogBasis-refine 在 sector 148、共同四维、总 dot bound 2 下
    能给出一个有限仿射候选，但 generalized-cut coverage 仍为 partial；尚未启动对应
    Kira/DE/FINAL_CHECK

## 4. Ansatz 生成和检验

- [x] 接入 DlogBasis-refine 生成约化前积分候选
    `methods/dlogbasis/run.wls` 直接调用公开的 `DlogBasisSearch`；候选仍需后续约化和独立典范性检查。
- [x] 接通约化候选组与独立 core checker
    适配器按 sector rank 组成的 groups 依 resident order 构造 `R` 与 `T=R^-1`；checker
    首过即停并保留 candidate ID/rejection trace，repair 只在 declared pool 精确耗尽后 eligible
- [x] 构造完整 lower-prefix/current-sector 候选池
    `BUILD_CUT_DE` 的同一次 full ordered DE 被直接复用；accepted raw lower transform 与每个
    group 的完整 reduced rows 决定唯一 block-lower completion，不丢 proper-subsector coupling
- [x] 运行 candidate-first tail screen
    `SOLVE_TAIL` 顺序筛选全部 declared completions；budget stop 与真实 pool exhaustion 分开，
    首 sector 明确走无 tail 路径
- [x] 每个 sector 独立检查完整 prefix 的 canonical dlog form
    `CHECK_CANONICAL` 从 source DE 重算完整 gauge；current-current block 失败路由到
    `CORE_FAIL`，仅 lower/cross/full-prefix 失败路由到 `TAIL_FAIL`

- [x] 用 immutable accepted prefix 逐 sector 推进
    `COMMIT_SECTOR` 只接受已通过的 canonical artifact 并累计 raw transformation；
    `NEXT_SECTOR` 从 resident manifest 与 accepted trace 纯函数重构下一 sector

- [ ] 有状态笔记本进行sector-by-sector检测
    只作为重复载入 rule 的运行优化；科学 artifact 与 resume 不依赖 notebook/kernel 状态

## 5. Sector 纠错机制

- [ ] 非对角元素不正确时，决定更换ansatz测试或是寻找变换修补非对角元素
    尽量不要修，而是期望把ansatz找的好一些，直接变成a+b eps的形式。判断：a+b eps积出来是超越函数要重新换ansatz
    修eps^n依赖的算法
    当前 Libra structured-repair 只覆盖零 cross-block 的单变量 direct-sum slice，不是一般
    nonzero lower-tail solver

## 6. 提交与总检

- [x] 实现 sector canonical acceptance 与 commit
    完整 prefix 通过 exact gauge、一个确定性精确有理点上的 flatness、epsilon/dlog 后才更新 accepted prefix；旧
    source/basis/transformation/matrix blocks 与 sector/candidate trace 保持 resident 顺序

- [x] 实现 `CheckFullSystem.wls`
    从完整 ordered master DE 与累计 accepted transformation 独立验算全局 gauge；完整
    resident trace、一个确定性精确有理点上的 flatness、epsilon factorization 与多变量 shared-residue dlog 全过后，
    只发布 canonical basis、已验证 DE 及非零 residue 的 deterministic alphabet；大型系统可显式选择 Fermat 精确后端

## 7. （发布前）验收

- [x] 用一个小 family 跑完整流程
    一圈 massless triangle sector 5 通过真实 DlogBasis-refine、Kira3 与全部 method-card
    stages 到 `ALL_PASS`；2026-09-05 的 planar 2l5p pentabox 已完成 46 sectors / 61 masters，
    五变量最终检查 `ALL_PASS`，24 个 active letters；不额外声称 UT 边界性质
- [x] 固化回归测试
    deterministic focused tests 默认保留；fresh live Kira end-to-end 由显式脚本调用
