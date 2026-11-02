import json,os,subprocess,sys,time
from pathlib import Path
import sympy as S
inp,out=map(Path,sys.argv[-2:]);out.mkdir(parents=True,exist_ok=True)
o=json.loads(inp.read_text())['payload'];exe=Path(o['executable']);cpu=int(o['cpu']);wall=time.monotonic()
x,y=S.symbols('v0 v1');lam=x+y+1
def num(n):return ('n',str(n))
def var(i):return ('v',str(i))
def add(*xs):return ('a',xs)
def mul(*xs):return ('m',xs)
def pow_(x,n):return ('p',(x,n))
def sub(a,b):return add(a,mul(num(-1),b))
xn,yn=var(0),var(1);r=('r',);ln=add(xn,yn,num(1));one=num(1)
def emit(e):
 if e[0]=='r':return 'r\n'
 if e[0] in ['n','v']:return ' '.join(e)+'\n'
 if e[0]=='p':return emit(e[1][0])+'p '+str(e[1][1])+'\n'
 return ''.join(map(emit,e[1]))+e[0]+' '+str(len(e[1]))+'\n'
fixtures=[
 ('rational_sign',sub(pow_(sub(xn,yn),-1),pow_(sub(yn,xn),-1)),2/(x-y),0),
 ('root_square',sub(pow_(r,2),ln),0,0),
 ('root_square_denominator',sub(mul(r,r,pow_(add(xn,one),-1)),mul(ln,pow_(add(xn,one),-1))),0,0),
 ('root_nonzero',mul(num(-3),r,pow_(sub(yn,num(2)),-1)),0,-3/(y-2)),
 ('conjugate_inverse',pow_(add(xn,r),-1),x/(x*x-lam),-1/(x*x-lam)),
 ('negative_power',pow_(mul(num(-2),r),-1),0,-1/(2*lam)),
 ('denominator_identity',sub(mul(add(xn,r),add(xn,mul(num(-1),r))),sub(pow_(xn,2),ln)),0,0),
 ('rational_nonzero',mul(num(-7),pow_(num(3),-1),pow_(add(xn,one),-1)),-S.Rational(7,3)/(x+1),0)
]
checks=[];env=os.environ.copy();env.update(OMP_NUM_THREADS='1',OPENBLAS_NUM_THREADS='1',MKL_NUM_THREADS='1')
for name,e,a,b in fixtures:
 path=out/(name+'.postfix');path.write_text('2\n'+emit(ln)+'e\n'+emit(e)+'e\n');start=time.monotonic()
 p=subprocess.run(['taskset','-c',str(cpu),str(exe),str(path)],capture_output=True,text=True,env=env,timeout=5)
 lines=p.stdout.strip().splitlines();got=[S.sympify(z.replace('^','**'),locals={'v0':x,'v1':y}) for z in lines]
 ok=p.returncode==0 and len(got)==2 and S.cancel(got[0]-a)==0 and S.cancel(got[1]-b)==0
 checks.append(dict(name=name,pass_=bool(ok),elapsed_seconds=time.monotonic()-start,expected=[str(a),str(b)],stdout=p.stdout,stderr=p.stderr,returncode=p.returncode))
negative={'zero_denominator':'2\nn 1\ne\nn 0\np -1\ne\n','undeclared_variable':'2\nn 1\ne\nv 2\ne\n','nested_root':'2\nr\ne\nn 1\ne\n','floating_number':'2\nn 1\ne\nn 1.5\ne\n','unknown_opcode':'2\nn 1\ne\nsin\ne\n'}
for name,data in negative.items():
 path=out/(name+'.postfix');path.write_text(data);p=subprocess.run(['taskset','-c',str(cpu),str(exe),str(path)],capture_output=True,text=True,env=env,timeout=5)
 checks.append(dict(name=name,pass_=p.returncode==2,returncode=p.returncode,stderr=p.stderr))
result={'status':'INCONCLUSIVE','code':'FIXTURES_FINISHED','scientific_acceptance':False,'all_pass':all(x['pass_'] for x in checks),'count':len(checks),'checks':checks,'sympy_version':S.__version__,'elapsed_seconds':time.monotonic()-wall,'all_children_closed':True}
(out/'result.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps({k:result[k] for k in ['all_pass','count','elapsed_seconds']}))
