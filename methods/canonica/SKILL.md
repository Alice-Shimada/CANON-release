# CANONICA 递归候选路线

## 目的

使用与本卡兼容的 CANONICA 1.0.3，为当前扇区割微分系统提出有理规范变换。CANON
不负责安装或登记 CANONICA，也不依赖某个工具
工作区的目录布局。

## 适用范围

- 一个或多个运动学变量；
- 有理微分方程矩阵；
- 显式且不可变的基顺序；
- 平坦联络；
- 由产物提供或由 CANONICA 推断的扇区边界列表。

代数根、椭圆系统、大型拟设调参和物理边界条件不属于本卡范围。

## 调用要求

使用标准 `SEARCH_CORE` 任务输入和输出目录运行 `run.wls`。调用环境必须提供可执行的
Wolfram 内核，并以以下二选一方式提供 CANONICA：

1. 在 `method_options.package_entry` 中给出 CANONICA 主文件路径；相对路径以
   `input.json` 所在目录为基准；
2. 将 `CANONICA`` 安装到标准 Wolfram `$Path`，由卡使用
   `FindFile["CANONICA`"]` 解析。

卡会记录实际解析入口、解析方式、入口 SHA-256 和 Wolfram `$Version`/`$SystemID`，
但不将某台机器的固定哈希作为运行前提；科学结果仍由独立检查器验收。

运行器保持包优先加载：它在求值 `sector_cut_de` 前完成入口解析、哈希、加载和
公共符号检查，避免输入先创建 `Global`eps` 后触发 ``CANONICA`eps::shdw``。因此工具与
输入同时失败时，具体 `ERROR/TOOL_*` 优先；工具边界通过后，非法或非平坦系统才返回
`ERROR/INVALID_DIFFERENTIAL_SYSTEM`。该顺序不得改成提供者回退。

## 结果与证据

成功时，本卡按 `old_basis = transformation . new_basis` 约定写出
`canon-neu/core-candidates/v1` 产物，并记录 CANONICA 入口、推断或提供的扇区边界、
字母表和提供者侧 ε 形式结果。`mma/CheckSectorCore.wls` 独立复算科学验收条件。提供者
成功只返回
`PROVISIONAL/CANDIDATE_TRANSFORMATION`；阶段耗尽返回
`INCONCLUSIVE/METHOD_EXHAUSTED`；非法或非平坦系统返回
`ERROR/INVALID_DIFFERENTIAL_SYSTEM`。本卡不能返回 `PASS` 或数学拒绝 `FAIL`。

## 边界

本卡不执行 IBP 约化，不改变扇区排序，不求解非对角低扇区尾部，不修改
`accepted_prefix`，也不接受自己提出的候选。它不调用 Libra 或 INITIAL，也不是 Libra
之后的固定回退。
