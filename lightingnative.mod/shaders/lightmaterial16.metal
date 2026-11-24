#include <metal_stdlib>
using namespace metal;
struct Output { float4 position [[position]]; float4 colour; float2 uv; };
float4 sampleThird(float2 uv, texture2d<float> thirdImage, sampler thirdState, float4 bounds, float4 info) {

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
float4 sampleFourth(float2 uv, texture2d<float> fourthImage, sampler fourthState, float4 bounds, float4 info) {

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
        float4 c00=fourthImage.read(uint2(q),0);
        q=origin+float2(b.x,a.y);
        float4 c10=fourthImage.read(uint2(q),0);
        q=origin+float2(a.x,b.y);
        float4 c01=fourthImage.read(uint2(q),0);
        q=origin+b;
        float4 c11=fourthImage.read(uint2(q),0);
        sampled=mix(mix(c00,c10,weight.x),mix(c01,c11,weight.x),weight.y);
    } else {
        float2 q=origin+clamp(floor(uv*size),float2(0,0),size-1.0);
        sampled=fourthImage.read(uint2(q),0);
    }
}
return sampled;
}
float4 userColour(float4 c, float2 uv, float4 m, float2 pixel, texture2d<float> thirdImage, sampler thirdState, texture2d<float> fourthImage, sampler fourthState, constant float4 *p) {
float4 basisX=p[0], basisY=p[1], material=p[2];
float2 position=float2(dot(basisX.xy,uv)+basisX.z,dot(basisY.xy,uv)+basisY.z);
float3 n=float3(0.0,0.0,1.0);
if(material.x>=0.0) { n=m.rgb*2.0-1.0; n.xy*=material.x; }
float a=basisX.x*basisX.w, b=basisX.y*basisY.w;
float d=basisY.x*basisX.w, e=basisY.y*basisY.w;
if(p[101].w>0.5) {
 position=float2(dot(p[101].xy,pixel)+p[101].z,dot(p[102].xy,pixel)+p[102].z);
 float2 ux=dfdx(uv), uy=dfdy(uv), qx=dfdx(pixel), qy=dfdy(pixel);
 float2 px=float2(dot(p[101].xy,qx),dot(p[102].xy,qx));
 float2 py=float2(dot(p[101].xy,qy),dot(p[102].xy,qy));
 float det=ux.x*uy.y-ux.y*uy.x;
 if(abs(det)>1.0e-20) {
 a=(px.x*uy.y-py.x*ux.y)/det*basisX.w;
 b=(py.x*ux.x-px.x*uy.x)/det*basisY.w;
 d=(px.y*uy.y-py.y*ux.y)/det*basisX.w;
 e=(py.y*ux.x-px.y*uy.x)/det*basisY.w;
 } else { a=0.0;b=0.0;d=0.0;e=0.0; }
}
float determinant=a*e-b*d;
if(abs(determinant)>0.000001) n=float3((e*n.x-d*n.y)/determinant,(-b*n.x+a*n.y)/determinant,n.z);
else n=float3(0.0,0.0,1.0);
n=n/max(length(n),0.000001);
float3 sum=float3(0.0,0.0,0.0);
if(p[103].w>0.5) {
 sum=c.rgb*p[103].rgb;
 if(p[100].w>0.0) {
  float4 emission=sampleFourth(uv,fourthImage,fourthState,p[110],p[111]);
  if(p[114].x!=0.0) emission=float4(1.0,1.0,1.0,emission.r);
  if(p[114].y!=0.0) emission.rgb=emission.a>0.0?emission.rgb/emission.a:float3(0.0,0.0,0.0);
  sum+=c.rgb*emission.rgb*emission.a*p[100].rgb*p[100].w;
 }

}

for(int i=0;i<16;++i) {
 if(float(i)>=p[3].x) break;
 float4 light=p[4+i*6], colour=p[5+i*6], shape=p[6+i*6];
 float3 delta=float3(light.xy-position,light.w);
 float attenuation=1.0;
 if(shape.x<0.0) delta=light.xyz;
 else attenuation=pow(max(0.0,1.0-length(delta.xy)/light.z),shape.x);
 float diffuse=1.0, specular=0.0;
 if(material.x>-1.5) {
  float3 direction=delta/max(length(delta),0.000001);
  diffuse=max(0.0,dot(n,direction));
  if(diffuse>0.0 && material.y>0.0) {
   float3 halfway=direction+float3(0.0,0.0,1.0);
   halfway=halfway/max(length(halfway),0.000001);
   specular=material.y*pow(max(0.0,dot(n,halfway)),material.z);
   if(material.w>0.5) specular*=clamp(m.a,0.0,1.0);
  }
 }
 float3 contribution=(c.rgb*diffuse+float3(specular,specular,specular))*colour.rgb*colour.a*attenuation;
 if(shape.y>0.5) {
  float4 mapX=p[7+i*6], mapY=p[8+i*6], tile=p[9+i*6];
  float2 mapUV=float2(dot(mapX.xy,position)+mapX.z,dot(mapY.xy,position)+mapY.z);
  float4 visibility=sampleThird(mapUV,thirdImage,thirdState,tile,float4(p[3].zw,shape.zw));
  if(mapX.w<0.5) visibility.rgb*=visibility.a;
  contribution*=visibility.rgb;
 }
 if(p[3].y>0.5) contribution=clamp(contribution,0.0,1.0);
 sum+=contribution;
}
return float4(sum*clamp(c.a,0.0,1.0),p[103].w>0.5?clamp(c.a,0.0,1.0):1.0);
}
float4 sampleMap(float2 uv, texture2d<float> secondImage, sampler secondState, constant float4 *p) {
float4 bounds=p[106], info=p[107];
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
float4 bounds=p[104], info=p[105];
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
fragment float4 m2dEffectMain(Output input [[stage_in]], texture2d<float> image [[texture(0)]], sampler sampleState [[sampler(0)]], texture2d<float> secondImage [[texture(1)]], sampler secondState [[sampler(1)]], texture2d<float> thirdImage [[texture(2)]], sampler thirdState [[sampler(2)]], texture2d<float> fourthImage [[texture(3)]], sampler fourthState [[sampler(3)]], constant float4 &mode [[buffer(0)]], constant float4 *p [[buffer(1)]]) {
float2 localUV=(input.uv-p[104].xy)/p[104].zw;
float4 m=sampleMap(localUV,secondImage,secondState,p);
if(p[112].x!=0) m=float4(1,1,1,m.r);
if(p[112].y!=0) m.rgb=m.a>0?m.rgb/m.a:float3(0,0,0);
float4 c=sampleRegion(localUV,image,sampleState,p);
if(mode.x!=0) c=float4(1,1,1,c.r);
if(mode.y!=0) c.rgb=c.a>0?c.rgb/c.a:float3(0,0,0);
c*=input.colour;
c=userColour(c,(input.uv-p[104].xy)/p[104].zw,m,input.position.xy,thirdImage,thirdState,fourthImage,fourthState,p);
c.a=clamp(c.a,0.0,1.0);
if(mode.z!=0 && c.a<0.5) discard_fragment();
if(mode.w!=0) c.rgb*=c.a;
return c;
}
