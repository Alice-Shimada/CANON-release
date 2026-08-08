# CANONICA 递归 candidate 路线

## 目的

使用与本卡兼容的 CANONICA 1.0.3，为 current-sector cut 微分系统提出有理
canonical transformation。CANON 不负责安装或登记 CANONICA，也不依赖某个工具
工作区的目录布局。

## 适用范围

- 一个或多个运动学变量；
- 有理微分方程矩阵；
- 显式且不可变的 basis 顺序；
- flat connection；
- 由 artifact 提供或由 CANONICA 推断的 sector boundary 列表。

代数根、椭圆系统、大型 ansatz 调参和物理边界条件不属于本卡范围。

## 调用要求

使用标准 `SEARCH_CORE` task input 和 output directory 运行 `run.wls`。调用环境必须
提供可执行的 Wolfram kernel，并以以下二选一方式提供 CANONICA：

1. 在 `method_options.package_entry` 中给出 CANONICA 主文件路径；相对路径以
   `input.json` 所在目录为基准；
2. 将 `CANONICA`` 安装到标准 Wolfram `$Path`，由卡使用
   `FindFile["CANONICA`"]` 解析。

卡会记录实际解析入口、解析方式、入口 SHA-256 和 Wolfram `$Version`/`$SystemID`，
但不将某台机器的固定 hash 作为运行前提；科学结果仍由独立 checker 验收。

## 结果与证据

成功时，本卡按 `old_basis = transformation . new_basis` 约定写出
`canon-neu/core-candidates/v1` artifact，并记录 CANONICA 入口、推断或提供的 sector
boundaries、alphabet 和 provider 侧 epsilon-form 结果。`mma/CheckSectorCore.wls`
独立复算科学验收条件。

## 边界

本卡不执行 IBP reduction，不改变 sector ordering，不求解非对角 lower-sector tail，
不修改 `accepted_prefix`，也不接受自己提出的 candidate。
