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

- [x] 实现 demo-only `PrepareFamily.wls`
    仅检查 Wolfram 14+ 并复制 one-loop fixture；无 task schema、manifest、hash、
    reducer 选择或自然语言转写。生产准备程序由合作者替换
- [ ] 接入合作者的生产准备程序
    由其提供 family、reducer executable、project/config/jobs 和必要的 target 生成接口

## 3. IBP Reduction和DE构建

- [x] 进行IBP约化
    最小 Kira adapter 运行显式的 reduction/export jobs，只输出 Kira 原序 masters
    与完全回代 rules；离线 fake-reducer 测试覆盖闭合、恶意表达式和进程失败
- [x] 进行DE构建并检验
    已解耦为纯内存 `BuildDifferentialEquations[family, masters, rules]`：只消费准备好的 affine denominator operators、有序 masters 和已完全回代 rules，直接组装解析矩阵并验证曲率；不再包含第二轮 IBP、request/artifact、sector 或 scaling pipeline
- [x] enhanced-Baikov zero-growth 优先与逐变量显式 fallback
    `ChooseDerivativeOperator` 在声明次数内搜索 exact membership；miss 时直接返回
    affine operator，不报错
- [ ] 接入 exact Baikov cofactor 到 reducer targets 的合作者转换
    当前最小仓库只直接闭合 affine fallback 分支，不能把 cofactor search PASS
    冒充为已完成的 IBP/DE 全链路
- [ ] 两圈五点无质量解析回归
    已冻结 61-master Kira project 和五变量 operator 输入；真实 20-thread Kira
    reduction、完整 derivative rules、五张 DE 矩阵及十个 bivariate slices
    必须在不纳入版本控制的 fresh workspace 中验收

## 4. Ansatz 生成和检验

- [ ] 实现 DlogBasis 的改进，每次开始前先进行一次ansatz生成，并将生成ansatz中涉及的标量积分送去约化
    DlogBasis的改进有待讨论-LBL不同维度 for each loop（需要接口去调整）
- [ ] 实现 Gram-Baikov 方法生成ansatz
    有待讨论-让AI去尝试归纳一下，不行穷举
- [ ]  实现一个 MethodCard 接口，允许各种方法插入，允许agent按照优先级选取一个方法
    每个方法需配置一系列的程序，并提供一个SKILL教AI如何使用这些程序生成ansatz
- [ ] 每个sector找完需要检查一下左上角是不是d-log form


- [ ] 有状态笔记本进行sector-by-sector检测
    使用有状态笔记本因为可以只读入一次rule，然后sector-by-sector连续工作。可以考虑用MICA调度笔记本。

## 5. Sector 纠错机制

- [ ] 非对角元素不正确时，决定更换ansatz测试或是寻找变换修补非对角元素
    尽量不要修，而是期望把ansatz找的好一些，直接变成a+b eps的形式。判断：a+b eps积出来是超越函数要重新换ansatz
    修eps^n依赖的算法

## 6. 提交与总检

- [ ] 实现 `CheckFullSystem.wls`
    检查微分方程的epsilon-form，检查确实是dlog-form，提取Alphabet

## 7. （发布前）验收

- [ ] 用一个小 family 跑完整流程
    先用当前 2l5p pentabox；必须区分 fixture 静态检查、Kira live reduction 和
    完整 DE/curvature 验收
- [ ] 固化回归测试
    可以交给AI设计测试，人工审核
