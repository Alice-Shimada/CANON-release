#!/usr/bin/env python3
"""Bind existing result artifacts into a normal scientific request."""

import argparse
import hashlib
import json
import os
from pathlib import Path


def read_json(path):
    return json.loads(path.read_text(encoding="utf-8"))


def resolve(declaring_file, path):
    return (declaring_file.parent / path).resolve()


def bind_request(template, declaring_file, destination):
    """Resolve artifact references; literal provider options remain data."""
    results = {}

    def bind(value, origin):
        if isinstance(value, list):
            return [bind(item, origin) for item in value]
        if not isinstance(value, dict):
            return value
        if "from_result" in value:
            source = resolve(origin, value["from_result"])
            if source not in results:
                result = read_json(source)
                if result["schema"] != "canon-neu/script-result/v1" or result["status"] not in {"PASS", "PROVISIONAL"}:
                    raise ValueError(f"Result is not usable for artifact binding: {source}")
                results[source] = result
            return bind(results[source]["artifacts"][value["artifact"]], source)
        bound = {key: bind(item, origin) for key, item in value.items()}
        if "path" in value:
            bound["path"] = os.path.relpath(resolve(origin, value["path"]), destination.parent)
        return bound

    if template["schema"] != "canon-neu/script-input/v1":
        raise ValueError("Template must use canon-neu/script-input/v1")
    return {**template, "payload": bind(template["payload"], declaring_file)}


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("input", type=Path)
    parser.add_argument("output", type=Path)
    args = parser.parse_args(argv)
    input_path, output = args.input.resolve(), args.output.resolve()
    task = read_json(input_path)
    output.mkdir(parents=True)
    result = {"schema": "canon-neu/script-result/v1", "task_id": task["task_id"],
              "step": task["step"], "artifacts": {}}
    try:
        if task["schema"] != "canon-neu/script-input/v1" or task["step"] != "PREPARE_REQUEST":
            raise ValueError("Expected a PREPARE_REQUEST script-input/v1 request")
        template_path = resolve(input_path, task["payload"]["template"]["path"])
        destination = output / "request.json"
        request = bind_request(read_json(template_path), template_path, destination)
        prepared_step = request["step"]
        destination.write_text(json.dumps(request, indent=2) + "\n", encoding="utf-8")
        result.update(status="PASS", code="REQUEST_READY", artifacts={"request": {
            "type": "json", "path": destination.name,
            "sha256": hashlib.sha256(destination.read_bytes()).hexdigest()}},
            summary={"prepared_step": prepared_step})
    except (OSError, ValueError, KeyError, TypeError) as exc:
        result.update(status="ERROR", code="REQUEST_BINDING_FAILED", summary={"reason": str(exc)})
    (output / "result.json").write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
    return 0 if result["status"] == "PASS" else 1


if __name__ == "__main__":
    raise SystemExit(main())
