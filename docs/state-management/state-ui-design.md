# State-machine UI implementation plan

> Historical scope: this document preserves an earlier UI proposal, recorded as
> not yet implemented. It does not establish current UI capabilities. For active
> work, follow [the current agent workflow](../agent-workflow.md) and current skills.

## 1. Overall form

Use a **fully static, self-contained local HTML page**:

```text
.state-management/[TASK_NAME]/views/ui/PROJECT_STATE.html
```

Open it directly in a browser through `file://`. Do not start a local server,
access the network, use `localStorage`, or create layout configuration files.

Task JSON remains the sole source of truth:

```text
meta.json + tasks/*.json
             │
             ▼
        rebuild_views
         ├── PROJECT_STATE.md
         └── ui/PROJECT_STATE.html
```

HTML only displays state. Coordinates created by user dragging exist only in the
current page's JavaScript memory. Refreshing or reopening the page restores the
automatic layout.

## 2. Intended page

```text
┌────────────────────────────────────────────────────────────────────────────┐
│ Overall task name    Ready 2  Running 1  Completed 5  Exceptions 1         │
│ Overall objective ▾                                                        │
├──────────────────────────────────────────┬─────────────────────────────────┤
│                                          │ T-004  Independent verification │
│              [T-001 ✓]                   │ Status: running                 │
│                  │                       │                                 │
│         ┌────────┴────────┐              │ Objective                       │
│         ▼                 ▼              │ ...                             │
│     [T-002 ●]         [T-003 ●]           │                                 │
│         │                 │              │ Acceptance criteria             │
│         └────────┬────────┘               │ 1. ...                          │
│                  ▼                       │ 2. ...                          │
│              [T-004 ▶]                   │                                 │
│                                          │ Dependencies, run, results...   │
│    Nodes can be dragged temporarily      │                                 │
└──────────────────────────────────────────┴─────────────────────────────────┘
```

The page has three areas:

- Top: overall task name, counts by status, and a collapsible overall objective.
- Left: a vertical dependency graph.
- Right: details of the node currently hovered over, focused, or clicked.

Task dependencies run from top to bottom. If `T-004` depends on `T-002`, the arrow is:

```text
T-002
  │
  ▼
T-004
```

## 3. Status colors

Colors distinguish broad status categories; text and icons distinguish individual
states:

| Status | Color | Display text |
| --- | --- | --- |
| `pending` | Gray | Waiting for dependencies |
| `ready` | Blue | Ready |
| `running` | Orange | Running |
| `submitted` | Orange | Awaiting review |
| `completed` | Green | Completed |
| `blocked` | Red | Blocked |
| `failed` | Red | Failed |

Nodes always display status text, so shared colors do not cause confusion between
`running/submitted` or `blocked/failed`.

## 4. Default vertical layout

Use a simplified layered DAG layout algorithm:

1. Compute each task's level from its longest dependency chain.
2. Place tasks without dependencies at the top.
3. Place subsequent tasks progressively lower.
4. Spread parallel tasks at the same level horizontally.
5. Adjust ordering within a level using the mean horizontal coordinate of predecessor nodes to reduce edge crossings.
6. Break sorting ties with task IDs so identical state produces identical layout.
7. Keep a fixed minimum spacing between nodes, with no overlap by default.

Additional dependency levels mainly increase canvas height. Canvas width grows
only when a level contains many parallel tasks. The graph area supports
independent vertical and horizontal scrolling without compressing node text.

## 5. Temporary dragging and synchronized edges

Nodes support free two-dimensional dragging within the current page.

Implementation:

- Use Pointer Events for both mouse and trackpad interactions.
- Capture the current node with `setPointerCapture` at drag start.
- Store node positions in a JavaScript object in the current page.
- Use `requestAnimationFrame` to update the display during dragging.
- Recompute only edges directly connected to the current node.
- Do not allow dragging nodes into negative canvas coordinates.
- Automatically expand the canvas when dragging to its right or bottom edge.

Represent dependency edges with SVG Bézier curves. Whenever a node moves:

1. Read the new positions of the dependency and successor nodes.
2. Choose the most suitable connection points among top, bottom, left, and right according to their relative direction.
3. Recompute the curve path.
4. Keep the arrow pointing toward the successor task.

Dragging changes display coordinates only:

- It does not modify `tasks/*.json`;
- It does not change dependencies;
- It does not change task order or status;
- It does not write to HTML;
- It does not use browser storage;
- Refreshing restores the default vertical layout.

Thus, even if a user temporarily drags a successor above a prerequisite, actual
dependency semantics still come from arrow direction and task JSON.

## 6. Task details

A node displays only:

- Status icon;
- Task ID;
- Title;
- Status text.

The right-hand details area displays fields actually present in the task:

- objective;
- background;
- acceptance criteria;
- dependencies;
- Current run ID;
- summary;
- artifact ID;
- blocked/failed reason;
- completed time.

Omit absent fields. Task content is safely embedded in HTML in advance; JavaScript
only switches the displayed details and does not concatenate unescaped HTML.

Hovering supports quick browsing. Clicking keeps a node selected so the user can
move the pointer to the right-hand area to read longer content. Keyboard focus
on a node provides the same behavior.

## 7. Code organization

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

Responsibilities:

- `cli.py`: read the source of truth, hold the view lock, and write view files atomically.
- `state_ui/layout.py`: compute the default vertical DAG layout.
- `state_ui/renderer.py`: construct UI view data and generate self-contained HTML.
- `state_ui/templates/project_state.html`: page structure.
- `state_ui/assets/project_state.css`: layout, status styling, and scrollable canvas.
- `state_ui/assets/project_state.js`: detail switching, temporary dragging, and SVG edge updates.
- `state_ui/tests/`: vertical-layout, HTML-rendering, and CLI-rebuild integration tests.

Inline CSS and JavaScript when generating HTML so a single `PROJECT_STATE.html`
can be opened independently.

The runtime view directory is:

```text
.state-management/[TASK_NAME]/views/
├── PROJECT_STATE.md
└── ui/
    └── PROJECT_STATE.html
```

Retain the existing `PROJECT_STATE.md`. Replace `rebuild_view` with a unified
`rebuild_views` that atomically replaces Markdown and `ui/PROJECT_STATE.html`
separately within the existing view lock.

## 8. Update timing

Rebuild HTML after these operations complete:

- `init`
- `task create`
- `task claim`
- `task submit`
- `task accept`
- `task block`
- `task unblock`
- `task fail`
- `project resume`

An open page does not refresh automatically. Refreshing the browser shows the
latest task state and resets all temporary drag positions to the new default layout.

## 9. Acceptance criteria

1. `views/ui/PROJECT_STATE.html` opens directly through `file://`, without a server or network connection.
2. All tasks are arranged from top to bottom according to dependencies by default.
3. Each task has exactly one node, and each dependency has exactly one directed edge.
4. Branches and joins are clear, default nodes do not overlap, and complex graphs can scroll vertically.
5. `running/submitted` share orange and `blocked/failed` share red, while icons and text distinguish them accurately.
6. Every node supports temporary two-dimensional dragging.
7. During dragging, all associated edges and arrows follow the node continuously without detachment or noticeable jumps.
8. Dragging affects only the current page; refreshing or reopening strictly restores the deterministic default layout.
9. The page creates no `UI_LAYOUT.json` and uses no cookies, `localStorage`, IndexedDB, or other persistence.
10. Hovering, focusing, or clicking a node displays that task's complete information in the details area.
11. Displayed state, dependencies, run, summary, artifact, and reason match task JSON exactly.
12. All user-supplied titles and body text are HTML-escaped and cannot inject scripts or page tags.
13. In a test graph containing at least 50 nodes and multiple branches and joins, the default layout has no overlap and scrolling and dragging remain smooth.
14. Do not change the JSON schema, task state model, CLI/MCP protocol, or meaning of the existing Markdown view.
15. All current state-management tests continue to pass; add tests for vertical layout, color mapping, temporary dragging, and edge recomputation.

The first version does not include layout saving, state editing, dependency
editing, zoom, search/filtering, a historical timeline, artifact previews, or an
overview of multiple overall tasks. Not yet implemented.
