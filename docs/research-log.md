# CANON research log

本日志只记录会改变研究路线或核心结论的节点；常规命令输出留在测试记录中，不在此重复。

## 本阶段验收标准

1. 先审计当前 dirty worktree、旧会话交接结论和现有测试，明确哪些能力可执行、仅有 scaffold、或因外部环境而 blocked；不得恢复已删除的 `workflow.py`，也不得建立第二套状态机。
2. INITIAL、Libra、CANONICA 的 method-card 和机器可读接口必须保持以下边界：INITIAL 只为指定且已归一化的 candidate 提供 UT 证据或显式候选变换；Libra 处理可定位、可分阶段的结构缺陷；CANONICA 寻找未知的整体有理 canonical transformation。三者不得构成固定 fallback 链。
3. `Inconclusive`、程序/环境失败、候选被数学拒绝必须是不同结果；后端失败不得自动触发 candidate replacement，也不得被解释成数学上不存在解。
4. 后端只能产出 candidate transformation/system；最终成功必须经过独立 verifier，至少核对约定一致性、可逆性、精确 gauge identity、epsilon factorization、除去 epsilon 后无残余 epsilon 依赖、预期 pole/dlog 结构，以及多变量时的 flatness。
5. 外部 package 调用只采用已查证的 primary-source API。缺少 package、版本或可复现实例时，只交付明确标记的 contract/scaffold/blocked capability，不伪造成功路径。
6. 至少完成一个经审计确认的最高收益缺口，并用代表性正负例自动验收；结果记录命令、输入、预期/容限、实际摘要、判定和产物路径。对会改变后续路线或核心结论的完成节点，由独立 agent 按本标准复核；实质问题整改后复验。
7. Git 只在关键节点固化核心 source-of-truth；排除无关改动、大文件和可复现生成物。除非交付确有需要，本阶段不生成新的 TeX。

## 关键节点

### 2026-08-09 — 接续边界确认

- 依据：用户提供的 method-card 边界文本、旧 `CANON`/`CANON-2` 任务记录、当前 `AGENTS.md` 与 `persistent-scientific-research` 规则。
- 结论：旧文本中“扩展 Python workflow 状态机”的要求已失效；INITIAL/Libra/CANONICA 的科学边界仍有效。此前 `full-prefix-tail-screen` 已有 21/21 synthetic 测试和独立 agent `ACCEPT` 记录，但当前未提交工作树仍需重新审计。
- 未决疑点：三张核心 card 中哪些已经具备真实 package 调用、哪些只是 scaffold；旧建议的 `constant-gauge-audit` 是否仍高于补齐 INITIAL card 的优先级。

### 2026-08-09 — 当前实现审计通过主审

- 依据：持久化任务 `T-001/R-001` 的 artifact `A-001`；无 package 注入时 17 个测试中 15 通过、2 跳过，注入登记的 Libra 1.2 与 CANONICA 1.0.3 入口后 17/17 通过（43.303 s）。
- 结论：CANONICA 已是可执行的单变量直接有理变换生成器；Libra 可执行范围是单变量 staged core generation，尚不是 frozen-prefix structured repair；INITIAL 在 CANON 中没有 card/interface/test。`NO_CANDIDATE` 仍混合不支持、计算失败和数学失败；通用多变量 final verifier 仍为 scaffold。下一候选里程碑定为固定官方 ladder 范围的 INITIAL evidence-only vertical slice，先于 `constant-gauge-audit`。
- 未决疑点：该路线与基线证据尚待独立复核；任意物理 candidate 的 INITIAL 支持仍缺少经 primary-source 验证的 basis/order/seed/alphabet 实例，不能从官方 ladder 外推。

### 2026-08-09 — 路线独立复核通过

- 依据：`T-002/R-002` 的独立 artifact `A-002`；真实 Libra/CANONICA 入口复跑 17/17 通过（41.367 s），并逐项核对 A-001 的文件级判断。
- 结论：复核判定 `ACCEPT`，无需整改。固定官方 26×26 ladder 的 INITIAL evidence-only vertical slice 是当前最高收益缺口；四类结果必须分离为 `INCONCLUSIVE/OUT_OF_SCOPE`、`ERROR/TOOL_*`、`FAIL/EVIDENCE_REJECTED`、以及只能由独立 checker 给出的 `PASS/VERIFIED_EVIDENCE`。
- 未决疑点：真实 INITIAL 运行的资源成本需在执行前按已验收调用卡核对；超出官方 ladder 的 candidate 一律不得宣称支持。

### 2026-08-09 — 固定 INITIAL ladder evidence 切片完成

- 依据：`docs/initial-method-card-validation.md`；fixture-only INITIAL 负例 5/5 通过，私有快照 method-card 回归 23 项中 20 项通过、3 项按外部 provider 注入条件跳过。
- 结论：新增 card 只覆盖登记的官方 26×26 ladder，provider 仅能返回 `PROVISIONAL/EVIDENCE_AWAITING_VERIFICATION`；独立 checker 对官方 A/basis/reference、变换相等、可逆性、精确 gauge identity、`B/eps` 和 `{x,1+x}` dlog span 全部复算后才可返回 `PASS/VERIFIED_EVIDENCE`。范围外、工具错误、证据拒绝和验证通过已经类型分离，且不会触发候选替换或 repair。
- 真实运行限定：唯一一次真实 `TCalc` 成功交付 provisional evidence，随后旧版通用 dlog checker 在 240 秒超时；修正后没有重跑 `TCalc`，而是用同一官方 reference 的 `basisChange` 独立构造 B，checker 在 10.47 秒内给出完整 verified summary。因而真实证据明确记录为“provider 成功 + post-fix 官方 reference checker 验证”，不伪装成同一进程的无间断端到端通过。
- 未决疑点：任意其他 family、basis、seed、order、alphabet 或 normalization 仍为 `OUT_OF_SCOPE`；本切片不支持外推。

### 2026-08-09 — 独立复核与共享工作树验收

- 依据：`T-004/R-004` artifact `A-004` 判定 `ACCEPT`；reviewer 在私有副本复跑 fixture 5/5、完整回归 23 项中 20 项通过/3 项跳过，并以官方 reference + `basisChange` 独立得到 checker `PASS/VERIFIED_EVIDENCE`，全程未调用 TCalc。
- 结论：A-003 的专用 dlog 条件与 `{1/x,1/(1+x)}` 常 residue span 精确等价；在 `old_basis = T.new_basis` 约定下直接检查 `A.T-D[T,x]-T.B==0` 正确且无需显式求逆。patch 已应用到共享工作树。
- 程序验收：共享工作树 INITIAL 合约负例 5/5 通过（21.413 s）；注入登记的 Libra/CANONICA 真实入口、显式不注入 INITIAL 后，完整 23-test 回归为 22 通过、1 项条件跳过（58.141 s），判定 PASS。
- 未决疑点：本轮没有在 checker 优化后再次运行 TCalc；证据严格限定为一次真实 provider provisional success 加一次独立的 post-fix 官方 reference checker PASS，不宣称连续端到端成功或任意 candidate 支持。

### 2026-08-09 — Prepared-basis contract、确定性 route 与 typed provider 结果

- 代表性输入：现有精确 2×2 单变量 `sector-cut-de.wl`；prepared-basis fixture 显式包含
  preparation/family/basis identity、冻结且已接受的 lower prefix、两个有 normalization/rank
  的 candidate、diagonal/off-diagonal quality、localized defect signature、INITIAL evidence
  reference、plateau/pool/alternatives history 和 remaining-problem classification。
- 预期/容限：所有判据均为精确符号判据，没有数值容限。Router 必须覆盖五个固定 decision；
  malformed/contradictory 输入必须稳定返回 `ERROR/INVALID_PREPARED_BASIS`；改变 INITIAL
  evidence 不得改变 route。Libra/CANONICA provider 成功预期
  `PROVISIONAL/CANDIDATE_TRANSFORMATION`，随后独立 checker 才能给出 `PASS/CORE_PASS`。
- Focused 命令：`python3 -m unittest -v` 运行 prepared-basis 五分支、INITIAL non-control、
  malformed/contradictory、Libra multivariable scope、CANONICA non-flat 和两项 exhaustion
  测试；全部通过。新测试暴露并修正了 `FlatConnectionQ` 原有的多变量 pair iterator，
  fixture 对 flat/non-flat 两方向分别精确返回 `True/False`。
- Libra 真实命令：以 `WolframKernel -noinit -noprompt -script methods/libra/run.wls`
  调用登记入口 `/Users/balth/Works/hep-tools/tools/libra/Source/Libra.m`（1.2，入口 SHA-256
  `b3574e7f560951516a289a8141aafbaf23f0f5ae563e29d0fa077b17ba4d3eb4`），caller-owned
  目录为 `validation-runs/libra-provider`。实际 provider summary 是
  `PROVISIONAL/CANDIDATE_TRANSFORMATION`、`provider_check_eps_form=true`、一个 candidate；
  `mma/CheckSectorCore.wls` 在 `validation-runs/libra-checker` 返回 `PASS/CORE_PASS`，
  `invertible/exact_gauge/flat_connection/epsilon_factorized` 全为 `true`。
- CANONICA 真实命令：同样以 fresh kernel 调用登记入口
  `/Users/balth/Works/hep-tools/tools/canonica/src/CANONICA.m`（1.0.3，入口 SHA-256
  `0bf334159265f17814fb21bf8f1248637e66622bc4a8a3768085f7416df9d200`），caller-owned
  目录为 `validation-runs/canonica-provider`。实际 provider summary 与 Libra 同为
  `PROVISIONAL/CANDIDATE_TRANSFORMATION`、provider epsilon check true、一个 candidate；
  checker 在 `validation-runs/canonica-checker` 返回同样四项全 true 的 `PASS/CORE_PASS`。
- 产物路径：两项 provider 的 `core-candidates.wl`/`result.json` 和 checker 的
  `core-transform.wl`/`result.json` 均保留在上述 run workspace 的 `validation-runs/` 下；
  它们是可复现验证输出，不进入交付 patch。
- 完整回归：注入登记的真实 Libra/CANONICA 入口并显式不注入 INITIAL，运行
  `python3 -m unittest discover -s tests -p 'test_*.py' -v`，29 项在 130.643 秒内
  `OK`，仅真实 INITIAL ladder 条件测试按预期跳过；其余 INITIAL 与 full-prefix regressions
  全部通过。全程没有运行 INITIAL、`TCalc`，两个 transformation provider 也没有互调或
  fallback。

### 2026-08-09 — A-007 rejection remediation 与重新验收

- 独立复核输入：T-007/A-007 的四项 blocking counterexample。修正版删除 method-card
  protocol 中过时的 `CANDIDATE_READY`；canonical quality 与 selected-candidate suspicion
  不再能并存；localized rational defect 必须同时有至少一个 `DEFECT` quality dimension
  和 `rational_transformation_expected=True`；`alternatives_remaining` 必须严格等于
  declared-minus-attempted candidate 数，pool exhausted 或 candidate selection complete
  时不得留有 declared unattempted candidate。
- 新负例与预期：四项输入都没有数值容限，必须稳定返回
  `ERROR/INVALID_PREPARED_BASIS`，field 分别为 `candidates.selected`、
  `remaining_problem.rational_transformation_expected`、`quality.localized_defect` 和
  `search_history.alternatives_remaining`。实际四项全按预期拒绝；五个合法 route branch
  仍全部产生原 decision。完整 focused contract 命令运行 10 个 test method，54.267 秒
  `OK`。
- CANONICA load precedence：保留 package-first load，避免输入先创建 `Global`eps` 后的
  ``CANONICA`eps::shdw`` 干扰 fail-closed package check。工具与输入同时失败时，确定性
  返回具体 `ERROR/TOOL_*`；工具边界通过后才分类
  `ERROR/INVALID_DIFFERENTIAL_SYSTEM`。这是错误优先级，不是 fallback。
- 真实 provider 重验：登记入口和 hash 未变。R-008 caller-owned 产物分别位于
  `validation-runs/libra-provider`、`validation-runs/libra-checker`、
  `validation-runs/canonica-provider` 和 `validation-runs/canonica-checker`。两个 provider
  实际均为 `PROVISIONAL/CANDIDATE_TRANSFORMATION`、一个 candidate、provider epsilon
  check true；两个独立 checker 均为 `PASS/CORE_PASS`，且
  `invertible/exact_gauge/flat_connection/epsilon_factorized` 全为 true。
- 完整回归：以登记的 Libra/CANONICA 入口运行
  `python3 -m unittest discover -s tests -p 'test_*.py' -v`，33 项在 143.147 秒内
  `OK`，仅 real INITIAL ladder 条件测试按预期跳过。全程没有运行 INITIAL、`TCalc`，
  没有修改外部安装。
