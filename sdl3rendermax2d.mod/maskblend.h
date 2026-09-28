/* Max2D alpha-test shader. SDL GPU renderer currently supported via MSL.
   Four immutable states avoid flushing queued draws to change uniforms. */
static const char m2d_mask_msl[] =
    "#include <metal_stdlib>\nusing namespace metal;\n"
    "struct Input { float4 color [[user(locn0)]]; float2 uv [[user(locn1)]]; };\n"
    "fragment float4 main0(Input in [[stage_in]], texture2d<float> image [[texture(0)]], "
    "sampler sampling [[sampler(0)]], constant float4 &mode [[buffer(0)]]) {\n"
    "float4 c=image.sample(sampling,in.uv);\n"
    "if(mode.x!=0.0) { if(c.a>0.0) c.rgb/=c.a; else c.rgb=float3(0.0); }\n"
    "c*=in.color; if(c.a<0.5) discard_fragment();\n"
    "if(mode.y!=0.0) c.rgb*=c.a; return c; }\n";

typedef struct M2DMask {
    SDL_GPUDevice *device;
    SDL_GPUShader *shader;
    SDL_GPURenderState *states[4];
    SDL_Texture *white;
} M2DMask;

void m2d_sdl_mask_destroy(M2DMask *mask) {
    if (!mask) return;
    for (int i=0; i<4; ++i) SDL_DestroyGPURenderState(mask->states[i]);
    SDL_DestroyTexture(mask->white);
    if (mask->shader) SDL_ReleaseGPUShader(mask->device,mask->shader);
    SDL_free(mask);
}

void *m2d_sdl_mask_create(SDL_Renderer *renderer) {
    SDL_GPUDevice *device=SDL_GetGPURendererDevice(renderer);
    if (!device) return NULL;
    if (!(SDL_GetGPUShaderFormats(device)&SDL_GPU_SHADERFORMAT_MSL)) {
        SDL_SetError("Max2D MASKBLEND: this GPU device has no bundled shader format (currently MSL)");
        return NULL;
    }
    M2DMask *mask=SDL_calloc(1,sizeof(*mask));
    if (!mask) return NULL;
    mask->device=device;
    SDL_GPUShaderCreateInfo shader={0};
    shader.code=(const Uint8 *)m2d_mask_msl;
    shader.code_size=sizeof(m2d_mask_msl)-1;
    shader.entrypoint="main0";
    shader.format=SDL_GPU_SHADERFORMAT_MSL;
    shader.stage=SDL_GPU_SHADERSTAGE_FRAGMENT;
    shader.num_samplers=1;
    shader.num_uniform_buffers=1;
    mask->shader=SDL_CreateGPUShader(device,&shader);
    if (!mask->shader) goto fail;
    for (int i=0; i<4; ++i) {
        SDL_GPURenderStateCreateInfo info={0};
        info.fragment_shader=mask->shader;
        mask->states[i]=SDL_CreateGPURenderState(renderer,&info);
        if (!mask->states[i]) goto fail;
        float mode[4]={(i&1)?1.0f:0.0f,(i&2)?1.0f:0.0f,0,0};
        if (!SDL_SetGPURenderStateFragmentUniforms(mask->states[i],0,mode,sizeof(mode))) goto fail;
    }
    mask->white=SDL_CreateTexture(renderer,SDL_PIXELFORMAT_RGBA32,SDL_TEXTUREACCESS_STATIC,1,1);
    if (!mask->white) goto fail;
    const Uint8 white[4]={255,255,255,255};
    if (!SDL_UpdateTexture(mask->white,NULL,white,4)) goto fail;
    return mask;
fail:
    m2d_sdl_mask_destroy(mask);
    return NULL;
}

int m2d_sdl_renderer_hint(const char *name) {
    return SDL_SetHint(SDL_HINT_RENDER_DRIVER,name) ? 1 : 0;
}
const char *m2d_sdl_renderer_name(SDL_Renderer *renderer) {
    return SDL_GetRendererName(renderer);
}
