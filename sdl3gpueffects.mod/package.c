/* Immutable shader-package assets; context-owned shader/pipeline caches. */
#include <SDL3/SDL.h>
#include <stdlib.h>
#include <string.h>
#include <stdio.h>
#include <stdint.h>
#include <limits.h>
typedef struct {
	unsigned char *metal,*spirv,*dxbc;
	size_t metalSize,spirvSize,dxbcSize;
	int slots,samplers;
	char key[64];
} M2DPackage;
extern void *m2d_gpu_image_effect_sized(void *,const char *,const SDL_GPUShaderCreateInfo *,int);
static SDL_AtomicInt nextPackage;
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
void m2d_package_free(M2DPackage *p) {
	if(!p) return;
	free(p->metal); free(p->spirv); free(p->dxbc); free(p);
}
void *m2d_package_create(const unsigned char *metal,int nm,const unsigned char *spirv,int ns,const unsigned char *dxbc,int nd,int slots,int abi) {
	if((abi!=1 && abi!=2 && abi!=3 && abi!=4) || slots<1 || slots>(abi>=3?3:abi==2?6:8) || nm<0 || ns<0 || nd<0 || nm>4194304 || ns>4194304 || nd>4194304 || !(nm||ns||nd)) {
		SDL_SetError("Max2D package: invalid ABI/schema/assets (%d, %d, %d/%d/%d bytes)",abi,slots,nm,ns,nd); return NULL;
	}
	if(!valid_spirv(spirv,ns)) { SDL_SetError("Max2D package: malformed SPIR-V (%d bytes)",ns); return NULL; }
	if(!valid_dxbc(dxbc,nd)) { SDL_SetError("Max2D package: malformed DXBC (%d bytes)",nd); return NULL; }
	if(nm && (!metal || memchr(metal,0,(size_t)nm))) {
		SDL_SetError("Max2D package: embedded zero in Metal source"); return NULL;
	}
	M2DPackage *p=calloc(1,sizeof(*p));
	if(!p) goto oom;
	if(nm) { p->metal=malloc((size_t)nm+1); if(!p->metal) goto oom; memcpy(p->metal,metal,(size_t)nm); p->metal[nm]=0; p->metalSize=(size_t)nm+1; }
	if(ns) { p->spirv=malloc((size_t)ns); if(!p->spirv) goto oom; memcpy(p->spirv,spirv,(size_t)ns); p->spirvSize=ns; }
	if(nd) { p->dxbc=malloc((size_t)nd); if(!p->dxbc) goto oom; memcpy(p->dxbc,dxbc,(size_t)nd); p->dxbcSize=nd; }
	p->samplers=abi>=3?2:1;
	p->slots=slots+(abi==4?7:abi==3?5:abi==2?2:0);
	int previous,id;
	do {
		previous=SDL_GetAtomicInt(&nextPackage);
		if(previous==INT_MAX) { m2d_package_free(p); SDL_SetError("Max2D package identity exhausted"); return NULL; }
		id=previous+1;
	} while(!SDL_CompareAndSwapAtomicInt(&nextPackage,previous,id));
	snprintf(p->key,sizeof(p->key),"max2d.package.v1.%d",id);
	return p;
oom:
	m2d_package_free(p); SDL_SetError("Max2D package: out of memory"); return NULL;
}
void *m2d_package_shader(void *context,SDL_GPUDevice *device,M2DPackage *p) {
	SDL_GPUShaderCreateInfo info={0};
	info.stage=SDL_GPU_SHADERSTAGE_FRAGMENT; info.num_samplers=p->samplers; info.num_uniform_buffers=2;
	SDL_GPUShaderFormat formats=SDL_GetGPUShaderFormats(device);
	if((formats & SDL_GPU_SHADERFORMAT_MSL) && p->metal) {
		info.format=SDL_GPU_SHADERFORMAT_MSL; info.code=p->metal; info.code_size=p->metalSize; info.entrypoint="m2dEffectMain";
	} else if((formats & SDL_GPU_SHADERFORMAT_SPIRV) && p->spirv) {
		info.format=SDL_GPU_SHADERFORMAT_SPIRV; info.code=p->spirv; info.code_size=p->spirvSize; info.entrypoint="main";
	} else if((formats & SDL_GPU_SHADERFORMAT_DXBC) && p->dxbc) {
		info.format=SDL_GPU_SHADERFORMAT_DXBC; info.code=p->dxbc; info.code_size=p->dxbcSize; info.entrypoint="m2dEffectMain";
	} else { SDL_SetError("Max2D package: no shader asset for this backend"); return NULL; }
	return m2d_gpu_image_effect_sized(context,p->key,&info,p->slots*16);
}
