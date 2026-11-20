#include <SDL3/SDL.h>
#include <max2d.mod/shadereffects.mod/package.h>
extern void *m2d_gpu_image_effect_sized(void *,const char *,const SDL_GPUShaderCreateInfo *,int);
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
