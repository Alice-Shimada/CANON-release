# 外部程序源码

每个子目录保存一个明确提交的原始仓库文件树，供用户自行编译、安装。没有执行编译、
复制本机安装结果或嵌套 `.git`。仓库来源和完整提交号见 [sources.json](sources.json)；
各包保留自己的许可证、文档、示例和上游已登记的测试数据。目录不是 Git submodule。

| 程序 | 用途与入口 | 编译、安装说明 |
| --- | --- | --- |
| DlogBasis-refine | 有界积分候选；`DlogBasis.wl` | [README](DlogBasis-refine/README.md)，Wolfram 源码直接加载；候选搜索需要 FiniteFlow 和 Singular |
| CANONICA | 有理 DE 与 tail；`src/CANONICA.m` | [README](CANONICA/README)，Wolfram 源码直接加载 |
| Libra | DE 变换与结构修复；`Source/Libra.m` | [Readme](Libra/Readme.md)、[INSTALL](Libra/INSTALL) |
| Fermatica | Fermat 的 Wolfram 接口；`source/Fermatica.wl` | [README](Fermatica/README.md)，先安装 Fermat，再设置 `FERMATPATH` |
| INITIAL | 有界可信 seed 核心候选及官方固定梯图证据；`INITIAL.m` | [README](INITIAL/README.md)，先安装 FiniteFlow |
| FiniteFlow | 有限域计算；`mathlink/FiniteFlow.m` | [README](FiniteFlow/README.md)，用 CMake 编译与本机 Wolfram 匹配的原生库 |
| Kira | IBP 约化；安装后的 `kira` | [README](Kira/README.rst)、[meson.build](Kira/meson.build)；本快照为 3.1，README 中部分说明仍沿用 2.x |
| Singular | DlogBasis-refine 候选组合的模块求解；安装后的 `Singular` | [README](Singular/README.md) 中的官方源码安装指南；快照为 `Release-4-2-1p2` |

Singular 是当前 DlogBasis-refine 候选搜索的依赖；即使 `residual_backend` 使用默认
`Current`，后续模块求解仍需要它。

`DlogBasis-refine` 是 CANON 维护的变体；清单中的 origin 是历史上游，不能据此认为
该变体提交已经发布到上游。分发时对其 skill 的路径说明及 study 的版本记录方式作了
小幅迁移修改，逐项记在清单中。当前 workflow 使用 `DlogBasis` 上下文的
`DlogBasisSearch`，旧 LS 压缩包已移除。

Fermat 没有附源码；其官方页面要求向作者索取当前 GPL 源码，详情见
[Fermat/README.md](Fermat/README.md)。这里未用可执行文件替代源码。

## 基础库与本机配置

GMP、MPFR、FLINT、CLN、GiNaC、zlib、yaml-cpp、FireFly、MPI、jemalloc 等基础库、
编译工具链，以及 Mathematica、Python、Git，由用户按所选包的原始说明自行安装。
没有额外下载或打包这些基础库。Singular 原始仓库内的 factory、libpolys、omalloc、
gfanlib 等组成部分按原树保留；Kira 原树中的 sqlite3 等内嵌源码也按原样保留。Kira 的 `.wrap` 文件只是上游依赖描述，未下载 subprojects。
若希望 Kira 只使用已经安装的库，Meson 可指定 `--wrap-mode=nofallback`。

在本机配置中提供实际安装路径，再由调用方写入任务参数；仓库不生成或提交本机配置。

| 配置位置 | 含义 |
| --- | --- |
| PATH | `WolframKernel`、`wolframscript`、`kira`、`Singular` 等已安装命令 |
| `CANON_WOLFRAM_KERNEL` | Python 测试使用的 WolframKernel；未设置时从 PATH 找 |
| `FERMATPATH` | 实际 Fermat 可执行文件，Fermatica/Kira 使用；Wolfram 内也可设 `Fermatica` 上下文的 `$FermatCMD` |
| `method_options.package_entry` | 当前方法的包主文件；有标准 Wolfram 安装的通用方法也支持 `$Path` |
| `method_options.finite_flow_package_file` | FiniteFlow 的 `.m` 文件；原生库通过本机 `$LibraryPath` 提供 |
| `method_options.singular_executable` | DlogBasis-refine 使用的 Singular 命令或路径，默认 `Singular` |
| Kira request 的 `executable`、`options` | reducer 命令和显式资源预算，例如 `--parallel=1` |

每个 JSON 中的相对 artifact/包路径以该 JSON 所在目录为基准；family spec 内资源路径
以 spec 文件所在目录为基准。JSON 字符串不展开 `$变量` 或 `~`：需要环境变量时由调用方
先读取、展开，再写入请求。已生成的研究产物含当次解析出的绝对路径和哈希；迁移研究
状态需保留依赖关系并重新绑定运行环境，源码可迁移不表示旧运行路径自动改写。

## INITIAL 独立组件配置

INITIAL [官方参考验证兼容接口](../examples/initial-official-ladder/README.md) 的
`method_options` 需要以下路径和身份，原生库文件名按本机平台填写。
相对路径从实际输入 JSON 目录计算，下面展示字段，不规定安装目录布局：

```json
{
  "package_entry": "../external/INITIAL/INITIAL.m",
  "finite_flow_package_file": "../external/FiniteFlow/mathlink/FiniteFlow.m",
  "finite_flow_library": "../installed/lib/fflowmlink.so",
  "reference_directory": "../external/INITIAL/examples/massless_3L4P",
  "initial_identity": "INITIAL 2.1; 63d8f813ac415f82f7ef945ee7e3f78a242fae49",
  "finiteflow_identity": "FiniteFlow; 278344c169010b74e791af8c5604c8cb9cd8df11",
  "threads": 1
}
```

`CANON_TEST_INITIAL_CONFIG` 可指向含这四个组件路径及可选 `threads` 的 JSON，供真实
INITIAL 测试读取；该文件内的相对路径以配置文件自身为基准。独立 checker 只需要
`package_entry`、`finite_flow_package_file`、`reference_directory`，不加载原生库。
固定身份属于该参考验证的科学范围；运行平台、安装目录与线程数由调用方决定。

常规 [INITIAL seed 核心接口](../methods/initial/SKILL.md) 使用同样的三个组件
路径与声明身份，但不需要 `reference_directory`。它需要明确的 `threads`、
`timeout_seconds`、`max_iterations`、`max_degree` 和 `max_primes`，以及 seed 行、
归一化证据、字母表和导数分配。它输出普通 `core_candidates`，交给 CHECK_CORE；
稳定入口为 `methods/initial/run.wls`，请求须明确 `step="SEARCH_CORE"`。
本机工具能力仍须由调用方核验，通用接口的存在不扩大任何机器的已验收运行范围。

其他真实 provider 测试接受 `CANON_TEST_CANONICA_ENTRY`、`CANON_TEST_LIBRA_ENTRY`、
`CANON_TEST_DLOGBASIS_REFINE_ENTRY`、`CANON_TEST_FINITEFLOW_ENTRY`；DlogBasis 的声明
版本可用 `CANON_TEST_DLOGBASIS_REVISION` 传入。未配置的真实 provider 测试会显式跳过。
`CANON_TEST_SINGULAR_ENTRY` 可为真实 DlogBasis 回归指定 Singular 的绝对入口，
避免依赖测试进程的 `PATH`。

原始仓库中的历史 notebook 输出、生成器注释、平台 help 配置及示例文件可能包含作者当时
的路径；Singular 的旧 openmath/python 演示脚本和示例 Makefile 也保留上游路径，
单独运行这些演示需自行配置。它们按原文保留，不作为 CANON 的安装配置。分发没有新增本机编译结果，上游
已经登记的示例数据和资源（例如 Singular 的 surfex.jar、Kira 的压缩测试输入）仍属于
对应原始文件树。
