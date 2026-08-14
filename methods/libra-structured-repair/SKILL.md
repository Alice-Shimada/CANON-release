---
name: canon-libra-structured-repair
description: 对显式满足 REPAIR_WITH_LIBRA 路由的精确单变量 1x1 已接受前缀与 2x2 尾部直和系统运行有界 Libra 尾部内部修复，并只发布与冻结前缀兼容的临时候选。
---

# Libra 结构化修复

本卡是 `methods/libra` 的 `SEARCH_CORE` 之外的独立能力。它只接受已经通过
`canon-neu/prepared-basis/v1` 校验、路线决策恰为 `REPAIR_WITH_LIBRA`、且有搜索完整候选池
耗尽（剩余替代项为零且所有已声明候选均已尝试）证据的
`canon-neu/libra-structured-repair-input/v1`。平台期只能作为诊断元数据，不能授权修复。

使用 Mathematica 14 ARM64，以 `-noinit -noprompt -script` 运行
`run.wls <input.json> <fresh-output-dir>`。调用方通过
`method_options.package_entry` 注入只读 Libra 1.2 主文件；运行器禁用 Fermatica，仅运行
`NewDSystem`、`Fuchsify`、`Transform`、`FactorOut`、`OverallTransformation` 与 `EFormQ`。
输出目录必须不存在，且必须由调用方拥有。卡不调用其他求解提供者，也没有回退。

当前 v1 范围严格限于：一个精确有理变量、`parameters -> {}`、一个已接受的典范 `1x1`
前缀与一个 `2x2` 当前尾部的直和、两个交叉块均为零且禁止混合，以及尾部内部
`current-current` ε 因子分解缺陷。已接受前缀必须在预检中精确通过平坦性、ε 因子分解、
除正则化参数后无残余依赖及声明的 dlog 字母表；预备的 `(row,column)` 必须精确映射为
`full_entry = 1 + {row,column}`；这不是一般非对角/完整前缀修复。多变量或非局部问题返回
`INCONCLUSIVE/OUT_OF_SCOPE`；无效或非平坦完整系统返回
`ERROR/INVALID_DIFFERENTIAL_SYSTEM`；有界阶段未生成满足冻结前缀身份与禁止混合块零值的
矩阵候选时返回 `INCONCLUSIVE/METHOD_EXHAUSTED`。

成功只返回 `PROVISIONAL/CANDIDATE_TRANSFORMATION`，并写出版本化
`canon-neu/libra-structured-repair-candidate/v1`：原始完整矩阵、变换后矩阵、完整变换、
前缀顺序与维数、局部目标特征、Libra 身份/哈希/选项/阶段和非权威提供者证据都在产物中。
科学接受只能由 `mma/CheckStructuredRepair.wls` 完成。提供者发布门只检查形状、声明的精确
系数语法、可逆性、前缀身份与禁止混合；不计算最终典范形式、ε 因子分解、dlog 或目标判定。

检查器输入必须通过 `checker_options` 独立注入权威 Libra 身份、入口与 SHA-256。检查器只
进行路径规范化、读取文件状态并计算该只读入口的哈希，绝不求值软件包或修改任何 Libra 上下文状态；
它逐项比对提供者来源信息，使用自己实现的完整科学判据，并把认证后的
入口/哈希/选项/阶段/运行时保留在已验证产物中。
