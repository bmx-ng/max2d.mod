#version 450
layout(location=0) in vec4 tint;
layout(location=1) in vec2 texcoord;
layout(location=0) out vec4 result;
layout(set=2,binding=0) uniform sampler2D image;
layout(set=3,binding=0) uniform Modes { vec4 mode; };
layout(set=3,binding=1) uniform Parameters { vec4 p[115]; };
layout(set=2,binding=1) uniform sampler2D secondImage;
layout(set=2,binding=2) uniform sampler2D thirdImage;
layout(set=2,binding=3) uniform sampler2D fourthImage;
vec4 sampleThird(vec2 uv, vec4 bounds, vec4 info) {

vec2 origin=floor(bounds.xy/info.xy+0.5);
vec2 size=floor(bounds.zw/info.xy+0.5);
vec4 sampled=vec4(0,0,0,0);
bool outside=uv.x<0.0 || uv.y<0.0 || uv.x>=1.0 || uv.y>=1.0;
if(info.z>=0.5 || !outside) {
    if(info.z>1.5) uv=uv-floor(uv);
    else uv=clamp(uv,vec2(0,0),vec2(1,1));
    if(info.w>0.5) {
        vec2 pixel=uv*size-0.5;
        vec2 lo=floor(pixel), weight=pixel-lo;
        vec2 a=lo, b=lo+1.0;
        if(info.z>1.5) {
            a-=floor(a/size)*size;
            b-=floor(b/size)*size;
        } else {
            a=clamp(a,vec2(0,0),size-1.0);
            b=clamp(b,vec2(0,0),size-1.0);
        }
        vec2 q=origin+a;
        vec4 c00=texelFetch(thirdImage,ivec2(q),0);
        q=origin+vec2(b.x,a.y);
        vec4 c10=texelFetch(thirdImage,ivec2(q),0);
        q=origin+vec2(a.x,b.y);
        vec4 c01=texelFetch(thirdImage,ivec2(q),0);
        q=origin+b;
        vec4 c11=texelFetch(thirdImage,ivec2(q),0);
        sampled=mix(mix(c00,c10,weight.x),mix(c01,c11,weight.x),weight.y);
    } else {
        vec2 q=origin+clamp(floor(uv*size),vec2(0,0),size-1.0);
        sampled=texelFetch(thirdImage,ivec2(q),0);
    }
}
return sampled;
}
vec4 sampleFourth(vec2 uv, vec4 bounds, vec4 info) {

vec2 origin=floor(bounds.xy/info.xy+0.5);
vec2 size=floor(bounds.zw/info.xy+0.5);
vec4 sampled=vec4(0,0,0,0);
bool outside=uv.x<0.0 || uv.y<0.0 || uv.x>=1.0 || uv.y>=1.0;
if(info.z>=0.5 || !outside) {
    if(info.z>1.5) uv=uv-floor(uv);
    else uv=clamp(uv,vec2(0,0),vec2(1,1));
    if(info.w>0.5) {
        vec2 pixel=uv*size-0.5;
        vec2 lo=floor(pixel), weight=pixel-lo;
        vec2 a=lo, b=lo+1.0;
        if(info.z>1.5) {
            a-=floor(a/size)*size;
            b-=floor(b/size)*size;
        } else {
            a=clamp(a,vec2(0,0),size-1.0);
            b=clamp(b,vec2(0,0),size-1.0);
        }
        vec2 q=origin+a;
        vec4 c00=texelFetch(fourthImage,ivec2(q),0);
        q=origin+vec2(b.x,a.y);
        vec4 c10=texelFetch(fourthImage,ivec2(q),0);
        q=origin+vec2(a.x,b.y);
        vec4 c01=texelFetch(fourthImage,ivec2(q),0);
        q=origin+b;
        vec4 c11=texelFetch(fourthImage,ivec2(q),0);
        sampled=mix(mix(c00,c10,weight.x),mix(c01,c11,weight.x),weight.y);
    } else {
        vec2 q=origin+clamp(floor(uv*size),vec2(0,0),size-1.0);
        sampled=texelFetch(fourthImage,ivec2(q),0);
    }
}
return sampled;
}
vec4 userColour(vec4 c, vec2 uv, vec4 m, vec2 pixel) {
vec4 basisX=p[0], basisY=p[1], material=p[2];
vec2 position=vec2(dot(basisX.xy,uv)+basisX.z,dot(basisY.xy,uv)+basisY.z);
vec3 n=vec3(0.0,0.0,1.0);
if(material.x>=0.0) { n=m.rgb*2.0-1.0; n.xy*=material.x; }
float a=basisX.x*basisX.w, b=basisX.y*basisY.w;
float d=basisY.x*basisX.w, e=basisY.y*basisY.w;
if(p[101].w>0.5) {
 position=vec2(dot(p[101].xy,pixel)+p[101].z,dot(p[102].xy,pixel)+p[102].z);
 vec2 ux=dFdx(uv), uy=dFdy(uv), qx=dFdx(pixel), qy=dFdy(pixel);
 vec2 px=vec2(dot(p[101].xy,qx),dot(p[102].xy,qx));
 vec2 py=vec2(dot(p[101].xy,qy),dot(p[102].xy,qy));
 float det=ux.x*uy.y-ux.y*uy.x;
 if(abs(det)>1.0e-20) {
 a=(px.x*uy.y-py.x*ux.y)/det*basisX.w;
 b=(py.x*ux.x-px.x*uy.x)/det*basisY.w;
 d=(px.y*uy.y-py.y*ux.y)/det*basisX.w;
 e=(py.y*ux.x-px.y*uy.x)/det*basisY.w;
 } else { a=0.0;b=0.0;d=0.0;e=0.0; }
}
float determinant=a*e-b*d;
if(abs(determinant)>0.000001) n=vec3((e*n.x-d*n.y)/determinant,(-b*n.x+a*n.y)/determinant,n.z);
else n=vec3(0.0,0.0,1.0);
n=n/max(length(n),0.000001);
vec3 sum=vec3(0.0,0.0,0.0);
if(p[103].w>0.5) {
 sum=c.rgb*p[103].rgb;
 if(p[100].w>0.0) {
  vec4 emission=sampleFourth(uv,p[110],p[111]);
  if(p[114].x!=0.0) emission=vec4(1.0,1.0,1.0,emission.r);
  if(p[114].y!=0.0) emission.rgb=emission.a>0.0?emission.rgb/emission.a:vec3(0.0,0.0,0.0);
  sum+=c.rgb*emission.rgb*emission.a*p[100].rgb*p[100].w;
 }

}

for(int i=0;i<16;++i) {
 if(float(i)>=p[3].x) break;
 vec4 light=p[4+i*6], colour=p[5+i*6], shape=p[6+i*6];
 vec3 delta=vec3(light.xy-position,light.w);
 float attenuation=1.0;
 if(shape.x<0.0) delta=light.xyz;
 else attenuation=pow(max(0.0,1.0-length(delta.xy)/light.z),shape.x);
 float diffuse=1.0, specular=0.0;
 if(material.x>-1.5) {
  vec3 direction=delta/max(length(delta),0.000001);
  diffuse=max(0.0,dot(n,direction));
  if(diffuse>0.0 && material.y>0.0) {
   vec3 halfway=direction+vec3(0.0,0.0,1.0);
   halfway=halfway/max(length(halfway),0.000001);
   specular=material.y*pow(max(0.0,dot(n,halfway)),material.z);
   if(material.w>0.5) specular*=clamp(m.a,0.0,1.0);
  }
 }
 vec3 contribution=(c.rgb*diffuse+vec3(specular,specular,specular))*colour.rgb*colour.a*attenuation;
 if(shape.y>0.5) {
  vec4 mapX=p[7+i*6], mapY=p[8+i*6], tile=p[9+i*6];
  vec2 mapUV=vec2(dot(mapX.xy,position)+mapX.z,dot(mapY.xy,position)+mapY.z);
  vec4 visibility=sampleThird(mapUV,tile,vec4(p[3].zw,shape.zw));
  if(mapX.w<0.5) visibility.rgb*=visibility.a;
  contribution*=visibility.rgb;
 }
 if(p[3].y>0.5) contribution=clamp(contribution,0.0,1.0);
 sum+=contribution;
}
return vec4(sum*clamp(c.a,0.0,1.0),p[103].w>0.5?clamp(c.a,0.0,1.0):1.0);
}
vec4 sampleMap(vec2 uv) {
vec4 bounds=p[106], info=p[107];
vec2 origin=floor(bounds.xy/info.xy+0.5);
vec2 size=floor(bounds.zw/info.xy+0.5);
vec4 sampled=vec4(0,0,0,0);
bool outside=uv.x<0.0 || uv.y<0.0 || uv.x>=1.0 || uv.y>=1.0;
if(info.z>=0.5 || !outside) {
    if(info.z>1.5) uv=uv-floor(uv);
    else uv=clamp(uv,vec2(0,0),vec2(1,1));
    if(info.w>0.5) {
        vec2 pixel=uv*size-0.5;
        vec2 lo=floor(pixel), weight=pixel-lo;
        vec2 a=lo, b=lo+1.0;
        if(info.z>1.5) {
            a-=floor(a/size)*size;
            b-=floor(b/size)*size;
        } else {
            a=clamp(a,vec2(0,0),size-1.0);
            b=clamp(b,vec2(0,0),size-1.0);
        }
        vec2 q=origin+a;
        vec4 c00=texelFetch(secondImage,ivec2(q),0);
        q=origin+vec2(b.x,a.y);
        vec4 c10=texelFetch(secondImage,ivec2(q),0);
        q=origin+vec2(a.x,b.y);
        vec4 c01=texelFetch(secondImage,ivec2(q),0);
        q=origin+b;
        vec4 c11=texelFetch(secondImage,ivec2(q),0);
        sampled=mix(mix(c00,c10,weight.x),mix(c01,c11,weight.x),weight.y);
    } else {
        vec2 q=origin+clamp(floor(uv*size),vec2(0,0),size-1.0);
        sampled=texelFetch(secondImage,ivec2(q),0);
    }
}
return sampled;
}
vec4 sampleRegion(vec2 uv) {
vec4 bounds=p[104], info=p[105];
vec2 origin=floor(bounds.xy/info.xy+0.5);
vec2 size=floor(bounds.zw/info.xy+0.5);
vec4 sampled=vec4(0,0,0,0);
bool outside=uv.x<0.0 || uv.y<0.0 || uv.x>=1.0 || uv.y>=1.0;
if(info.z>=0.5 || !outside) {
    if(info.z>1.5) uv=uv-floor(uv);
    else uv=clamp(uv,vec2(0,0),vec2(1,1));
    if(info.w>0.5) {
        vec2 pixel=uv*size-0.5;
        vec2 lo=floor(pixel), weight=pixel-lo;
        vec2 a=lo, b=lo+1.0;
        if(info.z>1.5) {
            a-=floor(a/size)*size;
            b-=floor(b/size)*size;
        } else {
            a=clamp(a,vec2(0,0),size-1.0);
            b=clamp(b,vec2(0,0),size-1.0);
        }
        vec2 q=origin+a;
        vec4 c00=texelFetch(image,ivec2(q),0);
        q=origin+vec2(b.x,a.y);
        vec4 c10=texelFetch(image,ivec2(q),0);
        q=origin+vec2(a.x,b.y);
        vec4 c01=texelFetch(image,ivec2(q),0);
        q=origin+b;
        vec4 c11=texelFetch(image,ivec2(q),0);
        sampled=mix(mix(c00,c10,weight.x),mix(c01,c11,weight.x),weight.y);
    } else {
        vec2 q=origin+clamp(floor(uv*size),vec2(0,0),size-1.0);
        sampled=texelFetch(image,ivec2(q),0);
    }
}
return sampled;
}
void main() {
vec2 localUV=(texcoord-p[104].xy)/p[104].zw;
vec4 m=sampleMap(localUV);
if(p[112].x!=0) m=vec4(1,1,1,m.r);
if(p[112].y!=0) m.rgb=m.a>0?m.rgb/m.a:vec3(0,0,0);
vec4 c=sampleRegion(localUV);
if(mode.x!=0) c=vec4(1,1,1,c.r);
if(mode.y!=0) c.rgb=c.a>0?c.rgb/c.a:vec3(0);
c*=tint;
c=userColour(c,(texcoord-p[104].xy)/p[104].zw,m,gl_FragCoord.xy);
c.a=clamp(c.a,0.0,1.0);
if(mode.z!=0 && c.a<0.5) discard;
if(mode.w!=0) c.rgb*=c.a;
result=c;
}
