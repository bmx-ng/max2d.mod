#version 120
uniform sampler2D image;
uniform int coverage, sourceTarget, sourcePremult, premultiply, mask;
uniform vec4 p[9];
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
    vec4 channels = p[0];
    float invert = p[1].x;
return uv;
}
vec4 userColour(vec4 c, vec4 m) {
    vec4 channels = p[0];
    float invert = p[1].x;
float coverage=clamp(dot(m,channels),0.0,1.0);
if(invert>0.5) coverage=1.0-coverage;
return vec4(c.rgb,c.a*coverage);
}
vec4 sampleMap(vec2 uv) {
vec4 bounds=p[4], info=p[5];
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
vec4 bounds=p[2], info=p[3];
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
vec2 localUV=(texcoord-p[2].xy)/p[2].zw;
vec2 mapUV=vec2(dot(p[6].xy,localUV)+p[6].z,dot(p[7].xy,localUV)+p[7].z);
vec4 m=sampleMap(mapUV);
if(p[8].x!=0) m=vec4(1,1,1,m.a);
if(p[8].y!=0) m.rgb=m.a>0?m.rgb/m.a:vec3(0,0,0);
vec4 c=sampleRegion(userEffect(localUV,m));
if(coverage!=0) c=vec4(1,1,1,c.a);
if(sourcePremult!=0) c.rgb=c.a>0?c.rgb/c.a:vec3(0);
c*=tint;
c=userColour(c,m);
c.a=clamp(c.a,0.0,1.0);
if(mask!=0 && c.a<0.5) discard;
if(premultiply!=0) c.rgb*=c.a;
gl_FragColor=c;
}
