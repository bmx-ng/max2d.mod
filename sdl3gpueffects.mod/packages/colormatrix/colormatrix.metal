#include <metal_stdlib>
using namespace metal;
struct Output { float4 position [[position]]; float4 colour; float2 uv; };
float4 userEffect(float4 c, constant float4 *p) {
    float4 row0 = p[0];
    float4 row1 = p[1];
    float4 row2 = p[2];
    float4 row3 = p[3];
    float4 bias = p[4];
return float4(dot(row0,c), dot(row1,c), dot(row2,c), dot(row3,c)) + bias;
}
fragment float4 m2dEffectMain(Output input [[stage_in]], texture2d<float> image [[texture(0)]], sampler sampleState [[sampler(0)]], constant float4 &mode [[buffer(0)]], constant float4 *p [[buffer(1)]]) {
float4 c=image.sample(sampleState,input.uv);
if(mode.x!=0) c=float4(1,1,1,c.r);
if(mode.y!=0) c.rgb=c.a>0?c.rgb/c.a:float3(0,0,0);
c*=input.colour;
c=userEffect(c,p);
c.a=clamp(c.a,0.0,1.0);
if(mode.z!=0 && c.a<0.5) discard_fragment();
if(mode.w!=0) c.rgb*=c.a;
return c;
}
