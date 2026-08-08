# Libra 有理微分系统 candidate 路线（当前自动实现：单变量）

## 目的

使用与本卡兼容的 Libra 1.2，为有理 current-sector cut system 提出 epsilon-form
transformation。Libra 本身可以保存并同步变换多变量微分系统；当前 `run.wls` 只实现并
验收了小型单变量自动路线。CANON 不负责安装或登记 Libra，也不依赖某个工具工作区的
目录布局。

## 适用范围

- 恰好一个运动学变量；
- 有理方阵微分方程；
- 只使用 Mathematica，并设置 `Libra`$LibraUseFermat = False`；
- 系统足够小，可使用无前端的 `Fuchsify` 后接 `FactorOut` 路线。

Fermatica、`BirkhoffGrothendieck`、交互式可视操作、代数根和物理边界条件不属于
本卡范围。

## Libra 的多变量能力与本卡边界

Libra 的 `NewDSystem[ds,{x->Mx,y->My,...}]` 以变量到连接矩阵的 association 保存
多变量系统；`Transform[ds,t]` 会对每个变量方向使用相应导数项同步更新连接矩阵，
`EFormQ[ds,eps]` 也会检查全部变量方向。因此，“当前卡只接受一个变量”不是 Libra
本身的能力限制。

但 `Fuchsify[ds,x]`、`FactorOut[ds,x,eps,mu]` 和可视 balancing 接口都先从指定方向
`ds[x]` 构造 transformation。随包教程的二维例子在需要时依次执行
`Fuchsify[ds,x]`、`Fuchsify[ds,y]`，每次都用 `Transform[ds,t]` 作用于完整系统；随后
把所有变量方向在共同精确运动学点的样本合并，交给 `FactorDependence` 寻找一个共同的
epsilon-factorizing transformation。随包演示文稿的三变量例子则混合使用逐方向
`VisBalancing`、单方向 `FactorOut`、`BlockTriangularToFuchsian`，并在
`FactorDependence` 前只对各矩阵对应的微分变量作部分特化。两份材料都证明这些组件能
用于多变量系统，但演示文稿同时把“更系统的多变量处理”列为待开发能力。

CANON 若采用非交互的逐变量 `Fuchsify`，它只是基于现有接口和教程提出的有界设计，尚未
通过本卡的多变量 kernel 验收。实现时必须明确变量遍历/回访和确定性取值策略，避开奇点
并保存取值；部分或完整特化都只能帮助构造 candidate，不能作接受证据。结束时仍须对未
取值的完整符号系统联合检查
精确 gauge relation、各方向 Fuchsian 性、平坦性与 epsilon factorization。完成这一
闭环前，多变量输入仍由当前 runner 明确返回 `INCONCLUSIVE/OUT_OF_SCOPE`，而不是被
描述为 Libra 不支持，也不会把尚未实现的卡范围
解释为 candidate 的数学失败。

还要注意，Libra 的 `EFormQ[ds,eps]` 只判定每个连接矩阵除以 `eps` 后是否不再含
`eps`；它不证明连接属于某个 dlog alphabet。多变量 canonical acceptance 因而还需要
CANON 独立实现并验收多变量 dlog 分解，不能只依赖 provider 的 `EFormQ`。

## 调用要求

使用标准 `SEARCH_CORE` task input 和 output directory 运行 `run.wls`。调用环境必须
提供可执行的 Wolfram kernel，并以以下二选一方式提供 Libra：

1. 在 `method_options.package_entry` 中给出 Libra 主文件路径；相对路径以
   `input.json` 所在目录为基准；
2. 将 `Libra`` 安装到标准 Wolfram `$Path`，由卡使用 `FindFile["Libra`"]` 解析。

卡会记录实际解析入口、入口 SHA-256、解析方式、Libra 报告的版本以及 Wolfram
`$Version`/`$SystemID`，但不读取 hep-tools 的机器状态。

## 结果与证据

本卡要求实际加载版本为 Libra 1.2，并记录精确 transformation、transformed matrix
和 Libra `EFormQ` 结果。在
`mma/CheckSectorCore.wls` 独立验证前，provider 输出始终只是
`PROVISIONAL/CANDIDATE_TRANSFORMATION`，不能返回 `PASS` 或数学拒绝 `FAIL`。

## 边界

本卡是有界自动路线。若 `Fuchsify` 或 `FactorOut` 无法给出结论，则返回
`INCONCLUSIVE/METHOD_EXHAUSTED`；非法或非 flat 系统返回
`ERROR/INVALID_DIFFERENTIAL_SYSTEM`。不得静默回退到 `Rookie`、交互式操作、
Fermatica、CANONICA、INITIAL 或 lower-sector 重写。
