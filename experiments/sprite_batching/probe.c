/* Isolated Metal experiment, not linked into Max2D modules. zlib/libpng licence. */
#include "../../sdl3gpumax2d.mod/glue.c"
#include <stdio.h>

typedef struct {
	float origin_dx[4];
	float dy_uv0[4];
	float uv1_pad[4];
	float colour[4];
} Sprite;
_Static_assert(sizeof(Sprite)==64,"Sprite storage layout");

static const char compact_shader[]=
"#include <metal_stdlib>\n"
"using namespace metal;\n"
"struct Sprite { float4 origin_dx; float4 dy_uv0; float4 uv1_pad; float4 colour; };\n"
"struct Output { float4 position [[position]]; float4 colour; float2 uv; };\n"
"vertex Output compactMain(uint id [[vertex_id]],constant float4 &transform [[buffer(0)]],device const Sprite *sprites [[buffer(1)]]) {\n"
"const float2 corners[6]={float2(0,0),float2(1,0),float2(1,1),float2(0,0),float2(1,1),float2(0,1)};\n"
"Sprite s=sprites[id/6]; float2 corner=corners[id%6];\n"
"float2 p=s.origin_dx.xy+s.origin_dx.zw*corner.x+s.dy_uv0.xy*corner.y;\n"
"Output o; o.position=float4(p*transform.xy+transform.zw,0,1);\n"
"o.colour=s.colour; o.uv=mix(s.dy_uv0.zw,s.uv1_pad.xy,corner); return o; }\n";

typedef struct {
	SDL_GPUBuffer *buffer;
	SDL_GPUTransferBuffer *transfer;
	SDL_GPUGraphicsPipeline *pipeline;
	void *data;
} Path;

static int build_path(GPUContext *c,Path *p,int compact,int count,int blend) {
	SDL_GPUShader *vertex=c->vertex;
	if(compact) {
		SDL_GPUShaderCreateInfo info={0};
		info.code=(const Uint8 *)compact_shader;
		info.code_size=sizeof(compact_shader)-1;
		info.format=SDL_GPU_SHADERFORMAT_MSL;
		info.entrypoint="compactMain";
		info.stage=SDL_GPU_SHADERSTAGE_VERTEX;
		info.num_uniform_buffers=1;
		info.num_storage_buffers=1;
		vertex=SDL_CreateGPUShader(c->device,&info);
		if(!vertex) return 0;
	}
	SDL_GPUVertexBufferDescription buffer={0,32,SDL_GPU_VERTEXINPUTRATE_VERTEX,0};
	SDL_GPUVertexAttribute attributes[3]={{0,0,SDL_GPU_VERTEXELEMENTFORMAT_FLOAT2,0},{1,0,SDL_GPU_VERTEXELEMENTFORMAT_FLOAT4,8},{2,0,SDL_GPU_VERTEXELEMENTFORMAT_FLOAT2,24}};
	SDL_GPUColorTargetDescription colour={0};
	colour.format=SDL_GPU_TEXTUREFORMAT_R8G8B8A8_UNORM;
	colour.blend_state.enable_blend=blend;
	colour.blend_state.color_blend_op=colour.blend_state.alpha_blend_op=SDL_GPU_BLENDOP_ADD;
	colour.blend_state.src_color_blendfactor=colour.blend_state.src_alpha_blendfactor=SDL_GPU_BLENDFACTOR_ONE;
	colour.blend_state.dst_color_blendfactor=colour.blend_state.dst_alpha_blendfactor=SDL_GPU_BLENDFACTOR_ONE_MINUS_SRC_ALPHA;
	SDL_GPUGraphicsPipelineCreateInfo pipeline={0};
	pipeline.vertex_shader=vertex;
	pipeline.fragment_shader=c->fragment;
	if(!compact) pipeline.vertex_input_state=(SDL_GPUVertexInputState){&buffer,1,attributes,3};
	pipeline.primitive_type=SDL_GPU_PRIMITIVETYPE_TRIANGLELIST;
	pipeline.target_info.color_target_descriptions=&colour;
	pipeline.target_info.num_color_targets=1;
	p->pipeline=SDL_CreateGPUGraphicsPipeline(c->device,&pipeline);
	if(compact) SDL_ReleaseGPUShader(c->device,vertex);
	Uint32 size=(Uint32)count*(compact?64:192);
	SDL_GPUBufferCreateInfo bi={compact?SDL_GPU_BUFFERUSAGE_GRAPHICS_STORAGE_READ:SDL_GPU_BUFFERUSAGE_VERTEX,size,0};
	SDL_GPUTransferBufferCreateInfo ti={SDL_GPU_TRANSFERBUFFERUSAGE_UPLOAD,size,0};
	p->buffer=SDL_CreateGPUBuffer(c->device,&bi);
	p->transfer=SDL_CreateGPUTransferBuffer(c->device,&ti);
	p->data=malloc(size);
	return p->pipeline && p->buffer && p->transfer && p->data;
}
static void destroy_path(GPUContext *c,Path *p) {
	if(p->buffer) SDL_ReleaseGPUBuffer(c->device,p->buffer);
	if(p->transfer) SDL_ReleaseGPUTransferBuffer(c->device,p->transfer);
	if(p->pipeline) SDL_ReleaseGPUGraphicsPipeline(c->device,p->pipeline);
	free(p->data);
}
static void pack(Path *p,const Sprite *sprites,int count,int compact,float movement) {
	if(compact) {
		Sprite *out=p->data;
		for(int i=0;i<count;++i) {
			out[i]=sprites[i];
			out[i].origin_dx[0]+=movement;
		}
	} else {
		static const int corners[12]={0,0,1,0,1,1,0,0,1,1,0,1};
		float *out=p->data;
		for(int i=0;i<count;++i) {
			const Sprite *s=&sprites[i];
			for(int v=0;v<6;++v,out+=8) {
				int x=corners[v*2],y=corners[v*2+1];
				out[0]=(s->origin_dx[0]+movement)+s->origin_dx[2]*x+s->dy_uv0[0]*y;
				out[1]=s->origin_dx[1]+s->origin_dx[3]*x+s->dy_uv0[1]*y;
				memcpy(out+2,s->colour,16);
				out[6]=x?s->uv1_pad[0]:s->dy_uv0[2];
				out[7]=y?s->uv1_pad[1]:s->dy_uv0[3];
			}
		}
	}
}
static int draw(GPUContext *c,Path *p,GPUFrame *target,GPUFrame *image,int count,int compact,int clipped) {
	Uint32 size=(Uint32)count*(compact?64:192);
	void *mapped=SDL_MapGPUTransferBuffer(c->device,p->transfer,true);
	if(!mapped) return 0;
	memcpy(mapped,p->data,size);
	SDL_UnmapGPUTransferBuffer(c->device,p->transfer);
	SDL_GPUCommandBuffer *cmd=SDL_AcquireGPUCommandBuffer(c->device);
	if(!cmd) return 0;
	SDL_GPUCopyPass *copy=SDL_BeginGPUCopyPass(cmd);
	SDL_GPUTransferBufferLocation src={p->transfer,0};
	SDL_GPUBufferRegion dest={p->buffer,0,size};
	SDL_UploadToGPUBuffer(copy,&src,&dest,true);
	SDL_EndGPUCopyPass(copy);
	SDL_GPUColorTargetInfo colour={0};
	colour.texture=target->texture;
	colour.load_op=SDL_GPU_LOADOP_CLEAR;
	colour.store_op=SDL_GPU_STOREOP_STORE;
	SDL_GPURenderPass *pass=SDL_BeginGPURenderPass(cmd,&colour,1,NULL);
	if(!pass) { SDL_CancelGPUCommandBuffer(cmd); return 0; }
	float transform[4]={2.f/target->width,-2.f/target->height,-1,1};
	float mode[4]={(float)image->coverage,0,0,1};
	SDL_PushGPUVertexUniformData(cmd,0,transform,sizeof(transform));
	SDL_PushGPUFragmentUniformData(cmd,0,mode,sizeof(mode));
	SDL_BindGPUGraphicsPipeline(pass,p->pipeline);
	if(compact) SDL_BindGPUVertexStorageBuffers(pass,0,&p->buffer,1);
	else {
		SDL_GPUBufferBinding binding={p->buffer,0};
		SDL_BindGPUVertexBuffers(pass,0,&binding,1);
	}
	SDL_GPUTextureSamplerBinding sampler={image->texture,image->sampler};
	SDL_BindGPUFragmentSamplers(pass,0,&sampler,1);
	SDL_Rect clip={clipped?17:0,clipped?29:0,target->width-(clipped?61:0),target->height-(clipped?47:0)};
	SDL_SetGPUScissor(pass,&clip);
	SDL_DrawGPUPrimitives(pass,count*6,1,0,0);
	SDL_EndGPURenderPass(pass);
	return SDL_SubmitGPUCommandBuffer(cmd);
}
static void fill(Sprite *sprites,int count,int scene) {
	for(int i=0;i<count;++i) {
		Sprite *s=&sprites[i];
		memset(s,0,sizeof(*s));
		int width=scene==0?8:scene==1?16:32;
		int height=scene==0?12:width;
		s->origin_dx[0]=(float)((i*37)%500);
		s->origin_dx[1]=(float)((i*71)%500);
		s->origin_dx[2]=(float)width;
		s->dy_uv0[1]=(float)height;
		if(scene==1) {
			/* Exact quarter turns, reflections and shear also exercise artwork mapping. */
			if(i%3==0) { s->origin_dx[2]=0; s->origin_dx[3]=width; s->dy_uv0[0]=-height; s->dy_uv0[1]=0; }
			if(i%3==1) s->origin_dx[2]=-width;
			if(i%3==2) s->dy_uv0[0]=4;
		}
		s->dy_uv0[2]=(i%2)*0.5f;
		s->uv1_pad[0]=s->dy_uv0[2]+0.5f;
		s->uv1_pad[1]=1;
		s->colour[0]=0.25f+(i%4)*0.25f;
		s->colour[1]=0.25f+(i%3)*0.25f;
		s->colour[2]=1;
		s->colour[3]=0.25f+(i%3)*0.25f;
	}
}
int sprite_probe(SDL_Window *window) {
	GPUContext *c=m2d_gpu_open(window);
	if(!c) return 0;
	if(strcmp(m2d_gpu_name(c),"metal")) { m2d_gpu_close(c); return fail("Prototype requires Metal"); }
	const char *depth=SDL_getenv("MAX2D_PROBE_INFLIGHT");
	int inflight=depth?atoi(depth):1;
	if(inflight<1 || inflight>3) inflight=1;
	printf("Backend: %s; in-flight limit: %d; native isolated benchmark, not Max2D application timings\n",m2d_gpu_name(c),inflight);
	GPUFrame *target=create_frame(c,512,512,1,0,0,0,1);
	GPUFrame *image=create_frame(c,16,16,0,0,0,0,1);
	GPUFrame *coverage=create_frame(c,16,16,0,1,0,0,1);
	unsigned char pixels[16*16*4],alpha[16*16];
	for(int i=0;i<256;++i) {
		pixels[i*4]=(i%16<8)?255:80;
		pixels[i*4+1]=(i/16<8)?255:80;
		pixels[i*4+2]=192;
		pixels[i*4+3]=(i%5)?255:0;
		alpha[i]=(i%5)*63;
	}
	if(!target || !image || !coverage || !m2d_gpu_update(image,pixels,64,0,0,16,16) || !m2d_gpu_update(coverage,alpha,16,0,0,16,16)) goto error;
	printf("scene,count,trial,path,pack_ms,submit_ms,completed_ms,upload_bytes\n");
	for(int scene=0;scene<3;++scene) for(int n=0;n<3;++n) {
		int count=n==0?1000:n==1?10000:40000;
		Sprite *sprites=malloc((size_t)count*sizeof(Sprite));
		Path paths[2]={{0}};
		if(!sprites || !build_path(c,&paths[0],0,count,1) || !build_path(c,&paths[1],1,count,1)) {
			free(sprites); destroy_path(c,&paths[0]); destroy_path(c,&paths[1]); goto error;
		}
		fill(sprites,count,scene);
		GPUFrame *source=scene==0?coverage:image;
		/* Exact pixel comparison outside timing, including source alpha and clipping. */
		unsigned char *reference=malloc(512*512*4),*actual=malloc(512*512*4);
		int good=reference && actual;
		for(int compact=0;compact<2 && good;++compact) {
			pack(&paths[compact],sprites,count,compact,0);
			good=draw(c,&paths[compact],target,source,count,compact,1) && m2d_gpu_read(c,target,0,0,512,512,compact?actual:reference,512*4);
		}
		if(good && memcmp(reference,actual,512*512*4)) { fail("Compact/expanded pixel mismatch"); good=0; }
		free(reference); free(actual);
		/* Alternating trial order; drain the device before each timed block. */
		for(int trial=0;trial<4 && good;++trial) for(int order=0;order<2 && good;++order) {
			int compact=(order+trial)%2;
			Path *p=&paths[compact];
			for(int warm=0;warm<5 && good;++warm) {
				pack(p,sprites,count,compact,0);
				good=draw(c,p,target,source,count,compact,0);
			}
			good=good && SDL_WaitForGPUIdle(c->device);
			Uint64 start=SDL_GetTicksNS(),packTime=0,submitTime=0;
			const int frames=30;
			for(int f=0;f<frames && good;++f) {
				Uint64 t=SDL_GetTicksNS();
				pack(p,sprites,count,compact,(f%8)*0.125f);
				Uint64 packed=SDL_GetTicksNS();
				good=draw(c,p,target,source,count,compact,0);
				Uint64 submitted=SDL_GetTicksNS();
				packTime+=packed-t;
				submitTime+=submitted-packed;
				/* Bound in-flight work; include completion cost in frame timing. */
				if((f+1)%inflight==0) good=good && SDL_WaitForGPUIdle(c->device);
			}
			Uint64 finish=SDL_GetTicksNS();
			printf("%s,%d,%d,%s,%.6f,%.6f,%.6f,%d\n",scene==0?"coverage":scene==1?"sprites":"tiles",count,trial,compact?"compact":"expanded",packTime/1e6/frames,submitTime/1e6/frames,(finish-start)/1e6/frames,count*(compact?64:192));
			fflush(stdout);
		}
		SDL_WaitForGPUIdle(c->device);
		destroy_path(c,&paths[0]); destroy_path(c,&paths[1]); free(sprites);
		if(!good) goto error;
	}
	m2d_gpu_destroy(target); m2d_gpu_destroy(image); m2d_gpu_destroy(coverage);
	m2d_gpu_close(c);
	printf("All nine pixel comparisons passed.\n");
	return 1;
error:
	if(target) m2d_gpu_destroy(target);
	if(image) m2d_gpu_destroy(image);
	if(coverage) m2d_gpu_destroy(coverage);
	m2d_gpu_close(c);
	return 0;
}
