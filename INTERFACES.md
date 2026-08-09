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
相对于 `result.json` 所在目录；状态机会把它规范化为绝对路径，但不会检查或解析文件内容。

## 各步骤 SKILL、payload 与输出

| step | SKILL | 脚本 | payload keys | PASS artifact keys |
|---|---|---|---|---|
| `PREPARE` | `canon-prepare-family` | `mma/PrepareFamily.wls` | `family_spec` | `prepared_family` |
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

状态机对普通科学信息保持不透明。只有 `status` 和表中必要的分流码会影响转移。

## Subagent 结果

subagent 与主 agent 使用同一个 `canon-neu/script-result/v1`，不再定义第二套
结果协议。subagent 身份、角色和被指定的脚本来自 `delegate` 记录；主 agent
用 `subreport` 登记标准脚本结果后，delegation gate 才可能满足。subagent
仍然不能修改 `state.json`。主 agent 若采用该路线，可以把同一个结果文件先
交给 `subreport`，再交给 `report`。
