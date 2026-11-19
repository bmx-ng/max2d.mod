#include <metal_stdlib>
using namespace metal;
struct Output { float4 position [[position]]; float4 colour; float2 uv; };
float2 userEffect(float2 uv, float4 m, constant float4 *p) {
    float4 amount = p[0];
return uv+(m.rg*2.0-1.0)*amount.xy;
}
float4 sampleMap(float2 uv, texture2d<float> secondImage, sampler secondState, constant float4 *p) {
float4 bounds=p[3], info=p[4];
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
        float4 c00=secondImage.read(uint2(q),0);
        q=origin+float2(b.x,a.y);
        float4 c10=secondImage.read(uint2(q),0);
        q=origin+float2(a.x,b.y);
        float4 c01=secondImage.read(uint2(q),0);
        q=origin+b;
        float4 c11=secondImage.read(uint2(q),0);
        sampled=mix(mix(c00,c10,weight.x),mix(c01,c11,weight.x),weight.y);
    } else {
        float2 q=origin+clamp(floor(uv*size),float2(0,0),size-1.0);
        sampled=secondImage.read(uint2(q),0);
    }
}
return sampled;
}
float4 sampleRegion(float2 uv, texture2d<float> image, sampler sampleState, constant float4 *p) {
float4 bounds=p[1], info=p[2];
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
fragment float4 m2dEffectMain(Output input [[stage_in]], texture2d<float> image [[texture(0)]], sampler sampleState [[sampler(0)]], texture2d<float> secondImage [[texture(1)]], sampler secondState [[sampler(1)]], constant float4 &mode [[buffer(0)]], constant float4 *p [[buffer(1)]]) {
float2 localUV=(input.uv-p[1].xy)/p[1].zw;
float4 m=sampleMap(localUV,secondImage,secondState,p);
if(p[5].x!=0) m=float4(1,1,1,m.r);
if(p[5].y!=0) m.rgb=m.a>0?m.rgb/m.a:float3(0,0,0);
float4 c=sampleRegion(userEffect(localUV,m,p),image,sampleState,p);
if(mode.x!=0) c=float4(1,1,1,c.r);
if(mode.y!=0) c.rgb=c.a>0?c.rgb/c.a:float3(0,0,0);
c*=input.colour;
c.a=clamp(c.a,0.0,1.0);
if(mode.z!=0 && c.a<0.5) discard_fragment();
if(mode.w!=0) c.rgb*=c.a;
return c;
}
