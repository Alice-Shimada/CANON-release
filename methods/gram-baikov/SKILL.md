# Gram-Baikov 约化前积分候选路线

## 目的

为未来的 D 维 Gram/Baikov 拟设生成器暂定一条 `PROPOSE_INTEGRAL_CANDIDATES` 路线；
它不生成约化后的变换。

## 必需交互

接口严格采用 `../../INTERFACES.md` 中约化前的
`canon-neu/integral-candidates/v1` 合同；不得读取 `sector_basis` 或
`sector_cut_de`。

## 边界

尚未选择或实现主要 Gram-Baikov API 或 CANON 适配器。本卡必须分别处理维数、
分子/幂计数、预算/耗尽、候选单位和归一化，且不能发布 `PASS`、`FAIL` 或 UT/典范形式结论。
