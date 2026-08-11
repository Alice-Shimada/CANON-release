# DLogBasis 约化前积分候选路线

## 目的

通过 `PROPOSE_INTEGRAL_CANDIDATES` 提出约化前的积分/dlog 候选。本卡不生成主积分基变换。

## 必需交互

接口严格采用 `../../INTERFACES.md` 中的 `PROPOSE_INTEGRAL_CANDIDATES` 和
`canon-neu/integral-candidates/v1` 合同。未来的运行器可以读取族/扇区身份，以及分别声明的
维数、幂计数、预算、候选单位和归一化策略；不得读取 `sector_basis` 或
`sector_cut_de`。

## 边界

尚未实现 CANON DLogBasis 适配器。受版本控制的软件包中只有
`LeadingSingularitiesPortable.tar.gz` 是自包含的；`LS_modified.zip` 不是。上游
`IntegrandAnsatz` 文档把可选参数描述为分子幂次数，而受版本控制的实现在幂计数公式中
使用 `dim_:4`。适配器必须先解决这一差异，且不得混淆维数、幂计数或候选预算。本卡不能
发布 `PASS`、`FAIL` 或 UT/典范形式结论。
