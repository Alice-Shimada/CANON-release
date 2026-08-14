# 方法卡协议

方法卡是附着在某个明确工作阶段上的有界科学能力单元。当前可执行的 `SEARCH_CORE` 卡
负责提出当前扇区割系统的变换。后续卡可以预处理同一输入、筛选积分候选、求解完整前缀
尾部，或提供独立 UT 证据。方法卡不负责扇区调度，不修改已接受的低扇区前缀，也不能
接受自己的结果。

约化前积分候选现在有独立的 `PROPOSE_INTEGRAL_CANDIDATES` 合同，位于 IBP、主基排序和
DE 变换之前；它不再复用 `SEARCH_CORE`。`SEARCH_CORE` 保持为 Libra/CANONICA 兼容的
约化后变换阶段。

## 角色

- **积分生成器**：在 IBP 约化前生成一个或多个可追溯的 Feynman 积分候选；
- **变换生成器**：从已知微分系统生成当前扇区或完整前缀的基变换；
- **预处理器**：改变变量，或向生成器提供字母表、奇点等提示；
- **筛选器**：拒绝候选或对候选排序，但不声称已经得到完整基；
- **验证器/校准器**：提供 ε 形式不能蕴含的证据，例如首奇点、
  边界归一化或独立数值。

只有在声明阶段确实生成候选变换的提供者才能返回
`PROVISIONAL/CANDIDATE_TRANSFORMATION`；提供者不能接受或拒绝自己的结果。预处理器、
筛选器和验证器必须在一条路线内组合使用，或者只返回诊断证据。

首批启用的变换提供者是 `canonica` 和 `libra`。它们的 2x2 固定样例只证明提供者/检查器
协议闭合，不表示它们是默认的物理候选路线。计划中的默认路线是：使用 DLogBasis 或其他
积分生成器提出候选，在冻结的低扇区前缀上检查，并替换导致不良非对角块的候选。重型
变换提供者只保留为有界诊断/修复兜底。`dlogbasis` 与暂定分类的 `gram-baikov` 都是约化前
`PROPOSE_INTEGRAL_CANDIDATES` 仅接口卡；没有实现任何 CANON 科学适配器，也没有选择
Gram-Baikov 主要 API。DLogBasis 的三个相关公共 API
`IntegrandAnsatz`、`LeadingSingularities` 和 `GenerateDlogbasis` 提出 `G[...]` 积分或
dlog 组合，不产生有序主基 DE 变换。受版本控制的软件包中只有
`LeadingSingularitiesPortable.tar.gz` 是自包含的；`LS_modified.zip` 不是。
`IntegrandAnsatz` 用法把可选参数描述为分子幂次数，而受版本控制的实现以 `dim_:4` 在幂计数
公式中使用它；在适配器设计前此歧义必须解决，不能把维数、分子/幂计数与候选预算静默合并。

`initial` 是独立的证据提供者，不是变换搜索或修复提供者。它仅覆盖 INITIAL 2.1 已登记的
官方 26×26 无质量平面三圈四点梯图候选，固定官方基/顺序、第一项 UT 种子、
`TakeRow -> 1` 和字母表 `{x,1+x}`。范围外
输入返回 `INCONCLUSIVE/OUT_OF_SCOPE`，工具故障返回具体 `ERROR/TOOL_*`，都不会触发
候选替换或其他提供者。计算成功也只返回
`PROVISIONAL/EVIDENCE_AWAITING_VERIFICATION`；最终 `PASS/VERIFIED_EVIDENCE` 只能由
`mma/CheckUTEvidence.wls` 独立复算后给出。

## 有类型的结果语义

所有方法卡结果保持 `canon-neu/script-result/v1` 封装，并且状态只有以下
五种正式含义：

- `ERROR`：输入、环境、工具或计算失败，没有作出数学结论；
- `INCONCLUSIVE`：卡的适用范围不覆盖输入，或有界方法已经耗尽，但没有拒绝候选；
- `PROVISIONAL`：提供者提出了仍待独立检查的变换、证据或路线；
- `FAIL`：只有独立精确验证器/证据检查器可以用它拒绝科学结论；
- `PASS`：只有独立验证器可以用它接受科学结论。

因此 Libra/CANONICA 成功只能返回
`PROVISIONAL/CANDIDATE_TRANSFORMATION`，范围外返回
`INCONCLUSIVE/OUT_OF_SCOPE`，有界阶段耗尽返回 `INCONCLUSIVE/METHOD_EXHAUSTED`，非法或
非平坦微分系统返回 `ERROR/INVALID_DIFFERENTIAL_SYSTEM`。变换提供者不能返回 `PASS` 或
数学拒绝 `FAIL`。

约化前生成器成功只能返回 `PROVISIONAL/INTEGRAL_CANDIDATES` 和
`canon-neu/integral-candidates/v1`；`INCONCLUSIVE` 仍仅允许 `OUT_OF_SCOPE` 或
`METHOD_EXHAUSTED`，`ERROR` 必须给出具体代码而不能用 `ERROR/ERROR`。产物按
`INTERFACES.md` 分别记录族/扇区身份、维数策略、分子或幂计数策略、候选预算、候选池耗尽、
候选单位、归一化、稳定 ID、精确定义、方法证据与工具来源。它不声称候选具有 UT 性质或
呈典范形式；
后续约化和独立检查器保留各自权限。

## `libra-dependent-row-hierarchy/v1`

Libra `SEARCH_CORE` 中由调用方选择的 `sector-de-closure` 路线读取以下带类型 WL 产物：

```wl
<|
  "schema" -> "canon-neu/libra-dependent-row-hierarchy/v1",
  "hierarchy_id" -> "...",
  "sector" -> <|...|>, "family_id" -> "...", "basis_id" -> "...",
  "basis" -> {j1, ...},
  "master_sector_labels" -> {label1, ...},
  "sector_hierarchy" -> {{1, 0, ...}, ...},
  "max_mask_nonzeros" -> positiveInteger,
  "provenance" -> <|
    "producer" -> "...", "tool" -> "...", "tool_revision" -> "...",
    "mapped_sectors" -> False,
    "source_artifact" -> "...", "source_sha256" -> "64-hex-digits"
  |>
|>
```

`basis` 必须与割中的完整有序基精确相同；`master_sector_labels` 长度也是 `n`。
`sector_hierarchy` 是 `n×n` 二元关系掩码，对角为 1；不把它解释为行列表，不推断对称
映射，也不禁止环路。预算单位是闭包后的掩码非零数。缺失或矛盾的产物返回
`ERROR/INVALID_DIFFERENTIAL_SYSTEM`；闭包超预算返回 `INCONCLUSIVE/METHOD_EXHAUSTED`，
不会截断或重试。成功候选仍须由现有
`CheckSectorCore` 独立精确验收。

## `prepared-basis/v1` 与确定性路线

`route-prepared-basis` 是一个已经可执行、但尚未连接到外部协调器的纯路线卡。它只读取、
验证并分类预备基；不运行 Libra、CANONICA 或 INITIAL，也不改变候选。输入产物的完整
v1 形状为：

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

验证器要求预备/族/基身份完整、当前基 ID 一致、存在的低扇区前缀已被接受、候选 ID/排名
唯一且排名是从 1 开始的连续顺序、恰好一个已选候选、证据参考指向已声明候选，并拒绝
典范状态与缺陷或已选候选可疑状态并存、候选池耗尽/选择完成时仍有未尝试的已声明候选、
`alternatives_remaining` 与已声明数减已尝试数不一致、局部有理缺陷没有 `DEFECT` 质量维度
或有理预期，以及局部/全局分类与缺陷数据相矛盾等状态。失败是确定性的
`ERROR/INVALID_PREPARED_BASIS`，并报告稳定的字段/原因。

成功写出 `canon-neu/route-decision/v1`，结果为 `PROVISIONAL/ROUTE_DECISION`。决策优先级
固定为：已经呈典范形式 → `VERIFY_CANONICAL_DE`；可疑候选或局部缺陷且还有任何已声明替代项
（即使平台期为真）→ `REFINE_SECTOR_UT_CANDIDATES`；局部缺陷只有在完整候选池耗尽、
替代项为零且所有已声明候选都已尝试后 → `REPAIR_WITH_LIBRA`；候选选择已完成后的全局
有理缺陷 → `FIND_RATIONAL_CANONICAL_WITH_CANONICA`；其余 →
`DIAGNOSE_OR_CHANGE_VARIABLES`。`ut_evidence_references` 只用于追溯；改变 INITIAL 证据本身
不能选择后端、改变决策或终止路线。

## Libra 冻结前缀结构化修复

`libra-structured-repair` 是与 `methods/libra` 的 `SEARCH_CORE` 不同的提供者。它只读取
通过校验的预备基、恰为 `REPAIR_WITH_LIBRA` 的路线决策，以及
`canon-neu/libra-structured-repair-input/v1`。修复输入必须显式绑定预备/族/基/已选候选
身份、完整有序基与精确矩阵、`old_basis = transformation . new_basis` 约定、冻结前缀的
ID/基/顺序/维数/已接受矩阵、禁止混合块、局部目标特征、单变量有理 dlog 字母表，以及与
预备基完全相同的完整候选池耗尽证据。平台期只能作为诊断元数据，不能授权修复。上述
身份、范围、维数、候选池状态、约定或系数域的矛盾都在加载 Libra 前拒绝。

v1 不宣称一般局部/完整前缀修复：唯一支持的结构是一个已接受的典范 `1x1` 前缀与一个
`2x2` 当前尾部的直和，两个交叉块必须严格为零并禁止变换混合，缺陷必须是尾部内部
`current-current` ε 因子分解条目，失败测试必须是 `REGULATOR_INDEPENDENT_TERM`。已接受
前缀在解析软件包前必须精确通过平坦性、ε 因子分解、除正则化参数后无残余依赖和声明的
单变量 dlog 字母表。预备特征的 `(row,column)` 必须满足
`full_entry = prefix_dimension + {row,column}`。系数参数固定为 `parameters -> {}`，矩阵、
字母表和候选变换中出现 `x`、正则化参数之外的 `z` 等未声明符号会在失败时封闭拒绝。

当前提供者只运行登记或调用方注入的 Libra 1.2，并固定 Fermatica 为 `false`；阶段为
`NewDSystem` → `Fuchsify` → `Transform` → `FactorOut` → `Transform` →
`OverallTransformation` → `EFormQ`。它没有提供者回退，也不调用其他方法卡。多变量或
全局/非局部问题为 `INCONCLUSIVE/OUT_OF_SCOPE`，无效/非平坦系统为
`ERROR/INVALID_DIFFERENTIAL_SYSTEM`，有界阶段不能产生冻结前缀兼容的矩阵候选时为
`INCONCLUSIVE/METHOD_EXHAUSTED`。成功也只能写
`canon-neu/libra-structured-repair-candidate/v1` 并返回
`PROVISIONAL/CANDIDATE_TRANSFORMATION`。

提供者发布门只核对形状、声明的精确语法、可逆性、前缀身份和禁止混合，不运行
典范形式、ε 因子分解、dlog 与目标接受判据。`mma/CheckStructuredRepair.wls` 从权威预备/路线/请求重新加载
候选，以检查器自有实现独立核对全部身份/顺序/域/约定、变换维数与可逆性、前缀身份和
禁止混合块、完整精确规范恒等式、平坦性、ε 因子分解与除正则化参数后无残余依赖、声明的
dlog 字母表、目标缺陷消除，以及所有声明的已接受块不退化。检查器还必须通过
`checker_options` 独立进行路径规范化、读取文件状态并计算注入的 Libra 入口哈希，且不得求值
软件包或读写任何 Libra 上下文状态；随后逐项认证工具身份、入口/哈希、软件包来源、
运行时、Fermatica/μ 选项和阶段；认证来源保留在已验证产物中。只有它能返回
`PASS/VERIFIED_STRUCTURED_REPAIR`；任何提供者 `PASS` 字段都会作为伪造状态被
`FAIL/STRUCTURED_REPAIR_REJECTED` 拒绝，提供者证据不具有验收权限。

## 目标路线策略（尚未接线）

当前可执行检查器只验证或筛选显式候选产物，不承担扇区调度。已经删除的旧
`workflow.py` 曾把 `CHECK_CANONICAL/TAIL_FAIL` 直接路由到 `SOLVE_TAIL`；该控制流不再是
当前能力。下面是未来在现行状态管理/智能体编排层应实现的科学控制流，
不能把它描述成已有能力。

独立的 `full-prefix-tail-screen` 卡已经实现了其中“对预构造的精确单变量产物进行有界候选
筛选”的部分；`libra-structured-repair` 已实现显式符合条件的局部缺陷的提供者/检查器纵向
切片。两者仍未接入协调器，也不负责生成物理候选特定的完整 DE，所以端到端路线仍未闭合。

对每个当前扇区：

1. 生成可追溯的积分候选，并约化到声明的主基；
2. 通过精确当前扇区割门；
3. 不修改已接受的低扇区前缀，将其插入并构造完整前缀微分系统；
4. 对完整前缀进行精确可积性、ε/dlog 和字母表检查；
5. 若非对角块失败，记录精确失败特征，并测试下一个积分候选；
6. 只有有界候选池耗尽后，才调用声明过的尾部修复提供者，并独立复算完整系统。

ε 形式本身不能证明 UT 归一化。与运动学无关的可逆变换（包括依赖 ε 的变换）可以保持
ε 形式，甚至可能完全不改变联络。因此最终 UT 结论还需要适用的被积函数层 dlog/首奇点
判据、独立 INITIAL/Picard--Fuchs 检验，或者已知具有权重分级的低扇区/边界展开。数值
结果只有在与此类解析参考比较时才能校准微分方程看不见的归一化；裸数值一致不是 UT
证明。提供者排序只是调度提示，不是科学门。

## 科学产物

产物使用 Wolfram Language 关联，以 `Put` 写入、`Get` 读取；JSON 只携带产物描述符。

### 外部方法包的加载

CANON 的方法卡不读取 hep-tools、本机机器状态或固定目录。需要 Libra、
CANONICA 等外部包的卡，只能通过以下通用边界解析依赖：

- `method_options.package_entry` 显式给出包主文件；相对路径以任务 `input.json` 所在
  目录解析；
- 未给出时，使用 Wolfram 标准 `$Path` 和 `FindFile["PackageContext`"]`。

两条路径都无法解析时返回 `ERROR/TOOL_UNAVAILABLE`；`package_entry` 类型错误则返回
`ERROR/INVALID_OPTIONS`，不得把调用方错误伪装成环境缺包。卡必须检查包文件确实加载
成功以及本卡实际调用的公共符号存在，并记录实际入口、入口 SHA-256、解析方式、
Wolfram `$Version`/`$SystemID` 及工具能够报告的版本。提供者的工具自检仍不能代替
CANON 的独立科学检查器。本机安装与验收可以由外部环境管理，但不属于 CANON 工作流的
状态事实源。

CANONICA 运行器有意先解析并加载软件包，再读取和验证 `sector_cut_de`。这是为了避免
先求值输入中的 `Global`eps` 后加载 CANONICA 时触发 ``CANONICA`eps::shdw``，从而把一个
实际已经加载的软件包误判为不干净的加载。因而当工具不可用与微分输入非法或非平坦同时
存在时，结果优先为具体的 `ERROR/TOOL_*`；只有工具边界通过后才返回
`ERROR/INVALID_DIFFERENTIAL_SYSTEM`。该优先级是确定性的输入/环境错误分类，不是科学
回退，也不允许提供者作数学拒绝。

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

方程约定为 `D[basis, variable[[i]]] == matrices[[i]].basis`。矩阵必须是方阵，维数必须与
声明的基一致，并严格遵循声明的变量顺序。

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

其中基必须与 `sector_cut_de["basis"]` 完全相同。

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

提供者自报的证据不能作为接受证据。

### `ut-evidence/v1`

固定 INITIAL 证据产物使用 `canon-neu/ut-evidence/v1`，并显式绑定提供者任务、族/候选/基
ID、基顺序、归一化、官方参考 ID、26 项基、第一 UT 种子、变量/正则化参数、字母表、A、
T 与 B，以及登记的 INITIAL/FiniteFlow 身份、入口和输入文件哈希。它的
`verification_status` 必须为 `AWAITING_INDEPENDENT_VERIFICATION`；其中任何提供者自报
布尔值都没有通过权限。

`CheckUTEvidence.wls` 要求独立检查器任务声明原提供者任务 ID 和同一固定范围，随后从显式
`checker_options.hep_tools_root` 重新读取登记的官方 A、基与参考。检查器以失败封闭方式核对
任务/族/候选/基/顺序/归一化/参考、工具入口及哈希、官方基顺序和种子、`T` 与参考的严格
相等、可逆性、精确规范恒等式、`B/eps` 无残余 `eps`，以及单变量 `{x,1+x}` 常数留数 dlog
张成空间。只有这些独立检查全为真时才写 `canon-neu/verified-ut-evidence/v1` 并返回
`PASS/VERIFIED_EVIDENCE`。

完整前缀筛选要求显式 `candidate_id`。它在候选池重排后仍保持稳定，用来标识物理/积分
候选；列表索引只记录单次提供者运行时的调度顺序。

### 尾部筛选使用的 `accepted_prefix`

首个可执行尾部筛选卡接收一个已经检查、不可修改的低扇区前缀：

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

使用前，本卡会独立复查精确性、平坦性、ε 因子分解和声明的 dlog 字母表。

### `full_prefix_candidates`

`full-prefix-tail-screen` 接收有序、有界的候选池：

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

基顺序固定为低扇区前缀在前、当前扇区在后。`Tfull` 必须保持低扇区前缀不变，低扇区到
当前扇区的右上块必须为零，当前扇区内部块必须复现独立验收的核心变换。左下块是声明的
候选特定低扇区补全。卡会重新计算每个完整变换后的矩阵，不信任提供者的声明结果。

完整前缀候选池必须为核心候选池中每个 `candidate_id` 恰好提供一项；部分候选池是输入
错误，不能被报告成“池已耗尽”。候选按顺序检查，首项通过后立即短路，因此后续
重候选不会在已经成功后继续消耗预算。

当前实现有意限制为：一个精确有理变量和显式有理字母表。返回语义为：

- `TAIL_SCREEN_PASS`：首个候选通过完整前缀精确规范检查、冻结前缀、平坦性、ε 和 dlog 检查；
- `CANDIDATE_BUDGET_EXHAUSTED`：仍有未测试候选，不得启用修复；
- `CANDIDATE_POOL_EXHAUSTED`：每个核心候选都有补全且全部失败；可以启用单独的有界修复
  卡，但本卡不会自行调用。

## 独立验收

`mma/CheckSectorCore.wls` 选择第一个同时满足下列条件的候选：

1. 产物模式、基顺序、变量和正则化参数完全一致；
2. 任务扇区、稳定族 ID 和稳定基 ID 完全一致；
3. 所有系数都属于有限的精确有理函数域；拒绝机器实数、不定式、无穷大、代数根和无法
   分类的表达式；
4. `T` 是声明维数的可逆方阵，且其行列式经精确有理化简后非零；
5. 精确规范残差逐项为零；
6. 变换后的联络是平坦的；
7. 每个变换后矩阵都正比于声明的正则化参数，且除以正则化参数后与其无关。

非平坦的输入割联络是上游 `INVALID_CUT_DE` 错误，会阻塞工作流；它不是候选失败，不能
回到 `SEARCH_CORE`。

这只是当前扇区的**核心 ε 形式**门。完整 dlog/字母表结论仍需要在完整前缀（包括非对角
低扇区耦合）上执行 `CHECK_CANONICAL` 和 `FINAL_CHECK`。

## 执行边界

每次调用使用工作流所属的新输出目录，不得覆盖已有结果。工具安装只读。工具身份、实际
入口、选项和诊断消息应写入提供者证据或 JSON 摘要。进程返回码为零本身不构成科学成功。
