cbuffer Modes : register(b0) { float4 mode; };
cbuffer Parameters : register(b1) { float4 p[9]; };
Texture2D image : register(t0);
SamplerState sampleState : register(s0);
struct Output { float4 position: SV_Position; float4 colour: COLOR0; float2 uv: TEXCOORD0; };
Texture2D secondImage : register(t1);
SamplerState secondState : register(s1);
float2 userEffect(float2 uv, float4 m) {
    float4 channels = p[0];
    float invert = p[1].x;
return uv;
}
float4 userColour(float4 c, float4 m) {
    float4 channels = p[0];
    float invert = p[1].x;
float coverage=clamp(dot(m,channels),0.0,1.0);
if(invert>0.5) coverage=1.0-coverage;
return float4(c.rgb,c.a*coverage);
}
float4 sampleMap(float2 uv) {
float4 bounds=p[4], info=p[5];
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
        float4 c00=secondImage.Load(int3(q,0));
        q=origin+float2(b.x,a.y);
        float4 c10=secondImage.Load(int3(q,0));
        q=origin+float2(a.x,b.y);
        float4 c01=secondImage.Load(int3(q,0));
        q=origin+b;
        float4 c11=secondImage.Load(int3(q,0));
        sampled=lerp(lerp(c00,c10,weight.x),lerp(c01,c11,weight.x),weight.y);
    } else {
        float2 q=origin+clamp(floor(uv*size),float2(0,0),size-1.0);
        sampled=secondImage.Load(int3(q,0));
    }
}
return sampled;
}
float4 sampleRegion(float2 uv) {
float4 bounds=p[2], info=p[3];
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
        float4 c00=image.Load(int3(q,0));
        q=origin+float2(b.x,a.y);
        float4 c10=image.Load(int3(q,0));
        q=origin+float2(a.x,b.y);
        float4 c01=image.Load(int3(q,0));
        q=origin+b;
        float4 c11=image.Load(int3(q,0));
        sampled=lerp(lerp(c00,c10,weight.x),lerp(c01,c11,weight.x),weight.y);
    } else {
        float2 q=origin+clamp(floor(uv*size),float2(0,0),size-1.0);
        sampled=image.Load(int3(q,0));
    }
}
return sampled;
}
float4 m2dEffectMain(Output input): SV_Target0 {
float2 localUV=(input.uv-p[2].xy)/p[2].zw;
float2 mapUV=float2(dot(p[6].xy,localUV)+p[6].z,dot(p[7].xy,localUV)+p[7].z);
float4 m=sampleMap(mapUV);
if(p[8].x!=0) m=float4(1,1,1,m.r);
if(p[8].y!=0) m.rgb=m.a>0?m.rgb/m.a:float3(0,0,0);
float4 c=sampleRegion(userEffect(localUV,m));
if(mode.x!=0) c=float4(1,1,1,c.r);
if(mode.y!=0) c.rgb=c.a>0?c.rgb/c.a:float3(0,0,0);
c*=input.colour;
c=userColour(c,m);
c.a=clamp(c.a,0.0,1.0);
if(mode.z!=0 && c.a<0.5) discard;
if(mode.w!=0) c.rgb*=c.a;
return c;
}
