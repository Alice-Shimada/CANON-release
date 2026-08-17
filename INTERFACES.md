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
| `PREPARE` | `canon-prepare-family` | 合作者生产入口；仓库 demo 见文末直接接口 | `family_spec` | `prepared_family` |
| `PROPOSE_INTEGRAL_CANDIDATES` | method card | `methods/dlogbasis/run.wls` or `methods/gram-baikov/run.wls` (interface only) | `family_identity`, `sector_identity`, `prepared_family`, `dimension_policy`, `numerator_or_power_counting_policy`, `candidate_budget`, `candidate_unit`, `normalization_policy`, `method_options` | `integral_candidates` |
| `DISCOVER` | `canon-discover-sectors` | `mma/DiscoverSectors.wls` | `prepared_family` | `sector_manifest`, `master_basis` |
| `BUILD_CUT_DE` | `canon-build-cut-de` | `mma/BuildSectorCutDE.wls` | `prepared_family`, `master_basis`, `sector_manifest` | `sector_basis`, `sector_cut_de` |
| `SEARCH_CORE` | `canon-search-core` | `methods/*/run.wls` | `prepared_family`, `sector_basis`, `sector_cut_de`, `method_options` | `core_candidates` |
| `CHECK_CORE` | `canon-check-core` | `mma/CheckSectorCore.wls` | `sector_basis`, `sector_cut_de`, `core_candidates` | `core_transform` |
| `BUILD_FULL_DE` | `canon-build-full-de` | `mma/BuildFullSectorDE.wls` | `prepared_family`, `master_basis`, `sector_manifest`, `core_transform`, `accepted_prefix` | `full_sector_de` |
| `SOLVE_TAIL` | `canon-solve-tail` | `mma/SolveTail.wls` | `full_sector_de`, `core_transform`, `accepted_prefix`, `tail_options` | `sector_transform` |
| `CHECK_CANONICAL` | `canon-check-canonical` | `mma/CheckCanonical.wls` | `full_sector_de`, `sector_transform`, `accepted_prefix` | `canonical_sector_de` |
| `COMMIT_SECTOR` | `canon-commit-sector` | `mma/CommitSector.wls` | `previous_accepted_prefix`, `sector_basis`, `sector_transform`, `canonical_sector_de` | `accepted_prefix` |
| `FINAL_CHECK` | `canon-final-check` | `mma/CheckFullSystem.wls` | `prepared_family`, `master_basis`, `sector_manifest`, `accepted_prefix` | `canonical_basis`, `canonical_de` |

这些 SKILL 当前只有 frontmatter 和 HTML 注释中的职责/I/O 提示，没有科学实现。

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

脚本只负责报告 metadata；排序由 Python 完成。

## 最小结果码

`PROPOSE_INTEGRAL_CANDIDATES` 位于 IBP reduction、master-basis ordering、cut DE 和
`SEARCH_CORE` 之前。成功时只能发布 `PROVISIONAL/INTEGRAL_CANDIDATES`；provider
明确不覆盖输入或已穷尽其声明方法时分别发布 `INCONCLUSIVE/OUT_OF_SCOPE` 或
`INCONCLUSIVE/METHOD_EXHAUSTED`；输入、工具或计算故障必须使用具体 `ERROR/*` code，
不能使用笼统的 `ERROR/ERROR`。这个 stage 不能发布 `PASS`、`FAIL`、UT 或 canonical claim。

`SEARCH_CORE` 是 provider 步骤，不使用下表的 authoritative `PASS`/`FAIL`：候选已生成时
发布 `PROVISIONAL/CANDIDATE_TRANSFORMATION`，范围或方法未建立时发布
`INCONCLUSIVE/OUT_OF_SCOPE` 或 `INCONCLUSIVE/METHOD_EXHAUSTED`，输入或工具故障发布
具体 `ERROR/*`。其余 method-card provider 同样遵守 `methods/README.md` 的单一 typed
协议。

| step | PASS | 可恢复 FAIL |
|---|---|---|
| `PREPARE` | `OK` | 无 |
| `DISCOVER` | `SECTORS_READY` | 无 |
| `BUILD_CUT_DE` | `OK` | 无 |
| `CHECK_CORE` | `CORE_PASS` | `CORE_FAIL` |
| `BUILD_FULL_DE` | `OK` | 无 |
| `SOLVE_TAIL` | `TAIL_READY` | `TAIL_UNSOLVED` |
| `CHECK_CANONICAL` | `CANONICAL_PASS` | `CORE_FAIL`, `TAIL_FAIL` |
| `COMMIT_SECTOR` | `OK` | 无 |
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
  "candidate_unit" -> "INDIVIDUAL_G_INTEGRAL" | "NORMALIZED_LINEAR_COMBINATION",
  "normalization_policy" -> <|"convention" -> "...", "factors" -> <|...|>|>,
  "candidates" -> {
    <|
      "candidate_id" -> "provider-stable-candidate-id",
      "exact_definition" -> HoldComplete[G[family, {...}]] | HoldComplete[...],
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
另一个。下游 reduction adapter 必须保留 `candidate_id` 与 `exact_definition` 的对应关系，
但该 adapter 不属于本合同。

## Agent 与状态边界

`canon-neu/script-result/v1` 只描述 method-card 调用结果，不定义持久研究状态或 agent
delegation。当前唯一状态权限与交接协议由根目录 `AGENTS.md` 和 `README.md` 的 `statemng`
规则定义；本接口不创建第二套状态机。

## 直接 IBP/DE 接口

以下程序只处理数学输入和普通文件。调用它们的 Agent 负责在已分配 workspace 中运行，
并通过 `statemng` 登记需要保留的结果。

### 准备 demo

生产准备程序由合作者提供。仓库只保留一个可替换 demo：

```text
wolframscript -file mma/PrepareFamily.wls FRESH_OUTPUT_DIR
```

它检查 Wolfram 14+，将内置 one-loop box fixture 复制到 fresh output，并只打印：

```wl
<|"project" -> outputDirectory, "family" -> preparedFamilyFile|>
```

该 demo 不接收自然语言、不选择或探测 reducer，也不生成 method-card 或状态 envelope。

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
| `options` | 逐项传给 Kira 的 argv，例如 `--parallel=20` |

示例见 `interfaces/ibp-request.example.json`。适配器复制 project、依次运行两个 job，
读取有序 `masters.final` 与导出 rules，并验证每个 target 都是 master 或 rule 左端、
所有 rule 右端只含 master、积分 head/arity 一致，以及外部 Wolfram 文本在
`HoldComplete` 下只含允许语法。

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
  "parameters" -> {eps, x1, x2, ...},
  "operators" -> <|x1 -> C1, x2 -> C2, ...|>
|>
```

若积分有 `m` 个指标，每个 `Cx` 的维数必须为 `m x (m+1)`，表示
`d D_i/dx = Cx[[i,1]] + Sum_j Cx[[i,j+1]] D_j`。`masters` 固定矩阵顺序；
immediate `rules` 必须已经完全回代到这些 masters，所有系数属于声明的有理函数域。

矩阵采用 `D[masters,x] == A_x . masters`。二变量系统检查全局精确曲率；多变量系统
对每一变量对保留为符号，并为 spectator 记录确定性的精确有理赋值，因此只证明返回的
bivariate slices。

成功输出只有：

```wl
<|
  "matrices" -> <|x1 -> A1, x2 -> A2, ...|>,
  "validity" -> <|"scope" -> ..., "pairs" -> ...|>
|>
```

DE core 不读写文件、不运行 reducer、不生成 targets、不搜索算符，也不产生路径、hash、
provenance、sector 或 artifact 信息。
