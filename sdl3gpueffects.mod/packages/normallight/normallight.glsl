#version 120
uniform sampler2D image;
uniform int coverage, sourceTarget, sourcePremult, premultiply, mask;
uniform vec4 p[10];
varying vec4 tint;
varying vec2 texcoord;
uniform sampler2D secondImage;
uniform int secondTarget;
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
vec2 userEffect(vec2 uv, vec4 m) {
    vec4 light = p[0];
    vec4 colour = p[1];
    vec4 shape = p[2];
    vec4 basisX = p[3];
    vec4 basisY = p[4];
return uv;
}
vec4 userColour(vec4 c, vec2 uv, vec4 m) {
    vec4 light = p[0];
    vec4 colour = p[1];
    vec4 shape = p[2];
    vec4 basisX = p[3];
    vec4 basisY = p[4];
vec2 position=vec2(dot(basisX.xy,uv)+basisX.z,dot(basisY.xy,uv)+basisY.z);
vec3 delta=vec3(light.xy-position,light.w);
float attenuation=1.0;
if (shape.x<0.0) {
 delta=light.xyz;
} else {
 attenuation=pow(max(0.0,1.0-length(delta.xy)/light.z),shape.x);
}
vec3 n=vec3(0.0,0.0,1.0);
if (shape.y>=0.0) {
 n=m.rgb*2.0-1.0;
 n.xy*=shape.y;
}
float a=basisX.x*basisX.w, b=basisX.y*basisY.w;
float d=basisY.x*basisX.w, e=basisY.y*basisY.w;
float determinant=a*e-b*d;
if (abs(determinant)>0.000001) {
 n=vec3((e*n.x-d*n.y)/determinant,(-b*n.x+a*n.y)/determinant,n.z);
} else {
 n=vec3(0.0,0.0,1.0);
}
n=n/max(length(n),0.000001);
vec3 direction=delta/max(length(delta),0.000001);
float diffuse=max(0.0,dot(n,direction));
vec3 halfway=direction+vec3(0.0,0.0,1.0);
halfway=halfway/max(length(halfway),0.000001);
float specular=0.0;
if (diffuse>0.0 && shape.z>0.0) {
 specular=shape.z*pow(max(0.0,dot(n,halfway)),abs(shape.w));
 if(shape.w<0.0) specular*=clamp(m.a,0.0,1.0);
}
return vec4((c.rgb*diffuse+vec3(specular))*colour.rgb*colour.a*attenuation,c.a);
}
vec4 sampleMap(vec2 uv) {
vec4 bounds=p[7], info=p[8];
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
vec4 bounds=p[5], info=p[6];
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
vec2 localUV=(texcoord-p[5].xy)/p[5].zw;
vec4 m=sampleMap(localUV);
if(p[9].x!=0) m=vec4(1,1,1,m.a);
if(p[9].y!=0) m.rgb=m.a>0?m.rgb/m.a:vec3(0,0,0);
vec4 c=sampleRegion(userEffect(localUV,m));
if(coverage!=0) c=vec4(1,1,1,c.a);
if(sourcePremult!=0) c.rgb=c.a>0?c.rgb/c.a:vec3(0);
c*=tint;
c=userColour(c,(texcoord-p[5].xy)/p[5].zw,m);
c.a=clamp(c.a,0.0,1.0);
if(mask!=0 && c.a<0.5) discard;
if(premultiply!=0) c.rgb*=c.a;
gl_FragColor=c;
}
