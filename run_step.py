#!/usr/bin/env python3
"""Run one scientific step using the selected component package."""

import argparse
import json
import os
from pathlib import Path
import sys


ROOT = Path(__file__).resolve().parent
DEFAULT_COMPONENTS = ROOT / "components" / "default.json"


def component_paths(selection=None):
    """Accept the original single path or an ordered list of package manifests."""
    if selection is None or selection == "":
        return []
    if isinstance(selection, (str, os.PathLike)):
        value = str(selection)
        selection = json.loads(value) if value.lstrip().startswith("[") else [value]
    return [Path(path).resolve() for path in selection]


def manifests(path, parents=()):
    path = Path(path).resolve()
    if path in parents:
        raise ValueError(f"component include cycle: {' -> '.join(map(str, (*parents, path)))}")
    manifest = json.loads(path.read_text(encoding="utf-8"))
    if manifest["schema"] != "canon-neu/components/v1":
        raise ValueError(f"unsupported component schema: {path}")
    for included in manifest.get("extends", []):
        yield from manifests(path.parent / included, (*parents, path))
    yield path, manifest


def resolve_entry(name, entry, path, parents=()):
    """Bind one step without importing the other steps of its provider."""
    identity = (path, name)
    if identity in parents:
        raise ValueError(f"component step reference cycle: {path}: {name}")
    if "from" in entry:
        source = (path.parent / entry["from"]).resolve()
        key = entry.get("step", name)
        included = list(manifests(source))
        candidates = [(p, m, m["steps"][key]) for p, m in included
                      if key in m["steps"]]
        if not candidates:
            raise ValueError(f"no component for {key} in {source}")
        origin, manifest, definition = candidates[-1]
        bound, workflows = resolve_entry(key, definition, origin, (*parents, identity))
        for provider, metadata in included:
            if "workflow" in metadata:
                workflows.append({"manifest": str(provider),
                                  "instructions": str((provider.parent / metadata["workflow"]).resolve())})
        if "instructions" in entry:
            bound["instructions"] = str((path.parent / entry["instructions"]).resolve())
        bound["binding_manifest"] = str(path)
        return bound, workflows
    substitutions = {
        "package": str(path.parent), "canon": str(ROOT),
        "python": sys.executable,
        "wolframscript": os.environ.get("CANON_WOLFRAMSCRIPT", "wolframscript"),
    }
    bound = {"command": [arg.format_map(substitutions) for arg in entry["command"]],
             "instructions": str((path.parent / entry["instructions"]).resolve()),
             "manifest": str(path)}
    if "interface" in entry:
        bound["interface"] = entry["interface"]
    return bound, []


def resolve_components(selection=None):
    entries, workflows = {}, {}
    paths = [DEFAULT_COMPONENTS, *component_paths(selection)]
    for path, manifest in (item for path in paths for item in manifests(path)):
        for name, entry in manifest["steps"].items():
            entries[name], selected_workflows = resolve_entry(name, entry, path)
            for selected in selected_workflows:
                workflows[selected["instructions"]] = selected
        if "workflow" in manifest:
            instructions = str((path.parent / manifest["workflow"]).resolve())
            workflows[instructions] = {"manifest": str(path), "instructions": instructions}
    return entries, list(workflows.values())


def load_components(package=None):
    return resolve_components(package)[0]


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("input", type=Path, nargs="?")
    parser.add_argument("output", type=Path, nargs="?")
    selection = parser.add_mutually_exclusive_group()
    selection.add_argument("--components", type=Path, action="append",
                           help="package manifest; repeat to compose packages in order")
    selection.add_argument("--defaults", action="store_true",
                           help="use only built-in components, ignoring CANON_COMPONENTS")
    parser.add_argument("--method", help="explicit method for a step with several implementations")
    parser.add_argument("--list", action="store_true", help="list resolved components without running them")
    parser.add_argument("--describe", action="store_true", help="print the selected invocation without running it")
    args = parser.parse_args(argv)
    if not args.list and (args.input is None or args.output is None):
        parser.error("INPUT.json and OUTPUT_DIR are required")
    try:
        packages = component_paths([] if args.defaults else
                                   args.components or os.environ.get("CANON_COMPONENTS"))
        entries, workflows = resolve_components(packages)
        if args.list:
            print(json.dumps(entries, indent=2))
            return 0
        input_path = args.input.resolve()
        task = json.loads(input_path.read_text(encoding="utf-8"))
        key = task["step"] + (f"/{args.method}" if args.method else "")
        if key not in entries:
            parser.error(f"no component for {key}; use --list and select --method when needed")
        entry = entries[key]
        command = entry["command"] + [str(input_path), str(args.output.resolve())]
    except (OSError, ValueError, KeyError) as exc:
        parser.error(str(exc))
    if args.describe:
        print(json.dumps({"step": key, **entry, "command": command,
                          "components": list(map(str, packages)),
                          "workflows": workflows}, indent=2))
        return 0
    environment = os.environ.copy()
    environment["CANON_PYTHON"] = sys.executable
    if packages:
        environment["CANON_COMPONENTS"] = (str(packages[0]) if len(packages) == 1
                                            else json.dumps(list(map(str, packages))))
    else:
        environment.pop("CANON_COMPONENTS", None)
    os.execvpe(command[0], command, environment)


if __name__ == "__main__":
    sys.exit(main())
