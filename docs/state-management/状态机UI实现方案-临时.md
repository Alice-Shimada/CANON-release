# 状态机 UI 实现方案

## 一、总体形式

采用**完全静态、自包含的本地 HTML 页面**：

```text
.state-management/[TASK_NAME]/views/ui/PROJECT_STATE.html
```

浏览器通过 `file://` 直接打开，不启动本地服务，不访问网络，不使用 `localStorage`，也不产生布局配置文件。

任务 JSON 仍是唯一事实源：

```text
meta.json + tasks/*.json
             │
             ▼
        rebuild_views
         ├── PROJECT_STATE.md
         └── ui/PROJECT_STATE.html
```

HTML 只显示状态。用户拖拽产生的坐标仅存在于当前页面的 JavaScript 内存中，刷新或重新打开页面后恢复自动布局。

## 二、预期页面

```text
┌────────────────────────────────────────────────────────────┐
│ 总体任务名称    待执行 2  进行中 1  已完成 5  异常 1       │
│ 总体目标 ▾                                                 │
├────────────────────────────────────┬───────────────────────┤
│                                    │ T-004  独立验证       │
│            [T-001 ✓]               │ 状态：running         │
│                │                   │                       │
│       ┌────────┴────────┐          │ 目标                  │
│       ▼                 ▼          │ ……                    │
│   [T-002 ●]         [T-003 ●]      │                       │
│       │                 │          │ 验收标准              │
│       └────────┬────────┘          │ 1. ……                 │
│                ▼                   │ 2. ……                 │
│            [T-004 ▶]               │                       │
│                                    │ 依赖、run、结果……     │
│        节点可临时自由拖拽           │                       │
└────────────────────────────────────┴───────────────────────┘
```

页面分为：

- 顶部：总体任务名称、各状态任务数量、可折叠的总体目标。
- 左侧：纵向依赖图。
- 右侧：当前悬浮、聚焦或点击节点的详细信息。

任务依赖由上向下表达。若 `T-004` 依赖 `T-002`，箭头为：

```text
T-002
  │
  ▼
T-004
```

## 三、状态颜色

颜色只区分状态大类，具体状态依靠文字和图标区分：

| 状态 | 颜色 | 显示文字 |
| --- | --- | --- |
| `pending` | 灰色 | 待依赖 |
| `ready` | 蓝色 | 待执行 |
| `running` | 橙色 | 执行中 |
| `submitted` | 橙色 | 待验收 |
| `completed` | 绿色 | 已完成 |
| `blocked` | 红色 | 已阻塞 |
| `failed` | 红色 | 已失败 |

节点始终显示状态文字，因此不会因为合并颜色而混淆 `running/submitted` 或 `blocked/failed`。

## 四、默认纵向布局

布局采用简化的分层 DAG 算法：

1. 根据最长依赖链计算任务层级。
2. 无依赖任务位于最上层。
3. 后续任务依次向下排列。
4. 同一层的并行任务横向展开。
5. 根据前置节点的平均横坐标调整同层顺序，减少连线交叉。
6. 使用任务 ID 打破排序平局，保证相同状态生成相同布局。
7. 节点保持固定最小间距，默认情况下不重叠。

依赖层数主要增加画布高度。某一层包含大量并行任务时才增加画布宽度。图形区域可以独立进行纵向和横向滚动，不压缩节点文字。

## 五、临时拖拽与连线同步

节点支持在当前页面中二维自由拖拽。

实现方式：

- 使用 Pointer Events 统一处理鼠标和触控板操作。
- 拖拽开始时通过 `setPointerCapture` 锁定当前节点。
- 节点位置存放在当前页面的 JavaScript 对象中。
- 拖拽过程中使用 `requestAnimationFrame` 更新画面。
- 只重新计算与当前节点直接相连的边。
- 节点不能拖到画布的负坐标区域。
- 拖到右侧或底部边缘时，画布自动扩展。

表示依赖关系的线使用 SVG 贝塞尔曲线。每次节点移动时：

1. 读取依赖节点和后续节点的新位置。
2. 根据相对方向选择上、下、左、右中最合适的连接点。
3. 重新计算曲线路径。
4. 保证箭头始终指向后续任务。

拖拽只改变显示坐标：

- 不修改 `tasks/*.json`；
- 不改变依赖关系；
- 不改变任务顺序和状态；
- 不写入 HTML；
- 不使用浏览器存储；
- 刷新页面后恢复默认纵向布局。

因此，即使用户临时把后续任务拖到前置任务上方，实际依赖语义仍由箭头方向和任务 JSON 决定。

## 六、任务详情

节点只显示：

- 状态图标；
- 任务 ID；
- 标题；
- 状态文字。

右侧详情区根据任务实际拥有的字段显示：

- objective；
- background；
- acceptance criteria；
- dependencies；
- 当前 run ID；
- summary；
- artifact ID；
- blocked/failed reason；
- completed time。

不存在的字段不显示。任务内容预先安全地写入 HTML，JavaScript 只负责切换当前详情，不直接拼接未经转义的 HTML。

悬浮用于快速浏览；点击后保持选中，方便移动鼠标到右侧阅读较长内容。键盘聚焦节点时具有相同行为。

## 七、代码组织

```text
state-management/
└── state_management/
    ├── __init__.py
    ├── cli.py
    └── state_ui/
        ├── __init__.py
        ├── layout.py
        ├── renderer.py
        ├── templates/
        │   └── project_state.html
        ├── assets/
        │   ├── project_state.css
        │   └── project_state.js
        └── tests/
            ├── __init__.py
            ├── test_layout.py
            ├── test_renderer.py
            └── test_integration.py
```

职责划分：

- `cli.py`：读取事实源、持有视图锁、原子写入视图文件。
- `state_ui/layout.py`：计算默认纵向 DAG 布局。
- `state_ui/renderer.py`：构造 UI 视图数据并生成自包含 HTML。
- `state_ui/templates/project_state.html`：页面结构。
- `state_ui/assets/project_state.css`：排版、状态样式和滚动画布。
- `state_ui/assets/project_state.js`：详情切换、临时拖拽和 SVG 连线更新。
- `state_ui/tests/`：纵向布局、HTML 渲染和 CLI 重建集成测试。

生成时把 CSS 和 JavaScript 内联到 HTML 中，使单个 `PROJECT_STATE.html` 可以独立打开。

运行期视图目录为：

```text
.state-management/[TASK_NAME]/views/
├── PROJECT_STATE.md
└── ui/
    └── PROJECT_STATE.html
```

现有 `PROJECT_STATE.md` 保留。`rebuild_view` 调整为统一的 `rebuild_views`，在现有视图锁内分别原子替换 Markdown 和 `ui/PROJECT_STATE.html`。

## 八、更新时机

以下操作完成后重建 HTML：

- `init`
- `task create`
- `task claim`
- `task submit`
- `task accept`
- `task block`
- `task unblock`
- `task fail`
- `project resume`

已经打开的页面不会自动刷新。用户刷新浏览器后看到最新任务状态，同时所有临时拖拽位置恢复为新的默认布局。

## 九、验收标准

1. `views/ui/PROJECT_STATE.html` 可以通过 `file://` 直接打开，无需启动服务或联网。
2. 所有任务默认按照依赖关系从上到下排列。
3. 每个任务恰好对应一个节点，每条依赖恰好对应一条有向连线。
4. 分支和汇合关系清楚，默认节点不重叠，复杂图可以纵向滚动。
5. `running/submitted` 使用同一橙色，`blocked/failed` 使用同一红色，并能通过图标和文字准确区分。
6. 任意节点都可以临时二维拖拽。
7. 拖拽过程中，所有关联连线和箭头连续跟随节点移动，不脱节、不明显跳动。
8. 拖拽只影响当前页面；刷新和重新打开后严格恢复确定性的默认布局。
9. 页面不创建 `UI_LAYOUT.json`，不使用 Cookie、`localStorage`、IndexedDB 或其他持久化方式。
10. 悬浮、聚焦或点击节点时，详情区显示对应任务的完整信息。
11. 页面显示的状态、依赖、run、summary、artifact 和 reason 与任务 JSON 完全一致。
12. 用户提供的标题和正文均经过 HTML 转义，不能注入脚本或页面标签。
13. 包含至少 50 个节点以及多处分支、汇合的测试图中，默认布局无重叠，滚动和拖拽保持流畅。
14. 不修改 JSON schema、任务状态模型、CLI/MCP 协议以及现有 Markdown 视图的含义。
15. 当前状态管理测试继续全部通过，并增加纵向布局、颜色映射、临时拖拽和连线重计算测试。

第一版不加入布局保存、状态编辑、依赖编辑、缩放、搜索过滤、历史时间线、artifact 预览或多总体任务总览。尚未实施。
