float4 mode : register(c0);
float4 p[10] : register(c1);
float4 sourceScale : register(c11);
float4 mapScale : register(c12);
sampler2D image : register(s0);
struct Output { float4 colour: TEXCOORD1; float2 uv: TEXCOORD0; float2 screen:TEXCOORD2; };
sampler2D secondImage : register(s1);
float2 userEffect(float2 uv, float4 m) {
    float4 light = p[0];
    float4 colour = p[1];
    float4 shape = p[2];
    float4 basisX = p[3];
    float4 basisY = p[4];
return uv;
}
float4 userColour(float4 c, float2 uv, float4 m) {
    float4 light = p[0];
    float4 colour = p[1];
    float4 shape = p[2];
    float4 basisX = p[3];
    float4 basisY = p[4];
float2 position=float2(dot(basisX.xy,uv)+basisX.z,dot(basisY.xy,uv)+basisY.z);
float3 delta=float3(light.xy-position,light.w);
float attenuation=1.0;
if (shape.x<0.0) {
 delta=light.xyz;
} else {
 attenuation=pow(max(0.0,1.0-length(delta.xy)/light.z),shape.x);
}
float3 n=float3(0.0,0.0,1.0);
if (shape.y>=0.0) {
 n=m.rgb*2.0-1.0;
 n.xy*=shape.y;
}
float a=basisX.x*basisX.w, b=basisX.y*basisY.w;
float d=basisY.x*basisX.w, e=basisY.y*basisY.w;
float determinant=a*e-b*d;
if (abs(determinant)>0.000001) {
 n=float3((e*n.x-d*n.y)/determinant,(-b*n.x+a*n.y)/determinant,n.z);
} else {
 n=float3(0.0,0.0,1.0);
}
n=n/max(length(n),0.000001);
float3 direction=delta/max(length(delta),0.000001);
float diffuse=max(0.0,dot(n,direction));
float3 halfway=direction+float3(0.0,0.0,1.0);
halfway=halfway/max(length(halfway),0.000001);
float specular=0.0;
if (diffuse>0.0 && shape.z>0.0) {
 specular=shape.z*pow(max(0.0,dot(n,halfway)),abs(shape.w));
 if(shape.w<0.0) specular*=clamp(m.a,0.0,1.0);
}
return float4((c.rgb*diffuse+float3(specular,specular,specular))*colour.rgb*colour.a*attenuation,c.a);
}
float4 sampleMap(float2 uv) {
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
        weight=lerp(weight,float2(0,0),step(weight,float2(0.000001,0.000001)));
        weight=lerp(weight,float2(1,1),step(float2(0.999999,0.999999),weight));
        float2 a=lo, b=lo+1.0;
        if(info.z>1.5) {
            a-=floor(a/size)*size;
            b-=floor(b/size)*size;
        } else {
            a=clamp(a,float2(0,0),size-1.0);
            b=clamp(b,float2(0,0),size-1.0);
        }
        float2 q=origin+a;
        float4 c00=tex2Dlod(secondImage,float4((q+0.5)*mapScale.zw,0,0));
        q=origin+float2(b.x,a.y);
        float4 c10=tex2Dlod(secondImage,float4((q+0.5)*mapScale.zw,0,0));
        q=origin+float2(a.x,b.y);
        float4 c01=tex2Dlod(secondImage,float4((q+0.5)*mapScale.zw,0,0));
        q=origin+b;
        float4 c11=tex2Dlod(secondImage,float4((q+0.5)*mapScale.zw,0,0));
        sampled=lerp(lerp(c00,c10,weight.x),lerp(c01,c11,weight.x),weight.y);
    } else {
        float2 q=origin+clamp(floor(uv*size),float2(0,0),size-1.0);
        sampled=tex2Dlod(secondImage,float4((q+0.5)*mapScale.zw,0,0));
    }
}
return sampled;
}
float4 sampleRegion(float2 uv) {
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
        weight=lerp(weight,float2(0,0),step(weight,float2(0.000001,0.000001)));
        weight=lerp(weight,float2(1,1),step(float2(0.999999,0.999999),weight));
        float2 a=lo, b=lo+1.0;
        if(info.z>1.5) {
            a-=floor(a/size)*size;
            b-=floor(b/size)*size;
        } else {
            a=clamp(a,float2(0,0),size-1.0);
            b=clamp(b,float2(0,0),size-1.0);
        }
        float2 q=origin+a;
        float4 c00=tex2Dlod(image,float4((q+0.5)*sourceScale.zw,0,0));
        q=origin+float2(b.x,a.y);
        float4 c10=tex2Dlod(image,float4((q+0.5)*sourceScale.zw,0,0));
        q=origin+float2(a.x,b.y);
        float4 c01=tex2Dlod(image,float4((q+0.5)*sourceScale.zw,0,0));
        q=origin+b;
        float4 c11=tex2Dlod(image,float4((q+0.5)*sourceScale.zw,0,0));
        sampled=lerp(lerp(c00,c10,weight.x),lerp(c01,c11,weight.x),weight.y);
    } else {
        float2 q=origin+clamp(floor(uv*size),float2(0,0),size-1.0);
        sampled=tex2Dlod(image,float4((q+0.5)*sourceScale.zw,0,0));
    }
}
return sampled;
}
float4 m2dEffectMain(Output input,float2 pixel:VPOS): COLOR0 {
input.uv+=ddx(input.uv)*(pixel.x-input.screen.x)+ddy(input.uv)*(pixel.y-input.screen.y);
float2 localUV=(input.uv-p[5].xy)/p[5].zw;
float4 m=sampleMap(localUV);
if(p[9].x!=0) m=float4(1,1,1,m.r);
if(p[9].y!=0) m.rgb=m.a>0?m.rgb/m.a:float3(0,0,0);
float4 c=sampleRegion(userEffect(localUV,m));
if(mode.x!=0) c=float4(1,1,1,c.r);
if(mode.y!=0) c.rgb=c.a>0?c.rgb/c.a:float3(0,0,0);
c*=input.colour;
c=userColour(c,(input.uv-p[5].xy)/p[5].zw,m);
c.a=clamp(c.a,0.0,1.0);
if(mode.z!=0 && c.a<0.5) discard;
if(mode.w!=0) c.rgb*=c.a;
return c;
}
