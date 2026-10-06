#!/usr/bin/env python3
"""Run a finite sequence of configured commands, then normalize declared exports."""
import hashlib
import json
from pathlib import Path
import subprocess
import sys


def resolve(base, path):
    value = Path(path)
    return value.resolve() if value.is_absolute() else (base / value).resolve()


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def normalize_commands(operation, tokens, backend_dir):
    """Bind either public command form to one ordered list of literal argv lists."""
    if ("argv" in operation) == ("commands" in operation):
        raise ValueError("Command mode requires exactly one of argv or commands.")
    commands = [operation["argv"]] if "argv" in operation else operation["commands"]
    if not isinstance(commands, list) or not commands:
        raise ValueError("commands must be a nonempty list of argv lists.")
    bound = []
    for command in commands:
        if not isinstance(command, list) or not command or not all(isinstance(value, str) for value in command) or not command[0]:
            raise ValueError("Every command must be a nonempty argv list of strings.")
        command = [replace_tokens(value, tokens) for value in command]
        if "/" in command[0] or "\\" in command[0]:
            command[0] = str(resolve(backend_dir, command[0]))
        bound.append(command)
    return bound


def main():
    canon, wolfram, adapter, package, request_path, output = sys.argv[1:]
    canon, package, request_path, output = map(Path, (canon, package, request_path, output))
    output.mkdir(parents=True, exist_ok=True)
    if (output / "result.json").exists():
        raise SystemExit("Output already contains result.json; use a fresh output directory.")
    task = json.loads(request_path.read_text())

    def error(code, reason):
        value = dict(schema="canon-neu/script-result/v1", task_id=task["task_id"], step=task["step"],
                     status="ERROR", code=code, artifacts={}, summary={"reason": reason})
        (output / "result.json").write_text(json.dumps(value, indent=2) + "\n")

    try:
        descriptor = task["payload"]["backend"]
        if "payload_key" in descriptor:
            raise ValueError("Legacy nested reduction settings belong to the default Kira adapter.")
        backend_path = resolve(request_path.parent, descriptor["path"])
        if "sha256" in descriptor and descriptor["sha256"] != sha(backend_path):
            raise ValueError("Backend descriptor hash does not match its file.")
        backend = json.loads(backend_path.read_text())
        if backend.get("schema") != "canon-neu/native-backend/v1" or backend.get("adapter") != adapter:
            raise ValueError("Backend schema/adapter does not match the selected component.")
        operation = backend.get("operations", {}).get(task["step"])
        if operation is None:
            error("UNSUPPORTED_NATIVE_OPERATION", "Configure an explicit exporter for this operation.")
            return
        mode = operation.get("mode")
        if mode not in ("import", "command"):
            raise ValueError("Operation mode must be import or command.")
        native_output = output / "native"
        native_output.mkdir(exist_ok=True)
        context_path = output / "native-context.json"
        context = dict(schema="canon-neu/native-call/v1", adapter=adapter, step=task["step"],
                       request=str(request_path.resolve()), backend=str(backend_path), canon=str(canon.resolve()),
                       adapter_package=str(package.resolve()), normalizer=str(Path(__file__).resolve().parent),
                       output=str(native_output.resolve()), wolframscript=wolfram)
        context_path.write_text(json.dumps(context, indent=2) + "\n")
        commands = []
        if mode == "command":
            tokens = {"{python}": sys.executable, "{wolframscript}": wolfram, "{package}": str(package.resolve()),
                      "{backend_dir}": str(backend_path.parent), "{context}": str(context_path.resolve()),
                      "{input}": str(request_path.resolve()), "{output}": str(native_output.resolve())}
            commands = normalize_commands(operation, tokens, backend_path.parent)
        export_base = backend_path.parent if mode == "import" else native_output
        exports = {key: str(resolve(export_base, value)) for key, value in operation.get("exports", {}).items()}
        if mode == "command" and any(not Path(value).is_relative_to(native_output.resolve()) for value in exports.values()):
            raise ValueError("Command exports must be newly written inside the native output directory.")
        runtime = dict(schema="canon-neu/native-normalization-run/v1", adapter=adapter, backend=str(backend_path),
                       backend_sha256=sha(backend_path), mode=mode, driver_executed=False,
                       argv=commands[0] if len(commands) == 1 else [], commands=commands, command_results=[],
                       exports=exports, source_format=operation.get("source_format", ""),
                       native_engine_validation="not established by artifact normalization")
        runtime_path = output / "normalization-run.json"

        def save_runtime():
            runtime_path.write_text(json.dumps(runtime, indent=2) + "\n")

        save_runtime()
        if mode == "command":
            with (output / "native-driver.log").open("w") as log:
                for index, command in enumerate(commands, 1):
                    log.write(f"Command {index}: {json.dumps(command)}\n")
                    log.flush()
                    try:
                        result = subprocess.run(command, cwd=native_output, stdout=log, stderr=subprocess.STDOUT)
                    except OSError as exc:
                        runtime["command_results"].append(dict(index=index, argv=command, exit_code=None, error=str(exc)))
                        save_runtime()
                        error("NATIVE_DRIVER_FAILED", f"Command {index} could not start: {exc}")
                        return
                    runtime["driver_executed"] = True
                    runtime["command_results"].append(dict(index=index, argv=command, exit_code=result.returncode))
                    save_runtime()
                    if result.returncode:
                        error("NATIVE_DRIVER_FAILED", f"Command {index} exited {result.returncode}; inspect native-driver.log.")
                        return
        driver_receipt = native_output / "driver-receipt.json"
        if mode == "command" and driver_receipt.is_file():
            runtime["driver_receipt"] = json.loads(driver_receipt.read_text())
        save_runtime()
        result = subprocess.run([wolfram, "-file", str(Path(__file__).with_name("Normalize.wls")),
                                 str(canon.resolve()), str(request_path.resolve()), str(output.resolve()), str(runtime_path.resolve())], cwd=output)
        if result.returncode:
            try:
                reported = json.loads((output / "result.json").read_text())
            except (OSError, ValueError):
                reported = {}
            if reported.get("status") not in ("ERROR", "FAIL", "INCONCLUSIVE"):
                error("NORMALIZATION_PROCESS_FAILED", f"Normalizer exited {result.returncode}.")
    except (KeyError, ValueError, OSError) as exc:
        error("INVALID_NATIVE_BACKEND", str(exc))


def replace_tokens(value, tokens):
    for token, replacement in tokens.items():
        value = value.replace(token, replacement)
    return value


if __name__ == "__main__":
    main()
