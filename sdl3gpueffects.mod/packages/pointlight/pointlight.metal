#include <metal_stdlib>
using namespace metal;
struct Output { float4 position [[position]]; float4 colour; float2 uv; };
float2 userEffect(float2 uv, constant float4 *p) {
    float4 light = p[0];
    float4 colour = p[1];
    float4 shape = p[2];
    float4 basisX = p[3];
    float4 basisY = p[4];
return uv;
}
float4 userColour(float4 c, float2 uv, constant float4 *p) {
    float4 light = p[0];
    float4 colour = p[1];
    float4 shape = p[2];
    float4 basisX = p[3];
    float4 basisY = p[4];
float attenuation=1.0;
if (shape.y>0.5) {
 float2 position=float2(dot(basisX.xy,uv)+basisX.z,dot(basisY.xy,uv)+basisY.z);
 float distanceFromLight=length((position-light.xy)/light.zw);
 attenuation=pow(max(0.0,1.0-distanceFromLight),shape.x);
}
return float4(c.rgb*colour.rgb*colour.a*attenuation,c.a);
}
float4 sampleRegion(float2 uv, texture2d<float> image, sampler sampleState, constant float4 *p) {
float4 bounds=p[5], info=p[6];
float2 origin=floor(bounds.xy/info.xy+0.5);
float2 size=floor(bounds.zw/info.xy+0.5);
float4 sampled=float4(0,0,0,0);
bool outside=uv.x<0.0 || uv.y<0.0 || uv.x>=1.0 || uv.y>=1.0;
if(info.z>=0.5 || !outside) {
    if(info.z>1.5) uv=uv-floor(uv);
    else uv=clamp(uv,float2(0,0),float2(1,1));
    if(info.w>0.5) {
        float2 pixel=uv*size-0.5;
        float2 lo=floor(pixel), weight=pixel-lo;
        float2 a=lo, b=lo+1.0;
        if(info.z>1.5) {
            a-=floor(a/size)*size;
            b-=floor(b/size)*size;
        } else {
            a=clamp(a,float2(0,0),size-1.0);
            b=clamp(b,float2(0,0),size-1.0);
        }
        float2 q=origin+a;
        float4 c00=image.read(uint2(q),0);
        q=origin+float2(b.x,a.y);
        float4 c10=image.read(uint2(q),0);
        q=origin+float2(a.x,b.y);
        float4 c01=image.read(uint2(q),0);
        q=origin+b;
        float4 c11=image.read(uint2(q),0);
        sampled=mix(mix(c00,c10,weight.x),mix(c01,c11,weight.x),weight.y);
    } else {
        float2 q=origin+clamp(floor(uv*size),float2(0,0),size-1.0);
        sampled=image.read(uint2(q),0);
    }
}
return sampled;
}
fragment float4 m2dEffectMain(Output input [[stage_in]], texture2d<float> image [[texture(0)]], sampler sampleState [[sampler(0)]], constant float4 &mode [[buffer(0)]], constant float4 *p [[buffer(1)]]) {
float4 c=sampleRegion(userEffect((input.uv-p[5].xy)/p[5].zw,p),image,sampleState,p);
if(mode.x!=0) c=float4(1,1,1,c.r);
if(mode.y!=0) c.rgb=c.a>0?c.rgb/c.a:float3(0,0,0);
c*=input.colour;
c=userColour(c,(input.uv-p[5].xy)/p[5].zw,p);
c.a=clamp(c.a,0.0,1.0);
if(mode.z!=0 && c.a<0.5) discard_fragment();
if(mode.w!=0) c.rgb*=c.a;
return c;
}
