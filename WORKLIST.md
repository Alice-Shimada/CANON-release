# CANON Worklist

## 背景

由单一 Python 状态机调度 AI agent；科学计算由 agent 调用 Mathematica 脚本完成。

## 目标

按 sector 逐步构造并验证 canonical/UT basis，保持流程简洁、可恢复、可检查。

## 1. 编排框架

- [x] 完成 `workflow.py`、JSON 接口和任务模板
- [x] 跑通状态回环与 subagent null test

## 2. 预处理和Family 准备

- [ ] 环境检查
    将可能用到的IBP Reducer，Mathematica和各类程序包的路径锁定，确定他们已被安装。可以写SKILL，配合一些AI撰写的脚本来检测环境是否完备
- [ ] 实现 `PrepareFamily.wls`
    用户输入自然语言描述的family信息，或提供文件路径；由AI将其转化为一些固定格式的参数，喂给wls生成标准的约化所需的config和target文件

## 3. IBP Reduction和DE构建

- [ ] 进行IBP约化
    写SKILL让AI调用Reducer进行IBP约化，输入来自上一轮准备的config，输出Mathematica格式的replacement rules
- [ ] 进行DE构建
    求导（可以让AI写，旧的workflow里这个函数已经有了），然后做第二轮IBP。如果两次主积分数量一致，说明完备，构建微分方程。写一个`Build_DE.wls`程序让AI调用即可
- [ ] 验证 sector 排序和产物交接
    需要按照传播子从少到多+sector ID从小到大排列。将对各个变量的DE保存，约化规则保存，用作下一个阶段的input
- [ ] 优化的导数算符

## 4. Ansatz 生成和检验

- [ ] 实现 DlogBasis 的改进，每次开始前先进行一次ansatz生成，并将生成ansatz中涉及的标量积分送去约化
    DlogBasis的改进有待讨论
- [ ] 实现 Gram-Baikov 方法生成ansatz
    有待讨论
- [ ]  实现一个 MethodCard 接口，允许各种方法插入，允许agent按照优先级选取一个方法
    每个方法需配置一系列的程序，并提供一个SKILL教AI如何使用这些程序生成ansatz
- [ ] 有状态笔记本进行sector-by-sector检测
    使用有状态笔记本因为可以只读入一次rule，然后sector-by-sector连续工作。可以考虑用MICA调度笔记本。

## 5. Sector 纠错机制

- [ ] 非对角元素不正确时，决定更换ansatz测试或是寻找变换修补非对角元素
    有待讨论

## 6. 提交与总检

- [ ] 实现 `CheckFullSystem.wls`
    检查微分方程的epsilon-form，检查确实是dlog-form，提取Alphabet

## 7. （发布前）验收

- [ ] 用一个小 family 跑完整流程
    目前考虑用2l5p来做测试，＜100个主积分。如果表现够好，可以尝试3l5p
- [ ] 固化回归测试
    可以交给AI设计测试，人工审核
