# CANON

直接向 Agent 提出科研目标。对于需要多步骤推进的研究，Agent 会自动使用项目内部的 `statemng` 持续研究状态管理基础设施，并负责初始化、恢复、任务派发、结果审查和后续规划。用户不需要了解或调用状态管理 CLI。

## 当前可用范围

当前已经完成 Codex 接入，使用条件为：

- macOS 或 Linux；
- Python 3.10 或更高版本；
- Codex 将本仓库识别为 trusted project；
- 使用项目原始 checkout 的 Local 会话，不使用 Worktree 会话执行持续研究。

OpenCode、Claude Code 和 Hermes 的接入尚未实现。Windows 原生环境也尚未适配。

## 首次准备

### 用户操作

1. 在 Codex Desktop 中打开本仓库，按 Codex 的原生提示信任项目。
2. 新建一个 **Local** 会话。即使机器本地 launcher 尚未安装，该会话也应当可以正常创建。
3. 将下面的指令交给 Agent：

```text
请为当前 CANON checkout 完成 statemng Codex 接入准备：

1. 确认当前是 Local 会话，并确认 .git 是目录、git-dir 与 common-dir 都是 .git。
2. 由你运行 state-management/adapters/codex/install_launcher.py，安装机器本地 launcher。
3. 由你运行 state-management/adapters/codex/install_launcher.py --check，确认 launcher 指向当前 checkout。
4. 不要运行 statemng CLI，不要创建或修改任何研究状态。
5. 报告检查结果，并明确告诉我是否需要新建 Local 会话。
```

4. 如果 Codex 请求允许 Agent 写入 `$HOME/.codex/statemng/CANON/mcp`，批准这一明确路径的操作；不需要授予更宽泛的文件写入权限。
5. 安装完成后，完全退出并重新打开 Codex Desktop，再在本仓库中新建一个 Local 会话。MCP tool surface 在会话初始化时确定，安装 launcher 的旧会话不会热加载 `statemng` tools。

用户不应手动运行 `statemng` CLI、直接启动 `mcp_server.py`，也不应直接修改 `.state-management/` 中的 JSON。

### Agent 操作

接入 Agent 必须在仓库根目录执行：

```text
state-management/adapters/codex/install_launcher.py
state-management/adapters/codex/install_launcher.py --check
```

安装器会将当前 checkout 和当前 Python 的绝对路径写入：

```text
$HOME/.codex/statemng/CANON/mcp
```

该 launcher 是机器本地文件，不属于仓库，也不保存研究状态。仓库中没有用户个人目录的硬编码；其他用户机器上的接入 Agent 执行安装器后，会得到适合该机器的 launcher。

如果 `--check` 失败，Agent 应重新安装 launcher，并停止当前会话中的持续研究，等待全新 Local 会话加载 MCP。不得继续使用可能指向其他 checkout 的 tools。安装程序同时准备当前 checkout 专用的机器本地授权目录；它不保存研究结果，也不会写入 Git。

## MCP 自检

在重新打开的 Local 会话中，将下面的指令交给 Agent：

```text
请只做 statemng MCP 接入自检，不开展研究，也不修改任何研究状态：

1. 确认当前是 Codex Local 会话。
2. 由你运行 state-management/adapters/codex/install_launcher.py --check。
3. 确认 statemng_project_list 位于你的 MCP tool surface。
4. 必须通过 MCP 调用 statemng_project_list 一次，禁止用 shell、statemng CLI 或直接运行 mcp_server.py 代替。
5. 报告 launcher 校验结果、MCP tool 调用是否成功，以及 tool 返回的完整 structured result。
```

自检成功必须同时满足：

- 会话正常创建，没有 `required MCP servers failed to initialize`；
- launcher 校验返回 `"ok": true`；
- Agent 实际产生 `statemng_project_list` 的 MCP tool call；
- tool 返回 `isError: false`，且 `structuredContent.ok` 为 `true`。

`task_names` 为空只表示尚未创建持续研究任务，不是错误。Codex 显示的完整工具名可能是 `mcp__statemng__statemng_project_list`；前缀是宿主增加的命名空间。

## 正常使用

准备完成后，用户只需在 Local 会话中用自然语言提出科研目标。对于多步骤科研任务，Agent 必须加载 `persistent-scientific-research` Skill，并通过 `statemng` MCP tools 完成所有状态操作。

研究状态保存在：

```text
.state-management/[TASK_NAME]/
```

不同总体任务彼此隔离。已有任务由 Agent 恢复，不存在的任务由 Agent 初始化；用户不需要选择内部命令或管理任务状态。

`.state-management/` 已加入 `.gitignore`。其中的状态、run workspace 和 artifact 均保留在当前项目本地，不随 Git 提交。

## 科学接口

科学输入是 trusted family specification、Kira project/jobs、有序 masters 和逐变量导数算符。
`propagator_slots` 声明实际传播子在完整指标列表中的位置，`regulator` 与 `dimension_rule`
显式给出。流程不限制圈数、传播子个数、ISP 位置、sector rank 或运动学变量个数；仍以
给定 masters 和 IBP 约化为输入，不额外证明 master 完备性或识别函数类别。

主 Agent 在现有 `statemng` 任务中按以下顺序调用无状态科学接口：

1. `PrepareFamily.wls` 绑定输入；`DiscoverSectors.wls` 从 masters 生成 sector mask、rank
   和 resident order，不需要文献 sector manifest。
2. 用 `MasterDerivativeTargets[masters, preparedDerivatives]` 生成原始 DE 所需 targets，
   交给 `ReduceIBP.wls`。`BuildSectorCutDE.wls` 从 `ibp_reduction` 构造一次完整
   `ordered_master_de`；后续 sector 用 `SliceSectorCutDE.wls` 复用它。
3. 对每个 sector，直接选择 CANONICA 的多变量有理 DE 方法或 Libra 的单变量方法；
   也可用 DlogBasis-refine 提出积分候选，经 `ReduceCandidateIBP.wls` 约化，再由
   `RouteCoreCandidates.wls` 选择独立行基及单行替换。原始 DE 路线不以 LS 候选成功为前提。
4. `CheckSectorCore.wls` 通过后，`BuildFullSectorDE.wls` 将同一候选行表示嵌入完整 prefix。
   `SolveTail.wls` 使用 CANONICA 的公开 `TransformOffDiagonalBlock` 和
   `TransformDlogToEpsForm` 求新的非零 subsector 修正与 epsilon 归一化。
5. `CheckCanonical.wls` 重算完整 gauge；`CommitSector.wls` 累计完整变换，包括求解所需的
   lower-prefix 归一化。`NextSector.wls` 从 manifest 与 trace 计算下一项。
6. 全部 sector 完成后，`CheckFullSystem.wls` 从原始 ordered DE 和累计变换重算全局 gauge，
   联立所有方向的常数留数。只有 `ALL_PASS` 输出 `canonical_basis` 与 `canonical_de`。

`BUILD_FULL_DE` 的 `declared_alphabet` 可为 `null`，表示从联络的 pole factors 生成字母候选；
也可提供含精确代数表达式的 `letters`。根式以 Wolfram 原生表达式表示，例如
`x + Sqrt[1+x^2]`；求导、化简和 shared-residue solve 使用同一表达式，不要求先有理化。
这支持声明代数候选的传递与判定，不承诺自动发现所有代数字母。CANONICA 搜索仍有其有理
变换的算法范围；超出某次搜索空间只表示尚未找到，不表示不存在 canonical basis。

科学脚本继续使用：

```text
wolframscript -file mma/PrepareFamily.wls INPUT.json OUTPUT_DIR
wolframscript -file mma/ReduceIBP.wls REQUEST.json RESULT.wl
```

候选 IBP 桥与内存 DE API 的完整调用见 `INTERFACES.md`。所有运行输出放在调用方 workspace。
程序信任所声明的科学输入与工具入口；不增加版本白名单、重复检查或自动重试。

针对当前科学接口的测试：

```text
wolframscript -file tests/RunPrepareDiscoverUnitTests.wls PENTABOX_RESOURCE_DIRECTORY
wolframscript -file tests/RunDEBuilderUnitTests.wls
wolframscript -file tests/RunSectorCutDEUnitTests.wls
wolframscript -file tests/RunCandidateIBPBridgeUnitTests.wls
wolframscript -file tests/RunCoreCandidateRouteUnitTests.wls
wolframscript -file tests/RunFullSectorTailUnitTests.wls CANONICA_ENTRY
wolframscript -file tests/RunCanonicalCommitUnitTests.wls
wolframscript -file tests/RunFullSystemUnitTests.wls
```

真实积分链路使用显式提供的 DlogBasis、FiniteFlow、Kira 和正常安装的 Fermat：

```text
wolframscript -file tests/RunEndToEndWorkflowLiveTest.wls DLOGBASIS_ENTRY FINITEFLOW_ENTRY KIRA_EXECUTABLE FRESH_OUTPUT
```

两变量 tail 测试覆盖非零 coupling 和 lower epsilon 归一化；最终检查测试覆盖显式代数字母。
真实一圈回归与这些有限测试均不构成任意 MPL family 的完备性证明，也不单独证明 UT。

## 维护与故障处理

- checkout 路径、Python 路径或当前主要 checkout 发生变化后，Agent 必须重新安装并校验 launcher，然后使用全新 Local 会话。
- 每个用户的 `$HOME/.codex/statemng/CANON/mcp` 同时只指向一个 CANON checkout；首次状态调用前的 `--check` 用于防止写入另一 checkout。
- Worktree 会话仍可处理普通任务，但不得执行持续研究。
- `statemng` MCP 启动失败时，Codex 会话应保持可用；Agent 必须停止持续研究并报告接入错误，不得绕过 MCP 改用 CLI。

修改 Codex 接入或状态管理代码后，可从 `state-management/` 目录运行完整测试：

```text
python3 -m unittest discover -s tests -p 'test_*.py' -v
```

设计文档：

- [`跨通用 Agent 的持续研究状态管理基础设施设计方案.md`](docs/state-management/跨通用%20Agent%20的持续研究状态管理基础设施设计方案.md)
- [`持续研究状态管理的 Agent 接入补充方案.md`](docs/state-management/持续研究状态管理的%20Agent%20接入补充方案.md)
