# MethodCard 模板

## 目的

定义一个有界提供者角色，不假定每张方法卡都会变换约化后的微分系统。

## 必需交互

实例化的卡必须只声明一个阶段和角色，并采用 `../../INTERFACES.md` 中该阶段的合同：

- 约化前积分生成器：`PROPOSE_INTEGRAL_CANDIDATES` 和
  `PROVISIONAL/INTEGRAL_CANDIDATES`；
- 约化后变换生成器：`SEARCH_CORE` 和
  `PROVISIONAL/CANDIDATE_TRANSFORMATION`；
- 证据提供者或检查器：采用另行记录的合同与权限。

## 边界

只有实例化本 MethodCard 时才填写科学方法。不得混合约化前积分定义与约化后变换，
不得加入工作流状态或调度，也不得允许提供者发布 `PASS`/`FAIL`。
