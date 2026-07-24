#!/usr/bin/env python3
"""Single agent-facing state machine for CANON_neu.

This file is deliberately an orchestration layer only.  It creates task
packets, records agent/subagent reports, carries artifact paths forward, and
applies the fixed transition table.  It never launches Mathematica and never
decides whether an integral basis is UT or canonical.

Scientific work belongs to the step SKILL.md named in each task and to the
stateless Mathematica script selected by the agent.
"""

from __future__ import annotations

import argparse
import copy
import json
import os
import sys
import tempfile
from datetime import datetime, timezone
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parent
PROJECT_SCHEMA = "canon-neu/project/v1"
STATE_SCHEMA = "canon-neu/state/v1"
INPUT_SCHEMA = "canon-neu/script-input/v1"
RESULT_SCHEMA = "canon-neu/script-result/v1"

# Declarative step contract.  Adding scientific code here would cross the
# architecture boundary: this table may name inputs, outputs, skills, scripts,
# and delegation roles, but it may not inspect Mathematica expressions.
STAGES: dict[str, dict[str, Any]] = {
    "PREPARE": {
        "skill": "skills/canon-prepare-family/SKILL.md",
        "scripts": ["mma/PrepareFamily.wls"],
        "inputs": {"family_spec": "project:family_spec"},
        "outputs": ["prepared_family"],
    },
    "DISCOVER": {
        "skill": "skills/canon-discover-sectors/SKILL.md",
        "scripts": ["mma/DiscoverSectors.wls"],
        "inputs": {"prepared_family": "artifact:prepared_family"},
        "outputs": ["sector_manifest", "master_basis"],
    },
    "BUILD_CUT_DE": {
        "skill": "skills/canon-build-cut-de/SKILL.md",
        "scripts": ["mma/BuildSectorCutDE.wls"],
        "inputs": {
            "prepared_family": "artifact:prepared_family",
            "master_basis": "artifact:master_basis",
            "sector_manifest": "artifact:sector_manifest",
        },
        "outputs": ["sector_basis", "sector_cut_de"],
    },
    "SEARCH_CORE": {
        "skill": "skills/canon-search-core/SKILL.md",
        "scripts": [
            "methods/dlogbasis/run.wls",
            "methods/gram-baikov/run.wls",
            "methods/method-card-template/run.wls",
        ],
        "inputs": {
            "prepared_family": "artifact:prepared_family",
            "sector_basis": "artifact:sector_basis",
            "sector_cut_de": "artifact:sector_cut_de",
            "method_options": "option?:method_options",
        },
        "outputs": ["core_candidates"],
        "roles": ["candidate_route"],
    },
    "CHECK_CORE": {
        "skill": "skills/canon-check-core/SKILL.md",
        "scripts": ["mma/CheckSectorCore.wls"],
        "inputs": {
            "sector_basis": "artifact:sector_basis",
            "sector_cut_de": "artifact:sector_cut_de",
            "core_candidates": "artifact:core_candidates",
        },
        "outputs": ["core_transform"],
    },
    "BUILD_FULL_DE": {
        "skill": "skills/canon-build-full-de/SKILL.md",
        "scripts": ["mma/BuildFullSectorDE.wls"],
        "inputs": {
            "prepared_family": "artifact:prepared_family",
            "master_basis": "artifact:master_basis",
            "sector_manifest": "artifact:sector_manifest",
            "core_transform": "artifact:core_transform",
            "accepted_prefix": "artifact?:accepted_prefix",
        },
        "outputs": ["full_sector_de"],
    },
    "SOLVE_TAIL": {
        "skill": "skills/canon-solve-tail/SKILL.md",
        "scripts": ["mma/SolveTail.wls"],
        "inputs": {
            "full_sector_de": "artifact:full_sector_de",
            "core_transform": "artifact:core_transform",
            "accepted_prefix": "artifact?:accepted_prefix",
            "tail_options": "option?:tail_options",
        },
        "outputs": ["sector_transform"],
    },
    "CHECK_CANONICAL": {
        "skill": "skills/canon-check-canonical/SKILL.md",
        "scripts": ["mma/CheckCanonical.wls"],
        "inputs": {
            "full_sector_de": "artifact:full_sector_de",
            "sector_transform": "artifact:sector_transform",
            "accepted_prefix": "artifact?:accepted_prefix",
        },
        "outputs": ["canonical_sector_de"],
    },
    "COMMIT_SECTOR": {
        "skill": "skills/canon-commit-sector/SKILL.md",
        "scripts": ["mma/CommitSector.wls"],
        "inputs": {
            "previous_accepted_prefix": "artifact?:accepted_prefix",
            "sector_basis": "artifact:sector_basis",
            "sector_transform": "artifact:sector_transform",
            "canonical_sector_de": "artifact:canonical_sector_de",
        },
        "outputs": ["accepted_prefix"],
    },
    "FINAL_CHECK": {
        "skill": "skills/canon-final-check/SKILL.md",
        "scripts": ["mma/CheckFullSystem.wls"],
        "inputs": {
            "prepared_family": "artifact:prepared_family",
            "master_basis": "artifact:master_basis",
            "sector_manifest": "artifact:sector_manifest",
            "accepted_prefix": "artifact:accepted_prefix",
        },
        "outputs": ["canonical_basis", "canonical_de"],
    },
}

# Global steps receive sector=null.  Every other step is tied to the current
# sector chosen from the DISCOVER metadata.
GLOBAL_STEPS = {"PREPARE", "DISCOVER", "FINAL_CHECK"}

# Result codes are protocol tokens reported by scripts.  They are not computed
# or inferred by Python.
PASS_CODES = {
    "PREPARE": "OK",
    "DISCOVER": "SECTORS_READY",
    "BUILD_CUT_DE": "OK",
    "SEARCH_CORE": "CANDIDATE_READY",
    "CHECK_CORE": "CORE_PASS",
    "BUILD_FULL_DE": "OK",
    "SOLVE_TAIL": "TAIL_READY",
    "CHECK_CANONICAL": "CANONICAL_PASS",
    "COMMIT_SECTOR": "OK",
    "FINAL_CHECK": "ALL_PASS",
}

# Only these failures have an explicit recovery edge.  Any other FAIL/ERROR
# blocks the run instead of asking Python to guess a scientific remedy.
FAIL_ROUTES = {
    ("SEARCH_CORE", "NO_CANDIDATE"): "SEARCH_CORE",
    ("CHECK_CORE", "CORE_FAIL"): "SEARCH_CORE",
    ("SOLVE_TAIL", "TAIL_UNSOLVED"): "SOLVE_TAIL",
    ("CHECK_CANONICAL", "CORE_FAIL"): "SEARCH_CORE",
    ("CHECK_CANONICAL", "TAIL_FAIL"): "SOLVE_TAIL",
}


class WorkflowError(Exception):
    """A malformed command or protocol document that should stop cleanly."""

    pass


def timestamp() -> str:
    """Return an ISO timestamp for state-file bookkeeping."""

    return datetime.now(timezone.utc).isoformat()


def load_json(path: Path) -> dict[str, Any]:
    """Read one JSON object from disk."""

    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        raise WorkflowError(f"cannot read JSON {path}: {exc}") from exc
    if not isinstance(value, dict):
        raise WorkflowError(f"expected a JSON object in {path}")
    return value


def save_json(path: Path, value: dict[str, Any]) -> None:
    """Atomically replace a JSON file.

    Only the coordinator writes state.json, but atomic replacement still keeps
    an interrupted write from leaving half a JSON document.
    """

    path.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.NamedTemporaryFile(
        "w", encoding="utf-8", dir=path.parent, delete=False
    ) as handle:
        json.dump(value, handle, indent=2)
        handle.write("\n")
        temporary = Path(handle.name)
    os.replace(temporary, path)


def absolute(base: Path, raw: str) -> str:
    """Resolve a path relative to the document that declared it."""

    path = Path(raw).expanduser()
    return str((path if path.is_absolute() else base / path).resolve())


def read_project(path: Path) -> dict[str, Any]:
    """Load the small project envelope and normalize its declared paths."""

    raw = load_json(path)
    try:
        family = copy.deepcopy(raw["inputs"]["family_spec"])
        family["path"] = absolute(path.parent, family["path"])
        project = {
            "run_id": raw["run_id"],
            "run_root": absolute(path.parent, raw["run_root"]),
            "inputs": {"family_spec": family},
            "options": copy.deepcopy(raw.get("options", {})),
        }
    except (KeyError, TypeError) as exc:
        raise WorkflowError("project requires run_id, run_root, and family_spec") from exc
    if raw.get("schema") != PROJECT_SCHEMA:
        raise WorkflowError(f"project schema must be {PROJECT_SCHEMA}")
    return project


def load_state(path: Path) -> dict[str, Any]:
    """Load a CANON_neu workflow state."""

    state = load_json(path)
    if state.get("schema") != STATE_SCHEMA:
        raise WorkflowError(f"state schema must be {STATE_SCHEMA}")
    return state


def save_state(path: Path, state: dict[str, Any]) -> None:
    """Persist the coordinator-owned workflow state."""

    state["updated_at"] = timestamp()
    save_json(path, state)


def current_task(state: dict[str, Any], task_id: str | None = None) -> dict[str, Any]:
    """Return the one dispatchable task and optionally verify its id."""

    current_id = state.get("current_task")
    if current_id is None:
        raise WorkflowError("workflow has no current task")
    if task_id is not None and task_id != current_id:
        raise WorkflowError(f"{task_id} is not the current task")
    return state["tasks"][current_id]


def current_sector(state: dict[str, Any]) -> dict[str, int] | None:
    """Return copied sector metadata; never derive it from scientific data."""

    index = state["sector_index"]
    return None if index is None else copy.deepcopy(state["sectors"][index])


def build_payload(state: dict[str, Any], step: str) -> dict[str, Any]:
    """Resolve a step's named inputs from project data or prior artifacts.

    Source prefixes in STAGES have one purpose:
      project:  immutable project input
      artifact: latest reported artifact with that logical name
      option:   opaque user options

    A trailing '?' makes the source optional, for example the absent accepted
    prefix in the first sector.
    """

    payload = {}
    for name, source in STAGES[step]["inputs"].items():
        kind, key = source.split(":", 1)
        optional = kind.endswith("?")
        kind = kind.rstrip("?")
        if kind == "project":
            value = state["project"]["inputs"].get(key)
        elif kind == "artifact":
            value = state["artifacts"].get(key)
        else:
            value = state["project"]["options"].get(key)
        if value is None and not optional:
            raise WorkflowError(f"cannot create {step}: missing input {key}")
        payload[name] = copy.deepcopy(value)
    return payload


def new_task(state: dict[str, Any], step: str) -> dict[str, Any]:
    """Create one READY task and its exact script input.json."""

    state["next_task"] += 1
    task_id = f"T{state['next_task']:04d}-{step}"
    sector = None if step in GLOBAL_STEPS else current_sector(state)
    scope = "global" if sector is None else f"sector-{sector['id']}"
    attempt_key = f"{scope}:{step}"
    attempt = state["attempts"].get(attempt_key, 0) + 1
    state["attempts"][attempt_key] = attempt

    task_dir = Path(state["project"]["run_root"]) / "tasks" / task_id
    input_path = task_dir / "input.json"
    output_dir = task_dir / "output"
    output_dir.mkdir(parents=True, exist_ok=True)
    save_json(
        input_path,
        {
            "schema": INPUT_SCHEMA,
            "task_id": task_id,
            "step": step,
            "sector": sector,
            "payload": build_payload(state, step),
        },
    )
    task = {
        "task_id": task_id,
        "step": step,
        "sector": sector,
        "attempt": attempt,
        "status": "READY",
        "owner": None,
        "input": str(input_path),
        "output_dir": str(output_dir),
        "skill": STAGES[step]["skill"],
        "scripts": copy.deepcopy(STAGES[step]["scripts"]),
        "expected_outputs": copy.deepcopy(STAGES[step]["outputs"]),
        "delegation": {
            "required_roles": copy.deepcopy(STAGES[step].get("roles", [])),
            "assignments": [],
        },
        "result": None,
    }
    state["tasks"][task_id] = task
    state["current_task"] = task_id
    state["phase"] = step
    return task


def task_packet(task: dict[str, Any]) -> dict[str, Any]:
    """Render agent instructions without executing any command.

    The returned wolframscript command is metadata for the agent.  There is no
    subprocess call anywhere in this workflow.
    """

    packet = copy.deepcopy(task)
    packet["skill_path"] = str(ROOT / task["skill"])
    packet["commands"] = [
        [
            "wolframscript",
            "-file",
            str(ROOT / script),
            task["input"],
            task["output_dir"],
        ]
        for script in task["scripts"]
    ]
    packet["result_path"] = str(Path(task["output_dir"]) / "result.json")
    return packet


def normalize_artifacts(
    value: Any, result_path: Path, task: dict[str, Any]
) -> dict[str, Any]:
    """Normalize reported artifact paths while leaving contents opaque."""

    if not isinstance(value, dict):
        raise WorkflowError("result artifacts must be an object")
    artifacts = {}
    for name, descriptor in value.items():
        if not isinstance(descriptor, dict) or not isinstance(
            descriptor.get("path"), str
        ):
            raise WorkflowError(f"artifact {name} must contain a path")
        item = copy.deepcopy(descriptor)
        item["path"] = absolute(result_path.parent, item["path"])
        item["task_id"] = task["task_id"]
        item["step"] = task["step"]
        item["sector"] = copy.deepcopy(task["sector"])
        artifacts[name] = item
    return artifacts


def read_result(path: Path, task: dict[str, Any]) -> dict[str, Any]:
    """Validate only the shared result envelope, never scientific content."""

    result = load_json(path)
    if result.get("schema") != RESULT_SCHEMA:
        raise WorkflowError(f"result schema must be {RESULT_SCHEMA}")
    if result.get("task_id") != task["task_id"] or result.get("step") != task["step"]:
        raise WorkflowError("result does not match the current task")
    if result.get("status") not in {"PASS", "FAIL", "ERROR"}:
        raise WorkflowError("result status must be PASS, FAIL, or ERROR")
    if not isinstance(result.get("code"), str) or not result["code"]:
        raise WorkflowError("result code must be a non-empty string")
    if not isinstance(result.get("summary", {}), dict):
        raise WorkflowError("result summary must be an object")
    result["summary"] = copy.deepcopy(result.get("summary", {}))
    result["artifacts"] = normalize_artifacts(result.get("artifacts"), path, task)
    if result["status"] == "PASS":
        missing = set(task["expected_outputs"]) - set(result["artifacts"])
        if missing:
            raise WorkflowError("PASS result is missing: " + ", ".join(sorted(missing)))
    return result


def sorted_sectors(summary: dict[str, Any]) -> list[dict[str, int]]:
    """Sort script-reported metadata by propagator count, then sector id."""

    sectors = summary.get("sectors")
    if not isinstance(sectors, list) or not sectors:
        raise WorkflowError("DISCOVER/PASS requires summary.sectors")
    compact = []
    for sector in sectors:
        try:
            sector_id = sector["id"]
            count = sector["propagator_count"]
        except (KeyError, TypeError) as exc:
            raise WorkflowError("each sector requires id and propagator_count") from exc
        if (
            not isinstance(sector_id, int)
            or isinstance(sector_id, bool)
            or not isinstance(count, int)
            or isinstance(count, bool)
            or count < 0
        ):
            raise WorkflowError(
                "sector id must be an integer and propagator_count non-negative"
            )
        compact.append({"id": sector_id, "propagator_count": count})
    if len({sector["id"] for sector in compact}) != len(compact):
        raise WorkflowError("sector ids must be unique")
    return sorted(compact, key=lambda sector: (sector["propagator_count"], sector["id"]))


def delegation_ready(task: dict[str, Any]) -> tuple[bool, list[str]]:
    """Check whether every required role has one completed subreport."""

    missing = [
        role
        for role in task["delegation"]["required_roles"]
        if not any(
            item["role"] == role and item["status"] == "DONE"
            for item in task["delegation"]["assignments"]
        )
    ]
    return not missing, missing


def route(state: dict[str, Any], task: dict[str, Any], result: dict[str, Any]) -> str:
    """Apply the fixed workflow transition table.

    The script owns PASS/FAIL and CORE_FAIL/TAIL_FAIL classification.  Python
    only maps those already-reported tokens to the next step.
    """

    step, status, code = task["step"], result["status"], result["code"]
    if status == "ERROR":
        return "BLOCKED"
    if status == "FAIL":
        return FAIL_ROUTES.get((step, code), "BLOCKED")
    if code != PASS_CODES[step]:
        return "BLOCKED"

    next_steps = {
        "PREPARE": "DISCOVER",
        "BUILD_CUT_DE": "SEARCH_CORE",
        "SEARCH_CORE": "CHECK_CORE",
        "CHECK_CORE": "BUILD_FULL_DE",
        "BUILD_FULL_DE": "SOLVE_TAIL",
        "SOLVE_TAIL": "CHECK_CANONICAL",
        "CHECK_CANONICAL": "COMMIT_SECTOR",
    }
    if step in next_steps:
        return next_steps[step]
    if step == "DISCOVER":
        state["sectors"] = sorted_sectors(result["summary"])
        state["sector_index"] = 0
        return "BUILD_CUT_DE"
    if step == "COMMIT_SECTOR":
        state["accepted"].append(current_sector(state))
        next_index = state["sector_index"] + 1
        if next_index < len(state["sectors"]):
            state["sector_index"] = next_index
            return "BUILD_CUT_DE"
        return "FINAL_CHECK"
    if step == "FINAL_CHECK":
        return "DONE"
    raise WorkflowError(f"no route defined for {step}")


def board(state: dict[str, Any]) -> dict[str, Any]:
    """Build the compact progress view returned by the status command."""

    task = None if state["current_task"] is None else current_task(state)
    ready, missing = (True, []) if task is None else delegation_ready(task)
    return {
        "run_id": state["project"]["run_id"],
        "workflow_status": state["status"],
        "phase": state["phase"],
        "current_sector": None if task is None else task["sector"],
        "sector_order": state["sectors"],
        "accepted_sectors": state["accepted"],
        "current_task": None
        if task is None
        else {
            "task_id": task["task_id"],
            "step": task["step"],
            "status": task["status"],
            "owner": task["owner"],
            "attempt": task["attempt"],
            "skill": task["skill"],
            "scripts": task["scripts"],
            "delegation_ready": ready,
            "missing_delegation_roles": missing,
            "input": task["input"],
        },
    }


def command_init(args: argparse.Namespace) -> None:
    """Initialize state.json and create the first PREPARE task."""

    project_path = Path(args.project).expanduser().resolve()
    project = read_project(project_path)
    state_path = (
        Path(args.state).expanduser().resolve()
        if args.state
        else Path(project["run_root"]) / "state.json"
    )
    if state_path.exists():
        raise WorkflowError(f"state already exists: {state_path}")
    state = {
        "schema": STATE_SCHEMA,
        "status": "ACTIVE",
        "phase": "PREPARE",
        "project": project,
        "sectors": [],
        "sector_index": None,
        "accepted": [],
        "artifacts": {},
        "attempts": {},
        "next_task": 0,
        "current_task": None,
        "tasks": {},
        "updated_at": timestamp(),
    }
    task = new_task(state, "PREPARE")
    save_state(state_path, state)
    print(f"initialized: {state_path}")
    print(f"next task: {task['task_id']}")


def command_status(args: argparse.Namespace) -> None:
    """Show the current workflow board without mutating it."""

    value = board(load_state(Path(args.state).expanduser().resolve()))
    if args.json:
        print(json.dumps(value, indent=2))
        return
    print(f"workflow: {value['workflow_status']}  phase: {value['phase']}")
    print(f"sector: {value['current_sector']}")
    print(f"accepted: {[sector['id'] for sector in value['accepted_sectors']]}")
    task = value["current_task"]
    if task is None:
        print("current task: none")
        return
    print(
        f"current task: {task['task_id']}  {task['status']}  "
        f"attempt {task['attempt']}"
    )
    print(f"skill: {task['skill']}")
    print(f"scripts: {', '.join(task['scripts'])}")
    if task["missing_delegation_roles"]:
        print("delegation required: " + ", ".join(task["missing_delegation_roles"]))


def command_next(args: argparse.Namespace) -> None:
    """Dispatch the current task packet to an agent."""

    state = load_state(Path(args.state).expanduser().resolve())
    if state["status"] != "ACTIVE":
        raise WorkflowError(f"workflow is {state['status']}")
    packet = task_packet(current_task(state))
    if args.json:
        print(json.dumps(packet, indent=2))
        return
    print(f"task: {packet['task_id']} ({packet['step']})")
    print(f"sector: {packet['sector']}")
    print(f"skill: {packet['skill_path']}")
    print(f"input: {packet['input']}")
    print(f"result: {packet['result_path']}")
    for command in packet["commands"]:
        print("command: " + " ".join(command))
    if packet["delegation"]["required_roles"]:
        print("required subagent roles: " + ", ".join(packet["delegation"]["required_roles"]))


def command_start(args: argparse.Namespace) -> None:
    """Claim the READY task for one main agent."""

    state_path = Path(args.state).expanduser().resolve()
    state = load_state(state_path)
    task = current_task(state, args.task_id)
    if state["status"] != "ACTIVE" or task["status"] != "READY":
        raise WorkflowError("start requires an ACTIVE workflow and READY task")
    task["status"], task["owner"] = "RUNNING", args.agent
    save_state(state_path, state)
    print(f"started: {task['task_id']} by {args.agent}")


def command_delegate(args: argparse.Namespace) -> None:
    """Record a required subagent role and its assigned script."""

    state_path = Path(args.state).expanduser().resolve()
    state = load_state(state_path)
    task = current_task(state, args.task_id)
    if task["status"] != "RUNNING" or task["owner"] != args.agent:
        raise WorkflowError("only the owner of a RUNNING task may delegate")
    if args.role not in task["delegation"]["required_roles"]:
        raise WorkflowError(f"role is not required: {args.role}")
    if args.script not in task["scripts"]:
        raise WorkflowError(f"script is not allowed: {args.script}")
    if any(item["subagent"] == args.subagent for item in task["delegation"]["assignments"]):
        raise WorkflowError(f"subagent is already assigned: {args.subagent}")
    task["delegation"]["assignments"].append(
        {
            "subagent": args.subagent,
            "role": args.role,
            "script": args.script,
            "status": "ASSIGNED",
            "result": None,
        }
    )
    save_state(state_path, state)
    print(f"delegated: {task['task_id']} -> {args.subagent} ({args.role})")


def command_subreport(args: argparse.Namespace) -> None:
    """Attach a standard script result to one subagent assignment."""

    state_path = Path(args.state).expanduser().resolve()
    result_path = Path(args.result).expanduser().resolve()
    state = load_state(state_path)
    task = current_task(state, args.task_id)
    matches = [
        item
        for item in task["delegation"]["assignments"]
        if item["subagent"] == args.subagent
    ]
    if len(matches) != 1:
        raise WorkflowError(f"no unique assignment for {args.subagent}")
    result = read_result(result_path, task)
    assignment = matches[0]
    assignment["status"] = "FAILED" if result["status"] == "ERROR" else "DONE"
    assignment["result"] = {"path": str(result_path), **result}
    save_state(state_path, state)
    print(f"subagent report: {args.subagent} -> {assignment['status']}")


def command_report(args: argparse.Namespace) -> None:
    """Record the main result, route it, and create the next task."""

    state_path = Path(args.state).expanduser().resolve()
    result_path = Path(args.result).expanduser().resolve()
    state = load_state(state_path)
    task = current_task(state, args.task_id)
    if state["status"] != "ACTIVE" or task["status"] != "RUNNING":
        raise WorkflowError("report requires an ACTIVE workflow and RUNNING task")
    ready, missing = delegation_ready(task)
    if not ready:
        raise WorkflowError("required subagent reports are missing: " + ", ".join(missing))

    result = read_result(result_path, task)
    destination = route(state, task, result)
    task["result"] = {"path": str(result_path), **result}
    for name, descriptor in result["artifacts"].items():
        state["artifacts"][name] = copy.deepcopy(descriptor)

    if destination == "BLOCKED":
        task["status"], state["status"] = "BLOCKED", "BLOCKED"
        save_state(state_path, state)
        print(f"blocked: {task['task_id']} -> {result['status']}/{result['code']}")
        return

    task["status"], state["current_task"] = "DONE", None
    if destination == "DONE":
        state["status"], state["phase"] = "DONE", "DONE"
        save_state(state_path, state)
        print("workflow complete: DONE")
        return
    next_task = new_task(state, destination)
    save_state(state_path, state)
    print(f"recorded: {task['task_id']} -> {result['status']}/{result['code']}")
    print(f"next task: {next_task['task_id']}")


def parser() -> argparse.ArgumentParser:
    """Define the intentionally small agent-facing CLI."""

    root = argparse.ArgumentParser(description=__doc__)
    commands = root.add_subparsers(dest="command", required=True)
    specs = {
        "init": command_init,
        "status": command_status,
        "next": command_next,
        "start": command_start,
        "delegate": command_delegate,
        "subreport": command_subreport,
        "report": command_report,
    }
    for name, handler in specs.items():
        command = commands.add_parser(name)
        command.set_defaults(handler=handler)
        if name == "init":
            command.add_argument("project")
            command.add_argument("--state")
            continue
        command.add_argument("state")
        if name in {"start", "delegate", "subreport", "report"}:
            command.add_argument("task_id")
        if name in {"subreport", "report"}:
            command.add_argument("result")
        if name == "start":
            command.add_argument("--agent", required=True)
        if name == "delegate":
            command.add_argument("--agent", required=True)
            command.add_argument("--subagent", required=True)
            command.add_argument("--role", required=True)
            command.add_argument("--script", required=True)
        if name == "subreport":
            command.add_argument("--subagent", required=True)
        if name in {"status", "next"}:
            command.add_argument("--json", action="store_true")
    return root


def main() -> int:
    """Run one CLI command and present protocol errors without a traceback."""

    args = parser().parse_args()
    try:
        args.handler(args)
    except WorkflowError as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 2
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
