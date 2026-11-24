#version 120
uniform sampler2D image;
uniform int coverage, sourceTarget, sourcePremult, premultiply, mask;
uniform vec4 p[64];
varying vec4 tint;
varying vec2 texcoord;
uniform sampler2D secondImage;
uniform int secondTarget;
uniform sampler2D thirdImage;
uniform int thirdTarget;
vec4 m2dThirdTexel(vec2 pixel, vec2 texelSize) {
vec2 uv=(pixel+0.5)*texelSize;
if(thirdTarget!=0) uv.y=1.0-uv.y;
return texture2D(thirdImage,uv);
}
vec4 m2dMapTexel(vec2 pixel, vec2 texelSize) {
vec2 uv=(pixel+0.5)*texelSize;
if(secondTarget!=0) uv.y=1.0-uv.y;
return texture2D(secondImage,uv);
}
vec4 m2dTexel(vec2 pixel, vec2 texelSize) {
vec2 uv=(pixel+0.5)*texelSize;
if(sourceTarget!=0) uv.y=1.0-uv.y;
return texture2D(image,uv);
}
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
        vec4 c00=m2dThirdTexel(q,info.xy);
        q=origin+vec2(b.x,a.y);
        vec4 c10=m2dThirdTexel(q,info.xy);
        q=origin+vec2(a.x,b.y);
        vec4 c01=m2dThirdTexel(q,info.xy);
        q=origin+b;
        vec4 c11=m2dThirdTexel(q,info.xy);
        sampled=mix(mix(c00,c10,weight.x),mix(c01,c11,weight.x),weight.y);
    } else {
        vec2 q=origin+clamp(floor(uv*size),vec2(0,0),size-1.0);
        sampled=m2dThirdTexel(q,info.xy);
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
if(p[53].w>0.5) {
 position=vec2(dot(p[53].xy,pixel)+p[53].z,dot(p[54].xy,pixel)+p[54].z);
 vec2 ux=dFdx(uv), uy=dFdy(uv), qx=dFdx(pixel), qy=dFdy(pixel);
 vec2 px=vec2(dot(p[53].xy,qx),dot(p[54].xy,qx));
 vec2 py=vec2(dot(p[53].xy,qy),dot(p[54].xy,qy));
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
if(p[55].w>0.5) {
 sum=c.rgb*p[55].rgb;
 if(p[52].w>0.0) {
  vec4 emission=sampleThird(uv,p[60],p[61]);
  if(p[63].x!=0.0) emission=vec4(1.0,1.0,1.0,emission.a);
  if(p[63].y!=0.0) emission.rgb=emission.a>0.0?emission.rgb/emission.a:vec3(0.0,0.0,0.0);
  sum+=c.rgb*emission.rgb*emission.a*p[52].rgb*p[52].w;
 }

}

for(int i=0;i<8;++i) {
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
return vec4(sum*clamp(c.a,0.0,1.0),p[55].w>0.5?clamp(c.a,0.0,1.0):1.0);
}
vec4 sampleMap(vec2 uv) {
vec4 bounds=p[58], info=p[59];
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
        vec4 c00=m2dMapTexel(q,info.xy);
        q=origin+vec2(b.x,a.y);
        vec4 c10=m2dMapTexel(q,info.xy);
        q=origin+vec2(a.x,b.y);
        vec4 c01=m2dMapTexel(q,info.xy);
        q=origin+b;
        vec4 c11=m2dMapTexel(q,info.xy);
        sampled=mix(mix(c00,c10,weight.x),mix(c01,c11,weight.x),weight.y);
    } else {
        vec2 q=origin+clamp(floor(uv*size),vec2(0,0),size-1.0);
        sampled=m2dMapTexel(q,info.xy);
    }
}
return sampled;
}
vec4 sampleRegion(vec2 uv) {
vec4 bounds=p[56], info=p[57];
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
        vec4 c00=m2dTexel(q,info.xy);
        q=origin+vec2(b.x,a.y);
        vec4 c10=m2dTexel(q,info.xy);
        q=origin+vec2(a.x,b.y);
        vec4 c01=m2dTexel(q,info.xy);
        q=origin+b;
        vec4 c11=m2dTexel(q,info.xy);
        sampled=mix(mix(c00,c10,weight.x),mix(c01,c11,weight.x),weight.y);
    } else {
        vec2 q=origin+clamp(floor(uv*size),vec2(0,0),size-1.0);
        sampled=m2dTexel(q,info.xy);
    }
}
return sampled;
}
void main() {
vec2 localUV=(texcoord-p[56].xy)/p[56].zw;
vec4 m=sampleMap(localUV);
if(p[62].x!=0) m=vec4(1,1,1,m.a);
if(p[62].y!=0) m.rgb=m.a>0?m.rgb/m.a:vec3(0,0,0);
vec4 c=sampleRegion(localUV);
if(coverage!=0) c=vec4(1,1,1,c.a);
if(sourcePremult!=0) c.rgb=c.a>0?c.rgb/c.a:vec3(0);
c*=tint;
c=userColour(c,(texcoord-p[56].xy)/p[56].zw,m,vec2(gl_FragCoord.x,p[54].w-gl_FragCoord.y));
c.a=clamp(c.a,0.0,1.0);
if(mask!=0 && c.a<0.5) discard;
if(premultiply!=0) c.rgb*=c.a;
gl_FragColor=c;
}
