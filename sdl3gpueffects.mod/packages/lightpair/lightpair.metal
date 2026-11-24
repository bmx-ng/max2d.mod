#include <metal_stdlib>
using namespace metal;
struct Output { float4 position [[position]]; float4 colour; float2 uv; };
float2 userEffect(float2 uv, float4 m, float4 t, constant float4 *p) {
    float4 lightA = p[0];
    float4 colourA = p[1];
    float4 lightB = p[2];
    float4 colourB = p[3];
    float4 basisX = p[4];
    float4 basisY = p[5];
    float4 options = p[6];
return uv;
}
float4 userColour(float4 c, float2 uv, float4 m, float4 t, constant float4 *p) {
    float4 lightA = p[0];
    float4 colourA = p[1];
    float4 lightB = p[2];
    float4 colourB = p[3];
    float4 basisX = p[4];
    float4 basisY = p[5];
    float4 options = p[6];
float2 position=float2(dot(basisX.xy,uv)+basisX.z,dot(basisY.xy,uv)+basisY.z);
float a=pow(max(0.0,1.0-length(position-lightA.xy)/lightA.z),lightA.w);
float b=pow(max(0.0,1.0-length(position-lightB.xy)/lightB.z),lightB.w);
float3 first=c.rgb*colourA.rgb*colourA.a*a;
float3 second=c.rgb*colourB.rgb*colourB.a*b;
if (options.x>0.5) first*=m.rgb*m.a;
if (options.y>0.5) second*=t.rgb*t.a;
if (options.z>0.5) { first=clamp(first,0.0,1.0); second=clamp(second,0.0,1.0); }
return float4((first+second)*clamp(c.a,0.0,1.0),1.0);
}
float2 userSecondUV(float2 uv, constant float4 *p) {
    float4 lightA = p[0];
    float4 colourA = p[1];
    float4 lightB = p[2];
    float4 colourB = p[3];
    float4 basisX = p[4];
    float4 basisY = p[5];
    float4 options = p[6];
float2 position=float2(dot(basisX.xy,uv)+basisX.z,dot(basisY.xy,uv)+basisY.z);
return (position-lightA.xy)/(2.0*lightA.z)+0.5;
}
float2 userThirdUV(float2 uv, constant float4 *p) {
    float4 lightA = p[0];
    float4 colourA = p[1];
    float4 lightB = p[2];
    float4 colourB = p[3];
    float4 basisX = p[4];
    float4 basisY = p[5];
    float4 options = p[6];
float2 position=float2(dot(basisX.xy,uv)+basisX.z,dot(basisY.xy,uv)+basisY.z);
return (position-lightB.xy)/(2.0*lightB.z)+0.5;
}
float4 sampleThird(float2 uv, texture2d<float> thirdImage, sampler thirdState, constant float4 *p) {
float4 bounds=p[11], info=p[12];
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
        float4 c00=thirdImage.read(uint2(q),0);
        q=origin+float2(b.x,a.y);
        float4 c10=thirdImage.read(uint2(q),0);
        q=origin+float2(a.x,b.y);
        float4 c01=thirdImage.read(uint2(q),0);
        q=origin+b;
        float4 c11=thirdImage.read(uint2(q),0);
        sampled=mix(mix(c00,c10,weight.x),mix(c01,c11,weight.x),weight.y);
    } else {
        float2 q=origin+clamp(floor(uv*size),float2(0,0),size-1.0);
        sampled=thirdImage.read(uint2(q),0);
    }
}
return sampled;
}
float4 sampleMap(float2 uv, texture2d<float> secondImage, sampler secondState, constant float4 *p) {
float4 bounds=p[9], info=p[10];
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
float4 bounds=p[7], info=p[8];
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
fragment float4 m2dEffectMain(Output input [[stage_in]], texture2d<float> image [[texture(0)]], sampler sampleState [[sampler(0)]], texture2d<float> secondImage [[texture(1)]], sampler secondState [[sampler(1)]], texture2d<float> thirdImage [[texture(2)]], sampler thirdState [[sampler(2)]], constant float4 &mode [[buffer(0)]], constant float4 *p [[buffer(1)]]) {
float2 localUV=(input.uv-p[7].xy)/p[7].zw;
float4 t=sampleThird(userThirdUV(localUV,p),thirdImage,thirdState,p);
if(p[14].x!=0) t=float4(1,1,1,t.r);
if(p[14].y!=0) t.rgb=t.a>0?t.rgb/t.a:float3(0,0,0);
float4 m=sampleMap(userSecondUV(localUV,p),secondImage,secondState,p);
if(p[13].x!=0) m=float4(1,1,1,m.r);
if(p[13].y!=0) m.rgb=m.a>0?m.rgb/m.a:float3(0,0,0);
float4 c=sampleRegion(userEffect(localUV,m,t,p),image,sampleState,p);
if(mode.x!=0) c=float4(1,1,1,c.r);
if(mode.y!=0) c.rgb=c.a>0?c.rgb/c.a:float3(0,0,0);
c*=input.colour;
c=userColour(c,(input.uv-p[7].xy)/p[7].zw,m,t,p);
c.a=clamp(c.a,0.0,1.0);
if(mode.z!=0 && c.a<0.5) discard_fragment();
if(mode.w!=0) c.rgb*=c.a;
return c;
}
