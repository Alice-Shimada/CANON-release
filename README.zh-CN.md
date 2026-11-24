<picture>
  <source media="(prefers-color-scheme: dark)" srcset="assets/branding/canon/candidate-b-gluon-axle/canon-icon-reverse.svg">
  <img src="assets/branding/canon/candidate-b-gluon-axle/canon-icon.svg" alt="CANON 的火炮标志，轮轴为胶子，炮弹为 ε" width="160" height="160">
</picture>

# CANON

[English](README.md)

CANON 用 AI 智能体为费曼积分寻找正则基。给定一组主积分 $I$，目标是找到换基矩阵 $T$，使新基 $J=T^{-1}I$ 满足

$$
\mathrm{d}J = \epsilon \left(\sum_a R_a\,\mathrm{d}\log W_a\right) J .
$$

其中，字母 $W_a$ 是运动学变量的函数，留数矩阵 $R_a$ 是常数矩阵，$\epsilon$ 是维数正规化参数。给定边界值后，就可以从这个方程逐阶求出主积分的 $\epsilon$ 展开。

CANON 按扇区寻找正则基。一组积分在本扇区内给出了正则方程，加回传播子更少的低扇区后，这组基仍可能需要调整。智能体可以尝试不同的积分分子，也可以直接对微分方程换基。独立的代数程序会把最终的换基矩阵代回原方程，对每个运动学变量分别检验。

## 读取论文算例

论文中三个算例的正则基、字母表和对数矩阵都在仓库里，可以直接用 Wolfram Language 读取。

| 积分族 | 主积分数 | 扇区数 | 运动学变量数 | 实际出现的字母数 |
| --- | ---: | ---: | ---: | ---: |
| [含一条有质量内线的离壳双盒](examples/double-box/) | 37 | 24 | 5 | 21 |
| [无质量两圈五点 pentabox](examples/pentabox/) | 61 | 46 | 5 | 24 |
| [三圈积分族](examples/three-loop/) | 40 | 28 | 2 | 3 |

```sh
git clone https://github.com/Alice-Shimada/CANON-release.git
cd CANON-release
```

要查看三圈结果，可以在仓库根目录启动一个新的 Wolfram 会话，读入这三个文件。

```wl
basis = Get["examples/three-loop/canonical-basis.wl"];
letters = Get["examples/three-loop/alphabet.wl"];
aTilde = Get["examples/three-loop/Atilde.wl"];

{Length[basis], letters, Dimensions[aTilde]}
(* {40, {s, u, 1 - u}, {40, 40}} *)

Coefficient[aTilde, Log[W[1]]] === -3 IdentityMatrix[Length[basis]]
(* True *)
```

`Atilde.wl` 保存的是 $\sum_a R_a \log W_a$。这里 `W[1]` 代表 $s$，它的对数项系数是单位矩阵的 $-3$ 倍。因此，在 $u$ 固定时，每个基积分都满足 $s\,\partial_s J_i=-3\epsilon J_i$。各积分族的传播子顺序和归一化约定见[算例说明](examples/README.md)。

## 用 CANON 计算一个积分族

默认配置需要 Python 3.10 或更高版本，以及带 `wolframscript` 的 Wolfram Language。如果需要做分部积分（IBP）约化，还要配置 Kira 等约化程序。使用仓库自带的 Codex 配置时，请在 Local 会话中打开仓库，按指南完成设置。CANON 会保存已完成的扇区，下次可以接着算。[安装说明](docs/installation.md) · [Codex 配置](docs/hosts/codex.md)

第一次运行可以用随库的一圈三角形积分族。第 5 扇区只含其中两个传播子，可以直接把下面的请求发给智能体。

> 请用 `interfaces/prepare.example.json` 为三角形积分族的第 5 扇区寻找正则基。任务名用 `triangle-sector-5-example`，主积分取输入中给定的 `tri[1,0,1]`，维数取 `d = 2 - 2 eps`。约化用一个线程，最多算 30 分钟。请附上 PDF 报告。如果基和方程已通过检验，也请一并给出。

换成自己的积分族时，请给出传播子、运动学关系、时空维数、要计算的扇区和可用的计算资源。如果已有微分方程，可以直接提供矩阵，并注明主积分和变量的排列顺序。[输入说明](docs/agent-workflow.md#what-to-provide) · [可用方法](methods/README.md)

也可以在命令行用 `python3 run_step.py INPUT.json OUTPUT_DIR` 单独运行某一步。[命令行接口](INTERFACES.md#common-invocation)

计算成功后，`canonical-basis.wl` 给出正则基和换基矩阵，`canonical-de.wl` 给出微分方程的矩阵、字母表和留数矩阵。[输出文件说明](docs/results.md)

即使还有扇区没解出，智能体也会返回 PDF 报告。报告里每个扇区都有一条记录，写明试过哪些方法、积分如何选取和归一化，以及通过了哪些检验。每种实际用到的方法和软件包都附有 GitHub 仓库链接或原始论文出处。[报告要求](skills/canon-workflow/SKILL.md#export-the-final-pdf-report)

## 作者与引用

Dongshan Jian、Yuanche Liu、Yanqing Ma、Boxuan Shi、Yu Wu、Zihao Wu、Yang Zhang。

引用 CANON 时，请注明所用版本或提交号。[软件引用信息](CITATION.cff) · [方法与文献](CREDITS.md)

CANON 采用 MIT 许可证，随库分发的外部软件包各自沿用原许可证。[CANON 许可证](LICENSE) · [外部软件包](external/README.md)
