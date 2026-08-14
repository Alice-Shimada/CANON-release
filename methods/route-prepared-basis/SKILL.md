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

1. 对角与非对角质量均为典范，且没有剩余问题：
   `VERIFY_CANONICAL_DE`。
2. 已选候选可疑或存在局部缺陷，且仍有任何已声明的替代项；即使平台期为真也如此：
   `REFINE_SECTOR_UT_CANDIDATES`。
3. 只有候选池完全耗尽、剩余替代项为零、并且所有已声明候选都已尝试后，局部缺陷才进入：
   `REPAIR_WITH_LIBRA`。
4. 候选选择完成后的全局有理缺陷：
   `FIND_RATIONAL_CANONICAL_WITH_CANONICA`。
5. 其他所有有效状态：`DIAGNOSE_OR_CHANGE_VARIABLES`。

`ut_evidence_references` 是追溯数据。改变 INITIAL 或其他 UT 证据参考不能选择后端、
改变决策或终止路线。

## 输出边界

路线产物记录预备/族/基身份、已选候选、决策、稳定原因，以及 UT 证据不控制路线这一
明确事实。路线决策不等于科学接受，因此本卡永远不返回 `PASS` 或 `FAIL`。
