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
协议闭合，不表示它们是默认的物理候选路线。积分生成由 `dlogbasis` 卡负责：运行器从
`prepared_family` 读取 ``DlogBasis`` family，从请求 sector ID 展开当前 sector mask，调用
``DlogBasis`DlogBasisSearch``，并把返回的 `CandidateCombinations`、有限仿射覆盖状态和
完整 package evidence 封装为
`canon-neu/integral-candidates/v1`。候选仅是有界 maximal-cut constant-leading-singularity
候选；不声称 global dlog、IBP independence、UT、epsilon form 或 canonical basis。
package 未返回候选时，本卡 fail closed 为 `INCONCLUSIVE/METHOD_EXHAUSTED`，且不写
`integral_candidates`。

DlogBasis-refine 的每个 module-lift 方向是一个候选；方法卡按预算截取候选方向。
IBP 后由 `mma/RouteCoreCandidates.wls` 按当前 sector 的实际 master rank 选择独立行基
及单行替换，再构造 `R` 和 `T=Inverse[R]`。该 adapter 只返回 provisional pool，
仍由 `CheckSectorCore.wls` 独立验收。

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

成功写出 `canon-neu/route-decision/v1`。决策依次为：已 canonical →
`VERIFY_CANONICAL_DE`；可疑候选且有替代项 → `REFINE_SECTOR_UT_CANDIDATES`；
canonical core 的 lower-to-current 缺陷 → `SOLVE_TAIL`；预期存在有理变换 →
`FIND_RATIONAL_CANONICAL_WITH_CANONICA`；其余 → `DIAGNOSE_OR_CHANGE_VARIABLES`。
求解不以 candidate pool 耗尽为前提；UT evidence 仅记录来源。

## Libra 冻结前缀结构化修复

这是保留的独立有界方法；当前 `route-prepared-basis` 不产生 `REPAIR_WITH_LIBRA`。
通用 `SOLVE_TAIL` 路线见下文，不使用本卡的冻结前缀直和限制。

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

当前提供者只运行登记或调用方注入的 Libra，记录实际加载版本，并固定 Fermatica 为
`false`；阶段为
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

## 当前核心路线与验收边界

DlogBasis-refine reduced groups 通过 `ROUTE_CORE_CANDIDATES` 进入独立 `CHECK_CORE`。
core 通过后，`BUILD_FULL_DE` 构造完整前缀系统，`SOLVE_TAIL` 提出扇区变换，
`CHECK_CANONICAL` 独立验算后才由 `COMMIT_SECTOR` 保存 accepted prefix；
`NEXT_SECTOR` 推进扇区游标，`FINAL_CHECK` 基于原始 DE 独立核验累计变换与整族典范系统。
通用 tail 的适用范围和 prefix 归一化规则见
[canon-solve-tail](../skills/canon-solve-tail/SKILL.md)；旧 full-prefix screen 是独立诊断方法。

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
声明的基一致，并严格遵循声明的变量顺序。BUILD_CUT_DE 生成的
`sector_boundaries` 是矩阵行号区间 `{{1,n}}`；`proper_subsectors` 单独列出
cut quotient 丢弃的 strict proper subsectors。

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

`epsilon-zero/run.wls` 提供一个通用的有界 DE 候选方法：从 `A(0)` 的 trace 和
可选 `declared_alphabet` 生成代数前因子，解齐次多项式水平行；两维欠秩时尝试
由 DE 本身确定的 epsilon-singular completion。它只输出 provisional candidates，
仍走同一个 core、tail 和完整 canonical 检查。具体输入见
[`epsilon-zero/SKILL.md`](epsilon-zero/SKILL.md)。

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
  "candidate_group_pool" -> <|
    "declared" -> n, "eligible" -> m, "remaining" -> n-m,
    "unconsumed_candidates" -> k, "pool_exhausted" -> True | False
  |>,
  "candidates" -> {
    <|
      "candidate_id" -> "provider-stable-candidate-id",
      "member_candidate_ids" -> {"integral-candidate-id", ...},
      "new_basis_rows" -> R,
      "construction_rejection" -> None | "singular_reduced_basis",
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

所有 production provider 都携带 `source_basis`、`full_new_basis_rows` 与
`member_candidate_ids`；直接 DE provider 的 source 可以仅为当前 sector，full builder
按列映射嵌入完整 raw basis。对约化积分组，
`new_basis = R.old_basis`，所以 `T = Inverse[R]`。`R` 的列严格使用
`sector_basis["basis"]` resident 顺序；lower-sector coefficients 不混入 core quotient，
但以每组 `full_new_basis_rows` 相对顶层 raw `source_basis` 的顺序显式携带到
`BUILD_FULL_DE`。候选 IBP 后只保留独立行基及独立单行替换；不预先枚举全部子集。

提供者自报的证据不能作为接受证据。

### `ut-evidence/v1`

固定 INITIAL 证据产物使用 `canon-neu/ut-evidence/v1`，并显式绑定提供者任务、族/候选/基
ID、基顺序、归一化、官方参考 ID、26 项基、第一 UT 种子、变量/正则化参数、字母表、A、
T 与 B，以及登记的 INITIAL/FiniteFlow 身份、入口和输入文件哈希。它的
`verification_status` 必须为 `AWAITING_INDEPENDENT_VERIFICATION`；其中任何提供者自报
布尔值都没有通过权限。

`CheckUTEvidence.wls` 要求独立检查器任务声明原提供者任务 ID 和同一固定范围，随后从显式
`checker_options.package_entry`、`finite_flow_package_file` 和 `reference_directory`
重新读取登记的工具入口及官方 A、基与参考；相对路径以检查器输入 JSON 所在目录为准。检查器以失败封闭方式核对
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
  "source_basis" -> {rawL1, ...},
  "basis" -> {l1, ...},
  "convention" ->
    "old_source_basis = transformation . accepted_basis",
  "transformation" -> Tlower,
  "variables" -> {x},
  "regulator" -> eps,
  "alphabet" -> {x, 1 - x, ...},
  "matrices" -> {Alower}
|>
```

`source_basis` 与 `transformation` 是构造 raw off-diagonal block 所需的最小信息；
`basis`、`matrices` 与 `alphabet` 仍描述冻结的 canonical lower prefix。使用前，本卡会
独立复查精确性、平坦性、ε 因子分解和声明的 dlog 字母表。

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
`BUILD_FULL_DE` 的 `full_sector_de` descriptor 直接指向这一 schema；其中 alphabet 可由
显式 `declared_alphabet` 提供，也可先为空，再由 SOLVE_TAIL 提取 pole factors。

完整前缀候选池必须为核心候选池中每个 `candidate_id` 恰好提供一项；部分候选池是输入
错误，不能被报告成“池已耗尽”。候选按顺序检查，首项通过后立即短路，因此后续
重候选不会在已经成功后继续消耗预算。

当前实现有意限制为：一个精确有理变量和显式有理字母表。返回语义为：

- `TAIL_SCREEN_PASS`：首个候选通过完整前缀精确规范检查、冻结前缀、平坦性、ε 和 dlog 检查；
- `CANDIDATE_BUDGET_EXHAUSTED`：仍有未测试候选，不得启用修复；
- `CANDIDATE_POOL_EXHAUSTED`：每个核心候选都有补全且全部失败；可以启用单独的有界修复
  卡，但本卡不会自行调用。

上面的单变量 screen 是独立的诊断方法；当前 `SOLVE_TAIL` 不调用它。
通用 tail 路线先抽取只依赖 epsilon 的公共归一化。若非对角块为 `a+b epsilon`，
按 [arXiv:2206.04609, Eq. (78)](https://arxiv.org/html/2206.04609v2#S3.SS2)
求 `a` 的代数原函数，构造三角修补。原函数的多项式／极点 ansatz 在全部变量方向
联立求解。后续使用 CANONICA 公开 off-diagonal 与 epsilon-normalization 算法，
允许完整 prefix 的归一化更新，并统一交由 CHECK_CANONICAL 接受。
非对角求解可限制在当前 sector 的依赖闭包；epsilon 归一化作用于完整 prefix，
以保留闭包外指向这些低 sector 的耦合。`BUILD_FULL_DE` 复用已接受的低 sector
矩阵，`FINAL_CHECK` 基于原始 DE 独立核验累计变换与整族典范系统。
不再强制先耗尽候选、测试 dots 或重放 prefix。

## 独立验收

`mma/CheckSectorCore.wls` 按声明顺序选择第一个同时满足下列条件的候选：

1. reduction 后的候选组可逆；
2. 精确规范残差逐项为零；
3. 变换后的联络平坦；
4. 每个矩阵正比于声明的正则化参数，且除后与其无关。

每次 rejection 保留 candidate ID 与精确 signature；首个 PASS 后立即停止。只有所有
eligible groups 已尝试且上游 pool 精确耗尽时，summary 才给出 `repair_eligible -> True`；
预算停止不得进入 repair，checker 本身也从不调用 repair/provider。

这只是当前扇区的**核心 ε 形式**门。完整 dlog/字母表结论仍需要在完整前缀（包括非对角
低扇区耦合）上执行 `CHECK_CANONICAL` 和 `FINAL_CHECK`。

大型整族检查可显式设置 `method_options.gauge_backend -> "fermat"`，用
`method_options.package_entry` 指定 Fermatica，并通过 `FERMATPATH` 指定 Fermat。
它在代数商域上精确检验 `A_i T - D_i T - T B_i == 0`；结合已有的 T 可逆性检查，
这与直接计算 gauge 变换等价。默认仍使用 Wolfram 计算。两种后端都使用同一个
多变量共享常数 residue 门；工具来源和实际版本/hash 写入 `canonical_de`。

## 执行边界

每次调用使用工作流所属的新输出目录，不得覆盖已有结果。工具安装只读。工具身份、实际
入口、选项和诊断消息应写入提供者证据或 JSON 摘要。进程返回码为零本身不构成科学成功。
