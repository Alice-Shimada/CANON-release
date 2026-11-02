#!/usr/bin/env python3
"""Index retained normalization checks plus corrected FINAL checks; no mathematical replay."""
import argparse,json,hashlib
from pathlib import Path

def read(p):return json.loads(p.read_text())
def ref(p):return {'path':str(p.resolve()),'sha256':hashlib.sha256(p.read_bytes()).hexdigest()}
p=argparse.ArgumentParser();p.add_argument('--cases',type=Path,required=True);p.add_argument('--retained',type=Path,required=True);p.add_argument('--current',type=Path,required=True);p.add_argument('--output',type=Path,required=True);a=p.parse_args()
cases=read(a.cases);retained=read(a.retained);current=read(a.current)
normal={c['name'] for c in cases if c['kind']=='normalization'};final={c['name'] for c in cases if c['kind']=='final'}
assert normal and final and set(current['checks'])==final
assert normal <= set(retained['checks'])
checks={n:retained['checks'][n] for n in normal};checks.update(current['checks'])
all_pass=set(checks)=={c['name'] for c in cases} and all(isinstance(row,dict) and row and all(v is True for v in row.values()) for row in checks.values())
result={'all_pass':all_pass,'check_count':sum(map(len,checks.values())),'case_count':len(checks),'checks':checks,'sources':{'retained_normalization':ref(a.retained),'corrected_final':ref(a.current)},'retained_normalization_cases':len(normal),'corrected_final_cases':len(final),'retained_normalization_flags':sum(len(checks[n]) for n in normal),'corrected_final_flags':sum(len(checks[n]) for n in final),'superseded_assertions':[n+'/epsilon_dependent_invertible_map' for n in sorted(final)],'correction':'Old Boolean-versus-zero assertion was tautological; corrected FINAL checks prove an exact finite nonsingular-point determinant. No normalization/FINAL replay; other42 cases are retained.','scientific_acceptance':False}
a.output.write_text(json.dumps(result,indent=2)+'\n');assert all_pass
