cbuffer Modes : register(b0) { float4 mode; };
cbuffer Parameters : register(b1) { float4 p[64]; };
Texture2D image : register(t0);
SamplerState sampleState : register(s0);
struct Output { float4 position: SV_Position; float4 colour: COLOR0; float2 uv: TEXCOORD0; };
Texture2D secondImage : register(t1);
SamplerState secondState : register(s1);
Texture2D thirdImage : register(t2);
SamplerState thirdState : register(s2);
float4 sampleThird(float2 uv, float4 bounds, float4 info) {

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
        float4 c00=thirdImage.Load(int3(q,0));
        q=origin+float2(b.x,a.y);
        float4 c10=thirdImage.Load(int3(q,0));
        q=origin+float2(a.x,b.y);
        float4 c01=thirdImage.Load(int3(q,0));
        q=origin+b;
        float4 c11=thirdImage.Load(int3(q,0));
        sampled=lerp(lerp(c00,c10,weight.x),lerp(c01,c11,weight.x),weight.y);
    } else {
        float2 q=origin+clamp(floor(uv*size),float2(0,0),size-1.0);
        sampled=thirdImage.Load(int3(q,0));
    }
}
return sampled;
}
float4 userColour(float4 c, float2 uv, float4 m, float2 pixel) {
float4 basisX=p[0], basisY=p[1], material=p[2];
float2 position=float2(dot(basisX.xy,uv)+basisX.z,dot(basisY.xy,uv)+basisY.z);
float3 n=float3(0.0,0.0,1.0);
if(material.x>=0.0) { n=m.rgb*2.0-1.0; n.xy*=material.x; }
float a=basisX.x*basisX.w, b=basisX.y*basisY.w;
float d=basisY.x*basisX.w, e=basisY.y*basisY.w;
if(p[53].w>0.5) {
 position=float2(dot(p[53].xy,pixel)+p[53].z,dot(p[54].xy,pixel)+p[54].z);
 float2 ux=ddx(uv), uy=ddy(uv), qx=ddx(pixel), qy=ddy(pixel);
 float2 px=float2(dot(p[53].xy,qx),dot(p[54].xy,qx));
 float2 py=float2(dot(p[53].xy,qy),dot(p[54].xy,qy));
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
if(p[55].w>0.5) {
 sum=c.rgb*p[55].rgb;
 if(p[52].w>0.0) {
  float4 emission=sampleThird(uv,p[60],p[61]);
  if(p[63].x!=0.0) emission=float4(1.0,1.0,1.0,emission.r);
  if(p[63].y!=0.0) emission.rgb=emission.a>0.0?emission.rgb/emission.a:float3(0.0,0.0,0.0);
  sum+=c.rgb*emission.rgb*emission.a*p[52].rgb*p[52].w;
 }
if(p[3].y>0.5) sum=clamp(sum,0.0,1.0);
}
[loop]
for(int i=0;i<8;++i) {
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
  float4 visibility=sampleThird(mapUV,tile,float4(p[3].zw,shape.zw));
  if(mapX.w<0.5) visibility.rgb*=visibility.a;
  contribution*=visibility.rgb;
 }
 if(p[3].y>0.5) contribution=clamp(contribution,0.0,1.0);
 sum+=contribution;
}
return float4(sum*clamp(c.a,0.0,1.0),p[55].w>0.5?clamp(c.a,0.0,1.0):1.0);
}
float4 sampleMap(float2 uv) {
float4 bounds=p[58], info=p[59];
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
float4 bounds=p[56], info=p[57];
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
float2 localUV=(input.uv-p[56].xy)/p[56].zw;
float4 m=sampleMap(localUV);
if(p[62].x!=0) m=float4(1,1,1,m.r);
if(p[62].y!=0) m.rgb=m.a>0?m.rgb/m.a:float3(0,0,0);
float4 c=sampleRegion(localUV);
if(mode.x!=0) c=float4(1,1,1,c.r);
if(mode.y!=0) c.rgb=c.a>0?c.rgb/c.a:float3(0,0,0);
c*=input.colour;
c=userColour(c,(input.uv-p[56].xy)/p[56].zw,m,input.position.xy);
c.a=clamp(c.a,0.0,1.0);
if(mode.z!=0 && c.a<0.5) discard;
if(mode.w!=0) c.rgb*=c.a;
return c;
}
