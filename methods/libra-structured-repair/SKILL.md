---
name: canon-libra-structured-repair
description: 对显式满足 REPAIR_WITH_LIBRA 路由的精确单变量 1x1 accepted prefix 与 2x2 tail 直和系统运行有界 Libra tail-internal 修复，并只发布冻结前缀兼容的 provisional candidate。
---

# Libra structured repair

本卡是 `methods/libra` 的 `SEARCH_CORE` 之外的独立能力。它只接受已经通过
`canon-neu/prepared-basis/v1` 校验、route decision 恰为 `REPAIR_WITH_LIBRA`、且有 search
完整候选池耗尽（零 remaining alternatives 且所有 declared candidate 已尝试）证据的
`canon-neu/libra-structured-repair-input/v1`。plateau 只能作为诊断 metadata，不能授权 repair。

使用 Mathematica 14 ARM64，以 `-noinit -noprompt -script` 运行
`run.wls <input.json> <fresh-output-dir>`。调用方通过
`method_options.package_entry` 注入只读 Libra 1.2 主文件；runner 禁用 Fermatica，仅运行
`NewDSystem`、`Fuchsify`、`Transform`、`FactorOut`、`OverallTransformation` 与 `EFormQ`。
输出目录必须不存在，且必须由调用方拥有。卡不调用其他求解 provider，也没有 fallback。

当前 v1 范围严格限于：一个精确有理变量、`parameters -> {}`、一个已接受 canonical
`1x1` prefix 与一个 `2x2` current tail 的直和、两个 cross blocks 均为零且禁止混合，
以及 tail 内部 `current-current` epsilon-factorization defect。已接受 prefix 必须在 preflight
精确通过 flatness、epsilon factorization、除 regulator 后无残余依赖及声明 dlog alphabet；
prepared `(row,column)` 必须精确映射为
`full_entry = 1 + {row,column}`；这不是一般 off-diagonal/full-prefix repair。多变量或非局部问题返回
`INCONCLUSIVE/OUT_OF_SCOPE`；无效或 non-flat full system 返回
`ERROR/INVALID_DIFFERENTIAL_SYSTEM`；有界阶段未生成满足 frozen-prefix identity 与禁止混合块零值
的矩阵 candidate 时返回 `INCONCLUSIVE/METHOD_EXHAUSTED`。

成功只返回 `PROVISIONAL/CANDIDATE_TRANSFORMATION`，并写出版本化
`canon-neu/libra-structured-repair-candidate/v1`：原始完整矩阵、变换后矩阵、完整变换、
prefix 顺序与维数、局部 target signature、Libra identity/hash/options/stages 和非权威
provider evidence 都在 artifact 中。科学接受只能由 `mma/CheckStructuredRepair.wls` 完成。
Provider publication gate 只检查 shape、declared exact coefficient syntax、invertibility、
prefix identity 与禁止 mixing；不计算最终 gauge/epsilon/dlog/target verdict。

Checker 输入必须通过 `checker_options` 独立注入 authoritative Libra identity、entry 与
SHA-256。Checker 只 canonicalize/stat/hash 该只读 entry，绝不求值 package 或修改任何
Libra context state；它逐项比对 provider provenance，使用自己
实现的完整科学判据，并把认证后的 entry/hash/options/stages/runtime 保留在 verified artifact。
