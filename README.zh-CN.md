<picture>
  <source media="(prefers-color-scheme: dark)" srcset="assets/branding/canon/candidate-b-gluon-axle/canon-icon-reverse.svg">
  <img src="assets/branding/canon/candidate-b-gluon-axle/canon-icon.svg" alt="CANON 的火炮标志，轮轴为胶子，炮弹为 ε" width="160" height="160">
</picture>

# CANON

[English](README.md)

**CANON 借助智能体构造和检验费曼积分的正则微分方程。**

从一个积分族出发，CANON 可以准备输入、做分部积分（IBP）约化、构造微分方程、寻找换基矩阵，并处理低扇区耦合。智能体根据已有结果选择和调整方法，Wolfram Language 程序负责代数计算和检验。

工作流和方法说明独立于具体的智能体平台和模型。需要跨轮次接续的研究使用本地 `statemng` MCP 服务和平台自身的子智能体。本版本已验证 Codex 集成，其他平台可按文档中的 MCP 接口接入，其原生集成仍待验证。

## 入门

- [安装与最低依赖](docs/installation.md)
- [智能体工作流与输入准备](docs/agent-workflow.md)
- [科学计算组件与自定义包](docs/components.md)
- [自动生成对运动学变量的导数](docs/physical-derivatives.md)
- [智能体如何选择下一步](skills/canon-workflow/SKILL.md)
- [已保存的算例](examples/README.md)
- [如何读取正则基、字母表和对数矩阵](docs/results.md)
- [Codex 平台配置](docs/hosts/codex.md)

配置好平台后，下面的请求会从随库的单圈积分族开始计算。

```text
在当前 CANON 工作目录中阅读 AGENTS.md 和 skills/canon-workflow/SKILL.md。
以 interfaces/family-spec.example.wl 为输入，创建名为 triangle-demo 的研究任务。
使用我提供的工具安装和资源预算，为这个积分族构造正则微分方程，返回积分基、
换基矩阵、微分方程、字母表和结果摘要。续做时复用已经验收的输入和检验结果。
```

[积分族定义示例](interfaces/family-spec.example.wl)及其 [PREPARE 请求](interfaces/prepare.example.json)使用随库提供的单圈算例。用户给出科学问题和可用资源，智能体处理任务命令和计算文件。

要查看已保存的三圈结果，可在仓库根目录启动新的 Wolfram 会话，运行下面的代码。

```wl
basis = Get["examples/three-loop/canonical-basis.wl"];
alphabet = Get["examples/three-loop/alphabet.wl"];
Atilde = Get["examples/three-loop/Atilde.wl"];
{Length[basis], alphabet, Dimensions[Atilde]}
```

## 计算范围

默认输入包括积分族定义、有序主积分列表和对应各变量的导数算符。约化程序的原生项目和导出设置由所选后端处理。智能体可按明确的约定准备这些输入。`PrepareFamily.wls` 负责绑定已提供的文件。从任意一组传播子开始时，仍需给出相应的物理定义。已有的主积分、约化规则和微分方程可直接作为输入。详见[输入指南](docs/agent-workflow.md)。

各步骤由[组件清单](components/default.json)选择。自定义包可以替换其中任意步骤，同时遵守已发布的科学输入和输出约定。默认工作流按下面的顺序执行。

```text
PREPARE → DISCOVER → IBP 约化 → 审核约化结果 → 按扇区排列的微分方程
  → 提出当前扇区对角块的候选变换 → CHECK_CORE → 扩充已有积分基并处理低扇区耦合
  → CHECK_CANONICAL → COMMIT_SECTOR → 下一扇区 → FINAL_CHECK
```

[IBP 约化审核](INTERFACES.md#ibp-reduction-audit)用独立声明的目标积分、主积分和系数符号检查整套约化规则的结构与覆盖范围。`BUILD_CUT_DE` 和候选积分约化会先执行审核。外部导入或待交付的约化也可以用 `mma/CheckIBPReduction.wls` 单独检查。生成程序把审核记录与最终文件绑定。后续步骤核对文件身份和当前所需的积分，复用已有审核结果，再进行数学检验。

从积分族寻找均匀超越权重（UT）基或正则基时，先根据几何结构和已有检验选择一小组候选。可以给个别传播子升幂并选择归一化，构造有几何依据的 Gram 行列式分子，或用 DlogBasis-refine 在有限范围内搜索。候选积分随后经过 IBP 约化，并接受对角块和完整系统的检验。

已有微分方程时，也可以直接构造换基变换。CANONICA 提供有理变换，Libra 支持单变量变换，也可以沿指定的有限个多变量方向依次变换，最后对各方向的方程同时提取维数正则化参数 ε 的因子。两种方法的结果都要通过同样的检验。若已有归一化明确的 UT 种子、给定的字母表和有理的单变量切割，可显式指定 `SEARCH_CORE`，通过 `methods/initial/run.wls` 用 [INITIAL](methods/initial/SKILL.md) 构造对角块候选。随库也保留了 INITIAL 官方固定梯图的[参考验证与兼容接口](methods/initial/reference/README.md)。

可以在已有步骤中启用 Libra 的归一化选项，或调整 CANONICA 的有限 T/D 待定式。低扇区耦合的计算可以从检查点续做。[工作流说明](skills/canon-workflow/SKILL.md)介绍如何根据结果更换方法、记录可复用的经验。[方法说明](methods/README.md)列出了各方法的适用条件。寻找积分基时可按证据选择分子和升幂的组合。

最终检验通过后，CANON 返回所声明积分空间和 dlog 字母表下的正则基与微分方程。检验包括精确的换基恒等式、符号平坦性、ε 因子化，以及各变量共用的常数留数矩阵。处理低扇区耦合的程序可以从方程推断极点因子和支持类型的二次根式字母。也可以直接提供字母表，用精确的 Wolfram 表达式声明代数字母。有限搜索失败只说明在所选范围内没有找到解。

一般积分族的正则基、任意代数字母的自动发现、主积分的完备性和物理边界常数都需要各自的依据。仅凭正则微分方程也无法确定所有 UT 归一化。

## 算例

AI4UT 稿件的三个主要算例均以可直接读取的 Wolfram 表达式分发。每个积分族目录的三个文件分别是 `canonical-basis.wl`、`alphabet.wl` 和 `Atilde.wl`。

| 积分族 | 主积分数 / 扇区数 | 变量数 / 实际出现的字母数 |
| --- | --- | --- |
| [含一个内线质量的离壳双盒](examples/README.md#off-shell-double-box) | 37 / 24 | 5 / 21 |
| [无质量两圈五点 pentabox](examples/README.md#massless-pentabox) | 61 / 46 | 5 / 24 |
| [三圈积分族](examples/README.md#three-loop-family) | 40 / 28 | 2 / 3 |

矩阵满足 `d J = eps d Atilde . J`，其中 `Atilde = Sum[R[a] Log[W[a]], {a, Length[alphabet]}]`，`W[a] = alphabet[[a]]`。行列顺序与积分基一致。[算例说明](examples/README.md)给出积分、运动学和归一化的定义。[结果说明](docs/results.md)给出读取方法。

三个算例都已有 `FINAL_CHECK: PASS / ALL_PASS` 记录，覆盖精确的全系统换基恒等式、符号平坦性和共同的常数留数。发布时导出这些已保存的表达式，并核对重新读取的结果。

## 接口与扩展

数学计算位于 `mma/`，候选构造方法位于 `methods/`，各步骤的操作说明位于 `skills/`。[接口文档](INTERFACES.md)定义了请求和结果的格式。运行程序按请求中的 `step` 选择对应组件。下面的命令单独执行一个无状态步骤，准备单圈算例的输入。

```sh
python3 run_step.py interfaces/prepare.example.json runs/triangle-prepare
```

每次调用应使用新的输出目录。相对路径以声明它的 JSON 文件为基准，积分族资源的路径以积分族定义文件为基准。工具入口和线程数通过文档规定的任务参数或环境变量提供。用 `--components /path/to/package/components.json` 选择自定义组件包。在 `SEARCH_CORE` 步骤中，可用 `--method libra` 等参数选择方法。

工作流用数学输入和 JSON 设置组合这些接口。`PREPARE_REQUEST` 把上一步的输出绑定到下一步的请求，`PREPARE_REDUCTION_TARGETS` 为主积分的符号导数准备约化目标。后端的初始化、求解和导出程序可以按执行顺序列成参数数组。详见[组件组合](docs/components.md#binding-requests-without-a-glue-program)和[标量 JSON 工作流示例](interfaces/examples/scalar-workflow/README.md)。

`--describe` 显示选定的命令与说明。可重复使用 `--components` 组合多个包，或通过清单中的相对 `extends` 列表继承配置，`--defaults` 恢复默认选择。程序在每次调用时读取包，包可以放在仓库之外。包的 `workflow` 说明可以定义其他流程及其完成条件。

[参数化组件](components/parameterization/README.md)支持自定义变量和标量积坐标，包括动量扭量坐标。参数化和约化后端可独立选择。配置文件可通过各步骤的 `from` 分别选择 `DISCOVER`、`REDUCE_IBP` 和 `BUILD_CUT_DE` 的提供方。参见[混用约化后端的配置](components/profiles/mixed-reducers.json)和 [Kira 适配器](components/reducers/kira/README.md)。Blade、FIRE7 和 NeatIBP 的适配包分别说明了各自的原生执行和导出要求。

可选的 [dlog 重构](components/dlog-reconstruction/README.md)使用调用方提供的采样数据。[本地执行与通知](components/local-jobs/README.md)可以按需启用。[批量扇区切片](components/batch-sector-cuts/README.md)复用已有的有序微分方程。[构造过程中的精确运算](docs/construction-arithmetic.md)和 [FLINT 最终检验](components/flint-final/README.md)提供不同的精确代数实现，相应的原生程序需单独安装。工作流也可直接使用默认组件。

智能体负责规划和验收，`statemng` 在 `.state-management/<task-name>/` 中保存研究任务及其产物。方法选择由智能体完成。详见 [AGENTS.md](AGENTS.md) 和[持续研究说明](.agents/skills/persistent-scientific-research/SKILL.md)。

[外部源码目录](external/README.md)收录各包的源码快照与许可证，[版本清单](external/sources.json)给出具体提交号。按所选计算流程安装相应程序即可。

## 引用与开发

作者按姓氏字母顺序排列为 Dongshan Jian、Yuanche Liu、Yanqing Ma、Boxuan Shi、Yu Wu、Zihao Wu 和 Yang Zhang。

引用 CANON 时请使用 [CITATION.cff](CITATION.cff)，并注明所用版本或提交号。作者标识和方法文献见 [CREDITS.md](CREDITS.md)。CANON 自有代码和文档使用 [MIT 许可证](LICENSE)，外部组件各自采用原有许可证。

报告问题和选择相应的检验方法请参阅[贡献指南](CONTRIBUTING.md)。本发布版的变更见[更新记录](CHANGELOG.md)。算例目录供读取已保存的结果，自动化测试另行运行。
