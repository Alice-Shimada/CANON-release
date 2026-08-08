---
name: canon-full-prefix-tail-screen
description: 在进行任何 tail 修复前，针对冻结的已接受 lower-sector prefix，独立筛选有界、有序的精确单变量 current-sector 候选池。
---

# Full-prefix tail 筛选

在已经构造好 candidate-specific full-prefix 微分方程后使用本卡。它是筛选器，
不是变换生成器：不会修改已接受的 lower prefix，也不会调用 Libra、CANONICA、
Fuchsia 或其他修复算法。

使用可用的 Wolfram kernel，以 `-noinit -noprompt -script` 运行
`run.wls <input.json> <new-output-dir>`。输入 step 为 `SCREEN_TAIL`，需要
`sector_basis`、`sector_cut_de`、`core_candidates`、`accepted_prefix`、
`full_prefix_candidates`，并可提供 `screen_options.candidate_budget`。

full-prefix pool 必须为每个声明的 core candidate ID 恰好提供一个 completion。
候选按池中顺序检查，并在首个候选通过后立即停止。

首个可执行范围有意限制为：精确有理系数、单变量、显式有理 alphabet。只有当本卡
独立验证 cut-core 变换、完整 prefix gauge 变换、冻结的 lower block、flatness、
epsilon factorization，以及相对于声明 alphabet 的精确常数 residue dlog 分解时，
candidate 才能通过。

`TAIL_SCREEN_PASS` 返回首个通过的 candidate 及截至该项的 attempts。
`CANDIDATE_BUDGET_EXHAUSTED` 表示仍有未测试候选，此时不得启用 repair。
`CANDIDATE_POOL_EXHAUSTED` 表示每个 core candidate 都有声明的 full-prefix
completion，且所有 completion 均已测试；只有此时才能允许另行授权的有界 repair
路线。所有结果中的 `repair_invoked` 都必须为 false。
