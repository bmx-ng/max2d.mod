/* Native SDL GPU command recording. zlib/libpng licence. */
#include <SDL3/SDL.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>
#include "shaders.h"
#include "shaders_dxbc.h"

typedef struct GPUContext GPUContext;
typedef struct {
	GPUContext *owner;
	SDL_GPUTexture *texture;
	int width,height,target,coverage,filtered;
	int levels,automatic,dirty,bytesPerUnit,kind;
	SDL_GPUSampler *sampler;
} GPUFrame;
typedef struct {
	GPUFrame *destination,*source;
	int blend,first,count,generate,compact;
	SDL_Rect clip;
	float transform[4];
} GPUDraw;
struct GPUContext {
	SDL_GPUDevice *device;
	SDL_Window *window;
	GPUFrame *backbuffer,*white;
	SDL_GPUShader *vertex,*fragment,*compactVertex;
	SDL_GPUGraphicsPipeline *pipelines[4][6];
	SDL_GPUGraphicsPipeline *compactPipelines[4][6];
	SDL_GPUSampler *samplers[2][32];
	SDL_GPUBuffer *vertices;
	SDL_GPUTransferBuffer *upload;
	Uint32 bufferSize;
	GPUDraw *draws;
	int drawCount,drawCapacity;
	float *data;
	int vertexCount,vertexCapacity;
	float transform[4];
	SDL_Rect clip;
	int sync;
};
static int fail(const char *message) { SDL_SetError("Max2D SDL GPU: %s",message); return 0; }
static int flush(GPUContext *c);
static void release_frame(GPUFrame *f) {
	if(!f) return;
	SDL_ReleaseGPUTexture(f->owner->device,f->texture);
	free(f);
}
/* Private format codes shared with TextureKind in the BlitzMax wrapper. */
static SDL_GPUTextureFormat texture_format(int kind) {
	switch(kind) {
	case 0:
		return SDL_GPU_TEXTUREFORMAT_R8G8B8A8_UNORM;
	case 1:
		return SDL_GPU_TEXTUREFORMAT_R8_UNORM;
	case 2:
		return SDL_GPU_TEXTUREFORMAT_R16G16B16A16_FLOAT;
	case 3:
		return SDL_GPU_TEXTUREFORMAT_R32G32B32A32_FLOAT;
	case 4:
		return SDL_GPU_TEXTUREFORMAT_BC1_RGBA_UNORM;
	case 5:
		return SDL_GPU_TEXTUREFORMAT_BC3_RGBA_UNORM;
	default:
		return SDL_GPU_TEXTUREFORMAT_INVALID;
	}
}
int m2d_gpu_support(GPUContext *c,int kind,int renderable) {
	SDL_GPUTextureFormat format=texture_format(kind);
	SDL_GPUTextureUsageFlags usage=SDL_GPU_TEXTUREUSAGE_SAMPLER;
	if(renderable) usage|=SDL_GPU_TEXTUREUSAGE_COLOR_TARGET;
	return SDL_GPUTextureSupportsFormat(c->device,format,SDL_GPU_TEXTURETYPE_2D,usage);
}
static int ensure_pipelines(GPUContext *c,int kind);
int m2d_gpu_target_support(GPUContext *c,int kind) {
	return (kind==0 || kind==2 || kind==3) && m2d_gpu_support(c,kind,1) && ensure_pipelines(c,kind);
}
static GPUFrame *create_frame(GPUContext *c,int w,int h,int target,int kind,int filtered,int automatic,int levels) {
	if(target && !m2d_gpu_target_support(c,kind)) return NULL;
	if(automatic) {
		levels=1;
		for(int size=w>h?w:h;size>1;size/=2) ++levels;
	}
	if(!levels) levels=1;
	if(levels>32) { fail("Too many mip levels"); return NULL; }
	if(!c->samplers[filtered][levels-1]) {
		SDL_GPUSamplerCreateInfo sampler={0};
		sampler.min_filter=sampler.mag_filter=filtered?SDL_GPU_FILTER_LINEAR:SDL_GPU_FILTER_NEAREST;
		sampler.mipmap_mode=filtered?SDL_GPU_SAMPLERMIPMAPMODE_LINEAR:SDL_GPU_SAMPLERMIPMAPMODE_NEAREST;
		sampler.address_mode_u=sampler.address_mode_v=sampler.address_mode_w=SDL_GPU_SAMPLERADDRESSMODE_CLAMP_TO_EDGE;
		sampler.max_lod=(float)(levels-1);
		c->samplers[filtered][levels-1]=SDL_CreateGPUSampler(c->device,&sampler);
		if(!c->samplers[filtered][levels-1]) return NULL;
	}
	SDL_GPUTextureCreateInfo info={0};
	info.type=SDL_GPU_TEXTURETYPE_2D;
	info.format=texture_format(kind);
	info.usage=SDL_GPU_TEXTUREUSAGE_SAMPLER|((target||automatic)?SDL_GPU_TEXTUREUSAGE_COLOR_TARGET:0);
	info.width=w;
	info.height=h;
	info.layer_count_or_depth=1;
	info.num_levels=levels;
	SDL_GPUTexture *texture=SDL_CreateGPUTexture(c->device,&info);
	if(!texture) return NULL;
	GPUFrame *f=calloc(1,sizeof(*f));
	if(!f) { SDL_ReleaseGPUTexture(c->device,texture); fail("Out of memory"); return NULL; }
	f->owner=c;
	f->texture=texture;
	f->width=w;
	f->height=h;
	f->target=target;
	f->kind=kind;
	f->coverage=kind==1;
	f->bytesPerUnit=kind==1?1:(kind==2 || kind==4)?8:(kind==3 || kind==5)?16:4;
	f->filtered=filtered;
	f->levels=levels;
	f->automatic=automatic;
	f->dirty=automatic;
	f->sampler=c->samplers[filtered][levels-1];
	if(target) {
		SDL_GPUCommandBuffer *cmd=SDL_AcquireGPUCommandBuffer(c->device);
		if(!cmd) { release_frame(f); return NULL; }
		SDL_GPUColorTargetInfo colour={0};
		colour.texture=texture;
		colour.load_op=SDL_GPU_LOADOP_CLEAR;
		colour.store_op=SDL_GPU_STOREOP_STORE;
		SDL_GPURenderPass *pass=SDL_BeginGPURenderPass(cmd,&colour,1,NULL);
		if(!pass) { SDL_CancelGPUCommandBuffer(cmd); release_frame(f); return NULL; }
		SDL_EndGPURenderPass(pass);
		if(!SDL_SubmitGPUCommandBuffer(cmd)) { release_frame(f); return NULL; }
	}
	return f;
}
int m2d_gpu_update_level(GPUFrame *f,const unsigned char *pixels,int pitch,int level,int x,int y,int w,int h) {
	GPUContext *c=f->owner;
	if(!flush(c)) return 0;
	/* One storage unit is a pixel, or a 4x4 block for BC formats. */
	int bpp=f->bytesPerUnit;
	/* Bundled SDL Metal uploads use destination width as the row stride.
	 * Pack tightly there; D3D12 benefits from its 256-byte upload alignment. */
	int block=f->kind>=4?4:1;
	int rows=(h+block-1)/block;
	Uint64 packedRow=(Uint64)((w+block-1)/block)*bpp;
	Uint64 row=packedRow;
	if(SDL_strcmp(SDL_GetGPUDeviceDriver(c->device),"direct3d12")==0) row=(row+255)&~(Uint64)255;
	if(row*rows>0xffffffffu) return fail("Upload is too large");
	SDL_GPUTransferBufferCreateInfo info={0};
	info.usage=SDL_GPU_TRANSFERBUFFERUSAGE_UPLOAD;
	info.size=(Uint32)(row*rows);
	SDL_GPUTransferBuffer *transfer=SDL_CreateGPUTransferBuffer(c->device,&info);
	if(!transfer) return 0;
	unsigned char *mapped=SDL_MapGPUTransferBuffer(c->device,transfer,false);
	if(!mapped) { SDL_ReleaseGPUTransferBuffer(c->device,transfer); return 0; }
	for(int yy=0;yy<rows;++yy) {
		unsigned char *output=mapped+yy*row;
		const unsigned char *input=pixels+(size_t)yy*pitch;
		if(f->automatic && !f->coverage) {
			for(int xx=0;xx<w;++xx) {
				for(int k=0;k<3;++k) output[xx*4+k]=(input[xx*4+k]*input[xx*4+3]+127)/255;
				output[xx*4+3]=input[xx*4+3];
			}
		} else memcpy(output,input,(size_t)packedRow);
	}
	SDL_UnmapGPUTransferBuffer(c->device,transfer);
	SDL_GPUCommandBuffer *cmd=SDL_AcquireGPUCommandBuffer(c->device);
	if(!cmd) { SDL_ReleaseGPUTransferBuffer(c->device,transfer); return 0; }
	SDL_GPUCopyPass *pass=SDL_BeginGPUCopyPass(cmd);
	SDL_GPUTextureTransferInfo source={transfer,0,(Uint32)(row/bpp)*block,(Uint32)rows*block};
	SDL_GPUTextureRegion dest={0};
	dest.texture=f->texture;
	dest.mip_level=level;
	dest.x=x;
	dest.y=y;
	dest.w=w;
	dest.h=h;
	dest.d=1;
	/* Partial updates must retain untouched texels: do not cycle the texture. */
	SDL_UploadToGPUTexture(pass,&source,&dest,false);
	SDL_EndGPUCopyPass(pass);
	int ok=SDL_SubmitGPUCommandBuffer(cmd);
	SDL_ReleaseGPUTransferBuffer(c->device,transfer);
	if(ok && f->automatic) f->dirty=1;
	return ok;
}
int m2d_gpu_update(GPUFrame *f,const unsigned char *pixels,int pitch,int x,int y,int w,int h) {
	return m2d_gpu_update_level(f,pixels,pitch,0,x,y,w,h);
}

void m2d_gpu_close(GPUContext *c) {
	if(!c) return;
	if(c->device) {
		flush(c);
		SDL_WaitForGPUIdle(c->device);
		release_frame(c->backbuffer);
		release_frame(c->white);
		for(int kind=0;kind<4;++kind) for(int i=1;i<=5;++i) {
			if(c->pipelines[kind][i]) SDL_ReleaseGPUGraphicsPipeline(c->device,c->pipelines[kind][i]);
			if(c->compactPipelines[kind][i]) SDL_ReleaseGPUGraphicsPipeline(c->device,c->compactPipelines[kind][i]);
		}
		for(int i=0;i<2;++i) for(int level=0;level<32;++level) {
			if(c->samplers[i][level]) SDL_ReleaseGPUSampler(c->device,c->samplers[i][level]);
		}
		if(c->vertex) SDL_ReleaseGPUShader(c->device,c->vertex);
		if(c->compactVertex) SDL_ReleaseGPUShader(c->device,c->compactVertex);
		if(c->fragment) SDL_ReleaseGPUShader(c->device,c->fragment);
		if(c->vertices) SDL_ReleaseGPUBuffer(c->device,c->vertices);
		if(c->upload) SDL_ReleaseGPUTransferBuffer(c->device,c->upload);
		if(c->window) SDL_ReleaseWindowFromGPUDevice(c->device,c->window);
		SDL_DestroyGPUDevice(c->device);
	}
	free(c->draws);
	free(c->data);
	free(c);
}
static SDL_GPUShader *shader(GPUContext *c,int stage) {
	int fragment=stage==1,compact=stage==2;
	SDL_GPUShaderCreateInfo info={0};
	SDL_GPUShaderFormat formats=SDL_GetGPUShaderFormats(c->device);
	info.stage=fragment?SDL_GPU_SHADERSTAGE_FRAGMENT:SDL_GPU_SHADERSTAGE_VERTEX;
	info.num_uniform_buffers=1;
	info.num_storage_buffers=compact?1:0;
	info.num_samplers=fragment?1:0;
	if(formats & SDL_GPU_SHADERFORMAT_MSL) {
		info.format=SDL_GPU_SHADERFORMAT_MSL;
		info.code=(const Uint8 *)gpu_metal;
		info.code_size=sizeof(gpu_metal);
		info.entrypoint=fragment?"pixelMain":compact?"compactMain":"vertexMain";
	} else if(formats & SDL_GPU_SHADERFORMAT_SPIRV) {
		info.format=SDL_GPU_SHADERFORMAT_SPIRV;
		info.code=fragment?gpu_frag_spv:compact?gpu_compact_spv:gpu_vert_spv;
		info.code_size=fragment?sizeof(gpu_frag_spv):compact?sizeof(gpu_compact_spv):sizeof(gpu_vert_spv);
		info.entrypoint="main";
	} else {
		info.format=SDL_GPU_SHADERFORMAT_DXBC;
		info.code=fragment?gpu_fragment_dxbc:compact?gpu_compact_dxbc:gpu_vertex_dxbc;
		info.code_size=fragment?gpu_fragment_dxbc_size:compact?gpu_compact_dxbc_size:gpu_vertex_dxbc_size;
		info.entrypoint=fragment?"pixelMain":compact?"compactMain":"vertexMain";
	}
	return SDL_CreateGPUShader(c->device,&info);
}
static int ensure_pipelines_mode(GPUContext *c,int kind,int compact) {
	if(compact && !c->compactVertex) {
		c->compactVertex=shader(c,2);
		if(!c->compactVertex) return 0;
	}
	SDL_GPUGraphicsPipeline **pipelines=compact?c->compactPipelines[kind]:c->pipelines[kind];
	SDL_GPUVertexBufferDescription buffer={0,32,SDL_GPU_VERTEXINPUTRATE_VERTEX,0};
	SDL_GPUVertexAttribute attributes[3]={{0,0,SDL_GPU_VERTEXELEMENTFORMAT_FLOAT2,0},{1,0,SDL_GPU_VERTEXELEMENTFORMAT_FLOAT4,8},{2,0,SDL_GPU_VERTEXELEMENTFORMAT_FLOAT2,24}};
	for(int blend=1;blend<=5;++blend) {
		if(pipelines[blend]) continue;
		SDL_GPUColorTargetDescription colour={0};
		colour.format=texture_format(kind);
		SDL_GPUColorTargetBlendState *b=&colour.blend_state;
		b->enable_blend=blend>=3;
		b->color_blend_op=SDL_GPU_BLENDOP_ADD;
		b->alpha_blend_op=SDL_GPU_BLENDOP_ADD;
		b->src_color_blendfactor=blend==5?SDL_GPU_BLENDFACTOR_DST_COLOR:SDL_GPU_BLENDFACTOR_ONE;
		b->dst_color_blendfactor=blend==3?SDL_GPU_BLENDFACTOR_ONE_MINUS_SRC_ALPHA:blend==4?SDL_GPU_BLENDFACTOR_ONE:SDL_GPU_BLENDFACTOR_ZERO;
		b->src_alpha_blendfactor=blend==3?SDL_GPU_BLENDFACTOR_ONE:SDL_GPU_BLENDFACTOR_ZERO;
		b->dst_alpha_blendfactor=blend==3?SDL_GPU_BLENDFACTOR_ONE_MINUS_SRC_ALPHA:SDL_GPU_BLENDFACTOR_ONE;
		SDL_GPUGraphicsPipelineCreateInfo pipeline={0};
		pipeline.vertex_shader=compact?c->compactVertex:c->vertex;
		pipeline.fragment_shader=c->fragment;
		if(!compact) pipeline.vertex_input_state=(SDL_GPUVertexInputState){&buffer,1,attributes,3};
		pipeline.primitive_type=SDL_GPU_PRIMITIVETYPE_TRIANGLELIST;
		pipeline.rasterizer_state.fill_mode=SDL_GPU_FILLMODE_FILL;
		pipeline.target_info.color_target_descriptions=&colour;
		pipeline.target_info.num_color_targets=1;
		pipelines[blend]=SDL_CreateGPUGraphicsPipeline(c->device,&pipeline);
		if(!pipelines[blend]) return 0;
	}
	return 1;
}
static int ensure_pipelines(GPUContext *c,int kind) { return ensure_pipelines_mode(c,kind,0); }
int m2d_gpu_compact_support(GPUContext *c) { return ensure_pipelines_mode(c,0,1); }
void *m2d_gpu_open(SDL_Window *window) {
	GPUContext *c=calloc(1,sizeof(*c));
	if(!c) { fail("Out of memory"); return NULL; }
	c->sync=1;
	c->device=SDL_CreateGPUDevice(SDL_GPU_SHADERFORMAT_MSL|SDL_GPU_SHADERFORMAT_SPIRV|SDL_GPU_SHADERFORMAT_DXBC,
#ifdef NDEBUG
		false,
#else
		true,
#endif
		NULL);
	if(!c->device) goto error;
	if(!SDL_ClaimWindowForGPUDevice(c->device,window)) goto error;
	c->window=window;
	c->vertex=shader(c,0);
	c->fragment=shader(c,1);
	if(!c->vertex || !c->fragment) goto error;
	if(!ensure_pipelines(c,0)) goto error;
	c->white=create_frame(c,1,1,0,0,0,0,1);
	if(!c->white) goto error;
	const unsigned char white[4]={255,255,255,255};
	if(!m2d_gpu_update(c->white,white,4,0,0,1,1)) goto error;
	return c;
error: {
	char message[1024];
	SDL_strlcpy(message,SDL_GetError(),sizeof(message));
	m2d_gpu_close(c);
	SDL_SetError("%s",message);
	return NULL;
}
}
const char *m2d_gpu_name(GPUContext *c) { return SDL_GetGPUDeviceDriver(c->device); }
int m2d_gpu_output(GPUContext *c,int *w,int *h) { return SDL_GetWindowSizeInPixels(c->window,w,h); }
void *m2d_gpu_create(GPUContext *c,int w,int h,int flags,int target,int kind,int levels) {
	return create_frame(c,w,h,target,kind,(flags&2)!=0,(flags&4)!=0 && levels==0,levels);
}
void m2d_gpu_destroy(GPUFrame *f) {
	if(!f) return;
	if(!flush(f->owner)) {
		/* Queued, unsubmitted commands cannot outlive their source textures. */
		f->owner->drawCount=0;
		f->owner->vertexCount=0;
	}
	release_frame(f);
}
static int ensure_backbuffer(GPUContext *c,int w,int h) {
	if(c->backbuffer && c->backbuffer->width==w && c->backbuffer->height==h) return 1;
	if(!flush(c)) return 0;
	GPUFrame *frame=create_frame(c,w,h,1,0,0,0,1);
	if(!frame) return 0;
	release_frame(c->backbuffer);
	c->backbuffer=frame;
	return 1;
}
static int clampi(int n,int lo,int hi) { return n<lo?lo:n>hi?hi:n; }
int m2d_gpu_view(GPUContext *c,GPUFrame *target,int width,int height,int ox,int oy,int vw,int vh,float sx,float sy,int x,int y,int w,int h) {
	if(!target && !ensure_backbuffer(c,width,height)) return 0;
	c->transform[0]=2*sx/width;
	c->transform[1]=-2*sy/height;
	c->transform[2]=2.f*ox/width-1;
	c->transform[3]=1-2.f*oy/height;
	int left=clampi(ox+(int)floorf(x*sx),ox,ox+vw);
	int top=clampi(oy+(int)floorf(y*sy),oy,oy+vh);
	int right=w?clampi(ox+(int)ceilf((x+w)*sx),ox,ox+vw):left;
	int bottom=h?clampi(oy+(int)ceilf((y+h)*sy),oy,oy+vh):top;
	c->clip=(SDL_Rect){left,top,right-left,bottom-top};
	return 1;
}
static int record_draw(GPUContext *c,GPUFrame *target,GPUFrame *source,int blend,const float *vertices,int count,int compact) {
	if(!c->clip.w || !c->clip.h) return 1;
	if(count<0 || count>262144) return fail("Vertex batch is too large");
	if(compact && !ensure_pipelines_mode(c,target?target->kind:0,1)) return 0;
	/* Offsets are in 32-byte units; storage records require 64-byte alignment. */
	int padding=compact?(c->vertexCount & 1):0;
	if(c->vertexCount+count+padding>262144) {
		if(!flush(c)) return 0;
		padding=0;
	}
	if(c->drawCount==c->drawCapacity) {
		int capacity=c->drawCapacity?c->drawCapacity*2:128;
		GPUDraw *draws=realloc(c->draws,(size_t)capacity*sizeof(*draws));
		if(!draws) return fail("Out of memory");
		c->draws=draws;
		c->drawCapacity=capacity;
	}
	if(c->vertexCount+count+padding>c->vertexCapacity) {
		int capacity=c->vertexCapacity?c->vertexCapacity*2:8192;
		if(capacity<c->vertexCount+count+padding) capacity=c->vertexCount+count+padding;
		float *data=realloc(c->data,(size_t)capacity*32);
		if(!data) return fail("Out of memory");
		c->data=data;
		c->vertexCapacity=capacity;
	}
	if(padding) {
		memset(c->data+(size_t)c->vertexCount*8,0,32);
		++c->vertexCount;
	}
	GPUDraw *draw=&c->draws[c->drawCount++];
	draw->compact=compact;
	draw->destination=target;
	draw->source=source;
	draw->blend=blend;
	draw->first=c->vertexCount;
	draw->count=count;
	draw->generate=source && source->automatic && source->dirty && source->levels>1;
	if(source && source->automatic) source->dirty=0;
	if(target && target->automatic) target->dirty=1;
	draw->clip=c->clip;
	memcpy(draw->transform,c->transform,sizeof(c->transform));
	memcpy(c->data+(size_t)c->vertexCount*8,vertices,(size_t)count*32);
	c->vertexCount+=count;
	return 1+draw->generate;
}
int m2d_gpu_draw(GPUContext *c,GPUFrame *target,GPUFrame *source,int blend,const float *vertices,int count) {
	return record_draw(c,target,source,blend,vertices,count,0);
}
int m2d_gpu_draw_quads(GPUContext *c,GPUFrame *target,GPUFrame *source,int blend,const float *records,int count) {
	if(count<0 || count>131072) return fail("Rectangle batch is too large");
	return record_draw(c,target,source,blend,records,count*2,1);
}

static void generate_mips(GPUContext *c,SDL_GPUCommandBuffer *cmd,GPUFrame *frame) {
	/* Bundled SDL Vulkan mip generation does not clamp shifted dimensions.
	 * Explicit per-level GPU blits keep rectangular chains valid through 1x1. */
	if(frame->width!=frame->height && SDL_strcmp(SDL_GetGPUDeviceDriver(c->device),"vulkan")==0) {
		int w=frame->width;
		int h=frame->height;
		for(int level=1;level<frame->levels;++level) {
			int nextW=w>1?w/2:1;
			int nextH=h>1?h/2:1;
			SDL_GPUBlitInfo blit={0};
			blit.source.texture=frame->texture;
			blit.source.mip_level=level-1;
			blit.source.w=w;
			blit.source.h=h;
			blit.destination.texture=frame->texture;
			blit.destination.mip_level=level;
			blit.destination.w=nextW;
			blit.destination.h=nextH;
			blit.load_op=SDL_GPU_LOADOP_DONT_CARE;
			blit.filter=SDL_GPU_FILTER_LINEAR;
			SDL_BlitGPUTexture(cmd,&blit);
			w=nextW;
			h=nextH;
		}
	} else SDL_GenerateMipmapsForGPUTexture(cmd,frame->texture);
}
static int flush(GPUContext *c) {
	if(!c->drawCount) return 1;
	Uint32 size=(Uint32)c->vertexCount*32;
	if(size>c->bufferSize) {
		SDL_GPUBufferCreateInfo buffer={SDL_GPU_BUFFERUSAGE_VERTEX|SDL_GPU_BUFFERUSAGE_GRAPHICS_STORAGE_READ,size,0};
		SDL_GPUTransferBufferCreateInfo transfer={SDL_GPU_TRANSFERBUFFERUSAGE_UPLOAD,size,0};
		SDL_GPUBuffer *vertices=SDL_CreateGPUBuffer(c->device,&buffer);
		SDL_GPUTransferBuffer *upload=SDL_CreateGPUTransferBuffer(c->device,&transfer);
		if(!vertices || !upload) {
			if(vertices) SDL_ReleaseGPUBuffer(c->device,vertices);
			if(upload) SDL_ReleaseGPUTransferBuffer(c->device,upload);
			return 0;
		}
		if(c->vertices) SDL_ReleaseGPUBuffer(c->device,c->vertices);
		if(c->upload) SDL_ReleaseGPUTransferBuffer(c->device,c->upload);
		c->vertices=vertices;
		c->upload=upload;
		c->bufferSize=size;
	}
	void *mapped=SDL_MapGPUTransferBuffer(c->device,c->upload,true);
	if(!mapped) return 0;
	memcpy(mapped,c->data,size);
	SDL_UnmapGPUTransferBuffer(c->device,c->upload);
	SDL_GPUCommandBuffer *cmd=SDL_AcquireGPUCommandBuffer(c->device);
	if(!cmd) return 0;
	SDL_GPUCopyPass *copy=SDL_BeginGPUCopyPass(cmd);
	SDL_GPUTransferBufferLocation source={c->upload,0};
	SDL_GPUBufferRegion dest={c->vertices,0,size};
	SDL_UploadToGPUBuffer(copy,&source,&dest,true);
	SDL_EndGPUCopyPass(copy);
	SDL_GPURenderPass *pass=NULL;
	GPUFrame *active=NULL;
	for(int i=0;i<c->drawCount;++i) {
		GPUDraw *draw=&c->draws[i];
		GPUFrame *target=draw->destination?draw->destination:c->backbuffer;
		if(draw->generate) {
			if(pass) SDL_EndGPURenderPass(pass);
			pass=NULL;
			active=NULL;
			generate_mips(c,cmd,draw->source);
		}
		if(target!=active) {
			if(pass) SDL_EndGPURenderPass(pass);
			SDL_GPUColorTargetInfo colour={0};
			colour.texture=target->texture;
			colour.load_op=SDL_GPU_LOADOP_LOAD;
			colour.store_op=SDL_GPU_STOREOP_STORE;
			pass=SDL_BeginGPURenderPass(cmd,&colour,1,NULL);
			if(!pass) { SDL_CancelGPUCommandBuffer(cmd); return 0; }
			active=target;
		}
		GPUFrame *image=draw->source?draw->source:c->white;
		float mode[4]={(float)image->coverage,(float)(image->target || (image->automatic && !image->coverage)),draw->blend==1,draw->blend==3 || draw->blend==4 || (draw->destination && draw->blend<=2)};
		SDL_PushGPUVertexUniformData(cmd,0,draw->transform,sizeof(draw->transform));
		SDL_PushGPUFragmentUniformData(cmd,0,mode,sizeof(mode));
		SDL_BindGPUGraphicsPipeline(pass,draw->compact?c->compactPipelines[target->kind][draw->blend]:c->pipelines[target->kind][draw->blend]);
		SDL_SetGPUScissor(pass,&draw->clip);
		SDL_GPUBufferBinding buffer={c->vertices,0};
		if(draw->compact) SDL_BindGPUVertexStorageBuffers(pass,0,&c->vertices,1);
		else SDL_BindGPUVertexBuffers(pass,0,&buffer,1);
		SDL_GPUTextureSamplerBinding sampler={image->texture,image->sampler};
		SDL_BindGPUFragmentSamplers(pass,0,&sampler,1);
		SDL_DrawGPUPrimitives(pass,draw->compact?draw->count*3:draw->count,1,draw->compact?draw->first*3:draw->first,0);
	}
	if(pass) SDL_EndGPURenderPass(pass);
	c->drawCount=0;
	c->vertexCount=0;
	return SDL_SubmitGPUCommandBuffer(cmd);
}
static int clear_rect(GPUContext *c,GPUFrame *target,int r,int g,int b,float a) {
	GPUFrame *dest=target?target:c->backbuffer;
	float vertices[48];
	const int corners[12]={0,0,1,0,0,1,0,1,1,0,1,1};
	float saved[4];
	memcpy(saved,c->transform,sizeof(saved));
	c->transform[0]=2.f/dest->width;
	c->transform[1]=-2.f/dest->height;
	c->transform[2]=-1;
	c->transform[3]=1;
	for(int i=0;i<6;++i) {
		float *v=vertices+i*8;
		v[0]=corners[i*2]*dest->width;
		v[1]=corners[i*2+1]*dest->height;
		v[2]=r/255.f;
		v[3]=g/255.f;
		v[4]=b/255.f;
		v[5]=a;
		v[6]=v[7]=0;
	}
	int ok=m2d_gpu_draw(c,target,NULL,2,vertices,6);
	memcpy(c->transform,saved,sizeof(saved));
	return ok;
}
int m2d_gpu_clear(GPUContext *c,GPUFrame *target,int bars,int r,int g,int b,float a,int br,int bg,int bb) {
	if(bars) {
		GPUFrame *dest=target?target:c->backbuffer;
		SDL_Rect saved=c->clip;
		c->clip=(SDL_Rect){0,0,dest->width,dest->height};
		int ok=clear_rect(c,target,br,bg,bb,1);
		c->clip=saved;
		if(!ok) return 0;
	}
	return clear_rect(c,target,r,g,b,a);
}
int m2d_gpu_present(GPUContext *c,int sync) {
	if(!flush(c)) return 0;
	sync=sync!=0;
	if(sync!=c->sync) {
		SDL_GPUPresentMode mode=sync?SDL_GPU_PRESENTMODE_VSYNC:SDL_GPU_PRESENTMODE_IMMEDIATE;
		if(!SDL_WindowSupportsGPUPresentMode(c->device,c->window,mode)) mode=SDL_GPU_PRESENTMODE_VSYNC;
		if(!SDL_SetGPUSwapchainParameters(c->device,c->window,SDL_GPU_SWAPCHAINCOMPOSITION_SDR,mode)) return 0;
		c->sync=sync;
	}
	SDL_GPUCommandBuffer *cmd=SDL_AcquireGPUCommandBuffer(c->device);
	if(!cmd) return 0;
	SDL_GPUTexture *swap=NULL;
	Uint32 w,h;
	if(!SDL_WaitAndAcquireGPUSwapchainTexture(cmd,c->window,&swap,&w,&h)) { SDL_CancelGPUCommandBuffer(cmd); return 0; }
	if(swap && c->backbuffer) {
		SDL_GPUBlitInfo blit={0};
		blit.source.texture=c->backbuffer->texture;
		blit.source.w=c->backbuffer->width;
		blit.source.h=c->backbuffer->height;
		blit.destination.texture=swap;
		blit.destination.w=w;
		blit.destination.h=h;
		blit.load_op=SDL_GPU_LOADOP_DONT_CARE;
		blit.filter=SDL_GPU_FILTER_NEAREST;
		SDL_BlitGPUTexture(cmd,&blit);
	}
	return SDL_SubmitGPUCommandBuffer(cmd);
}
static float decode_half(Uint16 value) {
	int exponent=(value>>10)&31;
	int mantissa=value&1023;
	float result;
	if(!exponent) result=ldexpf((float)mantissa,-24);
	else if(exponent==31) result=mantissa?NAN:INFINITY;
	else result=ldexpf((float)(1024+mantissa),exponent-25);
	return value&32768?-result:result;
}
static int read_pixels(GPUContext *c,GPUFrame *frame,int x,int y,int w,int h,unsigned char *pixels,int pitch,int floating) {
	if(!flush(c)) return 0;
	GPUFrame *f=frame?frame:c->backbuffer;
	if(!f || x<0 || y<0 || w>f->width || h>f->height || x>f->width-w || y>f->height-h) return fail("Read rectangle outside surface");
	if(floating ? (f->kind!=2 && f->kind!=3) : f->kind!=0) return fail("Readback format mismatch");
	int bpp=f->bytesPerUnit;
	Uint64 row=((Uint64)w*bpp+255)&~(Uint64)255;
	if(row*h>0xffffffffu) return fail("Readback is too large");
	SDL_GPUTransferBufferCreateInfo info={SDL_GPU_TRANSFERBUFFERUSAGE_DOWNLOAD,(Uint32)(row*h),0};
	SDL_GPUTransferBuffer *transfer=SDL_CreateGPUTransferBuffer(c->device,&info);
	if(!transfer) return 0;
	SDL_GPUCommandBuffer *cmd=SDL_AcquireGPUCommandBuffer(c->device);
	if(!cmd) { SDL_ReleaseGPUTransferBuffer(c->device,transfer); return 0; }
	SDL_GPUCopyPass *pass=SDL_BeginGPUCopyPass(cmd);
	SDL_GPUTextureRegion source={0};
	source.texture=f->texture;
	source.x=x;
	source.y=y;
	source.w=w;
	source.h=h;
	source.d=1;
	SDL_GPUTextureTransferInfo dest={transfer,0,(Uint32)row/bpp,(Uint32)h};
	SDL_DownloadFromGPUTexture(pass,&source,&dest);
	SDL_EndGPUCopyPass(pass);
	SDL_GPUFence *fence=SDL_SubmitGPUCommandBufferAndAcquireFence(cmd);
	int ok=0;
	if(fence && SDL_WaitForGPUFences(c->device,true,&fence,1)) {
		const unsigned char *mapped=SDL_MapGPUTransferBuffer(c->device,transfer,false);
		if(mapped) {
			for(int yy=0;yy<h;++yy) {
				if(!floating) {
					memcpy(pixels+(size_t)yy*pitch,mapped+yy*row,(size_t)w*4);
					continue;
				}
				for(int xx=0;xx<w;++xx) {
					float value[4];
					const unsigned char *sourcePixel=mapped+yy*row+(size_t)xx*bpp;
					if(f->kind==2) {
						Uint16 halves[4];
						memcpy(halves,sourcePixel,8);
						for(int k=0;k<4;++k) value[k]=decode_half(halves[k]);
					} else memcpy(value,sourcePixel,16);
					if(f->target) for(int k=0;k<3;++k) value[k]=value[3]>0?value[k]/value[3]:0;
					memcpy(pixels+(size_t)yy*pitch+(size_t)xx*16,value,16);
				}
			}
			SDL_UnmapGPUTransferBuffer(c->device,transfer);
			ok=1;
		}
	}
	if(fence) SDL_ReleaseGPUFence(c->device,fence);
	SDL_ReleaseGPUTransferBuffer(c->device,transfer);
	if(ok && !floating && frame && frame->target) for(int yy=0;yy<h;++yy) for(int xx=0;xx<w;++xx) {
		unsigned char *p=pixels+(size_t)yy*pitch+xx*4;
		int a=p[3];
		for(int k=0;k<3;++k) p[k]=a?clampi((p[k]*255+a/2)/a,0,255):0;
	}
	return ok;
}

int m2d_gpu_read(GPUContext *c,GPUFrame *frame,int x,int y,int w,int h,unsigned char *pixels,int pitch) {
	return read_pixels(c,frame,x,y,w,h,pixels,pitch,0);
}
int m2d_gpu_read_float(GPUContext *c,GPUFrame *frame,unsigned char *pixels) {
	return read_pixels(c,frame,0,0,frame->width,frame->height,pixels,frame->width*16,1);
}

/* Borrowed device and a scoped window overlay for native GPU integrations.
 * Callbacks are native C functions and must not throw or re-enter Max2D. */
SDL_GPUDevice *m2d_gpu_device(GPUContext *c) { return c->device; }
int m2d_gpu_window_format(void) { return SDL_GPU_TEXTUREFORMAT_R8G8B8A8_UNORM; }
int m2d_gpu_window_overlay(GPUContext *c,
	void (*prepare)(void *, SDL_GPUCommandBuffer *),
	void (*draw)(void *, SDL_GPUCommandBuffer *, SDL_GPURenderPass *), void *data) {
	if (!prepare || !draw) return fail("overlay callbacks are required");
	if (!c->backbuffer) return fail("window backbuffer is not available");
	if (!flush(c)) return 0;
	SDL_GPUCommandBuffer *cmd = SDL_AcquireGPUCommandBuffer(c->device);
	if (!cmd) return 0;
	prepare(data, cmd);
	SDL_GPUColorTargetInfo colour = {0};
	colour.texture = c->backbuffer->texture;
	colour.load_op = SDL_GPU_LOADOP_LOAD;
	colour.store_op = SDL_GPU_STOREOP_STORE;
	SDL_GPURenderPass *pass = SDL_BeginGPURenderPass(cmd, &colour, 1, NULL);
	if (!pass) { SDL_CancelGPUCommandBuffer(cmd); return 0; }
	draw(data, cmd, pass);
	SDL_EndGPURenderPass(pass);
	return SDL_SubmitGPUCommandBuffer(cmd);
}
