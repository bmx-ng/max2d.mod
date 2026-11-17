/* Optional image-effect package adapter. zlib/libpng licence. */
#include <SDL3/SDL.h>
#include "shaders.h"
#include "shaders_dxbc.h"
#include "blur_dxbc.h"

extern void *m2d_gpu_image_effect(void *context,const char *key,const SDL_GPUShaderCreateInfo *info);

void *m2d_saturation_shader(void *context,SDL_GPUDevice *device) {
	SDL_GPUShaderCreateInfo info={0};
	info.stage=SDL_GPU_SHADERSTAGE_FRAGMENT;
	info.num_samplers=1;
	info.num_uniform_buffers=2;
	SDL_GPUShaderFormat formats=SDL_GetGPUShaderFormats(device);
	if(formats & SDL_GPU_SHADERFORMAT_MSL) {
		info.format=SDL_GPU_SHADERFORMAT_MSL;
		info.code=(const Uint8 *)saturation_metal;
		info.code_size=sizeof(saturation_metal);
		info.entrypoint="saturationMain";
	} else if(formats & SDL_GPU_SHADERFORMAT_SPIRV) {
		info.format=SDL_GPU_SHADERFORMAT_SPIRV;
		info.code=saturation_spv;
		info.code_size=sizeof(saturation_spv);
		info.entrypoint="main";
	} else if(formats & SDL_GPU_SHADERFORMAT_DXBC) {
		info.format=SDL_GPU_SHADERFORMAT_DXBC;
		info.code=saturation_dxbc;
		info.code_size=sizeof(saturation_dxbc);
		info.entrypoint="saturationMain";
	} else {
		SDL_SetError("Max2D Effects: no compatible saturation shader format");
		return NULL;
	}
	return m2d_gpu_image_effect(context,"max2d.saturation.v1",&info);
}

void *m2d_blur_shader(void *context,SDL_GPUDevice *device) {
	SDL_GPUShaderCreateInfo info={0};
	info.stage=SDL_GPU_SHADERSTAGE_FRAGMENT;
	info.num_samplers=1;
	info.num_uniform_buffers=2;
	SDL_GPUShaderFormat formats=SDL_GetGPUShaderFormats(device);
	if(formats & SDL_GPU_SHADERFORMAT_MSL) {
		info.format=SDL_GPU_SHADERFORMAT_MSL;
		info.code=(const Uint8 *)blur_metal;
		info.code_size=sizeof(blur_metal);
		info.entrypoint="blurMain";
	} else if(formats & SDL_GPU_SHADERFORMAT_SPIRV) {
		info.format=SDL_GPU_SHADERFORMAT_SPIRV;
		info.code=blur_spv;
		info.code_size=sizeof(blur_spv);
		info.entrypoint="main";
	} else if(formats & SDL_GPU_SHADERFORMAT_DXBC) {
		info.format=SDL_GPU_SHADERFORMAT_DXBC;
		info.code=blur_dxbc;
		info.code_size=sizeof(blur_dxbc);
		info.entrypoint="blurMain";
	} else {
		SDL_SetError("Max2D Effects: no compatible blur shader format");
		return NULL;
	}
	return m2d_gpu_image_effect(context,"max2d.blur.v1",&info);
}
