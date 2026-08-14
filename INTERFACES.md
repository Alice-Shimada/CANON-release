# Mathematica 脚本接口

这里定义接口，不定义算法、内部函数或实现细节。

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
| `PREPARE` | `canon-prepare-family` | `mma/PrepareFamily.wls` | `family_spec` | `prepared_family` |
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
