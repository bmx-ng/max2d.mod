#include <max2d.mod/shadereffects.mod/package.h>
/* Metal runtime probe for SDL GPU's shared native command queue. */
void *m2d_test_gpu_texture_set(void) {
    static unsigned char source[]=
        "#include <metal_stdlib>\nusing namespace metal;\n"
        "struct Output {float4 position [[position]];float4 colour;float2 uv;};\n"
        "fragment float4 m2dEffectMain(Output input [[stage_in]],\n"
        "texture2d<float> image [[texture(0)]],sampler state [[sampler(0)]],\n"
        "texture2d<float> second [[texture(1)]],sampler s1 [[sampler(1)]],\n"
        "texture2d<float> third [[texture(2)]],sampler s2 [[sampler(2)]],\n"
        "texture2d<float> fourth [[texture(3)]],sampler s3 [[sampler(3)]],\n"
        "texture2d<float> fifth [[texture(4)]],sampler s4 [[sampler(4)]],\n"
        "constant float4 &mode [[buffer(0)]],constant float4 *p [[buffer(1)]]) {\n"
        "float4 s,m;float2 uv=input.uv;\n"
        "if(p[0].x<0.5){s=second.sample(s1,uv,level(0));m=p[1];}\n"
        "else if(p[0].x<1.5){s=third.sample(s2,uv,level(0));m=p[2];}\n"
        "else if(p[0].x<2.5){s=fourth.sample(s3,uv,level(0));m=p[3];}\n"
        "else{s=fifth.sample(s4,uv,level(0));m=p[4];}\n"
        "return float4((m.x>0.5?1.0:s.r)*p[0].y,m.x>0.5?s.r:s.a,m.y,1.0)*image.sample(state,uv,level(0)).r;}\n";
    static M2DPackage package={.metal=source,.metalSize=sizeof(source)-1,.slots=5,.samplers=5,
        .abi=M2D_NATIVE_MATERIAL_ABI,.key="test-gpu-five-textures-v1"};
    return &package;
}
/* A single mode vector exercises the arena path for small multi-texture uniforms. */
void *m2d_test_gpu_small_texture_set(void) {
    static unsigned char source[]=
        "#include <metal_stdlib>\nusing namespace metal;\n"
        "struct Output {float4 position [[position]];float4 colour;float2 uv;};\n"
        "fragment float4 m2dEffectMain(Output input [[stage_in]],\n"
        "texture2d<float> image [[texture(0)]],sampler state [[sampler(0)]],\n"
        "texture2d<float> second [[texture(1)]],sampler s1 [[sampler(1)]],\n"
        "constant float4 &mode [[buffer(0)]],constant float4 *p [[buffer(1)]]) {\n"
        "float4 s=second.sample(s1,input.uv,level(0));float4 m=p[0];\n"
        "return float4(m.x>0.5?1.0:s.r,m.x>0.5?s.r:s.a,m.y,1.0)*image.sample(state,input.uv,level(0)).r;}\n";
    static M2DPackage package={.metal=source,.metalSize=sizeof(source)-1,.slots=1,.samplers=2,
        .abi=M2D_NATIVE_MATERIAL_ABI,.key="test-gpu-small-textures-v1"};
    return &package;
}
