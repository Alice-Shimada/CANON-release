# Mathematica 脚本接口

这里定义接口，不定义算法、内部函数或实现细节。前半部分是 typed method-card
envelope；文末的直接 IBP/DE 接口是无状态科学适配层，不接收该 envelope，也不定义
第二套研究状态机。

## 统一调用

```text
wolframscript -file <script.wls> <input.json> <output_dir>
```

脚本实现后必须在 `<output_dir>/result.json` 写统一结果。科学 artifact 推荐写成 `.wl`，Python 只传递路径，不读取内容。

## 统一输入

可直接用于 `PREPARE` 的请求见 [`interfaces/prepare.example.json`](interfaces/prepare.example.json)，
其科学输入是 [`interfaces/family-spec.example.wl`](interfaces/family-spec.example.wl) 中的
Wolfram Association。输入准备与主 Agent 路由见 [agent workflow](docs/agent-workflow.md)。

```json
{
  "schema": "canon-neu/script-input/v1",
  "task_id": "T0006-CHECK_CORE",
  "step": "CHECK_CORE",
  "sector": {
    "id": 7,
    "propagator_count": 3
  },
  "payload": {}
}
```

全局步骤的 `sector` 是 `null`。

## 统一输出

```json
{
  "schema": "canon-neu/script-result/v1",
  "task_id": "T0006-CHECK_CORE",
  "step": "CHECK_CORE",
  "status": "PASS",
  "code": "CORE_PASS",
  "artifacts": {
    "core_transform": {
      "type": "mathematica-expression",
      "path": "core-transform.wl"
    }
  },
  "summary": {}
}
```

`status` 使用唯一的 typed method-card 协议，可为 `ERROR`、`INCONCLUSIVE`、
`PROVISIONAL`、`FAIL` 或 `PASS`。provider 只能发布前三类中受其 card 允许的 code，
不能发布 `PASS` 或 `FAIL`；独立 checker 保留最终 `PASS`/`FAIL` 权限。artifact 路径
相对于 `result.json` 所在目录，由 method-card caller 解析；`statemng` 不解析科学
`result.json`，也不根据其中的 code 自动推进 scientific stage graph。

## 各步骤 SKILL、payload 与输出

| step | SKILL | 脚本 | payload keys | artifact keys |
|---|---|---|---|---|
| `PREPARE` | `canon-prepare-family` | `mma/PrepareFamily.wls` | `family_spec` | `prepared_family` |
| `PROPOSE_INTEGRAL_CANDIDATES` | `canon-dlogbasis-integral-candidates` | `methods/dlogbasis/run.wls` | `family_identity`, `sector_identity`, `prepared_family`, `dimension_policy`, `numerator_or_power_counting_policy`, `candidate_budget`, `candidate_unit`, `normalization_policy`, `method_options` | `integral_candidates` |
| `DISCOVER` | `canon-discover-sectors` | `mma/DiscoverSectors.wls` | `prepared_family` | `sector_manifest`, `master_basis` |
| `BUILD_CUT_DE` | `canon-build-cut-de` | `mma/BuildSectorCutDE.wls` | `prepared_family`, `master_basis`, `sector_manifest`, `ibp_reduction` | `sector_basis`, `sector_cut_de`, `ordered_master_de` |
| `SLICE_CUT_DE` | `canon-build-cut-de` | `mma/SliceSectorCutDE.wls` | `ordered_master_de`, `sector_manifest` | `sector_basis`, `sector_cut_de` |
| `ROUTE_CORE_CANDIDATES` | `canon-search-core` | `mma/RouteCoreCandidates.wls` | `prepared_family`, `sector_basis`, `sector_cut_de`, `candidate_ibp_bridge` | `core_candidates` |
| `SEARCH_CORE` | `canon-search-core` | `methods/*/run.wls` | `prepared_family`, `sector_basis`, `sector_cut_de`, `method_options` | `core_candidates` |
| `CHECK_CORE` | `canon-check-core` | `mma/CheckSectorCore.wls` | `sector_basis`, `sector_cut_de`, `core_candidates` | `core_transform` |
| `BUILD_FULL_DE` | `canon-build-full-de` | `mma/BuildFullSectorDE.wls` | `ordered_master_de`, `sector_cut_de`, `core_candidates`, `core_transform`, `declared_alphabet`, `accepted_prefix` | `full_sector_de` |
| `SOLVE_TAIL` | `canon-solve-tail` | `mma/SolveTail.wls` | `full_sector_de`, `core_transform`, `method_options` | `sector_transform` |
| `CHECK_CANONICAL` | `canon-check-canonical` | `mma/CheckCanonical.wls` | `full_sector_de`, `sector_transform` | `canonical_sector_de` |
| `COMMIT_SECTOR` | `canon-commit-sector` | `mma/CommitSector.wls` | `previous_accepted_prefix`, `sector_basis`, `sector_transform`, `canonical_sector_de` | `accepted_prefix` |
| `NEXT_SECTOR` | `canon-commit-sector` | `mma/NextSector.wls` | `sector_manifest`, `accepted_prefix` | `sector_cursor` |
| `FINAL_CHECK` | `canon-final-check` | `mma/CheckFullSystem.wls` | `prepared_family`, `master_basis`, `sector_manifest`, `ordered_master_de`, `accepted_prefix` | `canonical_basis`, `canonical_de` |

`canon-build-de`、`canon-build-cut-de`、`canon-build-full-de`、
`canon-solve-tail`、`canon-check-canonical`、`canon-commit-sector` 与 `canon-final-check`
记录当前直接科学实现；
其余仍未实现的历史步骤不得因表中占位接口而视为完成。

首个 sector 的 `accepted_prefix` 或 `previous_accepted_prefix` 是 `null`。

`DISCOVER/PASS` 还必须给出：

```json
{
  "summary": {
    "sectors": [
      {"id": 7, "propagator_count": 3}
    ]
  }
}
```

脚本按 sector manifest rank 稳定排序 masters；同 sector 保持原 Kira position。

## 最小结果码

`PROPOSE_INTEGRAL_CANDIDATES` 是可选的约化前候选路线。原始 DE 构造和 DE provider
不依赖它。当前 provider 将 sector ID 展开为完整指标顺序的 bit mask，调用
``DlogBasis`DlogBasisSearch``，按 candidate budget 截取候选方向。候选归一化约定是
`normalization.factor ReleaseHold[exact_definition]` 精确重建 package 组合。
非空输出为 `PROVISIONAL/INTEGRAL_CANDIDATES`；没有候选为
`INCONCLUSIVE/METHOD_EXHAUSTED`。`method_options` 保留显式 `loop_order`、`loop_dimensions`、
`package_entry`、`finite_flow_package_file`，以及已有 numerator/backend 选项。
包与 FiniteFlow 文件的相对路径以输入 JSON 所在目录为准；可选 `package_revision`
记录调用方声明的源码版本，未提供时为 `null`。实际入口始终记录 SHA-256。

`ROUTE_CORE_CANDIDATES` 在 IBP 之后按当前 sector 的实际 master rank 选择独立行基与单行替换，
输出 `PROVISIONAL/CORE_CANDIDATES_ROUTED`。它不枚举全部大小为 rank 的子集。

`SEARCH_CORE` 是 provider 步骤，不使用下表的 authoritative `PASS`/`FAIL`：候选已生成时
发布 `PROVISIONAL/CANDIDATE_TRANSFORMATION`，范围或方法未建立时发布
`INCONCLUSIVE/OUT_OF_SCOPE` 或 `INCONCLUSIVE/METHOD_EXHAUSTED`，输入或工具故障发布
具体 `ERROR/*`。其余 method-card provider 同样遵守 `methods/README.md` 的单一 typed
协议。

| step | PASS | 未通过或未求解 |
|---|---|---|
| `PREPARE` | `OK` | 无 |
| `DISCOVER` | `SECTORS_READY` | 无 |
| `BUILD_CUT_DE` | `OK` | 无 |
| `CHECK_CORE` | `CORE_PASS` | `CORE_FAIL` |
| `BUILD_FULL_DE` | `OK` | 无 |
| `SOLVE_TAIL` | `TAIL_READY` | `INCONCLUSIVE/TAIL_UNSOLVED` |
| `CHECK_CANONICAL` | `CANONICAL_PASS` | `CORE_FAIL`, `TAIL_FAIL` |
| `COMMIT_SECTOR` | `OK` | 无 |
| `NEXT_SECTOR` | `OK` | 无 |
| `FINAL_CHECK` | `ALL_PASS` | 无 |

这些 code 只定义 scientific method-card 合同语义；当前 `statemng` 只记录显式研究任务
状态，不把 code 当作自动 scientific coordinator 的转移规则。

## `integral-candidates/v1`

`PROPOSE_INTEGRAL_CANDIDATES` 的 WL artifact 形状为：

```wl
<|
  "schema" -> "canon-neu/integral-candidates/v1",
  "proposal_id" -> "stable-proposal-id",
  "family_identity" -> <|"family_id" -> "...", "family_spec_id" -> "..."|>,
  "sector_identity" -> <|
    "sector_id" -> "stable-sector-id", "id" -> 7, "propagator_count" -> 3
  |>,
  "dimension_policy" -> <|
    "spacetime_dimension" -> "D" | 4 | ..., "per_loop_policy" -> "..."
  |>,
  "numerator_or_power_counting_policy" -> <|
    "policy_id" -> "...", "definition" -> <|...|>
  |>,
  "candidate_budget" -> <|
    "maximum" -> nonNegativeInteger, "consumed" -> nonNegativeInteger,
    "unit" -> "PROVIDER_CANDIDATE"
  |>,
  "pool_exhausted" -> True | False,
  "candidate_pool" -> <|
    "available" -> n, "remaining" -> k, "pool_exhausted" -> True | False
  |>,
  "candidate_unit" -> "INDIVIDUAL_G_INTEGRAL" | "NORMALIZED_LINEAR_COMBINATION",
  "normalization_policy" -> <|"convention" -> "...", "factors" -> <|...|>|>,
  "candidates" -> {
    <|
      "candidate_id" -> "provider-stable-candidate-id",
      "exact_definition" -> HoldComplete[j[family, a1, ...]] | HoldComplete[...],
      "candidate_unit" -> "...",
      "normalization" -> <|"convention" -> "...", "factor" -> ...|>
    |>, ...
  },
  "method_evidence" -> <|"method_id" -> "...", "evidence" -> {...}|>,
  "tool_provenance" -> <|
    "tool" -> "...", "tool_revision" -> "...", "entry" -> "...",
    "entry_sha256" -> "...", "runtime" -> "..."
  |>
|>
```

输入 envelope 必须同时用 `family_identity`、`sector_identity` 和顶层 `sector` 绑定同一
family/sector；output 必须原样保持这些稳定 identity。`dimension_policy`、
`numerator_or_power_counting_policy`、`candidate_budget`、`pool_exhausted`、
`candidate_unit` 和 `normalization_policy` 是不同字段，provider 不能从其中一个静默推断
另一个。provider 把 package 的每个 `CandidateCombinations` 方向作为一个 candidate；
candidate pool 只记录已有方向及预算截断。候选 IBP 桥保留每个 ID、定义与归一化；
group 在约化后才由 `BuildCoreCandidates` 生成，并携带其独立行选择范围。

## Agent 与状态边界

`canon-neu/script-result/v1` 只描述 method-card 调用结果，不定义持久研究状态或 agent
delegation。当前唯一状态权限与交接协议由根目录 `AGENTS.md` 和 `README.md` 的 `statemng`
规则定义；本接口不创建第二套状态机。

## 直接 IBP/DE 接口

以下程序只处理数学输入和普通文件。调用它们的 Agent 负责在已分配 workspace 中运行，
并通过 `statemng` 登记需要保留的结果。

### Production typed family preparation

`PrepareFamily.wls` 的 `family_spec` 是 trusted Wolfram Association，包含
`family_ref`、`basis_ref`、`topology`、`parameters`、`variables`、`regulator`、
`dimension_rule`、`index_order`、`propagator_slots`、`sector_convention`、`kira`、
`family_data`、`prepared_derivatives` 和 `ordered_masters`。Kira 字段与现有 project/jobs
保持一致；`family_data`、导数与 masters 是源文件路径。spec 内的相对资源路径（包括
`kira.project`）以 spec 所在目录为基准，Kira jobs/config/targets 相对于该 project。
`propagator_slots` 使用完整指标中的
一基位置。新的通用接口不读取 `sector_source` 或文献 basis indices。

`DiscoverSectors.wls` 从有序 master list 计算完整指标顺序的 `sector_bits`，ISP 位为零；
`id = sector_bits . 2^Range[0,n-1]`。每个 sector 同时给出 `propagator_count` 与
`master_count`，按 `(propagator_count,id)` 排序，同 sector 保持原 master 相对顺序。

### 导数算符选择

```wl
Get[FileNameJoin[{repoRoot, "mma", "lib", "BaikovDerivative.wl"}]];
choice = ChooseDerivativeOperator[prepared, variable];
```

`prepared` 同时提供 affine denominator operator 与有界 enhanced-Baikov membership
数据。找到 exact zero-growth 解时返回：

```wl
<|"kind" -> "enhanced-baikov", "cofactors" -> {...}, "f_cofactor" -> ...|>
```

声明次数内未找到解不是错误，直接返回：

```wl
<|"kind" -> "affine-fallback", "operator" -> prepared["operators", variable]|>
```

该包不生成 Kira targets、不运行 IBP、不构造 DE。cofactor 到 reducer targets 的转换
属于可替换的合作者准备接口。

### 候选导数与 IBP 桥

```text
wolframscript -file mma/ReduceCandidateIBP.wls \
  INTEGRAL-CANDIDATES.wl PREPARED-FAMILY.wl MASTER-BASIS.wl \
  PREPARED-DERIVATIVES.wl REQUEST.json RESULT.wl
```

输入候选使用 DlogBasis-refine 适配器给出的 `j[family,a1,...,an]` 线性组合；桥把它映射为
声明的 Kira topology head，并保留整体有理 prefactor、`candidate_id` 和有符号指标。
每个变量只采用 `ChooseDerivativeOperator` 的实际返回值。affine 分支使用声明的
denominator derivative；enhanced-Baikov 分支令

```wl
lambda = (d-L-E-1)/2; kappa = (E-d+1)/2;
v_i = If[MemberQ[propagatorSlots,i], z_i c_i, c_i];
weight = kappa D[Gext,x]/Gext + lambda cF +
  Sum[a_i v_i/z_i - D[v_i,z_i], {i,n}];
```

并逐项采用 `z^m I[a] = I[a-m]`。因此 protected `z_i c_i` 产生的真实 proper-subsector
tail 不得在 sector 过滤前删除；ISP 指标按 Kira 的负号 convention 原样保存。候选线性
组合还包括显式 `D[prefactor,x]` 项。

成功的 `canon-neu/candidate-ibp-bridge/v1` 只携带 family/basis/topology identity、slot
order、sector convention、逐变量 operator choice、有序 masters、候选导数与全部
ordered-master affine 导数的精确 reducer targets、
完全回代 rules、candidate pool，以及逐 `candidate_id` 的原定义、topology expression、derivatives、target
metadata、reduced expression 和 reduced derivatives。target metadata 恰有 `integral`、
`indices`、`sector_mask` 和 `numerator_indices`。该 artifact 是 IBP 闭合结果，不证明候选
为 UT、canonical basis 或完整 master basis。

### Core、完整 prefix 与 tail

`RouteCoreCandidates.wls` 消费 `prepared_family`、`sector_basis`、`sector_cut_de` 和
`candidate_ibp_bridge`。IBP 后的候选行先投影到 resident current-sector masters，再选择一个
独立基及其独立单行替换。低 sector 系数保留在 `full_new_basis_rows`，列顺序是顶层
`source_basis`。所有 group 的 `T=Inverse[R]`，使用 `old_basis=T.new_basis`。
该 group pool 是有界选择空间，耗尽不代表穷尽了所有积分代表。

CANONICA/Libra 直接 provider 使用相同的 `source_basis`、`full_new_basis_rows` 与
`member_candidate_ids`；其 source basis 可以仅含 current-sector masters。
`BuildFullSectorDE.wls` 按显式 source-basis 映射将行嵌入 raw prefix，缺少的列系数为零。
它复用完整 `ordered_master_de`，不再次进行 IBP 或构造 DE。

若 `old_lower=Tlower.accepted_lower`，先用 `T0=diag(Tlower,I)` 得到 mixed prefix DE。
完整候选行为 `{{I,0},{Rlower.Tlower,Rcurrent}}`，其逆为 `Tfull`。输出沿用
`canon-neu/full-prefix-candidates/v1`，包括 `source_matrices`、`block_boundaries` 和候选
completion。`declared_alphabet` 必须显式给 descriptor 或 `null`；后者表示自动 pole-factor
字母候选。显式 `letters` 允许 Wolfram 根式表达式。

`SolveTail.wls` 只消费 `full_sector_de`、`core_transform`、`method_options.package_entry`
（CANONICA）。若候选已经是完整 dlog form，直接交付；否则调用
`TransformOffDiagonalBlock` 与 `TransformDlogToEpsForm` 求新的修正，并组合完整变换。
不要求 candidate pool 耗尽，也不强制 dotted replay。求解未得到变换时返回
`INCONCLUSIVE/TAIL_UNSOLVED`；所得 `sector_transform` 交给 `CHECK_CANONICAL`。

`CheckCanonical.wls` 从 `source_matrices` 和 `sector_transform` 重算完整 gauge，使用
`sector_transform["alphabet"]`，检查 epsilon factorization、shared constant residues 与
prefix 闭合。对低 sector 的归一化改变作为完整变换的一部分接受，不另设冻结限制。
flatness 检查使用全部变量对的精确符号曲率。完整检查失败时按 current-current block
是否失败区分 `CORE_FAIL` 与 `TAIL_FAIL`。

`CommitSector.wls` 记录 `Taccepted=diag(Tlower,I).Tfull`、完整的新基与已检查矩阵；
不把 lower blocks 强行改回旧值。旧 artifact 不修改，sector/candidate trace 追加一项。
`NextSector.wls` 由 manifest 与 trace 计算下一项；迭代和持久化仍属于主 Agent 与 statemng。

`CheckFullSystem.wls` 从原始完整 DE 与累计变换重算全局 gauge，调用与 sector checker
共用的 `DLogResidues`，对所有变量联合求解常数留数并精确重建。仅 `ALL_PASS` 输出
`canonical_basis` 与 `canonical_de`。精确代数表达式直接使用 Wolfram 求导、化简与
`SolveAlways`；不额外构建代数域或分支管理层。

### IBP 约化

```text
wolframscript -file mma/ReduceIBP.wls REQUEST.json RESULT.wl
```

请求必须恰有七个字段：

| field | meaning |
|---|---|
| `executable` | 合作者指定的 reducer executable 或命令名 |
| `project` | 已准备的 Kira project |
| `jobs` | 按运行顺序给出的两个 project-relative job 文件 |
| `topology` | Kira topology / Wolfram integral head 名 |
| `targets` | project-relative target list |
| `output` | 尚不存在的 Kira 工作目录 |
| `options` | 逐项传给 Kira 的 argv，例如 `--parallel=1`；线程数由调用方按资源预算指定 |

`project`、`output` 和带路径分隔符的 `executable` 相对于请求 JSON 所在目录解析；
仅给命令名的 `executable` 从 PATH 查找。`jobs`、`targets` 相对于 Kira project。
候选 IBP 桥使用同一规则；命令行的结果文件路径仍相对于调用方工作目录。

示例见 `interfaces/ibp-request.example.json`。适配器信任合作者准备的 project 与 Kira
输出，复制 project、依次运行两个 argv job，并直接读取有序 `masters.final` 与导出
rules。调用者的正向科学测试负责核对精确 target 覆盖、master 顺序和 RHS 闭合。

成功结果只有：

```wl
<|"masters" -> orderedMasters, "rules" -> fullyReducedRules|>
```

适配器不探测版本、不计算 hash、不保存 log/provenance/sector manifest，也不修改研究
状态；master 顺序原样保留 Kira 的 `masters.final`。

### 微分方程构造

```wl
Get[FileNameJoin[{repoRoot, "mma", "lib", "DEBuilder.wl"}]];
result = BuildDifferentialEquations[family, masters, rules];
```

`family` 必须恰有声明参数和有序 affine operators：

```wl
<|
  "parameters" -> {d, x1, x2, ...},
  "operators" -> <|x1 -> C1, x2 -> C2, ...|>
|>
```

若积分有 `m` 个指标，每个 `Cx` 的维数必须为 `m x (m+1)`，表示
`d D_i/dx = Cx[[i,1]] + Sum_j Cx[[i,j+1]] D_j`。`masters` 固定矩阵顺序；
immediate `rules` 必须已经完全回代到这些 masters，所有系数属于声明的有理函数域。

矩阵采用 `D[masters,x] == A_x . masters`。每一变量对先完成符号求导，再按完整有序参数
列表在单个显式精确点 `{Prime[i]/Prime[i+1]}` 赋值维数与全部运动学变量；不重试或换点，
因此只证明记录的 exact-point samples。

成功输出只有：

```wl
<|
  "matrices" -> <|x1 -> A1, x2 -> A2, ...|>,
  "validity" -> <|
    "scope" -> ..., "flat" -> True | False,
    "pairs" -> {<|"variables" -> {...}, "assignments" -> {...}, "zero" -> ...|>, ...}
  |>
|>
```

DE core 不读写文件、不运行 reducer、不生成 targets、不搜索算符，也不产生路径、hash、
provenance、sector 或 artifact 信息。

### 当前扇区 cut DE

```text
wolframscript -file mma/BuildSectorCutDE.wls INPUT.json FRESH_OUTPUT_DIR
```

`prepared_family` 必须显式携带 `regulator` 与 `dimension_rule`；例如两圈五点取
`eps` 与 `d -> 4 - 2 eps`，脚本不从符号名推断。它把 accepted prepared derivative
records 转成上述 affine matrices，以 `master_basis["masters"]` 的原序和
`ibp_reduction["rules"]` 调用 `BuildDifferentialEquations` 恰好一次。完整 DE
构造后才应用 `dimension_rule`。

requested sector 的正指标 bits 与每个 master 的传播子 bits 精确比较；匹配位置保持
resident/Kira 顺序，并同时用于取矩阵的行与列：

```wl
masterBits = SectorBits[#, propagatorSlots] & /@ masters;
positions = Flatten @ Position[masterBits, currentBits];
cutMatrices = (#[[positions, positions]] & /@ orderedMatrices);
```

因此同一 sector 内的 dots、numerators 与线性混合全部保留；列投影仅商掉 manifest
声明的 strict proper-subsector tails。`proper_subsectors` 明列这些 proper subsectors；`sector_boundaries` 是当前矩阵的
行号区间 `{{1,n}}`。
输出为：

```wl
<|
  "schema" -> "canon-neu/sector-basis/v1",
  "sector" -> <|"id" -> ..., "propagator_count" -> ...|>,
  "family_id" -> familyRef,
  "basis_id" -> basisRef <> "/sector-" <> ToString[sectorID],
  "basis" -> currentSectorMasters
|>
```

以及同 identity、同 basis 的 `canon-neu/sector-cut-de/v1`，其 ordered `variables`、显式
`regulator`、exact-rational `matrices` 与 `sector_boundaries` 遵循
`D[basis,variable[[i]]] == matrices[[i]].basis`。同一次调用还写
`canon-neu/ordered-master-de/v1`，保留完整 master basis、矩阵与 DEBuilder validity，供
`BUILD_FULL_DE` 直接复用。该产物只证明这个 quotient block 和
DEBuilder 记录的 exact validity scope；不证明 UT、canonical form、全局 IBP 完备性或
完整 canonical system。

### 原始 DE 的独立 targets

```wl
Get[FileNameJoin[{repoRoot,"mma","lib","CandidateIBPBridge.wl"}]];
targets = CANON`CandidateIBPBridge`MasterDerivativeTargets[masters, preparedDerivatives];
```

该函数只根据 masters 和已有 affine operators 生成所需导数积分，排除已在 master basis
中的项。将这些 targets 按 reducer 的积分文本格式交给 `ReduceIBP.wls`，即可为
`BUILD_CUT_DE` 提供不依赖 LS 候选的 `ibp_reduction`。
