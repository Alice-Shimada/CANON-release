# CANON_neu

这是一个 clean-slate、agent-facing 的科研 workflow 框架。唯一状态机是
[`workflow.py`](workflow.py)；Mathematica 侧没有状态机。

当前完成的是框架层：

- Python workflow 已实现完整状态转移、sector 排序、任务板、artifact 路由和 subagent gate；
- 所有 `.wls` 只有输入/输出契约，没有科学实现；
- null test 用模拟结果文件验证整个 workflow，不运行 Mathematica。

架构与边界见 [`ARCHITECTURE.md`](ARCHITECTURE.md)，脚本协议见
[`INTERFACES.md`](INTERFACES.md)。

## 运行 null test

```bash
cd /home/liuyuanche/Program/CANON_neu
python3 -m unittest -v tests.test_null_workflow
```

## 初始化真实项目

复制并修改 `project.example.json`，然后：

```bash
python3 workflow.py init project.json
```

命令会打印生成的 `state.json` 路径。之后主 agent 的最小循环是：

```bash
python3 workflow.py status <state.json>
python3 workflow.py next <state.json>
python3 workflow.py start <state.json> <task-id> --agent root
```

如果当前任务要求 subagent：

```bash
python3 workflow.py delegate <state.json> <task-id> \
  --agent root \
  --subagent candidate-1 \
  --role candidate_route \
  --script methods/dlogbasis/run.wls

python3 workflow.py subreport <state.json> <task-id> <script-result.json> \
  --subagent candidate-1
```

如果主 agent 采用这个 subagent 的路线，同一个 `script-result.json` 可以直接
再次提交为主结果；否则主 agent 按 `next` 给出的接口生成另一个标准结果：

```bash
python3 workflow.py report <state.json> <task-id> <result.json>
```

再次查询 `status` 或 `next`，继续到 `DONE`。

## 当前刻意没有实现

所有 Mathematica、Kira、Blade、DlogBasis、Gram-Baikov、MethodCard、IBP、DE、UT/canonical 科学逻辑都为空。实现这些步骤时，保持已有 JSON I/O 不变即可；不要把计算或第二个状态机放进 Python。
