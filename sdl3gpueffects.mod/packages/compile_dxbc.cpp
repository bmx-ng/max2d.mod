// Build-time tool: fixed ABI fragment entry, raw DXBC output.
#include <windows.h>
#include <d3dcompiler.h>
#include <fstream>
#include <iterator>
#include <string>
#include <cstdio>
int main(int argc,char **argv) {
	if(argc!=3) return 1;
	std::ifstream in(argv[1]); if(!in) return 1;
	std::string source((std::istreambuf_iterator<char>(in)),std::istreambuf_iterator<char>());
	ID3DBlob *code=nullptr,*errors=nullptr;
	HRESULT hr=D3DCompile(source.data(),source.size(),argv[1],nullptr,nullptr,"m2dEffectMain","ps_5_1",D3DCOMPILE_OPTIMIZATION_LEVEL3,0,&code,&errors);
	if(errors) { fwrite(errors->GetBufferPointer(),1,errors->GetBufferSize(),stderr); errors->Release(); }
	if(FAILED(hr)) return 1;
	FILE *out=fopen(argv[2],"wb"); if(!out) { code->Release(); return 1; }
	size_t bytes=code->GetBufferSize(); bool ok=fwrite(code->GetBufferPointer(),1,bytes,out)==bytes;
	code->Release(); return fclose(out)!=0 || !ok;
}
