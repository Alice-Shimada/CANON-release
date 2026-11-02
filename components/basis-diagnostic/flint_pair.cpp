#include <flint/flint.h>
#include <flint/fmpz_mpoly_q.h>
#include <iostream>
#include <fstream>
#include <vector>
#include <string>
#include <stdexcept>
#include <chrono>
static fmpz_mpoly_ctx_t ctx;
struct Q {
 fmpz_mpoly_q_t q;
 Q(){fmpz_mpoly_q_init(q,ctx);}
 Q(long n):Q(){fmpz_mpoly_q_set_si(q,n,ctx);}
 Q(const Q& x):Q(){fmpz_mpoly_q_set(q,x.q,ctx);}
 Q& operator=(const Q& x){fmpz_mpoly_q_set(q,x.q,ctx);return *this;}
 ~Q(){fmpz_mpoly_q_clear(q,ctx);}
 bool zero()const{return fmpz_mpoly_q_is_zero(q,ctx);}
};
Q operator+(const Q&a,const Q&b){Q z;fmpz_mpoly_q_add(z.q,a.q,b.q,ctx);return z;}
Q operator-(const Q&a,const Q&b){Q z;fmpz_mpoly_q_sub(z.q,a.q,b.q,ctx);return z;}
Q operator*(const Q&a,const Q&b){Q z;fmpz_mpoly_q_mul(z.q,a.q,b.q,ctx);return z;}
Q operator/(const Q&a,const Q&b){if(b.zero())throw std::runtime_error("zero denominator");Q z;fmpz_mpoly_q_div(z.q,a.q,b.q,ctx);return z;}
struct E{Q a,b;E():a(0),b(0){}E(Q x,Q y):a(x),b(y){}};
E add(const E&x,const E&y){return E(x.a+y.a,x.b+y.b);}
E mul(const E&x,const E&y,const Q&l){return E(x.a*y.a+l*x.b*y.b,x.a*y.b+x.b*y.a);}
E inv(const E&x,const Q&l){if(x.b.zero())return E(Q(1)/x.a,Q(0));Q d=x.a*x.a-l*x.b*x.b;return E(x.a/d,(Q(0)-x.b)/d);}
E power(E x,long n,const Q&l){if(n<0){x=inv(x,l);n=-n;}E z(Q(1),Q(0));for(;n;n>>=1){if(n&1)z=mul(z,x,l);if(n>1)x=mul(x,x,l);}return z;}
E parse(std::istream&in,long nv,const Q&l,bool allowroot){
 std::vector<E> s;std::string op;
 while(in>>op){
  if(op=="e"){if(s.size()!=1)throw std::runtime_error("invalid stack");return s.back();}
  if(op=="n"){std::string n;if(!(in>>n))throw std::runtime_error("missing integer");Q x;fmpz_t z;fmpz_init(z);if(fmpz_set_str(z,n.c_str(),10))throw std::runtime_error("bad integer");fmpz_mpoly_q_set_fmpz(x.q,z,ctx);fmpz_clear(z);s.emplace_back(x,Q(0));}
  else if(op=="v"){long v;if(!(in>>v))throw std::runtime_error("missing variable");if(v<0||v>=nv)throw std::runtime_error("unknown variable");Q x;fmpz_mpoly_q_gen(x.q,v,ctx);s.emplace_back(x,Q(0));}
  else if(op=="r"){if(!allowroot)throw std::runtime_error("nested root");s.emplace_back(Q(0),Q(1));}
  else if(op=="p"){long n;if(!(in>>n))throw std::runtime_error("missing integer parameter");if(s.empty()||n< -10000||n>10000)throw std::runtime_error("bad power");s.back()=power(s.back(),n,l);}
  else if(op=="a"||op=="m"){long n;if(!(in>>n))throw std::runtime_error("missing integer parameter");if(n<1||size_t(n)>s.size())throw std::runtime_error("bad arity");E z=op=="a"?E(Q(0),Q(0)):E(Q(1),Q(0));size_t start=s.size()-n;for(size_t k=start;k<s.size();++k)z=op=="a"?add(z,s[k]):mul(z,s[k],l);s.resize(start);s.push_back(z);}
  else throw std::runtime_error("unsupported opcode");
 }
 throw std::runtime_error("missing end");
}
int main(int argc,char**argv){
 if(argc!=2&&!(argc==3&&std::string(argv[2])=="--batch")){std::cerr<<"usage: flint_pair INPUT or --version\n";return 2;}
 if(argc==2&&std::string(argv[1])=="--version"){std::cout<<FLINT_VERSION<<"\n"<<flint_version<<"\n";return 0;}
 try{
  auto start=std::chrono::steady_clock::now();std::ifstream in(argv[1]);long nv;in>>nv;if(!in||nv<1||nv>64)throw std::runtime_error("variable count");
  flint_set_num_threads(1);fmpz_mpoly_ctx_init(ctx,nv,ORD_LEX);
  {
   E lambda=parse(in,nv,Q(0),false);if(!lambda.b.zero())throw std::runtime_error("nonnested rational lambda required");bool batch=argc==3; long count=0; bool allzero=true; do { E z=parse(in,nv,lambda.a,true); ++count; allzero=allzero&&z.a.zero()&&z.b.zero();
   std::vector<std::string> names;std::vector<const char*> c;for(long i=0;i<nv;++i)names.push_back("v"+std::to_string(i));for(auto&v:names)c.push_back(v.c_str());
   char *a=fmpz_mpoly_q_get_str_pretty(z.a.q,c.data(),ctx),*b=fmpz_mpoly_q_get_str_pretty(z.b.q,c.data(),ctx);std::cout<<a<<"\n"<<b<<"\n";flint_free(a);flint_free(b);
   in>>std::ws; if(!batch&&in.peek()!=EOF)throw std::runtime_error("trailing input");
   } while(batch&&in.peek()!=EOF);
   std::cerr<<"{\"header_version\":\""<<FLINT_VERSION<<"\",\"runtime_version\":\""<<flint_version<<"\",\"all_zero\":"<<(allzero?"true":"false")<<",\"count\":"<<count<<",\"native_seconds\":"<<std::chrono::duration<double>(std::chrono::steady_clock::now()-start).count()<<"}\n";

  }
  fmpz_mpoly_ctx_clear(ctx);flint_cleanup();return 0;
 }catch(const std::exception&e){std::cerr<<"ERROR: "<<e.what()<<"\n";return 2;}
}
