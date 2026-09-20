# CANON 静态检查、局部试跑与科学成熟度评估

日期：2026-09-08。检查基线为 `demo` 的
`de29b1b20550215f9285ed1fc8adf061b081a85c`，结论包含本轮工作区修正。

**结论：可用于人工明确输入、控制搜索范围的简单 MPL family 的 canonical-basis 研究。**
现有实现具备实际候选、IBP、DE、前缀修正和最终验证链路；尚不能作为任意 family 的
全自动 UT 基发现器。本轮发现并修正了一个会错误通过最终检查的平坦性漏洞。

## 1. 静态检查与代码精简

检查了 CANON 自有的 29 个科学入口/库、相关接口与 skill；20 个 Python 文件通过 AST
解析，86 个 Wolfram 源码、脚本和夹具通过语法检查。Python 静态引用扫描中的两个
表面未使用导入实际由 `__all__` 对外导出，予以保留。外部包按现有来源提交核对其
方法边界，没有修改上游源码。

生产代码净减少 69 行，测试和说明另计：

| 位置 | 修改与保留的科学条件 |
| --- | --- |
| `methods/route-prepared-basis/run.wls` | `PreparedBasisRoute` 已验证输入，去掉调用前第二遍同样校验；保留失败字段和错误类别 |
| `mma/lib/MethodCardCore.wl` | 去掉由 `alternatives_remaining == Length[unattempted]` 已蕴含的候选池重复条件；严格单变量修复前缀只运行一次含 ε 分离要求的 dlog 检查 |
| `methods/canonica/run.wls` | CANON 已作完整符号曲率检验，去掉同一输入的第二次 CANONICA 可积性检查 |
| `mma/BuildSectorCutDE.wls` | 去掉对仓库内部 DEBuilder 固定生成的 validity 记录逐字段防御性检查；保留实际 DE 的维数、有理性与未闭合积分检查 |
| `mma/CheckCanonical.wls` | 完整块三角系统通过后，其对角块的平坦性和 dlog 性随之成立，直接复用结果；完整系统失败时仍独立检查当前块，以区分 `CORE_FAIL` 和 `TAIL_FAIL` |
| `mma/CheckStructuredRepair.wls` | 去掉单变量中恒为空的曲率循环和重复 ε 检查；将 ε 分离标志改为真正检查 `B/eps` 不含 `eps` |

保留了外部输入身份/基顺序、变换可逆性、精确 gauge、共享常数留数、正式文件不可覆盖
以及 provider/checker 权限边界。它们防止接受错误的科学对象。跨 provider 与 checker
的独立验证，也不能按同一进程内的重复代码删除。已有单变量旧导数输入兼容分支仍有
明确接口和回归用例，本轮没有移除这一实际能力。

## 2. 发现并修正的平坦性漏洞

采用仓库约定

\[
\partial_i I=A_i I,\qquad I=TJ,\qquad
B_i=T^{-1}(A_iT-\partial_iT).
\]

所需可积性是关于全部运动学变量的恒等式

\[
F_{ij}=\partial_i B_j-\partial_j B_i+B_jB_i-B_iB_j=0.
\]

这对应 [Henn 2013，式 (2)–(6)](https://arxiv.org/html/1304.1806v2#S1) 与
[Libra，式 (1)–(4)](https://arxiv.org/html/2012.00279v1#S2) 的联络约定。

旧 `FlatConnectionQ` 只在固定有理点求值。以下是本轮构造的反例，记 `Eij` 为矩阵单位：

\[
f(y)=1+(y-3/5)^2,\qquad
B_x=\epsilon E_{12}/x,\qquad B_y=\epsilon E_{21} f'(y)/f(y).
\]

它已经具有字母表 `{x,f(y)}` 和常数留数 `E12,E21`，但

\[
F_{xy}=\epsilon^2\frac{f'(y)}{xf(y)}\operatorname{diag}(-1,1)
\]

并非零恒等式；仅在旧样点 `y=3/5` 消失。把此系统送入原 `FINAL_CHECK`，确实得到
`PASS/ALL_PASS`。修正后得到 `FAIL/FULL_SYSTEM_FAIL`，且失败项恰是
`flat_connection`；gauge 和共享常数 dlog 留数仍通过。这说明常数 dlog 留数本身不足以
取代非交换矩阵联络的可积性检验。

现在使用更短的符号曲率计算，保留稀疏矩阵乘法；证书的 `check_scope` 已改为
`exact-global-gauge-symbolic-flatness-multivariable-shared-residue-declared-dlog-span`。
反例已加入 `tests/RunFullSystemUnitTests.wls`。`DEBuilder.validity` 的取点记录仍保留其
明确的局部诊断含义，不作为最终符号平坦性的替代。

另一个修正是结构修复 checker 原先把 `B - eps*(B/eps) == 0` 标作 ε 分离；对正常
有理表达式这只是恒等式。旧实现还有另一个有效的无残余 ε 检查，因此该问题主要会
误导诊断字段。现在两个对外字段来自同一次有效的 `FreeQ[Together[B/eps],eps]` 检验。

## 3. 小范围试跑

均使用当前会话发起的无状态批处理，遵守对应模块的 skill。运行数据在本地目录
`runs/static-audit-20260908-jrekfah2/`，不改动已有持续研究状态。

| 试跑 | 结果 | 范围 |
| --- | --- | --- |
| `RunFullSystemUnitTests.wls` | 16/16，51.639 秒 | 完整 gauge、共享留数、代数字母及本轮非平坦反例 |
| `RunCanonicalCommitUnitTests.wls` | 8/8，32.743 秒 | 前缀变换累计、core/tail 失败分类 |
| `RunBuildCutDECompatibilityUnitTests.wls` | 3/3，19.060 秒 | 已支持的导数格式与错误 DE 拒绝 |
| 方法卡针对性测试 | 9/9，151.239 秒 | 路由和输入矛盾；真实 CANONICA、Libra provider 及独立 checker；结构修复 |
| `RunFullSectorTailUnitTests.wls` | 11/11，120.786 秒 | 小型两变量系统、非零尾部、代数原函数及低扇区 ε 归一化 |
| `RunEndToEndWorkflowLiveTest.wls` | 12/12 验收项，53.185 秒 | 真实一圈 sector 5，一主积分，从 DlogBasis 候选经 Kira 到最终 canonical DE |

最后一项使用分发的 DlogBasis-refine 与 FiniteFlow Wolfram 源码、本机已有的 FiniteFlow
原生库、Wolfram 14.3，以及实际版本为 3.0 的 `kira3`。它不是对分发的 Kira 3.1 源码的
全新编译测试。Kira 使用一个线程。

该例在 `d=2-2 eps` 下得到

\[
J=\frac{(1+2\epsilon)s}{2}\,\mathrm{tri}[1,0,1],\qquad
\frac{dJ}{ds}=-\frac{\epsilon}{s}J.
\]

这是一个一主积分子族的实际 canonical-basis 结果，不能据此扩大为整个三角 family 或
任意两圈 family 的成功率。详细记录为上述目录中的 `module-tests.json`、
`focused-methods.log`、`full-sector-tail.log`、`flatness-before/result.json`、
`flatness-after/result.json` 和 `one-loop-live/end-to-end-receipt.wl`。

仓库原有 61-master / 46-sector pentabox 结果也已复核其报告、最终 JSON 和三个登记
文件的 SHA-256，均与原记录一致。该历史报告明确只做过取点平坦性检查；本轮没有把它
改称已经通过新增的完整符号曲率验证，也没有重跑该整族。

## 4. 文献与实际实现边界

| 文献 | 支持的科学方法 | CANON 当前实现与边界 |
| --- | --- | --- |
| [Henn 2013](https://arxiv.org/html/1304.1806v2) | 基变换、ε 形式、dlog 联络及边界条件 | 最终检查要求精确 gauge、符号平坦性、ε 分离与全部方向共享常数留数；不计算物理边界常数 |
| [Meyer 2017：算法](https://arxiv.org/abs/1611.01087)、[CANONICA](https://arxiv.org/abs/1705.06252) | 在存在有理变换的前提下求多尺度 canonical form | `canonica` 卡直接消费原始有理 DE；适合简单有理变换问题。有理搜索不成功不能推出不存在代数或更一般的变换 |
| [Lee：Libra](https://arxiv.org/html/2012.00279v1) | Fuchsification、归一化、ε 因子提取；论文也讨论多变量方法 | 当前自动 `libra` 卡只接单变量；结构修复卡进一步限于 `1x1 + 2x2` 直和切片。不能把上游包的全部能力计作本项目已经接入 |
| [Henn 等：dlog integrands](https://arxiv.org/abs/2002.09492)、[Chen 等：Baikov，§4.3](https://arxiv.org/html/2202.08127v2#S4.SS3) | 从对数形式构造候选，并处理广义 Baikov 形式到 Feynman 积分子空间的转换 | DlogBasis-refine 的有限仿射最大割证据和 module lift 是候选依据；仍须做实际物理维数下的 IBP 和完整 DE 检验。有限搜索不是全局 LS/UT 完备性证明 |
| [Dlapa、Henn、Yan：INITIAL](https://arxiv.org/html/2002.02340v1) | 从一个已知均匀权重积分出发构造 canonical DE | 本项目 INITIAL 卡只实现固定的 26 项官方三圈梯图证据；不是任意简单 family 的通用 UT 验证器 |
| [He 等 2022，式 (78)](https://arxiv.org/html/2206.04609v2#S3.SS2) | 对具有 `a+b eps` 结构的条目用原函数修正 | `SolveTail` 的下三角修补在 `old=T.new` 下取 `dD=a`，使尾部变为 `eps*(b+C D-D A)`；本地代数原函数 ansatz 有限，最终仍由 checker 验算 |
| [Kira](https://arxiv.org/abs/2008.06494)、[FiniteFlow](https://arxiv.org/abs/1905.08019) | IBP 约化与有限域函数重构 | adapter 依赖外部约化与声明的导数算符，验证可用规则和矩阵；没有自行证明 master 完备性 |
| [Adams、Weinzierl：椭圆情形](https://arxiv.org/abs/1802.05020) | 非 MPL 积分也可能通过非代数基变换得到 ε 形式 | 当前 rational/algebraic dlog 目标没有接入周期归一化或椭圆积分核；主积分少并不保证落在当前方法范围 |

`epsilon-zero` 是本地的有界 DE proposal：有限域求解只提出水平行，随后在全部原始方向
精确回代；两维欠秩 completion 也需通过后续完整检查。它不是对上述文献中任意 family
构造算法的完整实现。

## 5. 成熟度判断

可实际使用的范围是：已给出可信的有序 masters、闭合 IBP 与正确导数算符，预期属于
MPL，且所需变换为有理函数或落在当前已处理的代数候选范围。复杂度更取决于尺度数、
字母表和变换类别，而不是仅看圈数或主积分个数。对这种输入，可按现有 provider →
core → tail → final 流程寻找并检验 canonical basis。

尚未具备的保证包括：未知代数字母表的完备自动发现；所有分子/dot/维数候选的完备
搜索；任意非零尾部都可被当前 ansatz 消除；IBP master 完备性；椭圆及更一般函数类；
物理边界条件与 UT 归一化。

特别是对运动学变量恒定但依赖 ε 的重标度 `J -> (1+eps) J`，canonical DE 保持不变，
而 ε 展开中的权重可以混合。因此 canonical DE 证书不能独自完成 UT 边界归一化证明。
实际使用中应把 `ALL_PASS` 理解为所声明积分空间和字母表中的已验证 canonical DE，
把 `METHOD_EXHAUSTED` 理解为当前搜索空间耗尽。

本轮没有扩大研究目标，也没有增加新的回退框架。符号曲率检验比单点检查更严格，
大型多尺度系统可能因此花费更多时间；当前性能结论只覆盖上述小型试跑。
