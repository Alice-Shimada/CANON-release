#!/usr/bin/env python3
"""Prepare caller-owned engineering fixtures with independent literal expectations."""
import argparse,hashlib,json
from pathlib import Path
def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def put(p,v):Path(p).write_text(json.dumps(v,indent=2)+"\n")
def main():
 ap=argparse.ArgumentParser();ap.add_argument("--work",type=Path,required=True);w=ap.parse_args().work.resolve()
 cfg=json.loads((w/"test-config.json").read_text());rt=json.loads(Path(cfg["normal_runtime"]).read_text())
 helper=Path(cfg.get("arithmetic_helper",w/"flint-phase/ConstructionArithmetic.wl"))
 tests=w/"tests";tests.mkdir(exist_ok=True);faults=w/"faults";faults.mkdir(exist_ok=True)
 (faults/"EmptyHelper.wl").write_text("Null;\n")
 (faults/"FaultNative.py").write_text('''#!/usr/bin/env python3
"""Test-only injection; real C++ and executable remain unchanged."""
import json,os,sys
from pathlib import Path
real=os.environ["CANON_TEST_FLINT_REAL_EXE"]
if sys.argv[1]=="--version":os.execv(real,[real,"--version"])
mode=os.environ["CANON_TEST_FLINT_FAULT"]
if mode=="cancel":
 fifo=Path(sys.argv[1]).parent/"cancellation-native.fifo";os.mkfifo(fifo)
 Path(os.environ["CANON_TEST_NATIVE_RECEIPT"]).write_text("actual native exec queued")
 os.execv(real,[real,str(fifo),"--batch"])
if mode=="native-error":
 sys.stderr.write("ERROR: test-only injected native failure\\n");sys.exit(2)
outputs={"malformed":"Get[\\\"bad\\\"]\\n0\\n","unknown-index":"v999\\n0\\n","inexact-output":"0.5\\n0\\n","zero-denominator":"1/0\\n0\\n","bad-count":"0\\n","dummy-leak":"v0\\n0\\n","bad-receipt":"v0\\n0\\n","bad-zero-flag":"v0\\n0\\n"}
sys.stdout.write(outputs[mode])
sys.stderr.write(json.dumps({"header_version":"3.4.0","runtime_version":"3.4.0","count":2 if mode=="bad-receipt" else 1,"all_zero":mode=="bad-zero-flag","native_seconds":0.0})+"\\n")
''')
 (faults/"FaultNative.py").chmod(0o755)
 for name in ["fault-native","invalid-threads","unavailable-native","unavailable-helper","empty-helper"]:
  c=json.loads(json.dumps(rt))
  if name=="fault-native":c["flint_executable"]={"path":str(faults/"FaultNative.py"),"sha256":sha(faults/"FaultNative.py")}
  elif name=="invalid-threads":c["flint_threads"]=2
  elif name=="unavailable-native":c["flint_executable"]={"path":str(faults/"absent-native"),"sha256":"0"*64}
  elif name=="unavailable-helper":c["flint_helper"]={"path":str(faults/"absent-helper"),"sha256":"0"*64}
  else:c["flint_helper"]={"path":str(faults/"EmptyHelper.wl"),"sha256":sha(faults/"EmptyHelper.wl")}
  put(w/"runtime"/(name+".json"),c)
 cfg["environment"]["CANON_TEST_FLINT_REAL_EXE"]=rt["flint_executable"]["path"]
 cfg["cancel_native_executable"]=rt["flint_executable"]["path"]
 cfg["guarded_sources"] += [str(faults/"FaultNative.py")]
 put(w/"test-config.json",cfg)
 cases=json.loads((w/"cases.json").read_text());base=json.loads((w/"templates/rational-nonzero.json").read_text())
 phases=["source_current_lower_reduce","current_core_inverse_reduce","candidate_lower_transform_reduce","candidate_full_gauge_reduce"]
 policy={p:"flint" if p=="candidate_lower_transform_reduce" else "together" for p in phases}
 for name,default,overrides in [("all-flint","flint",{}),("mixed-four-backends","together",dict(zip(phases,["together","finiteflow","flint","fermat"])))]:
  request=json.loads(json.dumps(base));request["task_id"]="T-024:"+name
  request["payload"]["method_options"]={"normalization_backend":default,"normalization_backends":overrides,"runtime_config":{"path":cfg["normal_runtime"],"sha256":sha(cfg["normal_runtime"])}}
  p=w/"templates"/(name+".json");put(p,request)
  cases.append({"name":name,"template":str(p),"expected_status":"PASS","expected_name":"rational-nonzero","default_backend":default,"effective_map":{**{p:default for p in phases},**overrides}})
 x="CANON`DEData`x";y="CANON`DEData`y";L="(1+"+x+"+"+y+")"
 matrix=lambda body:"{{"+body+"}}"
 pairs=[
 ("rational-pairs",matrix("("+x+"^2-1)/("+x+"-1),-1/(1+"+x+"),0,-2/3"),matrix(x+"+1,-1/(1+"+x+"),0,-2/3")),
 ("quadratic-pairs","{{Sqrt["+L+"],-1/Sqrt["+L+"],"+L+"^(3/2),(1+Sqrt["+L+"])/(1-Sqrt["+L+"])},{0,Sqrt["+L+"]/(1+"+x+"),1/"+L+"^(3/2),(Sqrt["+L+"]+"+x+")/(Sqrt["+L+"]-"+x+")}}",
  "{{Sqrt["+L+"],-Sqrt["+L+"]/"+L+","+L+"*Sqrt["+L+"],(1+"+L+"+2*Sqrt["+L+"])/(1-"+L+")},{0,Sqrt["+L+"]/(1+"+x+"),Sqrt["+L+"]/"+L+"^2,("+L+"+"+x+"^2+2*"+x+"*Sqrt["+L+"])/("+L+"-"+x+"^2)}}"),
 ("pure-generator",matrix("Sqrt["+L+"]"),matrix("Sqrt["+L+"]")),
 ("constant-rational","{{0,2/3,-7},{1,3,1/5}}","{{0,2/3,-7},{1,3,1/5}}"),
 ("constant-quadratic","{{0,2/3,-7},{Sqrt[2],-1/Sqrt[2],2^(3/2)}}","{{0,2/3,-7},{Sqrt[2],-Sqrt[2]/2,2*Sqrt[2]}}")]
 def probe(name,expression,runtime="normal",status="PASS",code=None,fault=None,expected=None):
  f=tests/(name+"-input.wl");f.write_text(expression+"\n");rp=w/"runtime"/(runtime+".json")
  request={"schema":"canon-neu/script-input/v1","task_id":"T-024:"+name,"step":"NORMALIZE_FLINT_FIXTURE","payload":{"matrix":{"path":str(f),"sha256":sha(f)},"arithmetic_helper":{"path":str(helper),"sha256":sha(helper)},"method_options":{"normalization_backend":"together","normalization_backends":{"candidate_lower_transform_reduce":"flint"},"runtime_config":{"path":str(rp),"sha256":sha(rp)}}}}
  p=w/"templates"/(name+".json");put(p,request)
  case={"name":name,"template":str(p),"expected_status":status,"kind":"probe","effective_map":policy,"default_backend":"together","input_matrix_path":str(f)}
  if expected:
   e=tests/(name+"-expected.wl");e.write_text(expected+"\n");case["expected_matrix_path"]=str(e)
  if code:case.update(expected_code=code,error_backend="flint")
  if fault:case["environment"]={"CANON_TEST_FLINT_FAULT":fault}
  return case
 for name,expr,expected in pairs:cases.append(probe(name,expr,expected=expected))
 for name,expr in [("multiple-roots",matrix("Sqrt[1+"+x+"]+Sqrt[1+"+y+"]")),("nested-root",matrix("Sqrt[1+Sqrt[1+"+x+"]]")),("cubic",matrix(x+"^(1/3)")),("inexact",matrix("0.5+"+x)),("transcendental",matrix("Sin["+x+"]"))]:
  cases.append(probe(name,expr,status="ERROR",code="UNSUPPORTED_ARITHMETIC_DOMAIN"))
 for name in ["invalid-threads","unavailable-native","unavailable-helper","empty-helper"]:
  cases.append(probe(name,matrix(x),name,status="ERROR",code="INVALID_ARITHMETIC_CONFIG" if name=="invalid-threads" else "ARITHMETIC_BACKEND_UNAVAILABLE"))
 for name in ["malformed","unknown-index","inexact-output","zero-denominator","bad-count","dummy-leak","bad-receipt","bad-zero-flag","native-error"]:
  cases.append(probe(name,matrix("1" if name=="dummy-leak" else x),"fault-native",status="ERROR",code="ARITHMETIC_NORMALIZATION_FAILED",fault=name))
 put(w/"cases.json",cases)
 cancel=json.loads(json.dumps(base));cancel["task_id"]="T-024:cancel"
 cancel["payload"]["method_options"]["runtime_config"]={"path":str(w/"runtime/fault-native.json"),"sha256":sha(w/"runtime/fault-native.json")}
 put(w/"templates/cancel.json",cancel)
if __name__=="__main__":main()
