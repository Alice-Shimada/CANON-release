# Method-card 协议

Method card 是附着在某个明确工作阶段上的有界科学能力单元。当前可执行的
`SEARCH_CORE` 卡负责提出 current-sector cut system 的变换。后续卡可以预处理同一
输入、筛选积分候选、求解 full-prefix tail，或提供独立 UT 证据。Method card 不负责
sector 调度，不修改已接受的 lower-sector prefix，也不能接受自己的结果。

## 角色

- **积分生成器**：在 IBP 约化前生成一个或多个可追溯的 Feynman integral candidate；
- **变换生成器**：从已知微分系统生成 current-sector 或 full-prefix basis 变换；
- **预处理器**：改变变量，或向生成器提供 alphabet、奇点等提示；
- **筛选器**：拒绝候选或对候选排序，但不声称已经得到完整 basis；
- **验证器/校准器**：提供 epsilon form 不能蕴含的证据，例如 leading singularity、
  边界归一化或独立数值。

只有在声明阶段确实生成 candidate transformation 的 provider 才能返回
`PROVISIONAL/CANDIDATE_TRANSFORMATION`；provider 不能接受或拒绝自己的结果。预处理器、
筛选器和验证器必须在一条路线内组合使用，或者只返回诊断证据。

首批启用的变换 provider 是 `canonica` 和 `libra`。它们的 2x2 fixture 只证明
provider/checker 协议闭合，不表示它们是默认的物理 candidate 路线。计划中的默认路线
是：使用 DLogBasis 或其他积分生成器提出候选，在冻结的 lower-sector prefix 上检查，
并替换导致不良非对角块的候选。重型变换 provider 只保留为有界诊断/修复兜底。
`dlogbasis` 仍是由合作者维护的 interface-only provider。

`initial` 是独立的 evidence provider，不是变换搜索或 repair provider。它仅覆盖
INITIAL 2.1 已登记的官方 26×26 massless planar 3-loop 4-point ladder candidate，
固定官方 basis/order、第一项 UT seed、`TakeRow -> 1` 和 alphabet `{x,1+x}`。范围外
输入返回 `INCONCLUSIVE/OUT_OF_SCOPE`，工具故障返回具体 `ERROR/TOOL_*`，都不会触发
候选替换或其他 provider。计算成功也只返回
`PROVISIONAL/EVIDENCE_AWAITING_VERIFICATION`；最终 `PASS/VERIFIED_EVIDENCE` 只能由
`mma/CheckUTEvidence.wls` 独立复算后给出。

## 有类型的结果语义

所有 method-card 结果保持 `canon-neu/script-result/v1` envelope，并且 status 只有以下
五种正式含义：

- `ERROR`：输入、环境、工具或计算失败，没有作出数学结论；
- `INCONCLUSIVE`：卡的适用范围不覆盖输入，或有界方法已经耗尽，但没有拒绝 candidate；
- `PROVISIONAL`：provider 提出了仍待独立检查的 transformation、evidence 或 route；
- `FAIL`：只有独立 exact verifier/evidence checker 可以用它拒绝科学 claim；
- `PASS`：只有独立 verifier 可以用它接受科学 claim。

因此 Libra/CANONICA 成功只能返回
`PROVISIONAL/CANDIDATE_TRANSFORMATION`，范围外返回
`INCONCLUSIVE/OUT_OF_SCOPE`，有界 stages 耗尽返回
`INCONCLUSIVE/METHOD_EXHAUSTED`，非法或非 flat differential system 返回
`ERROR/INVALID_DIFFERENTIAL_SYSTEM`。Transformation provider 不能返回 `PASS` 或
数学拒绝 `FAIL`。

## `prepared-basis/v1` 与确定性 route

`route-prepared-basis` 是一个已经可执行、但尚未连接到外部 coordinator 的纯 route 卡。
它只读取、验证并分类 prepared basis；不运行 Libra、CANONICA 或 INITIAL，也不改变
候选。输入 artifact 的完整 v1 形状为：

```wl
<|
  "schema" -> "canon-neu/prepared-basis/v1",
  "identity" -> <|
    "preparation_id" -> "...", "family_id" -> "...", "basis_id" -> "...",
    "variables" -> {x, ...}, "regulator" -> eps
  |>,
  "current_basis" -> <|"basis_id" -> "...", "basis" -> {j1, ...}|>,
  "frozen_lower_prefix" -> <|
    "present" -> True | False, "accepted" -> True | False,
    "prefix_id" -> "..." | Null, "basis" -> {l1, ...} | {}
  |>,
  "candidates" -> {
    <|
      "candidate_id" -> "...", "definition" -> <|...|>,
      "normalization" -> "...", "rank" -> 1,
      "selected" -> True | False, "suspicious" -> True | False
    |>, ...
  },
  "quality" -> <|
    "diagonal" -> "CANONICAL" | "DEFECT" | "UNKNOWN",
    "off_diagonal" -> "CANONICAL" | "DEFECT" | "UNKNOWN",
    "localized_defect" -> <|
      "present" -> True | False, "block" -> "..." | Null,
      "signature" -> <|...|> | <||>
    |>
  |>,
  "ut_evidence_references" -> {
    <|
      "reference_id" -> "...", "provider" -> "...",
      "candidate_id" -> "...", "verification_status" -> "..."
    |>, ...
  },
  "search_history" -> <|
    "plateau" -> True | False, "pool_exhausted" -> True | False,
    "alternatives_remaining" -> 0, "attempted_candidate_ids" -> {"...", ...}
  |>,
  "remaining_problem" -> <|
    "classification" ->
      "NONE" | "SUSPICIOUS_CANDIDATE" | "LOCALIZED_RATIONAL_DEFECT" |
      "GLOBAL_RATIONAL_DEFECT" | "UNKNOWN_OR_NONRATIONAL",
    "candidate_selection_complete" -> True | False,
    "rational_transformation_expected" -> True | False
  |>
|>
```

Validator 要求 preparation/family/basis identity 完整、current basis ID 一致、present
lower prefix 已被接受、candidate ID/rank 唯一且 rank 是从 1 开始的连续顺序、恰好一个
selected candidate、evidence reference 指向已声明 candidate，并拒绝 canonical 与 defect
或 selected-candidate suspicion 并存、pool exhausted/selection complete 时仍有未尝试的
declared candidate、`alternatives_remaining` 与 declared-minus-attempted 数量不一致、
localized rational defect 没有 `DEFECT` quality dimension 或 rational expectation、以及
localized/global classification 与 defect data 相矛盾等状态。失败是
确定性的 `ERROR/INVALID_PREPARED_BASIS`，并报告稳定 field/reason。

成功写出 `canon-neu/route-decision/v1`，结果为 `PROVISIONAL/ROUTE_DECISION`。决策优先级
固定为：已经 canonical → `VERIFY_CANONICAL_DE`；suspicious candidate 或 localized defect
且还有 alternatives、没有 plateau → `REFINE_SECTOR_UT_CANDIDATES`；localized defect 在
plateau 或完整 pool exhaustion 后 → `REPAIR_WITH_LIBRA`；candidate selection 已完成后的
global rational defect → `FIND_RATIONAL_CANONICAL_WITH_CANONICA`；其余 →
`DIAGNOSE_OR_CHANGE_VARIABLES`。`ut_evidence_references` 只用于追溯；改变 INITIAL evidence
本身不能选择 backend、改变 decision 或终止 route。

## Libra frozen-prefix structured repair

`libra-structured-repair` 是与 `methods/libra` 的 `SEARCH_CORE` 不同的 provider。它只读取
通过校验的 prepared basis、恰为 `REPAIR_WITH_LIBRA` 的 route decision，以及
`canon-neu/libra-structured-repair-input/v1`。repair input 必须显式绑定 preparation/family/
basis/selected-candidate identity，完整 ordered basis 与精确 matrices，
`old_basis = transformation . new_basis` 约定，冻结 prefix 的 ID/basis/order/dimension/
accepted matrices，禁止混合块，localized target signature，单变量 rational dlog alphabet，
以及与 prepared basis 完全相同的 plateau 或完整 pool-exhaustion 证据。上述身份、范围、
维数、pool state、约定或系数域的矛盾都在加载 Libra 前拒绝。

v1 不宣称一般 localized/full-prefix repair：唯一支持的结构是一个 accepted canonical
`1x1` prefix 与一个 `2x2` current tail 的直和，两个 cross blocks 必须严格为零并禁止
transformation mixing，defect 必须是 tail 内部 `current-current` epsilon-factorization entry，
failure test 必须是 `REGULATOR_INDEPENDENT_TERM`。accepted prefix 在 package resolution 前
必须精确通过 flatness、epsilon factorization、除 regulator 后无残余依赖和声明的单变量 dlog
alphabet。prepared signature
的 `(row,column)` 必须满足 `full_entry = prefix_dimension + {row,column}`。系数参数固定
`parameters -> {}`，矩阵、alphabet 和 candidate transformation 中出现 `x`、regulator 之外
的 `z` 等未声明 symbol 会 fail-closed 拒绝。

当前 provider 只运行登记或调用方注入的 Libra 1.2，并固定 Fermatica 为 false；阶段为
`NewDSystem` → `Fuchsify` → `Transform` → `FactorOut` → `Transform` →
`OverallTransformation` → `EFormQ`。它没有 provider fallback，也不调用其他 method card。
多变量或 global/nonlocalized 问题为 `INCONCLUSIVE/OUT_OF_SCOPE`，无效/non-flat system
为 `ERROR/INVALID_DIFFERENTIAL_SYSTEM`，有界阶段不能产生冻结 prefix 兼容的矩阵 candidate 为
`INCONCLUSIVE/METHOD_EXHAUSTED`。成功也只能写
`canon-neu/libra-structured-repair-candidate/v1` 并返回
`PROVISIONAL/CANDIDATE_TRANSFORMATION`。

Provider 的 publication gate 只核对 shape、declared exact syntax、invertibility、prefix
identity 和禁止 mixing，不运行 gauge/epsilon/dlog/target acceptance。`mma/CheckStructuredRepair.wls`
从 authoritative prepared/route/request 重新加载 candidate，以 checker-owned 实现独立核对
全部 identity/order/domain/convention、变换维数与可逆性、prefix identity 和禁止
混合块、完整 exact gauge identity、flatness、epsilon factorization 与除 regulator 后无残余
依赖、声明 dlog alphabet、target defect 消除，以及所有 declared accepted blocks 不退化。
Checker 还必须通过 `checker_options` 独立 canonicalize/stat/hash injected Libra entry，且不得
求值 package 或读写任何 Libra context state；随后逐项认证
tool identity、entry/hash、package source、runtime、Fermatica/mu options 和 stages；认证 provenance
保留在 verified artifact。
只有它能返回 `PASS/VERIFIED_STRUCTURED_REPAIR`；任何 provider `PASS` 字段都会作为 forged
status 被 `FAIL/STRUCTURED_REPAIR_REJECTED` 拒绝，provider evidence 不具有验收权限。

## 目标路线策略（尚未接线）

当前可执行 checker 只验证或筛选显式 candidate artifact，不承担 sector 调度。已经
删除的旧 `workflow.py` 曾把 `CHECK_CANONICAL/TAIL_FAIL` 直接路由到 `SOLVE_TAIL`；该
控制流不再是当前能力。下面是未来在现行状态管理/agent 编排层应实现的科学控制流，
不能把它描述成已有能力。

独立的 `full-prefix-tail-screen` 卡已经实现了其中“对预构造的精确单变量 artifact 进行
有界候选筛选”的部分；`libra-structured-repair` 已实现显式 eligible localized defect 的
provider/checker vertical slice。两者仍未接入 coordinator，也不负责生成物理
candidate-specific full DE，所以端到端路线仍未闭合。

对每个 current sector：

1. 生成可追溯的积分候选，并约化到声明的 master basis；
2. 通过精确 current-sector cut gate；
3. 不修改 accepted lower-sector prefix，将其插入并构造 full-prefix 微分系统；
4. 对 full prefix 进行精确可积性、epsilon/dlog 和 alphabet 检查；
5. 若非对角块失败，记录精确 failure signature，并测试下一个积分候选；
6. 只有有界候选池耗尽后，才调用声明过的 tail-repair provider，并独立复算完整系统。

Epsilon form 本身不能证明 UT 归一化。与运动学无关的可逆变换（包括依赖 epsilon 的
变换）可以保持 epsilon form，甚至可能完全不改变 connection。因此最终 UT 结论还需要
适用的 integrand-level dlog/leading-singularity 判据、独立 INITIAL/Picard--Fuchs
检验，或者已知具有 weight grading 的 lower-sector/边界展开。数值结果只有在与此类
解析参考比较时才能校准微分方程看不见的归一化；裸数值一致不是 UT 证明。Provider
排序只是调度提示，不是科学 gate。

## 科学 artifact

Artifact 使用 Wolfram Language Association，以 `Put` 写入、`Get` 读取；JSON 只携带
artifact descriptor。

### 外部方法包的加载

CANON 的 method card 不读取 hep-tools、本机机器状态或固定目录。需要 Libra、
CANONICA 等外部包的卡，只能通过以下通用边界解析依赖：

- `method_options.package_entry` 显式给出包主文件；相对路径以 task `input.json` 所在
  目录解析；
- 未给出时，使用 Wolfram 标准 `$Path` 和 `FindFile["PackageContext`"]`。

两条路径都无法解析时返回 `ERROR/TOOL_UNAVAILABLE`；`package_entry` 类型错误则返回
`ERROR/INVALID_OPTIONS`，不得把调用方错误伪装成环境缺包。卡必须检查包文件确实加载
成功以及本卡实际调用的公共符号存在，并记录实际入口、入口 SHA-256、解析方式、
Wolfram `$Version`/`$SystemID` 及工具能够报告的版本。Provider 的工具自检仍不能代替
CANON 的独立科学 checker。本机安装与验收可以由外部环境管理，但不属于 CANON
workflow 的状态事实源。

CANONICA runner 有意先解析并加载 package，再读取和验证 `sector_cut_de`。这是为了避免
先求值输入中的 `Global`eps` 后加载 CANONICA 时触发 ``CANONICA`eps::shdw``，从而把一个
实际已经加载的 package 误判为不干净的加载。因而当工具不可用与 differential input
非法或 non-flat 同时存在时，结果优先为具体的 `ERROR/TOOL_*`；只有工具边界通过后才返回
`ERROR/INVALID_DIFFERENTIAL_SYSTEM`。该优先级是确定性的输入/环境错误分类，不是科学
fallback，也不允许 provider 作数学拒绝。

### `sector_cut_de`

```wl
<|
  "schema" -> "canon-neu/sector-cut-de/v1",
  "sector" -> <|"id" -> 7, "propagator_count" -> 3|>,
  "family_id" -> "stable-family-id",
  "basis_id" -> "stable-current-sector-basis-id",
  "coefficient_domain" -> "exact-rational-functions",
  "basis" -> {j1, j2, ...},
  "variables" -> {x, ...},
  "regulator" -> eps,
  "matrices" -> {Ax, ...},
  "sector_boundaries" -> Automatic | {...}
|>
```

方程约定为 `D[basis, variable[[i]]] == matrices[[i]].basis`。矩阵必须是方阵，维数
必须与声明的 basis 一致，并严格遵循声明的变量顺序。

### `sector_basis`

```wl
<|
  "schema" -> "canon-neu/sector-basis/v1",
  "sector" -> <|"id" -> 7, "propagator_count" -> 3|>,
  "family_id" -> "stable-family-id",
  "basis_id" -> "stable-current-sector-basis-id",
  "basis" -> {j1, j2, ...}
|>
```

其中 basis 必须与 `sector_cut_de["basis"]` 完全相同。

### `core_candidates`

```wl
<|
  "schema" -> "canon-neu/core-candidates/v1",
  "sector" -> <|"id" -> 7, "propagator_count" -> 3|>,
  "family_id" -> "stable-family-id",
  "basis_id" -> "stable-current-sector-basis-id",
  "coefficient_domain" -> "exact-rational-functions",
  "basis" -> {j1, j2, ...},
  "variables" -> {x, ...},
  "regulator" -> eps,
  "convention" -> "old_basis = transformation . new_basis",
  "method" -> <|"id" -> "...", "tool" -> "..."|>,
  "candidates" -> {
    <|
      "candidate_id" -> "provider-stable-candidate-id",
      "transformation" -> T,
      "transformed_matrices" -> {Bx, ...},
      "provider_evidence" -> <|...|>
    |>
  }
|>
```

对每个变量，变换约定为：

```wl
Bi == Inverse[T].(Ai.T - D[T, variable])
```

Provider 自报的 evidence 不能作为 acceptance evidence。

### `ut-evidence/v1`

固定 INITIAL evidence artifact 使用 `canon-neu/ut-evidence/v1`，并显式绑定 provider
task、family/candidate/basis ID、basis 顺序、normalization、官方 reference ID、26 项
basis、第一 UT seed、变量/regulator、alphabet、A、T 与 B，以及登记的 INITIAL/
FiniteFlow 身份、入口和输入文件 hash。它的 `verification_status` 必须为
`AWAITING_INDEPENDENT_VERIFICATION`；其中任何 provider 自报布尔值都没有通过权限。

`CheckUTEvidence.wls` 要求独立 checker task 声明原 provider task ID 和同一固定 scope，
随后从显式 `checker_options.hep_tools_root` 重新读取登记的官方 A、basis 与 reference。
checker fail-close 核对 task/family/candidate/basis/order/normalization/reference、工具入口
及 hash、官方 basis 顺序和 seed、`T` 与 reference 的严格相等、可逆性、精确 gauge
identity、`B/eps` 无残余 `eps`，以及单变量 `{x,1+x}` 常数 residue dlog span。只有这些
独立检查全为真时才写 `canon-neu/verified-ut-evidence/v1` 并返回
`PASS/VERIFIED_EVIDENCE`。

full-prefix 筛选要求显式 `candidate_id`。它在候选池重排后仍保持稳定，用来标识物理/
积分候选；列表 index 只记录单次 provider 运行时的调度顺序。

### tail 筛选使用的 `accepted_prefix`

首个可执行 tail-screen 卡接收一个已经检查、不可修改的 lower-sector prefix：

```wl
<|
  "schema" -> "canon-neu/accepted-prefix/v1",
  "prefix_id" -> "stable-prefix-id",
  "family_id" -> "stable-family-id",
  "coefficient_domain" -> "exact-rational-functions",
  "basis" -> {l1, ...},
  "variables" -> {x},
  "regulator" -> eps,
  "alphabet" -> {x, 1 - x, ...},
  "matrices" -> {Alower}
|>
```

使用前，本卡会独立复查精确性、flatness、epsilon factorization 和声明的 dlog
alphabet。

### `full_prefix_candidates`

`full-prefix-tail-screen` 接收有序、有界的 candidate pool：

```wl
<|
  "schema" -> "canon-neu/full-prefix-candidates/v1",
  "sector" -> <|"id" -> 7, "propagator_count" -> 3|>,
  "family_id" -> "stable-family-id",
  "current_basis_id" -> "stable-current-sector-basis-id",
  "accepted_prefix_id" -> "stable-prefix-id",
  "coefficient_domain" -> "exact-rational-functions",
  "lower_basis" -> {l1, ...},
  "current_basis" -> {j1, ...},
  "variables" -> {x},
  "regulator" -> eps,
  "alphabet" -> {x, 1 - x, ...},
  "convention" ->
    "old_prefix_basis = full_transformation . candidate_prefix_basis",
  "source_matrices" -> {Afull},
  "candidates" -> {
    <|
      "candidate_id" -> "provider-stable-candidate-id",
      "full_transformation" -> Tfull,
      "transformed_matrices" -> {Bfull}
    |>
  }
|>
```

Basis 顺序固定为 lower prefix 在前、current sector 在后。`Tfull` 必须保持 lower
prefix 不变，lower-to-current 的右上块必须为零，current-current 块必须复现独立验收
的 core transformation。左下块是声明的 candidate-specific lower-sector
completion。卡会重新计算每个完整变换后的矩阵，不信任 provider 的声明结果。

full-prefix pool 必须为 core pool 中每个 `candidate_id` 恰好提供一项；partial pool 是
输入错误，不能被报告成“池已耗尽”。候选按顺序检查，首项通过后立即短路，因此后续
重候选不会在已经成功后继续消耗预算。

当前实现有意限制为：一个精确有理变量和显式有理 alphabet。返回语义为：

- `TAIL_SCREEN_PASS`：首个候选通过 full-prefix exact gauge、frozen-prefix、
  flatness、epsilon 和 dlog 检查；
- `CANDIDATE_BUDGET_EXHAUSTED`：仍有未测试候选，不得启用 repair；
- `CANDIDATE_POOL_EXHAUSTED`：每个 core candidate 都有 completion 且全部失败；可以
  启用单独的有界 repair 卡，但本卡不会自行调用。

## 独立验收

`mma/CheckSectorCore.wls` 选择第一个同时满足下列条件的 candidate：

1. artifact schema、basis 顺序、变量和 regulator 完全一致；
2. task sector、稳定 family ID 和稳定 basis ID 完全一致；
3. 所有系数都属于有限的精确有理函数域；拒绝 machine real、indeterminate、
   infinity、algebraic root 和无法分类的表达式；
4. `T` 是声明维数的可逆方阵，且其行列式经精确有理化简后非零；
5. 精确 gauge-transformation residual 逐项为零；
6. 变换后的 connection 是 flat；
7. 每个变换后矩阵都正比于声明的 regulator，且除以 regulator 后与其无关。

非 flat 的输入 cut connection 是上游 `INVALID_CUT_DE` 错误，会阻塞 workflow；它不是
candidate failure，不能回到 `SEARCH_CORE`。

这只是 current-sector 的 **core epsilon-form** gate。完整 dlog/alphabet 结论仍需要在
full prefix（包括非对角 lower-sector coupling）上执行 `CHECK_CANONICAL` 和
`FINAL_CHECK`。

## 执行边界

每次调用使用 workflow 所属的新输出目录，不得覆盖已有结果。工具安装只读。工具身份、
实际入口、选项和诊断消息应写入 provider evidence 或 JSON summary。进程返回码为零本身
不构成科学成功。
