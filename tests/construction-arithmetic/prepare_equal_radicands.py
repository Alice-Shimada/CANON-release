#!/usr/bin/env python3
"""Create portable case templates from the public radicand fixture producer."""
import argparse
import copy
import hashlib
import json
from pathlib import Path

def read(path): return json.loads(Path(path).read_text())
def write(path,value):
    path.parent.mkdir(parents=True,exist_ok=True)
    path.write_text(json.dumps(value,indent=2)+"\n")
def ref(path):
    path=Path(path).resolve()
    return {"path":str(path),"sha256":hashlib.sha256(path.read_bytes()).hexdigest()}
def prepare(work):
    cfg=read(work/"test-config.json");fixtures=Path(cfg["fixture_directory"]).resolve()
    helper=ref(cfg.get("arithmetic_helper",str(Path(cfg["project_root"])/"mma/lib/ConstructionArithmetic.wl")))
    phases=("source_current_lower_reduce","current_core_inverse_reduce","candidate_lower_transform_reduce","candidate_full_gauge_reduce")
    cases=[]
    def add(name,task,positive,kind,**extra):
        task["task_id"]="equal-radicand:"+name
        path=work/"templates"/(name+".json");write(path,task)
        case={"name":name,"template":str(path),"expected_status":"PASS" if positive else "ERROR","kind":kind,
          "default_backend":"together","effective_map":{p:task["payload"]["method_options"]["normalization_backends"].get(p,"together") for p in phases},**extra}
        if not positive:case.update(expected_code="UNSUPPORTED_ARITHMETIC_DOMAIN",error_backend="flint")
        cases.append(case)
    for version in ("old","new"):
        runtime=ref(cfg["old_runtime"] if version=="old" else cfg["normal_runtime"])
        full=copy.deepcopy(read(fixtures/"mixed-full.json"))
        for key,value in list(full["payload"].items()):
            if isinstance(value,dict) and "path" in value:full["payload"][key]=ref(fixtures/value["path"])
        full["payload"]["method_options"]={"normalization_backend":"together","normalization_backends":{
          "candidate_lower_transform_reduce":"flint","candidate_full_gauge_reduce":"flint"},"runtime_config":runtime}
        extra={"expected_path":str(fixtures/"mixed-expected.wl")}
        if version=="old":extra.update(expected_error_phase="candidate_full_gauge_reduce",expected_reason="Only one explicit quadratic generator is supported.")
        add(version+"-mixed-full",full,version=="new","full-gauge",**extra)
    for probe in read(fixtures/"probes.json"):
        for version in (("old","new") if probe["name"]=="physical-spellings" else ("new",)):
            runtime=ref(cfg["old_runtime"] if version=="old" else cfg["normal_runtime"])
            task={"schema":"canon-neu/script-input/v1","step":"NORMALIZE_FLINT_FIXTURE","payload":{
              "matrix":ref(fixtures/probe["input"]["path"]),"arithmetic_helper":helper,"method_options":{
              "normalization_backend":"together","normalization_backends":{"candidate_lower_transform_reduce":"flint"},"runtime_config":runtime}}}
            extra={"input_matrix_path":str(fixtures/probe["input"]["path"])}
            if probe["positive"]:extra["expected_matrix_path"]=str(fixtures/probe["expected"]["path"])
            add(version+"-"+probe["name"],task,version=="new" and probe["positive"],"probe",**extra)
    write(work/"cases.json",cases)
    return cases
if __name__=="__main__":
    parser=argparse.ArgumentParser();parser.add_argument("--work",type=Path,required=True)
    prepare(parser.parse_args().work.resolve())
