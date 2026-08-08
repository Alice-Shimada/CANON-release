---
name: canon-initial-official-ladder-evidence
description: 为固定的 INITIAL 2.1 官方 massless 3L4P ladder candidate 生成待独立验证的 UT 证据；不搜索、排序、替换或修复候选。
---

# INITIAL 官方 ladder UT 证据卡

本卡只接受 INITIAL 2.1 官方 `massless_3L4P` planar three-loop four-point
ladder：26 项官方 basis 顺序、第一项 UT seed
`G[2,{1,1,1,1,1,1,1,1,1,1,-1,0,0,0,0}]`、`D=4-2 eps`、
`x=t/s`、alphabet `{x,1+x}`、`TakeRow -> 1`。任何 family、candidate、basis、
顺序、normalization、reference、seed 或 alphabet 偏离都返回
`INCONCLUSIVE/OUT_OF_SCOPE`，且不会调用工具或触发其他 workflow 动作。

调用方须在 `method_options` 中显式提供已登记的 `hep_tools_root`，以及精确身份
`INITIAL 2.1; 63d8f813ac415f82f7ef945ee7e3f78a242fae49` 和
`FiniteFlow; 278344c169010b74e791af8c5604c8cb9cd8df11`。使用 Mathematica 14 ARM64：

```text
/Applications/Mathematica.app/Contents/MacOS/WolframKernel \
  -noinit -noprompt -script methods/initial/run.wls input.json NEW_OUTPUT_DIR
```

`NEW_OUTPUT_DIR` 必须不存在、其父目录必须已存在且可写，并且不能位于 HEP 工具安装树
内。runner 固定使用四线程，显式加载登记的 FiniteFlow 三组件链路和 INITIAL 入口，
随后执行官方模板中的 `TCalc` 与 `basisChange`。它不调用 Libra、CANONICA 或任何候选
搜索、排序、替换、修复及路由逻辑。

成功计算只返回 `PROVISIONAL/EVIDENCE_AWAITING_VERIFICATION` 和
`canon-neu/ut-evidence/v1` artifact。provider 自报的 reference、gauge、epsilon 或
dlog 结果均不是最终结论。只有随后独立运行 `mma/CheckUTEvidence.wls`，重新读取官方
A/basis/reference 并复算所有精确条件后，才能得到 `PASS/VERIFIED_EVIDENCE`。

结果类别互不替代：范围外为 `INCONCLUSIVE/OUT_OF_SCOPE`；配置、组件、身份、加载或
计算故障为具体的 `ERROR/TOOL_*`；科学 evidence 被拒绝为
`FAIL/EVIDENCE_REJECTED`；provider 永远不能写出最终 `PASS`。
