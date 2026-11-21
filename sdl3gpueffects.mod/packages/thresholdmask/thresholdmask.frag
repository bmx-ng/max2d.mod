#version 450
layout(location=0) in vec4 tint;
layout(location=1) in vec2 texcoord;
layout(location=0) out vec4 result;
layout(set=2,binding=0) uniform sampler2D image;
layout(set=3,binding=0) uniform Modes { vec4 mode; };
layout(set=3,binding=1) uniform Parameters { vec4 p[10]; };
layout(set=2,binding=1) uniform sampler2D secondImage;
vec2 userEffect(vec2 uv, vec4 m) {
    vec4 channels = p[0];
    vec4 range = p[1];
    float invert = p[2].x;
return uv;
}
vec4 userColour(vec4 c, vec4 m) {
    vec4 channels = p[0];
    vec4 range = p[1];
    float invert = p[2].x;
float value=clamp(dot(m,channels),0.0,1.0);
float coverage;
if(range.y>range.x) coverage=smoothstep(range.x,range.y,value);
else coverage=step(range.x,value);
if(invert>0.5) coverage=1.0-coverage;
return vec4(c.rgb,c.a*coverage);
}
vec4 sampleMap(vec2 uv) {
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
vec4 bounds=p[3], info=p[4];
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
vec2 localUV=(texcoord-p[3].xy)/p[3].zw;
vec2 mapUV=vec2(dot(p[7].xy,localUV)+p[7].z,dot(p[8].xy,localUV)+p[8].z);
vec4 m=sampleMap(mapUV);
if(p[9].x!=0) m=vec4(1,1,1,m.r);
if(p[9].y!=0) m.rgb=m.a>0?m.rgb/m.a:vec3(0,0,0);
vec4 c=sampleRegion(userEffect(localUV,m));
if(mode.x!=0) c=vec4(1,1,1,c.r);
if(mode.y!=0) c.rgb=c.a>0?c.rgb/c.a:vec3(0);
c*=tint;
c=userColour(c,m);
c.a=clamp(c.a,0.0,1.0);
if(mode.z!=0 && c.a<0.5) discard;
if(mode.w!=0) c.rgb*=c.a;
result=c;
}
