# 分发迁移检查（2026-09-07）

范围是 CANON 源码、接口样例、测试、README、skill 和 worker 提示，以及逐包保存的
外部源码。研究状态和运行产物没有进入分发。

## 文件与接口

原有 179 个 Git 文件逐项扫描后，移除两份废弃的 LS 压缩包，其余 177 个文件按运行
入口、接口、测试、文档及配置检查了路径和机器假设。修改集中在以下位置：

- `MethodCardCore.wl` 统一按声明文件定位相对路径；PREPARE 的资源相对于 family spec，
  IBP 及候选桥的 project、output 和显式 executable 路径相对于请求 JSON。
- INITIAL 的入口、FiniteFlow 文件与原生库、参考目录分别由参数声明，线程数可配置，
  省略时为 1；移除固定 macOS ARM64、Mathematica 14 和个人工具树要求。
- DlogBasis 的 FiniteFlow/Singular 路径按请求解析；版本来自调用方声明，未提供时为
  `null`，入口 SHA-256 来自实际文件；不再读取外层仓库 HEAD。
- 测试夹具使用仓库内的合成工具文件及实际运行时信息；README、skill、worker 提示和
  接口样例说明一致的路径配置方式，历史结果文档保留原日期、版本、哈希和结论。

数学范围中的固定梯图、种子、字母表和参考身份仍属于该方法卡定义，不是安装配置。
测试中的不存在路径、Windows 路径样例和通用 `/usr/bin/env` shebang 也保留各自用途。

## 外部源码

八个程序共 11,147 个原始仓库文件、120,344,872 字节；来源提交及 tree ID 见
[external/sources.json](../external/sources.json)。逐文件与源提交比对，仅有清单列出的
两处 DlogBasis-refine 迁移修改。没有嵌套 `.git`、本机编译产物或额外获取的基础库。
原仓库自带的示例、图像、测试输入和内嵌源码按原文保留。

扫描外部源码时，其他个人路径匹配属于历史 notebook 输出、文档/生成器注释、示例
数据及 Singular 的旧 openmath/python 开发演示脚本和示例 Makefile；这些上游文件按
原始提交保留，单独运行旧演示时仍需配置它们自己的路径。平台 help 配置及
`$UserBaseDirectory` 下的 Applications 路径是上游原生配置。
这些文件不作为 CANON 的安装路径来源。Fermat 源码未取得，获取说明单列于
[Fermat/README.md](../external/Fermat/README.md)。

## 验证结果

| 检查 | 结果与范围 |
| --- | --- |
| 状态管理、Codex adapter 与提示契约 | 44 项通过，7.622 秒；只操作测试临时目录 |
| INITIAL、结构修复 checker、包解析与候选接口 | 12 项针对性测试最终通过；其中过期候选样例修正后只重跑了失败项 |
| DlogBasis-refine 实际 provider | 无 `.git` 的含空格目录运行 sector 148/182 回归及参数拒绝分支；1 项通过，23.120 秒；FiniteFlow 原生库复用本机已安装版本 |
| PREPARE/DISCOVER 迁移 | 2 项通过；JSON、spec、Kira project 分目录且含空格，调用工作目录不同 |
| Kira adapter 迁移 | 1 项通过；相对 project/output 路径，stub reducer 核对有序 masters 和规则 |
| DlogBasis 源码加载 | `RelocationSmoke.wls` 通过，两个预期候选且无新增 Global 符号 |
| 候选 IBP 桥路径传递 | 相对 executable/project/output 及异目录结果文件通过 stub reducer 检查 |

这是安装配置、路径传递和现有接口的回归验证。未执行八个外部程序在新机器上的全新
编译，未重新运行真实 INITIAL `TCalc`；Windows 原生持续研究仍未适配。已有研究产物
中的绝对运行路径不会随源码移动而自动重写。
