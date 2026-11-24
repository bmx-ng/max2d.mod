/* Immutable shader-package assets; context-owned shader/pipeline caches. */
#include "package.h"
#include <stdatomic.h>
#include <stdarg.h>
#include <stdlib.h>
#include <string.h>
#include <stdio.h>
#include <stdint.h>
#include <limits.h>

static char package_error[512];
const char *m2d_package_error(void) { return package_error; }
static void package_fail(const char *format,...) {
 va_list args; va_start(args,format); vsnprintf(package_error,sizeof(package_error),format,args); va_end(args);
}
static atomic_int nextPackage;
static uint32_t word(const unsigned char *p) {
	return (uint32_t)p[0]|((uint32_t)p[1]<<8)|((uint32_t)p[2]<<16)|((uint32_t)p[3]<<24);
}
static int valid_spirv(const unsigned char *p,int n) {
	if(!n) return 1;
	if(!p || n<20 || n%4 || word(p)!=0x07230203) return 0;
	for(int i=20;i<n;) {
		uint32_t count=word(p+i)>>16;
		if(!count || count>(uint32_t)(n-i)/4) return 0;
		i+=(int)count*4;
	}
	return 1;
}
static int valid_dxbc(const unsigned char *p,int n) {
	if(!n) return 1;
	if(!p || n<32 || memcmp(p,"DXBC",4) || word(p+24)!=(uint32_t)n) return 0;
	uint32_t count=word(p+28);
	if(count>(uint32_t)(n-32)/4) return 0;
	for(uint32_t i=0;i<count;i++) {
		uint32_t offset=word(p+32+i*4);
		if(offset>(uint32_t)n-8 || word(p+offset+4)>(uint32_t)n-offset-8) return 0;
	}
	return 1;
}
/* D3D9 CreatePixelShader has no byte-count argument. Walk the token stream
   before passing it to the driver so no instruction/comment runs past storage. */
static int valid_d3d9(const unsigned char *p,int n) {
 if(!n) return 1;
 if(!p || n<8 || n%4 || word(p)!=0xffff0300) return 0;
 for(int offset=4;offset<n;) {
  uint32_t token=word(p+offset), opcode=token&0xffff;
  if(opcode==0xffff) return token==0x0000ffff && offset==n-4;
  uint32_t operands=opcode==0xfffe?(token>>16)&0x7fff:(token>>24)&15;
  if(operands>(uint32_t)(n-offset-4)/4) return 0;
  offset+=4+(int)operands*4;
 }
 return 0;
}
void m2d_package_free(M2DPackage *p) {
	if(!p) return;
	free(p->metal); free(p->spirv); free(p->dxbc); free(p->glsl); free(p->d3d11); free(p->d3d9); free(p);
}
void *m2d_package_create(const unsigned char *metal,int nm,const unsigned char *spirv,int ns,const unsigned char *dxbc,int nd,int slots,int abi,const unsigned char *glsl,int ng,const unsigned char *d3d11,int n11,const unsigned char *d3d9,int n9) {
	if((abi!=1 && abi!=2 && abi!=3 && abi!=4 && abi!=5) || slots<1 || slots>(abi==5?8:abi==4?3:abi==3?5:abi==2?6:8) || nm<0 || ns<0 || nd<0 || nm>4194304 || ns>4194304 || nd>4194304 || ng<0 || ng>4194304 || n11<0 || n11>4194304 || n9<0 || n9>4194304 || !(nm||ns||nd||ng||n11||n9)) {
		package_fail("Max2D package: invalid ABI/schema/assets (%d, %d, %d/%d/%d bytes)",abi,slots,nm,ns,nd); return NULL;
	}
	if(!valid_spirv(spirv,ns)) { package_fail("Max2D package: malformed SPIR-V (%d bytes)",ns); return NULL; }
	if(!valid_dxbc(dxbc,nd)) { package_fail("Max2D package: malformed DXBC (%d bytes)",nd); return NULL; }
	if(nm && (!metal || memchr(metal,0,(size_t)nm))) {
		package_fail("Max2D package: embedded zero in Metal source"); return NULL;
	}
	if(ng && (!glsl || memchr(glsl,0,(size_t)ng))) { package_fail("Max2D package: invalid GLSL source or ABI"); return NULL; }
	if(!valid_dxbc(d3d11,n11)) { package_fail("Max2D package: malformed native D3D11 DXBC"); return NULL; }
	if(!valid_d3d9(d3d9,n9)) { package_fail("Max2D package: malformed native D3D9 ps_3_0 bytecode"); return NULL; }
	M2DPackage *p=calloc(1,sizeof(*p));
	if(!p) goto oom;
	if(nm) { p->metal=malloc((size_t)nm+1); if(!p->metal) goto oom; memcpy(p->metal,metal,(size_t)nm); p->metal[nm]=0; p->metalSize=(size_t)nm+1; }
	if(ns) { p->spirv=malloc((size_t)ns); if(!p->spirv) goto oom; memcpy(p->spirv,spirv,(size_t)ns); p->spirvSize=ns; }
	if(nd) { p->dxbc=malloc((size_t)nd); if(!p->dxbc) goto oom; memcpy(p->dxbc,dxbc,(size_t)nd); p->dxbcSize=nd; }
	if(ng) { p->glsl=malloc((size_t)ng+1); if(!p->glsl) goto oom; memcpy(p->glsl,glsl,(size_t)ng); p->glsl[ng]=0; }
	if(n11) { p->d3d11=malloc(n11); if(!p->d3d11) goto oom; memcpy(p->d3d11,d3d11,n11); p->d3d11Size=n11; }
	if(n9) { p->d3d9=malloc(n9); if(!p->d3d9) goto oom; memcpy(p->d3d9,d3d9,n9); p->d3d9Size=n9; }
	p->abi=abi;
	p->samplers=abi==5?3:abi>=3?2:1;
	p->slots=slots+(abi==5?8:abi==4?7:abi==3?5:abi==2?2:0);
	int previous,id;
	do {
		previous=atomic_load(&nextPackage);
		if(previous==INT_MAX) { m2d_package_free(p); package_fail("Max2D package identity exhausted"); return NULL; }
		id=previous+1;
	} while(!atomic_compare_exchange_weak(&nextPackage,&previous,id));
	snprintf(p->key,sizeof(p->key),"max2d.package.v1.%d",id);
	return p;
oom:
	m2d_package_free(p); package_fail("Max2D package: out of memory"); return NULL;
}
