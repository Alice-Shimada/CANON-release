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

只有在声明阶段确实生成 candidate 的 provider 才能返回 `CANDIDATE_READY`。预处理器、
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

## 目标路线策略（尚未接线）

当前可执行 checker 只验证或筛选显式 candidate artifact，不承担 sector 调度。已经
删除的旧 `workflow.py` 曾把 `CHECK_CANONICAL/TAIL_FAIL` 直接路由到 `SOLVE_TAIL`；该
控制流不再是当前能力。下面是未来在现行状态管理/agent 编排层应实现的科学控制流，
不能把它描述成已有能力。

独立的 `full-prefix-tail-screen` 卡已经实现了其中“对预构造的精确单变量 artifact 进行
有界候选筛选”的部分。它不生成 candidate-specific full DE，也未接入 coordinator，
所以端到端路线仍未闭合。

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
