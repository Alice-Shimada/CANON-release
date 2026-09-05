# 预备基确定性路由器

## 目的

本方法卡校验一个 `canon-neu/prepared-basis/v1` 产物，并输出一个
`canon-neu/route-decision/v1` 产物。它只执行确定性编排：不运行提供者、不改变候选、
不接受科学结论，也不检查提供者安装。

使用 `run.wls <input.json> <output_dir>` 运行；输入为
`canon-neu/script-input/v1` 封装，`step` 是 `ROUTE_PREPARED_BASIS`，`payload` 包含
`prepared_basis` Mathematica 表达式描述符。结果为 `PROVISIONAL/ROUTE_DECISION`；
格式错误或自相矛盾的产物返回 `ERROR/INVALID_PREPARED_BASIS`，并包含稳定的 `field`
与原因。

## 决策及其优先级

1. 已经呈 canonical form：`VERIFY_CANONICAL_DE`。
2. 已选候选可疑且仍有替代项：`REFINE_SECTOR_UT_CANDIDATES`。
3. core 已 canonical 且缺陷位于 lower-to-current coupling：`SOLVE_TAIL`。
4. 预期存在有理变换：`FIND_RATIONAL_CANONICAL_WITH_CANONICA`。
5. 其余：`DIAGNOSE_OR_CHANGE_VARIABLES`。

后两条求解路线不要求候选池耗尽。`ut_evidence_references` 只记录来源，
不控制路线。通用 tail 使用 `mma/SolveTail.wls`；旧 Libra 直和切片只保留为
单独的有界方法，不是通用流程的 tail backend。

## 输出边界

路线产物记录预备/族/基身份、已选候选、决策、稳定原因，以及 UT 证据不控制路线这一
明确事实。路线决策不等于科学接受，因此本卡永远不返回 `PASS` 或 `FAIL`。
