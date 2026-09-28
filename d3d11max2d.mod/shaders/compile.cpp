// Build tool only: applications use checked-in bytecode, not D3DCompiler.
#include <windows.h>
#include <d3dcompiler.h>
#include <fstream>
#include <iterator>
#include <string>
#include <cstdio>
int main(int argc,char **argv){
 if(argc!=3)return 1;
 std::ifstream in(argv[1]);if(!in)return 1;
 std::string source((std::istreambuf_iterator<char>(in)),std::istreambuf_iterator<char>());
 FILE *out=fopen(argv[2],"wb");if(!out)return 1;
 fprintf(out,"// Generated from shaders/draw.hlsl by shaders/compile.cpp.\n#include <cstddef>\n");
 const char *entries[]={"vertexMain","pixelMain"},*profiles[]={"vs_4_0","ps_4_0"},*names[]={"m2d11_vertex_shader","m2d11_pixel_shader"};
 for(int n=0;n<2;++n){
  ID3DBlob *code=nullptr,*errors=nullptr;
  HRESULT hr=D3DCompile(source.data(),source.size(),"draw.hlsl",nullptr,nullptr,entries[n],profiles[n],D3DCOMPILE_OPTIMIZATION_LEVEL3,0,&code,&errors);
  if(errors){fwrite(errors->GetBufferPointer(),1,errors->GetBufferSize(),stderr);errors->Release();}
  if(FAILED(hr)){fclose(out);return 1;}
  fprintf(out,"extern const unsigned char %s[]={\n",names[n]);
  auto bytes=(const unsigned char *)code->GetBufferPointer();
  for(size_t i=0;i<code->GetBufferSize();++i)fprintf(out,"0x%02x,%s",bytes[i],(i%16==15||i+1==code->GetBufferSize())?"\n":" ");
  fprintf(out,"\n};\nextern const size_t %s_size=sizeof(%s);\n",names[n],names[n]);code->Release();
 }
 return fclose(out)!=0;
}
