// Structural conversion only. No symbolic evaluation or arithmetic simplification.
#include <chrono>
#include <cstdio>
#include <fstream>
#include <iostream>
#include <limits>
#include <stdexcept>
#include <string>
#include <sstream>
#include <algorithm>
#include <unordered_map>
#include <unordered_set>
#include <vector>
#include <unistd.h>

static constexpr const char* VERSION="canon-fullform-postfix/v1";
static std::string json(const std::string& s){std::string out="\"";for(unsigned char c:s){if(c=='"'||c=='\\'){out+='\\';out+=c;}else if(c=='\n')out+="\\n";else if(c=='\r')out+="\\r";else if(c=='\t')out+="\\t";else if(c<32)out+='?';else out+=c;}return out+'"';}
struct Reader {
 std::istream& in;size_t offset=0;
 int peek(){return in.peek();}
 int take(){int c=in.get();if(c!=EOF)++offset;return c;}
 void ws(){while(peek()==' '||peek()=='\t'||peek()=='\r'||peek()=='\n')take();}
 [[noreturn]] void error(const std::string& s){throw std::runtime_error(s+" at byte "+std::to_string(offset));}
 void expect(char c){ws();if(take()!=c)error(std::string("Expected ")+c);}
 static bool letter(int c){return (c>='a'&&c<='z')||(c>='A'&&c<='Z')||c=='$'||c>=128;}
 std::string symbol(){if(!letter(peek())&&peek()!='\\'&&peek()!='`')error("Invalid digit-leading/non-symbol name");std::string s;while(true){int c=peek();if(letter(c)||(c>='0'&&c<='9')||c=='`'){s+=char(take());continue;}if(c=='\\'){s+=char(take());int kind=take();s+=char(kind);if(kind=='['){size_t n=0;while(letter(peek())||(peek()>='0'&&peek()<='9')){s+=char(take());++n;}if(!n||take()!=']')error("Malformed named character escape");s+=']';continue;}int digits=kind==':'?4:kind=='|'?6:0;if(!digits)error("Unsupported symbol escape");for(int i=0;i<digits;++i){int d=take();if(!((d>='0'&&d<='9')||(d>='a'&&d<='f')||(d>='A'&&d<='F')))error("Malformed hexadecimal character escape");s+=char(d);}continue;}break;}if(s.empty())error("Expected a declared symbol");return s;}
 std::string integer(){ws();std::string s;if(peek()=='-')s+=char(take());if(peek()<'0'||peek()>'9')error("Expected exact integer");while(peek()>='0'&&peek()<='9')s+=char(take());size_t start=s[0]=='-'?1:0;if(s.size()-start>1&&s[start]=='0')error("Noncanonical integer");if(s=="-0")error("Noncanonical signed zero");return s;}
};
static size_t count(const std::string& s){if(s.empty())throw std::runtime_error("Missing frame count");size_t n=0;for(char c:s){if(c<'0'||c>'9'||n>(std::numeric_limits<size_t>::max()-size_t(c-'0'))/10)throw std::runtime_error("Invalid frame count");n=n*10+size_t(c-'0');}return n;}
static bool prohibited(const std::string& s){std::string name=s.rfind("System`",0)==0?s.substr(7):s;return name=="Pi"||name=="E"||name=="I"||name=="Infinity"||name=="ComplexInfinity"||name=="Indeterminate"||name=="DirectedInfinity";}
struct Parser {
 Reader r;std::ostream& out;std::unordered_map<std::string,size_t> vars;std::string root;
 static std::string head(const std::string& s){return s.rfind("System`",0)==0?s.substr(7):s;}
 void expr(bool allowRoot=true){r.ws();if(r.peek()=='-'||(r.peek()>='0'&&r.peek()<='9')){out<<"n "<<r.integer()<<'\n';return;}std::string name=r.symbol();r.ws();if(r.peek()!='['){if(prohibited(name))r.error("Nonfinite or numeric symbol is outside the exact domain");auto it=vars.find(name);if(it!=vars.end()){out<<"v "<<it->second<<'\n';return;}if(name==root){if(!allowRoot)r.error("Formal root forbidden in defining lambda");out<<"r\n";return;}r.error("Unknown symbol");}r.take();std::string h=head(name);
  if(h=="Rational"){auto n=r.integer();r.expect(',');auto d=r.integer();if(d[0]=='-'||d=="0")r.error("Rational denominator must be positive nonzero integer");r.expect(']');out<<"n "<<n<<"\nn "<<d<<"\np -1\nm 2\n";return;}
  if(h=="Power"){expr(allowRoot);r.expect(',');auto p=r.integer();size_t pos=p[0]=='-'?1:0;size_t magnitude=0;for(;pos<p.size();++pos){magnitude=magnitude*10+size_t(p[pos]-'0');if(magnitude>10000)r.error("Integer power exceeds abs10000");}r.expect(']');out<<"p "<<p<<'\n';return;}
  if(h=="Plus"||h=="Times"){size_t n=0;do{if(n)r.expect(',');expr(allowRoot);++n;r.ws();}while(r.peek()==',');r.expect(']');if(n<2)r.error("Wrong arithmetic arity");out<<(h=="Plus"?"a ":"m ")<<n<<'\n';return;}
  r.error("Unsupported arithmetic head");
 }
 void listStart(){r.ws();if(head(r.symbol())!="List")r.error("Expected matrix/list framing");r.expect('[');}
 void matrix(size_t rows,size_t cols){listStart();for(size_t i=0;i<rows;++i){if(i)r.expect(',');listStart();for(size_t j=0;j<cols;++j){if(j)r.expect(',');expr();out<<"e\n";}r.expect(']');}r.expect(']');}
};
int main(int argc,char** argv){
 if(argc==2&&std::string(argv[1])=="--version"){std::cout<<VERSION<<'\n';return 0;}
 std::string partial;auto started=std::chrono::steady_clock::now();
 try{
  if(argc!=3)throw std::runtime_error("Usage: fullform_postfix INPUT OUTPUT");
  std::ifstream input(argv[1],std::ios::binary);if(!input)throw std::runtime_error("Cannot open structural input");
  std::string line;if(!std::getline(input,line)||line!="CANON_FULLFORM_POSTFIX_V1")throw std::runtime_error("Wrong structural format version");
  if(!std::getline(input,line))throw std::runtime_error("Missing frame dimensions");size_t a=line.find(' '),b=a==std::string::npos?a:line.find(' ',a+1);
  if(a==std::string::npos||b==std::string::npos||line.find(' ',b+1)!=std::string::npos)throw std::runtime_error("Invalid frame dimensions");
  size_t nv=count(line.substr(0,a));if(nv>64)throw std::runtime_error("Native variable frame exceeds64");size_t rows=count(line.substr(a+1,b-a-1)),cols=count(line.substr(b+1));if(!rows||!cols||rows>std::numeric_limits<size_t>::max()/cols)throw std::runtime_error("Invalid matrix dimensions");
  if(!std::getline(input,line))throw std::runtime_error("Missing formal root name");std::string root=line;
  auto validSymbol=[](const std::string& s){std::istringstream stream(s);Reader reader{stream};auto value=reader.symbol();if(value!=s||reader.peek()!=EOF)throw std::runtime_error("Invalid declared symbol spelling");};
  validSymbol(root);if(prohibited(root))throw std::runtime_error("Invalid formal root name");
  std::unordered_map<std::string,size_t> vars;for(size_t i=0;i<nv;++i){if(!std::getline(input,line))throw std::runtime_error("Truncated variable frame");validSymbol(line);if(prohibited(line)||line==root||!vars.emplace(line,i).second)throw std::runtime_error("Invalid duplicate/numeric variable frame");}
  partial=std::string(argv[2])+".partial-"+std::to_string(getpid());std::ofstream output(partial,std::ios::binary);if(!output)throw std::runtime_error("Cannot open owned temporary output");output<<std::max(size_t(1),nv)<<'\n';
  Parser parser{{input},output,std::move(vars),root};parser.listStart();parser.expr(false);output<<"e\n";parser.r.expect(',');parser.matrix(rows,cols);parser.r.expect(']');parser.r.ws();if(parser.r.peek()!=EOF)parser.r.error("Trailing structural input");output.flush();if(!output)throw std::runtime_error("Postfix output write failed");auto bytes=output.tellp();output.close();if(std::rename(partial.c_str(),argv[2]))throw std::runtime_error("Atomic output publication failed");partial.clear();
  std::cout<<"{\"schema\":\""<<VERSION<<"\",\"variable_count\":"<<nv<<",\"rows\":"<<rows<<",\"columns\":"<<cols<<",\"count\":"<<rows*cols<<",\"postfix_bytes\":"<<bytes<<",\"pid\":"<<getpid()<<",\"process_group\":"<<getpgrp()<<",\"seconds\":"<<std::chrono::duration<double>(std::chrono::steady_clock::now()-started).count()<<"}\n";return 0;
 }catch(const std::exception& e){if(!partial.empty())std::remove(partial.c_str());std::cerr<<"{\"schema\":\""<<VERSION<<"\",\"status\":\"rejected\",\"reason\":"<<json(e.what())<<",\"pid\":"<<getpid()<<",\"process_group\":"<<getpgrp()<<"}\n";return 2;}
}
