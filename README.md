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

如果 `--check` 失败，Agent 应重新安装 launcher，并停止当前会话中的持续研究，等待全新 Local 会话加载 MCP。不得继续使用可能指向其他 checkout 的 tools。

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

准备、IBP 和 DE 是三个独立边界。生产准备程序由合作者提供；仓库中的
`PrepareFamily.wls` 只是 one-loop demo。科学脚本不接收 task/run envelope，Agent
只需在状态机分配的 workspace 中运行它们并登记结果文件。

IBP 的最小调用是：

```text
wolframscript -file mma/ReduceIBP.wls REQUEST.json RESULT.wl
```

请求给出 Kira executable、已准备 project、两个 job、topology、targets、fresh
output 和 argv options。结果只含 Kira 原序 masters 与完全回代 rules；没有版本
探测、hash、provenance、sector manifest 或状态副作用。

DE 只消费内存中的数学对象：

```wl
Get[FileNameJoin[{repoRoot, "mma", "lib", "DEBuilder.wl"}]];
result = BuildDifferentialEquations[family, masters, rules];
```

成功只返回 `matrices` 和 `validity`。master 先替换为单位向量，rule 右端只向量化
一次，然后逐行拼装。完整契约见 `INTERFACES.md`。

快速 DE 测试只需要 Wolfram：

```text
wolframscript -file tests/RunDEBuilderUnitTests.wls
```

IBP 与导数选择的离线测试为：

```text
wolframscript -file tests/RunKiraIBPUnitTests.wls
wolframscript -file tests/RunBaikovDerivativeUnitTests.wls
wolframscript -file tests/RunPentaboxFixtureUnitTests.wls
```

其中 IBP 使用临时 fake reducer，不需要 Kira，也不写入仓库。

两圈五点无质量 pentabox 的 Kira 约化仍是 opt-in live test：

```text
wolframscript -file tests/RunPentaboxIBPLiveTest.wls KIRA_EXECUTABLE FRESH_OUTPUT
```

该脚本固定传入 `--parallel=20`。普通测试不启动真实 Kira。发布分支不保存任何
live run 的日志、数据库、rules 或矩阵；需要科学验收时，应在 fresh、被忽略的
workspace 中运行，并用完整导数 targets 检查五个运动学方向的 DE 全链路。

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
