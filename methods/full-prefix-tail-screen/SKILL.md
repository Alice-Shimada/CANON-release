---
name: canon-full-prefix-tail-screen
description: 在进行任何尾部修复前，针对冻结且已接受的低扇区前缀，独立筛选有界、有序的精确单变量当前扇区候选池。
---

# 完整前缀尾部筛选

在已经构造好候选特定的完整前缀微分方程后使用本卡。它是筛选器，不是变换生成器：
不会修改已接受的低扇区前缀，也不会调用 Libra、CANONICA、
Fuchsia 或其他修复算法。

使用可用的 Wolfram 内核，以 `-noinit -noprompt -script` 运行
`run.wls <input.json> <new-output-dir>`。输入步骤为 `SCREEN_TAIL`，需要
`sector_basis`、`sector_cut_de`、`core_candidates`、`accepted_prefix`、
`full_prefix_candidates`，并可提供 `screen_options.candidate_budget`。

完整前缀候选池必须为每个已声明的核心候选 ID 恰好提供一个补全。候选按池中顺序检查，
并在首个候选通过后立即停止。

首个可执行范围有意限制为：精确有理系数、单变量、显式有理字母表。只有当本卡独立验证
割核心变换、完整前缀规范变换、冻结的低扇区块、平坦性、ε 因子分解，以及相对于声明
字母表的精确常数留数 dlog 分解时，候选才能通过。

`TAIL_SCREEN_PASS` 返回首个通过的候选及截至该项的尝试记录。
`CANDIDATE_BUDGET_EXHAUSTED` 表示仍有未测试候选，此时不得启用修复。
`CANDIDATE_POOL_EXHAUSTED` 表示每个核心候选都有已声明的完整前缀补全，且所有补全均已
测试；只有此时才能允许另行授权的有界修复路线。所有结果中的 `repair_invoked` 都必须为
`false`。
